import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/db/chat_dao.dart';
import '../../core/services/media_cache_service.dart';
import '../../core/services/storage_info_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/audio_message_kind.dart';
import '../../core/utils/backend_url.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/conversation_display.dart';
import '../../core/utils/document_file_style.dart';
import '../../core/utils/forward_message.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/chat_provider.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/video_message_preview.dart';
import '../chats/forward_message_screen.dart';
import '../chats/media_viewer_screen.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/error_presenter.dart';
import 'export_period_sheet.dart';
import '../../core/services/media_expiry_policy.dart';

/// Miroir, pour l'avertissement de suppression uniquement, de
/// `MEDIA_RETENTION_DAYS` côté serveur (`mediaRetentionPolicy.js`, défaut 30
/// jours). Purement indicatif : la vraie valeur est réglable par variable
/// d'environnement serveur et le client ne peut pas la connaître avec
/// certitude — ça sert juste à distinguer « sûrement encore sur le serveur »
/// de « peut-être déjà purgé », pour affiner le texte de confirmation.
const _kMediaRetentionDaysHeuristic = 30;

/// Ordre d'affichage de la grille.
enum _MediaSort { recent, largest }

/// Origine des médias affichés.
enum _MediaOwner { received, sent, all }

/// Famille de médias affichée. Le découpage suit ce que l'utilisateur cherche
/// (« mes photos », « ce vocal ») et non les types serveur : [_MediaKind.all]
/// se traduit par la liste complète des types listables, pas par l'absence de
/// filtre, pour que la requête reste bornée aux messages porteurs de fichier.
enum _MediaKind { all, photos, videos, audio, files }

extension on _MediaKind {
  /// Types de message correspondants (voir `LocalMessages.type`).
  List<int> get types => switch (this) {
        _MediaKind.all => kMyMediaTypes,
        _MediaKind.photos => const [1],
        _MediaKind.videos => const [2],
        _MediaKind.audio => const [3],
        _MediaKind.files => const [4],
      };

  /// Types emportés par une **archive**. Identiques à [types], sauf « Tout » :
  /// une archive part du principe inverse de la grille — elle référence aussi
  /// les stickers (type 10), qui n'ont pourtant pas de copie locale à gérer. Une
  /// famille précise (photos, vidéos…) reste sans stickers : le choix explicite
  /// de l'inscrit prime.
  List<int> get exportTypes =>
      this == _MediaKind.all ? kExportMediaTypes : types;

  String label(AppLocalizations l10n) => switch (this) {
        _MediaKind.all => l10n.myMediaKindAll,
        _MediaKind.photos => l10n.myMediaKindPhotos,
        _MediaKind.videos => l10n.myMediaKindVideos,
        _MediaKind.audio => l10n.myMediaKindAudio,
        _MediaKind.files => l10n.myMediaKindFiles,
      };
}

/// Discussion retenue par le filtre. Le libellé est figé au moment du choix :
/// le résoudre à chaque build imposerait de garder la [LocalConversation]
/// entière en mémoire pour un texte de bouton.
class _DiscussionFilter {
  final int conversationID;
  final String label;
  const _DiscussionFilter(this.conversationID, this.label);
}

/// Enveloppe le résultat du sélecteur de discussion : `null` renvoyé par la
/// feuille modale signifie « fermée sans choisir », ce qui n'est pas la même
/// chose que « toutes les discussions » — d'où ce niveau d'indirection.
class _DiscussionChoice {
  final _DiscussionFilter? filter;
  const _DiscussionChoice(this.filter);
}

/// Une journée de médias, ou la totalité quand le tri par poids rend les dates
/// sans objet.
class _MediaGroup {
  final String? label;
  final List<MyMediaItem> items;

  const _MediaGroup({required this.label, required this.items});
}

/// Grille des médias **réellement présents sur l'appareil**, doublée d'un
/// outil de gestion du stockage : origine, poids et date de chaque élément,
/// tri par taille, filtres discussion / période / famille, et sélection
/// multiple pour libérer de la place ou transférer.
///
/// Source de vérité : la base locale (Drift), pas le serveur — un média reçu
/// mais jamais téléchargé (auto-téléchargement désactivé, échec de
/// téléchargement…) n'apparaît jamais ici, seulement une fois
/// `localMediaPath` renseigné, que ce soit via le téléchargement automatique
/// ou manuel. Ça fonctionne donc entièrement hors connexion.
class MyMediaScreen extends StatefulWidget {
  const MyMediaScreen({super.key});

  @override
  State<MyMediaScreen> createState() => _MyMediaScreenState();
}

class _MyMediaScreenState extends State<MyMediaScreen> {
  final _items = <MyMediaItem>[];

  /// msgID des éléments cochés. Vide = mode consultation.
  final _selected = <int>{};

  _MediaSort _sort = _MediaSort.recent;

