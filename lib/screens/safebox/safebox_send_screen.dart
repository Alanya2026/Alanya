//  Envoyer un fichier du coffre dans une discussion (jusqu'à 1 Go). Deux
//  chemins : un fichier déjà dans le coffre part tout de suite ; un fichier du
//  téléphone entre d'abord dans le coffre (sur l'espace de l'expéditeur), puis
//  part dans la discussion dès la fin de son envoi.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/safebox/safebox_controller.dart';
import '../../core/services/safebox/safebox_models.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/safebox_share_payload.dart';
import '../../talky_api_client.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import 'safebox_compression_sheet.dart';
import 'safebox_move_picker.dart';
import 'safebox_widgets.dart';

/// Ouvre l'écran d'envoi. Rend le contenu du message à envoyer (fichier pris
/// dans le coffre), ou null : renoncement, ou fichier du téléphone dont le
/// message partira de lui-même à la fin de l'envoi.
Future<SafeboxSharePayload?> showSafeboxSend(BuildContext context, {required int conversationId}) =>
    Navigator.push<SafeboxSharePayload>(
      context,
      MaterialPageRoute(builder: (_) => SafeboxSendScreen(conversationId: conversationId)),
    );

/// Envoie des fichiers du téléphone dans une discussion par le coffre :
/// chacun entre dans la racine de sa famille (avec la question de
/// compression), sur l'espace de l'expéditeur, puis part dans la discussion
/// à la fin de son envoi. Sert à l'écran d'envoi et à la proposition faite
/// quand un fichier dépasse la limite des médias de discussion. Rend vrai si
/// au moins un fichier est en route.
Future<bool> sendPhoneFilesViaSafebox(
  BuildContext context, {
  required int conversationId,
  required List<SafeboxPick> picks,
}) async {
  final c = context.read<SafeboxController>();
  final l10n = context.l10n;
  final vue = c.overview ?? await c.refreshOverview();
  if (vue == null || !context.mounted) return false;
  var parti = false;
  for (final famille in SafeboxRoot.values) {
    final lot = picks.where((p) => vue.limits.familyOf(p.name) == famille).toList();
    final racine = vue.rootIds[famille];
    if (lot.isEmpty || racine == null) continue;
    final dossier = SafeboxFolder(id: racine, parentId: null, root: famille, name: null, depth: 0);
    final tri = c.triage(lot, dossier);
    if (tri.rejected.isNotEmpty && context.mounted) {
      final r = tri.rejected.first;
      safeboxSnack(
        context,
        r.reason == SafeboxRejectReason.tooLarge
            ? l10n.safeboxFileTooLarge(formatBytes(vue.limits.maxFileBytes, l10n))
            : l10n.safeboxEmptyFile,
        error: true,
      );
    }
    if (tri.ok.isEmpty) continue;
    if (!context.mounted) return parti;
    final range = await _rangerDans(context, c, famille, racine, tri.ok.length);
    if (range == null) continue; // renoncement
    final cible = range == racine
        ? dossier
        : SafeboxFolder(id: range, parentId: null, root: famille, name: null, depth: 1);
    var compresser = false;
    final estimation = await c.estimate(tri.ok, famille);
    if (estimation != null && context.mounted) {
      final retenu = await c.rememberedChoice();
      if (retenu == SafeboxCompressionChoice.ask) {
        if (!context.mounted) return parti;
        final r = await showSafeboxCompressionSheet(
          context,
          originalBytes: estimation.original,
          compressedBytes: estimation.compressed,
        );
        if (r == null) continue;
        compresser = r.compress;
        if (r.remember) {
          await c.rememberChoice(r.compress ? SafeboxCompressionChoice.compressed : SafeboxCompressionChoice.original);
        }
      } else {
        compresser = retenu == SafeboxCompressionChoice.compressed;
      }
    }
    final total = tri.ok.fold<int>(0, (s, p) => s + p.size);
    if (!compresser && total > (c.overview ?? vue).quota.freeBytes) {
      if (context.mounted) safeboxSnack(context, l10n.safeboxQuotaExceeded, error: true);
      continue;
    }
    await c.addFiles(tri.ok, cible, compress: compresser, shareConversationId: conversationId);
    parti = true;
  }
  if (parti && context.mounted) safeboxSnack(context, l10n.safeboxShareQueued);
  return parti;
}

