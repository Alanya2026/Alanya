import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;
import 'package:provider/provider.dart';

import '../../core/db/app_database.dart';
import '../../core/errors/afficher_erreur.dart';
import '../../core/errors/app_error.dart';
import '../../core/services/call/voicemail_greeting_player.dart';
import '../../core/services/billing/entitlement_service.dart';
import '../../core/services/billing/entitlements.dart';
import '../../core/services/call/voicemail_provider.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/contact_list_display.dart';
import '../../talky_models.dart';
import '../../widgets/billing/paywall_sheet.dart';
import '../../widgets/calls/greeting_recorder_sheet.dart';
import '../../widgets/profile/settings_group.dart';
import 'pick_contact_list_sheet.dart';

/// Réglage du répondeur.
///
/// L'écran est organisé autour d'une distinction que tout le reste suit : il y a
/// ce qui se passe **quand je ne réponds pas** — le téléphone sonne, et l'appel
/// bascule au bout du délai, sur un refus, ou si la ligne est occupée — et ce
/// qui se passe **quand je suis indisponible** — le téléphone ne sonne pas du
/// tout.
///
/// Le premier est un interrupteur unique, permanent, cumulable. Les seconds sont
/// deux façons exclusives de se rendre muet : une durée, ou des plages. Le
/// serveur tient cette exclusivité, pas cet écran : deux appareils qui règlent
/// chacun leur mode laisseraient sinon un compte avec les deux armés.
///
/// L'activation par durée ne se règle pas ici mais dans la feuille rapide de
/// l'onglet Appels. Cet écran en montre l'état et permet de l'éteindre.
class VoicemailScheduleScreen extends StatefulWidget {
  const VoicemailScheduleScreen({super.key});

  @override
  State<VoicemailScheduleScreen> createState() =>
      _VoicemailScheduleScreenState();
}