  /// Tous par défaut : « Mes médias » doit contenir tous les médias de
  /// l'utilisateur (envoyés comme reçus). Les pastilles Reçus/Envoyés
  /// permettent de resserrer le périmètre.
  _MediaOwner _owner = _MediaOwner.all;

  _MediaKind _kind = _MediaKind.all;

  /// Discussion retenue, `null` = toutes.
  _DiscussionFilter? _discussion;

  /// Période retenue, `null` = pas de borne. Bornes inclusives à la journée :
  /// la conversion en bornes SQL (dont la fin exclusive) se fait dans
  /// [_subscribe].
  DateTimeRange? _period;

  /// Panneau de filtres déplié. Ouvert d'entrée : replié, il ne se distingue
  /// pas d'un écran sans filtres et personne ne le cherche.
  bool _filtersOpen = true;

  StreamSubscription<List<LocalMediaRow>>? _sub;
  bool _initial = true;
  bool _working = false;
  String? _error;

  /// Octets décodés des vignettes base64, par msgID. Évite de re-décoder à
  /// chaque build (Image.memory est keyé sur l'identité des octets) et borne
  /// la mémoire (~15 Ko par vignette).
  final _thumbBytes = <int, Uint8List>{};

  bool get _selecting => _selected.isNotEmpty;

  /// Un filtre au moins écarte des médias — sert à proposer la remise à zéro
  /// plutôt qu'un « aucun média » qui laisserait croire le téléphone vide.
  bool get _filtered =>
      _discussion != null ||
      _period != null ||
      _kind != _MediaKind.all ||
      _owner != _MediaOwner.all;

