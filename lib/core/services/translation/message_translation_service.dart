import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../db/app_database.dart';
import '../../db/chat_dao.dart';
import 'translatable_content.dart';
import 'translation_languages.dart';
import 'translation_settings.dart';
import 'translation_state.dart';

/// Traduction des messages reçus, entièrement sur l'appareil.
///
/// Aucun contenu ne quitte le téléphone et la traduction fonctionne hors
/// ligne. Le service ne fait qu'écrire dans `local_messages` : c'est le stream
/// `watchMessages` existant qui rafraîchit les bulles, sans second flux.
class MessageTranslationService {
  MessageTranslationService({
    required ChatDao dao,
    required TranslationSettings settings,
    TranslationModelStore? models,
  })  : _dao = dao,
        _settings = settings,
        _models = models ?? TranslationModelStore() {
    _settings.addListener(_onSettingsChanged);
    _lastTarget = _settings.target;
    _instance = this;
    // Rien ne justifie de tenir des modèles de langue ouverts pendant que
    // l'utilisateur est ailleurs : le worker s'arrête et les ressources
    // natives sont rendues dès la mise en arrière-plan.
    _lifecycle = AppLifecycleListener(
      onPause: () => unawaited(pause()),
      onResume: resume,
    );
  }

  AppLifecycleListener? _lifecycle;

  /// Instance courante, `null` tant que l'app n'a pas démarré.
  ///
  /// Même patron que [LocaleController] : les points d'entrée des messages
  /// (socket, sync) sont profonds dans `ChatRepository` et n'ont pas à porter
  /// une dépendance de plus dans leur constructeur — et le `null` rend le
  /// service transparent en test.
  static MessageTranslationService? _instance;
  static MessageTranslationService? get maybeInstance => _instance;

  final ChatDao _dao;
  final TranslationSettings _settings;
  final TranslationModelStore _models;

  /// Seuil de confiance de l'identification. En dessous, ML Kit renvoie `und`.
  static const double _kConfidence = 0.5;

  /// Paires de langues gardées ouvertes simultanément.
  ///
  /// Un [OnDeviceTranslator] détient des ressources natives : en ouvrir un par
  /// message fuit, et la fuite est invisible au profileur Dart. Trois suffisent
  /// (une conversation mélange rarement plus de deux langues sources).
  static const int _kMaxTranslators = 3;

  final Queue<LocalMessage> _queue = Queue<LocalMessage>();
  final Set<String> _queuedIds = <String>{};
  final Map<String, OnDeviceTranslator> _translators =
      <String, OnDeviceTranslator>{};
  final Map<int, bool> _convEnabledMemo = <int, bool>{};

  final Set<int> _pendingScans = <int>{};
  Timer? _scanTimer;

  LanguageIdentifier? _identifier;
  bool _draining = false;
  bool _paused = false;
  String _lastTarget = 'fr';

  /// Fenêtre de regroupement des scans.
  ///
  /// Un delta de synchronisation insère cinquante messages d'affilée ; sans
  /// regroupement, chacun déclencherait sa propre requête de balayage.
  static const Duration _kScanDebounce = Duration(milliseconds: 250);

  // ── Cycle de vie ────────────────────────────────────────────────────

  /// Suspend le worker quand l'app passe en arrière-plan et libère les
  /// ressources natives : rien ne justifie de tenir des modèles ouverts pendant
  /// que l'utilisateur est ailleurs.
  Future<void> pause() async {
    _paused = true;
    await _closeNativeResources();
  }

  void resume() {
    _paused = false;
    _drain();
  }

  Future<void> dispose() async {
    _settings.removeListener(_onSettingsChanged);
    _lifecycle?.dispose();
    _lifecycle = null;
    _scanTimer?.cancel();
    _queue.clear();
    _queuedIds.clear();
    _pendingScans.clear();
    if (identical(_instance, this)) _instance = null;
    await _closeNativeResources();
  }

  Future<void> _closeNativeResources() async {
    final translators = _translators.values.toList(growable: false);
    _translators.clear();
    for (final t in translators) {
      try {
        await t.close();
      } catch (_) {
        // Fermeture best-effort : un canal déjà tombé ne doit pas empêcher de
        // fermer les suivants.
      }
    }
    final identifier = _identifier;
    _identifier = null;
    if (identifier != null) {
      try {
        await identifier.close();
      } catch (_) {}
    }
  }