class _VoicemailScheduleScreenState extends State<VoicemailScheduleScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<VoicemailProvider>().refresh();
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _abonnementAnnonce?.cancel();
    // Le son ne doit pas survivre à l'écran, et le focus audio doit être rendu :
    // sinon la musique de l'utilisateur resterait baissée après coup.
    unawaited(VoicemailGreetingPlayer.instance.release());
    super.dispose();
  }

  VoicemailSchedule get _schedule =>
      context.read<VoicemailProvider>().schedule ?? const VoicemailSchedule();

  /// Allumer un mode demande Alanya Plus ; éteindre, jamais.
  Future<void> _allumer(String champ, bool valeur) async {
    if (valeur && !guardPlus(context, PlusFeature.voicemail)) return;
    await _patch({champ: valeur});
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    try {
      await context.read<VoicemailProvider>().patch(patch);
    } catch (e) {
      if (!mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }

  Future<void> _desactiver() async {
    try {
      await context.read<VoicemailProvider>().disable();
    } catch (e) {
      if (!mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }

  // ── Écoute de sa propre annonce ───────────────────────────────────────────

  /// Vrai tant que l'annonce joue. Rafraîchi par l'abonnement à l'état du
  /// lecteur, qui signale aussi la fin de lecture — sinon le bouton resterait
  /// bloqué sur « Couper ».
  bool _annonceJoue = false;
  StreamSubscription<PlayerState>? _abonnementAnnonce;
  String? _urlPrechargee;

  Future<void> _ecouterAnnonce(String url) async {
    final lecteur = VoicemailGreetingPlayer.instance;
    if (lecteur.isPlaying) {
      await lecteur.pause();
      if (mounted) setState(() => _annonceJoue = false);
      return;
    }

    // Un seul préchargement par URL : réécouter ne retélécharge pas, et
    // réenregistrer change l'URL, donc l'ancienne lecture ne peut pas être
    // servie à la place de la nouvelle.
    if (_urlPrechargee != url) {
      lecteur.prefetch(url);
      _urlPrechargee = url;
      await _abonnementAnnonce?.cancel();
      _abonnementAnnonce = null;
    }

    await lecteur.play();
    if (!mounted) return;
    // Après `play()`, pas avant : le flux d'état n'existe qu'une fois le
    // lecteur construit.
    _abonnementAnnonce ??= lecteur.stateStream?.listen((_) {
      if (mounted) setState(() => _annonceJoue = lecteur.isPlaying);
    });
    setState(() => _annonceJoue = lecteur.isPlaying);
  }

  Future<void> _supprimerAnnonce() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await context.read<VoicemailProvider>().deleteGreeting();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.voicemailGreetingDeleted),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      afficherErreur(context, e, domaine: ErrorDomain.appel);
    }
  }

  String _dayLabel(int bit) {
    final l10n = context.l10n;
    return switch (bit) {
      0 => l10n.dndDayMon,
      1 => l10n.dndDayTue,
      2 => l10n.dndDayWed,
      3 => l10n.dndDayThu,
      4 => l10n.dndDayFri,
      _ when bit == 5 => l10n.dndDaySat,
      _ => l10n.dndDaySun,
    };
  }

  // ── Plages ────────────────────────────────────────────────────────────────

  /// Écrit la liste COMPLÈTE des plages : le serveur remplace en bloc.
  ///
  /// Remplacement plutôt que différentiel, parce qu'un différentiel obligerait
  /// l'écran à suivre des identifiants de lignes qu'il n'a aucune raison de
  /// connaître.
  Future<void> _ecrireLesPlages(List<VoicemailSlot> plages) async {
    await _patch({'slots': plages.map((s) => s.toJson()).toList()});
  }

  Future<void> _ajouterPlage(int dayBit) async {
    final debut = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 22, minute: 0),
      helpText: context.l10n.dndStartTime,
    );
    if (debut == null || !mounted) return;
    final fin = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      helpText: context.l10n.dndEndTime,
    );
    if (fin == null || !mounted) return;

    final suivantes = [
      ..._schedule.slots,
      VoicemailSlot(
        dayBit: dayBit,
        startTime: _fmt(debut),
        endTime: _fmt(fin),
      ),
    ];
    await _ecrireLesPlages(suivantes);
  }

  Future<void> _supprimerPlage(VoicemailSlot plage) async {
    final suivantes = [..._schedule.slots]..remove(plage);
    await _ecrireLesPlages(suivantes);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Décrit une plage, en disant clairement quand elle déborde sur le lendemain.
  String _decrirePlage(VoicemailSlot p) {
    final l10n = context.l10n;
    if (p.startTime == p.endTime) return l10n.voicemailSlotAllDay;
    final debordeeh = p.endTime.compareTo(p.startTime) < 0;
    final base = '${p.startTime} – ${p.endTime}';
    return debordeeh ? l10n.voicemailSlotOvernight(base) : base;
  }

  // ── Liste autorisée ───────────────────────────────────────────────────────

  Future<void> _choisirLaListe() async {
    final choix = await showPickContactList(
      context,
      selectedId: _schedule.bypassListId,
    );
    // `null` = feuille refermée sans choisir. Ce n'est pas « Personne », qui
    // est un choix explicite portant `idList == null`.
    if (choix == null || !mounted) return;
    await _patch({'bypassListId': choix.idList});
  }

  String _sousTitreListe(List<LocalContactList> listes) {
    final l10n = context.l10n;
    final id = _schedule.bypassListId;
    if (id == null) return l10n.voicemailBypassNobody;
    for (final l in listes) {
      if (l.idList == id) return l.displayName(l10n);
    }
    // Liste supprimée entre-temps : la colonne est retombée à NULL côté base.
    // On affiche « Personne » plutôt qu'un nom fantôme.
    return l10n.voicemailBypassNobody;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final vm = context.watch<VoicemailProvider>();
    final s = vm.schedule ?? const VoicemailSchedule();

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(title: Text(l10n.voicemailScheduleTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                AppSpacing.vGapLg,
                if (!context
                    .watch<EntitlementService>()
                    .has(PlusFeature.voicemail)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: PlusLockedBanner(
                      feature: PlusFeature.voicemail,
                      text: l10n.plusLockedVoicemail,
                    ),
                  ),
                  AppSpacing.vGapLg,
                ],
                // L'état courant en premier : c'est la question que se pose
                // celui qui ouvre cet écran — « est-ce que ça tourne, là ? ».
                if (vm.isActive) _carteEtatCourant(vm),
                if (vm.isActive) AppSpacing.vGapXxl,

                SettingsGroup(
                  title: l10n.voicemailWhenNoAnswer,
                  child: SettingsBoolTile(
                    icon: Icons.phone_missed_outlined,
                    title: l10n.voicemailAfterDelay,
                    subtitle: l10n.voicemailAfterDelaySubtitle,
                    value: s.noAnswerEnabled,
                    onChanged: (v) => _allumer('noAnswerEnabled', v),
                  ),
                ),
                AppSpacing.vGapXxl,

                SettingsGroup(
                  title: l10n.voicemailWhenUnavailable,
                  child: SettingsBoolTile(
                    icon: Icons.event_busy_outlined,
                    title: l10n.voicemailSlotsEnabled,
                    subtitle: l10n.voicemailSlotsEnabledSubtitle,
                    value: s.enabled,
                    onChanged: (v) => _allumer('enabled', v),
                  ),
                ),
                if (s.enabled) _editeurDePlages(s),
                AppSpacing.vGapXxl,

                SettingsGroup(
                  title: l10n.voicemailGreetingSection,
                  child: Column(
                    children: [
                      SettingsNavTile(
                        icon: Icons.graphic_eq_rounded,
                        title: l10n.voicemailGreetingTitle,
                        subtitle: s.greetingUrl == null
                            ? l10n.voicemailGreetingNone
                            : l10n.voicemailGreetingSet(s.greetingSeconds ?? 0),
                        onTap: () => showGreetingRecorder(context),
                      ),
                      // Écouter ce qu'on a enregistré : sans ça, on ne sait pas
                      // ce que les appelants entendent, et on ne peut que
                      // réenregistrer à l'aveugle pour vérifier.
                      if (s.greetingUrl != null)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                          leading: Icon(
                            _annonceJoue
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                            color: context.colors.primary,
                          ),
                          title: Text(
                            _annonceJoue
                                ? l10n.voicemailGreetingPause
                                : l10n.voicemailGreetingListen,
                            style: TextStyle(color: context.colors.primary),
                          ),
                          onTap: () => _ecouterAnnonce(s.greetingUrl!),
                        ),
                      if (s.greetingUrl != null)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
                          leading: Icon(Icons.delete_outline,
                              color: context.colors.error),
                          title: Text(
                            l10n.voicemailGreetingDelete,
                            style: TextStyle(color: context.colors.error),
                          ),
                          onTap: vm.isSaving ? null : _supprimerAnnonce,
                        ),
                    ],
                  ),
                ),
                AppSpacing.vGapXxl,

                StreamBuilder<List<LocalContactList>>(
                  stream:
                      context.read<LocalCacheRepository>().watchContactLists(),
                  builder: (context, snapshot) => SettingsGroup(
                    title: l10n.voicemailBypassTitle,
                    child: SettingsNavTile(
                      icon: Icons.notifications_active_outlined,
                      title: l10n.voicemailBypassTile,
                      subtitle: _sousTitreListe(
                          snapshot.data ?? const <LocalContactList>[]),
                      onTap: _choisirLaListe,
                    ),
                  ),
                ),
                AppSpacing.vGapXxl,
              ],
            ),
    );
  }

  Widget _carteEtatCourant(VoicemailProvider vm) {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.screenH,
      child: Card(
        color: context.colors.primaryContainer,
        elevation: 0,
        child: ListTile(
          leading: Icon(Icons.voicemail_rounded,
              color: context.colors.onPrimaryContainer),
          title: Text(
            vm.deadline == null
                ? l10n.voicemailBannerActive
                : l10n.voicemailBannerUntil(vm.deadline!),
            style: TextStyle(
              color: context.colors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: TextButton(
            onPressed: vm.isSaving ? null : _desactiver,
            child: Text(l10n.voicemailBannerDisable),
          ),
        ),
      ),
    );
  }

  Widget _editeurDePlages(VoicemailSchedule s) {
    final l10n = context.l10n;
    return Column(
      children: [
        AppSpacing.vGapSm,
        for (var bit = 0; bit < 7; bit++) _jour(s, bit),
        Padding(
          padding: AppSpacing.card,
          child: Text(
            // Le fuseau réellement utilisé, en clair. Il se résout par cascade
            // côté serveur — réglage de l'appareil, puis pays du compte — et
            // sans cette ligne, un compte rattaché au mauvais pays donnerait un
            // créneau décalé que rien n'expliquerait.
            l10n.voicemailTimezoneHint(s.resolvedTimezone),
            style: context.text.bodySmall
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _jour(VoicemailSchedule s, int bit) {
    final plages = s.slotsForDay(bit);
    final peutAjouter = plages.length < s.maxSlotsPerDay;
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _dayLabel(bit),
                style: context.text.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      context.l10n.voicemailSlotNone,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ),
                for (final p in plages)
                  Row(
                    children: [
                      Expanded(
                        child: Text(_decrirePlage(p),
                            style: context.text.bodyMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: context.colors.onSurfaceVariant,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _supprimerPlage(p),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            color: peutAjouter
                ? context.colors.primary
                : context.colors.outlineVariant,
            onPressed: peutAjouter ? () => _ajouterPlage(bit) : null,
          ),
        ],
      ),
    );
  }
}