  @override
  void initState() {
    super.initState();
    _subscribe();
    // Le compteur d'espace en tête vient du même service que l'écran
    // Paramètres › Stockage, pour que les deux affichent la même valeur.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<StorageInfoService>().refresh();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// (Ré)abonnement à la base locale selon les filtres courants. Appelé à
  /// l'ouverture et à chaque changement de filtre : le tri, lui, se fait en
  /// mémoire (voir [_onRows]), inutile de se réabonner pour ça.
  void _subscribe() {
    _sub?.cancel();
    _thumbBytes.clear();
    final dao = context.read<ChatProvider>().repository.dao;
    final myId = context.read<ChatProvider>().repository.myId;
    bool? mineOnly;
    if (_owner == _MediaOwner.sent) mineOnly = true;
    if (_owner == _MediaOwner.received) mineOnly = false;

    final period = _period;
    // Bornes de journée : « du 1er au 31 mars » doit contenir un média envoyé
    // le 31 à 14 h, d'où la fin exclusive au lendemain minuit.
    final from = period == null ? null : _startOfDay(period.start);
    final until = period == null
        ? null
        : _startOfDay(period.end).add(const Duration(days: 1));

    setState(() {
      _initial = true;
      _error = null;
    });
    _sub = dao
        .watchLocalMedia(
      myId,
      mineOnly: mineOnly,
      conversationID: _discussion?.conversationID,
      from: from,
      until: until,
      types: _kind.types,
    )
        .listen(
      _onRows,
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _initial = false;
          _error = presenterErreur(context.l10n, e, domaine: ErrorDomain.media);
        });
      },
    );
  }

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Convertit les lignes locales en [MyMediaItem] pour l'affichage, en
  /// vérifiant au passage que le fichier annoncé existe encore réellement sur
  /// le disque — la base peut mentir si le fichier a été effacé hors de
  /// l'app (nettoyage du système, gestionnaire de fichiers…). Un fichier
  /// manquant est désynchronisé de la base plutôt que laissé à pointer dans
  /// le vide.
  ///
  /// La même visite du disque sert à **rattraper les tailles manquantes**
  /// (voir [ChatDao.setMediaSize]) : un `stat` renseigne l'existence et le
  /// poids d'un seul appel système, là où le contrôle d'existence seul en
  /// coûtait déjà autant. Le rattrapage est donc gratuit.
  void _onRows(List<LocalMediaRow> rows) {
    final dao = context.read<ChatProvider>().repository.dao;
    final myId = context.read<ChatProvider>().repository.myId;
    final items = <MyMediaItem>[];
    for (final row in rows) {
      final msg = row.message;
      final path = msg.localMediaPath;
      if (path == null) continue;
      final stat = FileStat.statSync(path);
      if (stat.type == FileSystemEntityType.notFound) {
        unawaited(dao.clearLocalMediaPath(msg.msgID));
        continue;
      }
      // Taille connue de la base, ou mesurée ici puis réécrite pour que la
      // grille, le tri par poids et le total cessent définitivement de
      // compter ce média pour zéro octet.
      var size = msg.mediaSize;
      if (size == null || size <= 0) {
        size = stat.size;
        unawaited(dao.setMediaSize(msg.clientId, size));
      }
      items.add(MyMediaItem(
        msgID: msg.msgID,
        conversationID: msg.conversationID,
        senderID: msg.senderID,
        isMine: msg.senderID == myId,
        senderName: row.senderName,
        type: msg.type,
        mediaUrl: msg.mediaUrl ?? '',
        mediaName: msg.mediaName,
        mediaThumb: msg.mediaThumb,
        mediaDuration: msg.mediaDuration,
        // Taille mesurée, pas celle de la base : l'écriture de rattrapage est
        // asynchrone, attendre son retour par le flux ferait clignoter un
        // « 0 o » le temps d'un aller-retour.
        mediaSize: size,
        sendAt: msg.sendAt,
        localMediaPath: path,
      ));
    }
    if (_sort == _MediaSort.largest) {
      items.sort((a, b) => (b.mediaSize ?? 0).compareTo(a.mediaSize ?? 0));
    }
    // Tri "récent" déjà assuré par l'ORDER BY sendAt DESC de la requête.

    if (!mounted) return;
    setState(() {
      _items
        ..clear()
        ..addAll(items);
      // Une sélection portant sur des éléments qui ne sont plus chargés
      // n'aurait plus de sens.
      _selected.removeWhere((id) => items.every((i) => i.msgID != id));
      _initial = false;
    });
  }

  /// Force une nouvelle vérification d'existence des fichiers (voir
  /// [_onRows]) : utile si des fichiers ont été effacés hors de l'app depuis
  /// le dernier passage, ce dont la base ne peut pas être informée toute
  /// seule.
  Future<void> _reload() async {
    _subscribe();
  }

  Future<void> _changeSort(_MediaSort sort) async {
    if (sort == _sort) return;
    setState(() => _sort = sort);
    // Le jeu d'éléments ne change pas, seul l'ordre : pas besoin de
    // réabonnement, un tri en mémoire suffit à partir de la liste courante.
    final current = List<MyMediaItem>.from(_items);
    if (sort == _MediaSort.largest) {
      current.sort((a, b) => (b.mediaSize ?? 0).compareTo(a.mediaSize ?? 0));
    } else {
      current.sort((a, b) =>
          (b.sendAt ?? DateTime(0)).compareTo(a.sendAt ?? DateTime(0)));
    }
    setState(() {
      _items
        ..clear()
        ..addAll(current);
    });
  }

  Future<void> _changeOwner(_MediaOwner owner) async {
    if (owner == _owner) return;
    setState(() => _owner = owner);
    _subscribe();
  }

  void _changeKind(_MediaKind kind) {
    if (kind == _kind) return;
    setState(() => _kind = kind);
    _subscribe();
  }

  void _resetFilters() {
    setState(() {
      _kind = _MediaKind.all;
      _owner = _MediaOwner.all;
      _discussion = null;
      _period = null;
    });
    _subscribe();
  }

  // ── Filtre discussion ────────────────────────────────────────────────

  /// Ne propose que les discussions qui ont réellement un média sur
  /// l'appareil : la liste complète offrirait des choix qui n'affichent rien,
  /// ce qui se lit comme un bug et non comme un filtre vide.
  Future<void> _pickDiscussion() async {
    final chat = context.read<ChatProvider>();
    final myId = chat.repository.myId;
    final dao = chat.repository.dao;

    setState(() => _working = true);
    final convs = await dao.watchConversations().first;
    final withMedia = await dao.conversationIdsWithLocalMedia(myId);
    if (!mounted) return;
    setState(() => _working = false);

    final candidates =
        convs.where((c) => withMedia.contains(c.conversID)).toList();
    final choice = await showModalBottomSheet<_DiscussionChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => _DiscussionPickerSheet(
        conversations: candidates,
        myId: myId,
        selectedId: _discussion?.conversationID,
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _discussion = choice.filter);
    _subscribe();
  }

  // ── Filtre période ───────────────────────────────────────────────────

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      // Antérieure à l'app elle-même : la borne basse ne doit jamais couper
      // dans l'historique, quel qu'il soit.
      firstDate: DateTime(2015),
      lastDate: _startOfDay(now),
      initialDateRange: _period,
      helpText: context.l10n.myMediaFilterPeriod,
    );
    if (range == null || !mounted) return;
    setState(() => _period = range);
    _subscribe();
  }

  /// Raccourci « n derniers jours », borné à aujourd'hui.
  void _setLastDays(int days) {
    final today = _startOfDay(DateTime.now());
    setState(() => _period = DateTimeRange(
          start: today.subtract(Duration(days: days - 1)),
          end: today,
        ));
    _subscribe();
  }

  void _setThisYear() {
    final today = _startOfDay(DateTime.now());
    setState(() => _period = DateTimeRange(
          start: DateTime(today.year, 1, 1),
          end: today,
        ));
    _subscribe();
  }

  void _clearPeriod() {
    if (_period == null) return;
    setState(() => _period = null);
    _subscribe();
  }

  // ── Regroupement ─────────────────────────────────────────────────────

  /// Une section par journée en tri chronologique. En tri par poids l'ordre
  /// n'est plus temporel : un en-tête de date y serait faux, on n'en met pas.
  List<_MediaGroup> _buildGroups() {
    if (_items.isEmpty) return const [];
    if (_sort == _MediaSort.largest) {
      return [_MediaGroup(label: null, items: _items)];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <_MediaGroup>[];
    var current = <MyMediaItem>[];
    String? currentLabel;

    for (final item in _items) {
      final sentAt = item.sendAt;
      final label = sentAt == null ? '' : _dayLabel(sentAt, today, yesterday);
      if (current.isNotEmpty && currentLabel != label) {
        groups.add(_MediaGroup(
          label: currentLabel!.isEmpty ? null : currentLabel,
          items: current,
        ));
        current = <MyMediaItem>[];
      }
      currentLabel = label;
      current.add(item);
    }
    if (current.isNotEmpty) {
      groups.add(_MediaGroup(
        label: (currentLabel ?? '').isEmpty ? null : currentLabel,
        items: current,
      ));
    }
    return groups;
  }

  String _dayLabel(DateTime at, DateTime today, DateTime yesterday) {
    final date = DateTime(at.year, at.month, at.day);
    if (date == today) return context.l10n.today;
    if (date == yesterday) return context.l10n.yesterday;
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // ── Sélection ────────────────────────────────────────────────────────

  void _toggle(MyMediaItem item) {
    setState(() {
      if (!_selected.remove(item.msgID)) _selected.add(item.msgID);
    });
  }

  void _clearSelection() => setState(_selected.clear);

  void _selectAll() =>
      setState(() => _selected.addAll(_items.map((i) => i.msgID)));

  List<MyMediaItem> get _selectedItems =>
      _items.where((i) => _selected.contains(i.msgID)).toList();

  // ── Actions ──────────────────────────────────────────────────────────

  /// Supprime la copie locale des médias cochés : ils disparaissent de « Mes
  /// médias » (qui ne liste que ce qui est téléchargé) et redeviennent, dans
  /// leur conversation, un média à retélécharger. Le message et le fichier
  /// distant ne sont pas touchés — sauf si le fichier distant a déjà été
  /// purgé côté serveur (rétention 30 jours), auquel cas cette suppression
  /// devient définitive : voir l'avertissement adapté ci-dessous.
  Future<void> _freeSpace() async {
    final l10n = context.l10n;
    final targets = _selectedItems;
    if (targets.isEmpty) return;

    final maybeGone = targets.any((i) =>
        i.sendAt != null &&
        DateTime.now().difference(i.sendAt!).inDays >
            _kMediaRetentionDaysHeuristic);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.myMediaFreeSpace),
        content: Text(maybeGone
            ? l10n.myMediaFreeSpaceConfirmMaybeGone
            : l10n.myMediaFreeSpaceConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _working = true);
    final cache = MediaCacheService();
    final dao = context.read<ChatProvider>().repository.dao;
    var freed = 0;
    for (final item in targets) {
      final bytes = await cache.removeForUrl(item.mediaUrl);
      if (bytes > 0) {
        freed += bytes;
      }
      // Le chemin local pointait sur le fichier qu'on vient d'effacer (ou
      // sur un fichier hors du cache géré par [MediaCacheService], selon
      // l'origine du téléchargement) : le laisser en base ferait échouer
      // l'ouverture de la bulle dans la conversation.
      await dao.clearLocalMediaPath(item.msgID);
    }
    if (!mounted) return;

    setState(() {
      _working = false;
      _selected.clear();
    });
    await context.read<StorageInfoService>().refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          freed > 0
              ? l10n.myMediaFreedSpace(formatBytes(freed, l10n))
              : l10n.myMediaNothingCached,
        ),
      ),
    );
  }

  Future<void> _forward() async {
    final l10n = context.l10n;
    final ids = _selectedItems.map((i) => i.msgID).toList();
    if (ids.isEmpty) return;

    setState(() => _working = true);
    final dao = context.read<ChatProvider>().repository.dao;
    final rows = await dao.messagesByIds(ids);
    if (!mounted) return;
    setState(() => _working = false);

    // Un média peut avoir quitté le cache local (historique masqué, purge) :
    // l'API le connaît encore, pas la base Drift dont le transfert dépend.
    final forwardable = rows.where(canForwardMessage).toList();
    if (forwardable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.myMediaForwardUnavailable)),
      );
      return;
    }

    _clearSelection();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => forwardable.length == 1
            ? ForwardMessageScreen(message: forwardable.first)
            : ForwardMessageScreen(messages: forwardable),
      ),
    );
  }

  void _open(MyMediaItem item) {
    if (item.isVisual) {
      _openViewer(item);
    } else {
      unawaited(_openExternally(item));
    }
  }

  /// La visionneuse plein écran ne défile qu'entre images et vidéos : y
  /// glisser vocaux et documents donnerait des pages vides. L'index est donc
  /// calculé dans la sous-liste visuelle, pas dans la grille affichée.
  void _openViewer(MyMediaItem target) {
    final visual = _items.where((i) => i.isVisual).toList();
    final index = visual.indexWhere((i) => i.msgID == target.msgID);
    if (index < 0) return;
    final viewerItems = visual
        .map(
          (m) => MediaViewerItem(
            isVideo: m.isVideo,
            localPath: m.localMediaPath,
            networkUrl: normalizeBackendUrl(m.mediaUrl),
            title: m.mediaName,
            msgID: m.msgID,
          ),
        )
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          items: viewerItems,
          initialIndex: index,
        ),
      ),
    );
  }

  /// Vocaux et documents s'ouvrent avec l'application du système : le fichier
  /// est déjà sur l'appareil (c'est la condition d'entrée dans cette grille),
  /// aucun téléchargement à déclencher.
  Future<void> _openExternally(MyMediaItem item) async {
    final path = item.localMediaPath;
    if (path == null) return;
    final res = await OpenFilex.open(path);
    if (res.type == ResultType.done || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.errAucuneAppPourFichier),
        backgroundColor: context.colors.error,
      ),
    );
  }

  // ── Rendu ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      // En mode sélection, Retour annule la sélection avant de quitter.
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _clearSelection();
      },
      child: Scaffold(
        backgroundColor: context.semantic.surfaceMuted,
        appBar: _selecting ? _selectionAppBar(l10n) : _browseAppBar(l10n),
        body: Column(
          children: [
            if (_working) const LinearProgressIndicator(minHeight: 2),
            _header(l10n),
            Expanded(child: _body(l10n)),
            // Hors du mode sélection : la barre du bas y porte déjà des
            // actions, en ajouter une troisième créerait une ambiguïté sur ce
            // qui serait exporté — la sélection, ou la période ?
            if (!_selecting) _exportBar(l10n),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _browseAppBar(AppLocalizations l10n) => AppBar(
        title: Text(l10n.myMediaTitle),
        actions: [
          IconButton(
            icon: Icon(_filtersOpen ? Icons.filter_list_off : Icons.tune),
            tooltip: l10n.myMediaFilters,
            // Replier le panneau ne doit pas relâcher les filtres en cours :
            // la ligne de résumé continue de dire ce qui est appliqué.
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
          ),
        ],
      );

  PreferredSizeWidget _selectionAppBar(AppLocalizations l10n) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _clearSelection,
        ),
        title: Text(l10n.selectedCount(_selected.length)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: l10n.myMediaSelectAll,
            onPressed: _working ? null : _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.forward),
            tooltip: l10n.forward,
            onPressed: _working ? null : _forward,
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: l10n.myMediaFreeSpace,
            onPressed: _working ? null : _freeSpace,
          ),
        ],
      );

  /// Espace occupé, filtres et ordre : la page sert à retrouver un média
  /// autant qu'à faire de la place.
  Widget _header(AppLocalizations l10n) {
    final cacheBytes =
        context.watch<StorageInfoService>().breakdown.mediaCacheBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sd_storage_outlined,
                size: 18,
                color: context.colors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.myMediaOnThisDevice(formatBytes(cacheBytes, l10n)),
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ),
              SegmentedButton<_MediaSort>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _MediaSort.recent,
                    label: Text(l10n.myMediaSortRecent),
                  ),
                  ButtonSegment(
                    value: _MediaSort.largest,
                    label: Text(l10n.myMediaSortLargest),
                  ),
                ],
                selected: {_sort},
                onSelectionChanged: (s) => _changeSort(s.first),
              ),
            ],
          ),
          if (_filtersOpen) ...[
            const SizedBox(height: 10),
            _filterCard(l10n),
          ],
          const SizedBox(height: 10),
          _kindChips(l10n),
          const SizedBox(height: 8),
          _summaryLine(l10n),
        ],
      ),
    );
  }

  /// Panneau discussion / période / origine, calqué sur la maquette : un
  /// libellé à gauche, le contrôle à droite, une ligne par critère.
  Widget _filterCard(AppLocalizations l10n) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.brMd,
          border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _filterRow(
              label: l10n.myMediaFilterDiscussion,
              child: _discussionButton(l10n),
            ),
            const SizedBox(height: 10),
            _filterRow(
              label: l10n.myMediaFilterPeriod,
              child: _periodButtons(l10n),
            ),
            const SizedBox(height: 8),
            _periodPresets(l10n),
            const SizedBox(height: 10),
            _filterRow(
              label: l10n.myMediaFilterOrigin,
              child: Wrap(
                spacing: 6,
                children: [
                  _ownerChip(_MediaOwner.all, l10n.myMediaFilterAll),
                  _ownerChip(_MediaOwner.received, l10n.myMediaFilterReceived),
                  _ownerChip(_MediaOwner.sent, l10n.myMediaFilterSent),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _filterRow({required String label, required Widget child}) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );

  Widget _discussionButton(AppLocalizations l10n) => _FilterField(
        icon: Icons.person_outline,
        text: _discussion?.label ?? l10n.myMediaAllDiscussions,
        muted: _discussion == null,
        trailing: Icons.expand_more,
        onTap: _working ? null : _pickDiscussion,
      );

  Widget _periodButtons(AppLocalizations l10n) {
    final material = MaterialLocalizations.of(context);
    final period = _period;
    return Row(
      children: [
        Expanded(
          child: _FilterField(
            icon: Icons.calendar_today_outlined,
            text: period == null
                ? l10n.myMediaPeriodStart
                : material.formatShortDate(period.start),
            muted: period == null,
            onTap: _pickPeriod,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward,
            size: 16,
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: _FilterField(
            icon: Icons.calendar_today_outlined,
            text: period == null
                ? l10n.myMediaPeriodEnd
                : material.formatShortDate(period.end),
            muted: period == null,
            onTap: _pickPeriod,
          ),
        ),
        if (period != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: l10n.myMediaPeriodClear,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: _clearPeriod,
          ),
      ],
    );
  }

  /// Raccourcis de période : trois pressions courantes, pour éviter le
  /// calendrier quand on cherche « ce que j'ai reçu ces derniers jours ».
  Widget _periodPresets(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.only(left: 78),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ActionChip(
              label: Text(l10n.myMediaPeriodLast7),
              visualDensity: VisualDensity.compact,
              onPressed: () => _setLastDays(7),
            ),
            ActionChip(
              label: Text(l10n.myMediaPeriodLast30),
              visualDensity: VisualDensity.compact,
              onPressed: () => _setLastDays(30),
            ),
            ActionChip(
              label: Text(l10n.myMediaPeriodThisYear),
              visualDensity: VisualDensity.compact,
              onPressed: _setThisYear,
            ),
          ],
        ),
      );

  /// Familles de médias. Défilement horizontal plutôt qu'un [Wrap] : cinq
  /// pastilles passent rarement sur une ligne en gros caractères, et une
  /// deuxième ligne repousserait la grille hors de l'écran.
  Widget _kindChips(AppLocalizations l10n) => SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _MediaKind.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final kind = _MediaKind.values[i];
            return ChoiceChip(
              label: Text(kind.label(l10n)),
              selected: _kind == kind,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _changeKind(kind),
            );
          },
        ),
      );

  /// « 47 éléments · 128 Mo » : le décompte porte sur ce que les filtres
  /// laissent passer, pas sur la totalité de l'appareil (celle-là est déjà en
  /// haut de l'écran).
  Widget _summaryLine(AppLocalizations l10n) {
    final bytes = _items.fold<int>(0, (sum, i) => sum + (i.mediaSize ?? 0));
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.myMediaSummary(_items.length, formatBytes(bytes, l10n)),
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        if (_filtered)
          TextButton(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _resetFilters,
            child: Text(l10n.myMediaResetFilters),
          ),
      ],
    );
  }

  /// Barre d'action basse, comme sur la maquette. Elle porte sur **la période
  /// filtrée**, pas sur une sélection : c'est l'écran entier, tel qu'il est
  /// affiché, que l'inscrit emporte.
  Widget _exportBar(AppLocalizations l10n) => Material(
        color: context.colors.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.archive_outlined, size: 18),
                label: Text(l10n.exportPeriodAction),
                // Désactivé quand la grille est vide : la feuille n'aurait
                // rien à annoncer.
                onPressed: _items.isEmpty || _working ? null : _openExport,
              ),
            ),
          ),
        ),
      );

  Future<void> _openExport() async {
    final chat = context.read<ChatProvider>();
    final period = _period;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => ExportPeriodSheet(
        dao: chat.repository.dao,
        repository: chat.repository,
        request: ExportRequest(
          myId: chat.repository.myId,
          mineOnly: switch (_owner) {
            _MediaOwner.sent => true,
            _MediaOwner.received => false,
            _MediaOwner.all => null,
          },
          conversationID: _discussion?.conversationID,
          conversationName: _discussion?.label,
          from: period == null ? null : _startOfDay(period.start),
          // Même borne exclusive que la grille, pour que l'archive contienne
          // exactement ce que l'écran montrait.
          until: period == null
              ? null
              : _startOfDay(period.end).add(const Duration(days: 1)),
          // L'archive « Tout » emporte aussi les stickers ; une famille précise
          // (photos, vidéos…) reste sans, conformément à [exportTypes].
          types: _kind.exportTypes,
        ),
      ),
    );
  }

  Widget _ownerChip(_MediaOwner owner, String label) => ChoiceChip(
        label: Text(label),
        selected: _owner == owner,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => _changeOwner(owner),
      );

  Widget _body(AppLocalizations l10n) {
    if (_initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: AppSpacing.screenH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.myMediaLoadFailed),
              AppSpacing.vGapMd,
              TextButton(
                onPressed: _reload,
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      // Un écran vide sous filtres se lit comme « je n'ai plus rien » : dire
      // que ce sont les filtres, et offrir la sortie.
      return Center(
        child: Padding(
          padding: AppSpacing.screenH,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _filtered ? l10n.myMediaEmptyFiltered : l10n.myMediaEmpty,
                textAlign: TextAlign.center,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (_filtered) ...[
                AppSpacing.vGapMd,
                TextButton(
                  onPressed: _resetFilters,
                  child: Text(l10n.myMediaResetFilters),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final groups = _buildGroups();
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (group.label != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    group.label!,
                    style: context.text.labelMedium?.copyWith(
                      color: context.colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: group.items.length,
                itemBuilder: (context, i) => _cell(group.items[i], l10n),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Octets décodés une seule fois par média (le décodage base64 est keyé
  /// sur l'identité des octets par le cache d'images de Flutter, un nouveau
  /// décodage à chaque build ré-enregistrerait une entrée).
  Uint8List _thumbBytesFor(int msgID, String base64) {
    var bytes = _thumbBytes[msgID];
    if (bytes == null) {
      // Borne mémoire (~15 Ko par vignette, 400 × 15 Ko ≈ 6 Mo au pire).
      if (_thumbBytes.length > 400) _thumbBytes.clear();
      bytes = base64Decode(base64);
      _thumbBytes[msgID] = bytes;
    }
    return bytes;
  }

  Widget _cell(MyMediaItem item, AppLocalizations l10n) {
    final checked = _selected.contains(item.msgID);
    final sender = item.senderName;
    return GestureDetector(
      onTap: () => _selecting ? _toggle(item) : _open(item),
      onLongPress: () => _toggle(item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _preview(item, l10n),
          if (!item.isMine && sender != null && sender.isNotEmpty)
            _senderOverlay(l10n.myMediaFrom(sender)),
          if (item.mediaSize != null) _sizeOverlay(item.mediaSize!, l10n),
          if (_selecting) _selectionOverlay(checked),
        ],
      ),
    );
  }

  /// Aperçu seul, sans habillage. Le fichier est, par construction de
  /// [ChatDao.watchLocalMedia], toujours présent sur le disque — aucun appel
  /// réseau ici, ni pour l'image/vidéo elle-même ni pour sa vignette :
  /// `mediaThumb` (base64, en priorité, décodage bon marché pour une petite
  /// tuile de grille) ou à défaut le fichier local lui-même. Vocaux et
  /// documents n'ont pas d'image : ils prennent une tuile typée.
  Widget _preview(MyMediaItem item, AppLocalizations l10n) {
    final fallback = context.semantic.surfaceMuted;
    if (item.isVideo) {
      return VideoMessagePreview(
        localPath: item.localMediaPath,
        thumbBase64: item.mediaThumb,
        durationSeconds: item.mediaDuration,
        borderRadius: BorderRadius.zero,
        expandToFill: true,
        playIconSize: 26,
        fallbackColor: fallback,
      );
    }
    if (item.isAudio) return _audioTile(item, l10n);
    if (item.isDocument) return _documentTile(item, l10n);

    final thumb = item.mediaThumb;
    if (thumb != null && thumb.isNotEmpty) {
      return Image.memory(
        _thumbBytesFor(item.msgID, thumb),
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    final path = item.localMediaPath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 480,
        errorBuilder: (_, __, ___) => Container(
          color: context.semantic.brandContainer,
          child: Icon(
            Icons.broken_image_outlined,
            color: context.colors.onSurfaceVariant,
          ),
        ),
      );
    }
    // Ni vignette, ni copie locale. Reste à distinguer deux absences que la
    // même icône confondait : un aperçu simplement indisponible, et un média
    // que le serveur a supprimé. L'horloge est le même signe que dans les
    // bulles de conversation — l'appui ouvre le visionneur, qui l'explique.
    final expire = item.localMediaPath == null &&
        MediaExpiryPolicy.isExpired(item.mediaUrl);
    return Container(
      color: context.semantic.brandContainer,
      child: Icon(
        expire ? Icons.history_toggle_off_rounded : Icons.image_outlined,
        color: expire ? context.colors.onSurfaceVariant : context.colors.primary,
      ),
    );
  }

  /// Vocal enregistré ou morceau importé : les deux sont des messages de type
  /// 3, seul le nom de fichier les sépare (voir [audioKindFromName]).
  Widget _audioTile(MyMediaItem item, AppLocalizations l10n) {
    final isMusic =
        audioKindFromName(item.mediaName) == AudioMessageKind.music;
    final title = isMusic
        ? musicTitleFromName(item.mediaName, fallback: l10n.music)
        : l10n.voiceMessage;
    return _KindTile(
      icon: isMusic ? Icons.music_note : Icons.mic,
      background: context.semantic.brandContainer,
      foreground: context.colors.primary,
      title: title,
      subtitle: _durationLabel(item.mediaDuration),
    );
  }

  Widget _documentTile(MyMediaItem item, AppLocalizations l10n) {
    final style = DocumentFileStyle.fromMessage(
      mediaName: item.mediaName,
      mediaUrl: item.mediaUrl,
    );
    return _KindTile(
      icon: style.icon,
      background: style.color,
      foreground: AppColors.white,
      title: item.mediaName ?? l10n.document,
      subtitle: style.extension,
      onColoredBackground: true,
    );
  }

  static String? _durationLabel(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  /// Expéditeur en haut, sur un média reçu : sans lui, une grille tous
  /// expéditeurs confondus ne dit pas d'où vient ce qu'on s'apprête à effacer.
  Widget _senderOverlay(String label) => Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: Colors.white),
          ),
        ),
      );

  /// Poids en bas à gauche, sur un dégradé qui garantit le contraste quelle
  /// que soit l'image. À droite, `VideoMessagePreview` pose déjà sa durée.
  Widget _sizeOverlay(int bytes, AppLocalizations l10n) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Text(
            formatBytes(bytes, l10n),
            style: context.text.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );

  Widget _selectionOverlay(bool checked) => Container(
        color: checked ? Colors.black38 : Colors.transparent,
        alignment: Alignment.topRight,
        padding: const EdgeInsets.all(4),
        child: Icon(
          checked ? Icons.check_circle : Icons.circle_outlined,
          size: 20,
          color: checked ? context.colors.primary : Colors.white70,
        ),
      );
}

/// Champ de filtre : une bordure, une icône, un texte tronqué. Grisé tant que
/// le critère n'est pas posé, pour qu'un coup d'œil suffise à voir ce qui
/// filtre réellement.
class _FilterField extends StatelessWidget {
  const _FilterField({
    required this.icon,
    required this.text,
    required this.muted,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final bool muted;
  final IconData? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        muted ? context.colors.onSurfaceVariant : context.colors.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.brSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: AppRadius.brSm,
          border: Border.all(
            color: context.colors.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: color),
              ),
            ),
            if (trailing != null) Icon(trailing, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// Tuile carrée pour un média sans image (vocal, document) : icône, nom,
/// détail. Occupe la même case que les vignettes pour que la grille reste une
/// grille, comme dans la maquette.
class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.title,
    this.subtitle,
    this.onColoredBackground = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final String title;
  final String? subtitle;

  /// Fond plein coloré (document) : le texte passe en blanc. Sinon le fond est
  /// un conteneur de marque, et le texte suit le thème.
  final bool onColoredBackground;

  @override
  Widget build(BuildContext context) {
    final textColor =
        onColoredBackground ? AppColors.white : context.colors.onSurface;
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 26, color: foreground),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(color: textColor),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              style: context.text.labelSmall?.copyWith(
                color: textColor.withValues(alpha: 0.75),
              ),
            ),
        ],
      ),
    );
  }
}