  // ── Entrées ─────────────────────────────────────────────────────────

  /// Soumet des messages fraîchement arrivés en base.
  ///
  /// Sans effet si la traduction automatique est désactivée : les lignes
  /// restent en [MessageTranslationState.pending] et redeviendront candidates
  /// si l'utilisateur l'active plus tard.
  void enqueue(Iterable<LocalMessage> messages) {
    if (!_settings.auto) return;
    var added = false;
    for (final m in messages) {
      if (m.translationState != MessageTranslationState.pending) continue;
      if (_queuedIds.contains(m.clientId)) continue;
      _queuedIds.add(m.clientId);
      _queue.add(m);
      added = true;
    }
    if (added) _drain();
  }

  /// Signale que des messages viennent d'entrer en base pour cette
  /// conversation, sans avoir à transporter les lignes.
  ///
  /// C'est le point d'entrée unique de `ChatRepository` : il couvre aussi bien
  /// l'arrivée temps réel que les deltas de synchronisation et la remontée du
  /// fil. Le service relit lui-même ce qui reste à traiter, ce qui le rend
  /// auto-réparant — un message manqué lors d'un passage précédent sera repris
  /// au suivant.
  /// On planifie même quand le réglage global est à off : une conversation
  /// peut forcer la traduction, et cela ne se lit qu'en base. Le filtre
  /// s'applique au balayage, pas ici.
  void scheduleScan(int conversationID) {
    _pendingScans.add(conversationID);
    _scanTimer?.cancel();
    _scanTimer = Timer(_kScanDebounce, _runScans);
  }

  Future<void> _runScans() async {
    final ids = _pendingScans.toList(growable: false);
    _pendingScans.clear();
    for (final id in ids) {
      if (!await _isEnabledFor(id)) continue;
      enqueueForced(await _dao.pendingTranslations(id));
    }
  }

  /// Traduction déclenchée à la main depuis le menu d'un message.
  ///
  /// Court-circuite le réglage automatique et l'override de conversation —
  /// c'est une demande explicite — mais pas les filtres de contenu : un JSON
  /// de trajet reste intraduisible, quoi qu'on en demande.
  Future<void> translateNow(LocalMessage message) async {
    await _process(message, respectSettings: false);
  }

  /// Après installation d'un modèle : relance les messages qui l'attendaient.
  Future<void> onModelInstalled() async {
    await _dao.retryMissingModelTranslations();
    _convEnabledMemo.clear();
  }

  /// Réexamine une conversation dont l'override vient de changer.
  Future<void> refreshConversation(int conversationID) async {
    _convEnabledMemo.remove(conversationID);
    if (!_settings.auto && (await _dao.translateModeOf(conversationID)) != 1) {
      return;
    }
    enqueueForced(await _dao.pendingTranslations(conversationID));
  }

  /// Comme [enqueue] mais sans le garde-fou du réglage global : appelé quand
  /// une conversation force la traduction alors que le global est à off.
  void enqueueForced(Iterable<LocalMessage> messages) {
    var added = false;
    for (final m in messages) {
      if (m.translationState != MessageTranslationState.pending) continue;
      if (_queuedIds.contains(m.clientId)) continue;
      _queuedIds.add(m.clientId);
      _queue.add(m);
      added = true;
    }
    if (added) _drain();
  }

  void _onSettingsChanged() {
    if (_settings.target != _lastTarget) {
      _lastTarget = _settings.target;
      _invalidateAll();
    } else if (_settings.auto) {
      _drain();
    }
  }

  /// La langue de lecture a changé : les traductions en base visent l'ancienne
  /// et deviendraient trompeuses. On les efface et on repart de zéro.
  Future<void> _invalidateAll() async {
    _queue.clear();
    _queuedIds.clear();
    _convEnabledMemo.clear();
    await _closeNativeResources();
    await _dao.clearAllTranslations();
  }

  // ── Worker ──────────────────────────────────────────────────────────