/// Où ranger les fichiers dans le coffre (conception, section 07). Sans
/// sous-dossier dans cette famille, rien n'est demandé : la racine. Sinon une
/// feuille « Ranger dans : Documents · Modifier · Continuer ». Rend le dossier
/// choisi, ou null si l'inscrit renonce.
Future<int?> _rangerDans(BuildContext context, SafeboxController c, SafeboxRoot famille, int racine, int nombre) async {
  SafeboxFolderPage page;
  try {
    page = await c.api.fetchSafeboxFolder(racine);
  } catch (_) {
    return racine; // hors ligne : la racine, comme avant
  }
  if (page.folders.isEmpty || !context.mounted) return racine;
  var choisi = racine;
  var libelle = SafeboxController.rootLabel(famille, context.l10n);
  return showAppBottomSheet<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final l10n = ctx.l10n;
        return SafeArea(
          child: Padding(
            padding: AppSpacing.card,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.safeboxStoreInTitle, style: ctx.text.titleMedium),
                AppSpacing.vGapXs,
                Text(l10n.safeboxStoreInHint(nombre),
                    style: ctx.text.bodySmall?.copyWith(color: ctx.colors.onSurfaceVariant)),
                AppSpacing.vGapSm,
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(choisi == racine ? safeboxRootIcon(famille) : Icons.folder_outlined,
                      color: ctx.colors.primary),
                  title: Text(libelle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: TextButton(
                    onPressed: () async {
                      final id = await pickSafeboxDestination(
                        ctx,
                        startFolderId: racine,
                        currentParentId: -1,
                        actionLabel: l10n.safeboxStoreHere,
                      );
                      if (id == null || !ctx.mounted) return;
                      var nom = libelle;
                      try {
                        nom = SafeboxController.folderLabel((await c.api.fetchSafeboxFolder(id)).folder, l10n);
                      } catch (_) {}
                      setState(() {
                        choisi = id;
                        libelle = nom;
                      });
                    },
                    child: Text(l10n.safeboxStoreChange),
                  ),
                ),
                AppSpacing.vGapSm,
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, choisi),
                  child: Text(l10n.safeboxStoreContinue),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class SafeboxSendScreen extends StatefulWidget {
  const SafeboxSendScreen({super.key, required this.conversationId});
  final int conversationId;

  @override
  State<SafeboxSendScreen> createState() => _SafeboxSendScreenState();
}

class _SafeboxSendScreenState extends State<SafeboxSendScreen> {
  bool _occupe = false;

  SafeboxController get _c => context.read<SafeboxController>();

  @override
  void initState() {
    super.initState();
    if (_c.overview == null) _c.refreshOverview();
  }

  /// Fichier choisi dans le coffre : le partage est créé, le message rendu.
  Future<void> _envoyerDuCoffre(SafeboxFile f) async {
    setState(() => _occupe = true);
    try {
      final payload = await _c.shareFile(f, widget.conversationId);
      if (mounted) Navigator.pop(context, payload);
    } catch (e) {
      if (mounted) safeboxShowError(context, e);
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// Fichier du téléphone : déposé dans la racine de sa famille, il partira
  /// dans la discussion à la fin de l'envoi.
  Future<void> _depuisLeTelephone() async {
    final res = await FilePicker.platform.pickFiles(withData: false);
    final f = res?.files.single;
    if (f == null || f.path == null || !mounted) return;
    final parti = await sendPhoneFilesViaSafebox(
      context,
      conversationId: widget.conversationId,
      picks: [SafeboxPick(path: f.path!, name: f.name, size: f.size)],
    );
    if (parti && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vue = context.watch<SafeboxController>().overview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.safeboxSharePickTitle)),
      body: AbsorbPointer(
        absorbing: _occupe,
        child: ListView(
          children: [
            Padding(
              padding: AppSpacing.card,
              child: Text(
                l10n.safeboxSharePickHint(formatBytes(vue?.limits.maxFileBytes ?? 0, l10n)),
                style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: AppSpacing.screenH,
              child: OutlinedButton.icon(
                onPressed: _depuisLeTelephone,
                icon: const Icon(Icons.smartphone),
                label: Text(l10n.safeboxSharePickFromPhone),
              ),
            ),
            if (_occupe) const LinearProgressIndicator(),
            AppSpacing.vGapMd,
            if (vue == null)
              const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.xl), child: CircularProgressIndicator()))
            else
              for (final r in SafeboxRoot.values)
                if (vue.rootIds[r] != null)
                  ListTile(
                    leading: Icon(safeboxRootIcon(r), color: context.colors.primary),
                    title: Text(SafeboxController.rootLabel(r, l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final f = await Navigator.push<SafeboxFile>(
                        context,
                        MaterialPageRoute(builder: (_) => _Parcourir(folderId: vue.rootIds[r]!)),
                      );
                      if (f != null && mounted) await _envoyerDuCoffre(f);
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

/// Un dossier du coffre, pour y choisir un fichier.
class _Parcourir extends StatefulWidget {
  const _Parcourir({required this.folderId});
  final int folderId;

  @override
  State<_Parcourir> createState() => _ParcourirState();
}

class _ParcourirState extends State<_Parcourir> {
  SafeboxFolderPage? _page;

  @override
  void initState() {
    super.initState();
    context.read<SafeboxController>().api.fetchSafeboxFolder(widget.folderId).then((p) {
      if (mounted) setState(() => _page = p);
    }).catchError((Object e) {
      if (mounted) safeboxShowError(context, e);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: Text(page == null ? '' : SafeboxController.folderLabel(page.folder, l10n))),
      body: page == null
          ? const Center(child: CircularProgressIndicator())
          : page.folders.isEmpty && page.files.isEmpty
              ? Center(child: Text(l10n.safeboxFolderEmpty))
              : ListView(
                  children: [
                    for (final d in page.folders)
                      ListTile(
                        leading: Icon(Icons.folder_outlined, color: context.colors.primary),
                        title: Text(d.name ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final f = await Navigator.push<SafeboxFile>(
                            context,
                            MaterialPageRoute(builder: (_) => _Parcourir(folderId: d.id)),
                          );
                          if (f != null && context.mounted) Navigator.pop(context, f);
                        },
                      ),
                    for (final f in page.files)
                      ListTile(
                        leading: SafeboxFileThumb(file: f, size: 44),
                        title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(f.plainBytes, l10n)),
                        trailing: const Icon(Icons.send_outlined),
                        onTap: () => Navigator.pop(context, f),
                      ),
                  ],
                ),
    );
  }
}