/// Sélecteur de discussion. Liste filtrable, « toutes » en tête.
class _DiscussionPickerSheet extends StatefulWidget {
  const _DiscussionPickerSheet({
    required this.conversations,
    required this.myId,
    required this.selectedId,
  });

  final List<LocalConversation> conversations;
  final int myId;
  final int? selectedId;

  @override
  State<_DiscussionPickerSheet> createState() => _DiscussionPickerSheetState();
}

class _DiscussionPickerSheetState extends State<_DiscussionPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final matches = widget.conversations
        .where((c) =>
            conversationMatchesSearch(c, widget.myId, _query))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: l10n.myMediaSearchDiscussion,
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.brSm,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: matches.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(l10n.myMediaAllDiscussions),
                      selected: widget.selectedId == null,
                      onTap: () => Navigator.pop(
                        context,
                        const _DiscussionChoice(null),
                      ),
                    );
                  }
                  final conv = matches[index - 1];
                  final name =
                      conversationDisplayName(conv, widget.myId);
                  return ListTile(
                    leading: AppAvatar(
                      imageUrl: conversationDisplayAvatar(conv, widget.myId),
                      name: name,
                      size: AppSizes.avatarSm,
                      isGroup: conv.isGroup,
                    ),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: widget.selectedId == conv.conversID,
                    onTap: () => Navigator.pop(
                      context,
                      _DiscussionChoice(
                        _DiscussionFilter(conv.conversID, name),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