  /// Boucle de traitement, unique et sérielle.
  ///
  /// Traduire en parallèle sature le thread natif et fait sauter des frames
  /// pendant le scroll. On cède la main entre chaque message pour que le rendu
  /// reste prioritaire.
  Future<void> _drain() async {
    if (_draining || _paused) return;
    _draining = true;
    try {
      while (_queue.isNotEmpty && !_paused) {
        final message = _queue.removeFirst();
        _queuedIds.remove(message.clientId);
        await _process(message, respectSettings: true);
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _process(
    LocalMessage message, {
    required bool respectSettings,
  }) async {
    final text = translatableTextOf(message);
    if (text == null) {
      await _dao.setTranslationState(
          message.clientId, MessageTranslationState.skipped);
      return;
    }

    if (respectSettings && !await _isEnabledFor(message.conversationID)) {
      // On laisse l'état à `pending` : la conversation peut être réactivée.
      return;
    }

    final target = mlKitLanguageOf(_settings.target);
    if (target == null) {
      await _dao.setTranslationState(
          message.clientId, MessageTranslationState.skipped);
      return;
    }

    try {
      final identifier = _identifier ??=
          LanguageIdentifier(confidenceThreshold: _kConfidence);
      final tag = await identifier.identifyLanguage(text);
      final source = mlKitLanguageOf(tag);

      // Indéterminé, romanisé, non supporté, ou déjà dans la langue de
      // lecture : rien à faire, et c'est définitif.
      if (source == null || source == target) {
        await _dao.setTranslationState(
            message.clientId, MessageTranslationState.skipped);
        return;
      }

      final ready = await _modelsReady(source, target);
      if (!ready) {
        await _dao.setTranslationState(
            message.clientId, MessageTranslationState.missingModel);
        return;
      }

      final translator = await _translatorFor(source, target);
      final translated = await translator.translateText(text);

      // ML Kit renvoie parfois le texte inchangé quand il ne sait rien en
      // faire. Afficher une « traduction » identique à l'original, chip
      // compris, ne ferait que dérouter.
      if (translated.trim().isEmpty || translated.trim() == text.trim()) {
        await _dao.setTranslationState(
            message.clientId, MessageTranslationState.skipped);
        return;
      }

      await _dao.setTranslation(
        message.clientId,
        content: translated,
        sourceLang: source.bcpCode,
      );
      // La liste des discussions lit un aperçu dénormalisé : sans ce recalage,
      // le fil afficherait la traduction et l'inbox l'original.
      await _dao.refreshTranslatedPreview(message.conversationID);
    } catch (e) {
      debugPrint('[traduction] échec sur ${message.clientId} : $e');
      await _dao.setTranslationState(
          message.clientId, MessageTranslationState.failed);
    }
  }

  // ── Filtres ─────────────────────────────────────────────────────────

  /// La traduction est-elle active pour cette conversation ?
  ///
  /// L'override de conversation prime sur le réglage global : `1` force la
  /// traduction même si le global est à off, `0` l'interdit même s'il est à on.
  Future<bool> _isEnabledFor(int conversationID) async {
    final memo = _convEnabledMemo[conversationID];
    if (memo != null) return memo;

    final mode = await _dao.translateModeOf(conversationID);
    final enabled = switch (mode) {
      1 => true,
      0 => false,
      _ => _settings.auto,
    };
    _convEnabledMemo[conversationID] = enabled;
    return enabled;
  }

  // ── Modèles et traducteurs ──────────────────────────────────────────

  Future<bool> _modelsReady(
      TranslateLanguage source, TranslateLanguage target) async {
    final results = await Future.wait([
      _models.isDownloaded(source.bcpCode),
      _models.isDownloaded(target.bcpCode),
    ]);
    return results.every((ok) => ok);
  }

  /// Traducteur pour une paire, avec cache borné en FIFO.
  Future<OnDeviceTranslator> _translatorFor(
      TranslateLanguage source, TranslateLanguage target) async {
    final key = '${source.bcpCode}>${target.bcpCode}';
    final existing = _translators[key];
    if (existing != null) return existing;

    if (_translators.length >= _kMaxTranslators) {
      final oldestKey = _translators.keys.first;
      final evicted = _translators.remove(oldestKey);
      try {
        await evicted?.close();
      } catch (_) {}
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: source,
      targetLanguage: target,
    );
    _translators[key] = translator;
    return translator;
  }
}
