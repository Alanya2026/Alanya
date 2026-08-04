import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/utils/app_log.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/common/common.dart';
import '../authentification/login_screen.dart';

/// Tous les appareils sur lesquels le compte est ouvert — pas seulement ceux
/// ajoutés par QR — avec déconnexion à distance ligne par ligne.
class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  List<_AppareilConnecte> _appareils = [];
  bool _chargement = true;
  bool _erreur = false;

  /// Révocations en vol, par identifiant d'appareil : un appui répété sur la
  /// même ligne ne doit pas partir deux fois.
  final Set<int> _revocations = {};

  /// Déconnexion de CET appareil déjà engagée (voir [_deconnecterCetAppareil]).
  bool _deconnexionEnCours = false;

  StreamSubscription<void>? _abonnementRevocation;
  StreamSubscription<AccountDeviceLogin>? _abonnementConnexions;

  @override
  void initState() {
    super.initState();
    final api = context.read<TalkyApiClient>();
    _abonnementRevocation =
        api.thisDeviceRevoked.listen((_) => _surRevocationDistante());
    _abonnementConnexions = api.accountLogins.listen(_surNouvelleConnexion);
    unawaited(_charger());
  }

  @override
  void dispose() {
    unawaited(_abonnementRevocation?.cancel());
    unawaited(_abonnementConnexions?.cancel());
    super.dispose();
  }

  // ── DONNÉES ───────────────────────────────────────────────────────

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final api = context.read<TalkyApiClient>();
      final data = await api.listDeviceSessions();
      if (!mounted) return;
      setState(() {
        _appareils = data.map(_AppareilConnecte.fromJson).toList();
        _chargement = false;
      });
    } catch (e, st) {
      AppLog.e('ConnectedDevices', 'Chargement des appareils échoué', e, st);
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  /// Une session vient de s'ouvrir ailleurs : la liste affichée est périmée.
  void _surNouvelleConnexion(AccountDeviceLogin login) {
    if (!mounted) return;
    _afficher(
      context.l10n.qrBannerNewDevice(
        login.deviceName ?? context.l10n.qrDevicesUnknownDevice,
      ),
      AppColors.brandPrimary,
    );
    unawaited(_charger());
  }

  // ── RÉVOCATION ────────────────────────────────────────────────────

  Future<void> _revoquer(_AppareilConnecte appareil) async {
    if (_revocations.contains(appareil.id)) return;

    final nom = _nom(appareil);
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.qrDevicesRevokeConfirmTitle),
        content: Text(ctx.l10n.qrDevicesRevokeConfirmBody(nom)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              ctx.l10n.qrDevicesRevoke,
              style: TextStyle(color: ctx.colors.error),
            ),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    setState(() => _revocations.add(appareil.id));
    try {
      await context.read<TalkyApiClient>().revokeDeviceSession(appareil.id);
      if (!mounted) return;
      if (appareil.current) {
        await _deconnecterCetAppareil(context.l10n.qrDevicesRevokeDone);
        return;
      }
      setState(() {
        _appareils = _appareils.where((a) => a.id != appareil.id).toList();
        _revocations.remove(appareil.id);
      });
      _afficher(context.l10n.qrDevicesRevokeDone, AppColors.success);
    } catch (e, st) {
      AppLog.e('ConnectedDevices', 'Révocation d\'appareil échouée', e, st);
      if (!mounted) return;
      setState(() => _revocations.remove(appareil.id));
      _afficher(
        e is TalkyException ? e.message : context.l10n.qrLoginNetworkError,
        AppColors.error,
      );
    }
  }

  /// Cet appareil a été déconnecté depuis un autre : ses tokens sont déjà
  /// effacés par la couche socket, il ne reste qu'à finir proprement.
  void _surRevocationDistante() {
    if (!mounted) return;
    unawaited(
      _deconnecterCetAppareil(context.l10n.qrBannerSignedOutRemotely),
    );
  }

  /// Révoquer sa propre ligne condamne la session locale : le prochain appel
  /// partirait en 401. On prend les devants avec le chemin de déconnexion
  /// normal de l'app, qui purge aussi le cache local.
  ///
  /// Le verrou n'est pas décoratif : se déconnecter soi-même déclenche AUSSI
  /// `auth:device_revoked` sur cet appareil, donc deux chemins arrivent ici.
  Future<void> _deconnecterCetAppareil(String message) async {
    if (_deconnexionEnCours) return;
    _deconnexionEnCours = true;
    _afficher(message, AppColors.brandPrimary);
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _afficher(String message, Color fond) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: fond,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── RENDU ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(context.l10n.qrDevicesTitle),
      ),
      body: _corps(),
    );
  }

  Widget _corps() {
    if (_chargement) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erreur) {
      return EmptyState(
        icon: Icons.cloud_off,
        title: context.l10n.qrDevicesLoadError,
        iconColor: context.colors.error,
        action: TextButton(
          onPressed: () => unawaited(_charger()),
          child: Text(context.l10n.commonRetry),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        // Sans ça, une liste d'un seul appareil ne se tire pas pour rafraîchir.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        children: [
          if (_appareils.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxxl),
              child: EmptyState(
                icon: Icons.devices_outlined,
                title: context.l10n.qrDevicesEmpty,
              ),
            )
          else
            for (final appareil in _appareils)
              _LigneAppareil(
                appareil: appareil,
                libelle: _nom(appareil),
                enCours: _revocations.contains(appareil.id),
                onRevoke: () => unawaited(_revoquer(appareil)),
              ),
          AppSpacing.vGapLg,
          // Limite connue d'iOS : `identifierForVendor` ne survit pas à une
          // réinstallation, l'appareil revient donc comme un nouveau.
          WarningBanner(
            message: context.l10n.qrDevicesIosNote,
            variant: WarningBannerVariant.info,
          ),
        ],
      ),
    );
  }

  String _nom(_AppareilConnecte appareil) =>
      appareil.deviceName ?? context.l10n.qrDevicesUnknownDevice;
}

/// Une ligne de la liste : identité de l'appareil, méthode de connexion,
/// dernière activité, et déconnexion.
class _LigneAppareil extends StatelessWidget {
  const _LigneAppareil({
    required this.appareil,
    required this.libelle,
    required this.enCours,
    required this.onRevoke,
  });

  final _AppareilConnecte appareil;
  final String libelle;
  final bool enCours;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (_methode(context) != null) _methode(context)!,
      if (appareil.lastActiveAt != null)
        context.l10n.qrDevicesLastActive(_date(appareil.lastActiveAt!)),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadius.brSm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icone(),
                color: context.colors.onSurfaceVariant,
                size: AppIconSize.md,
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          libelle,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                      ),
                      if (appareil.current) ...[
                        AppSpacing.hGapSm,
                        const _BadgeCetAppareil(),
                      ],
                    ],
                  ),
                  if (details.isNotEmpty) ...[
                    AppSpacing.vGapXs,
                    Text(
                      details,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.hGapSm,
            if (enCours)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: onRevoke,
                child: Text(
                  context.l10n.qrDevicesRevoke,
                  style: TextStyle(
                    color: context.colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _methode(BuildContext context) => switch (appareil.loginMethod) {
        'password' => context.l10n.qrDevicesMethodPassword,
        'register' => context.l10n.qrDevicesMethodSignup,
        'qr' => context.l10n.qrDevicesMethodQr,
        _ => null,
      };

  IconData _icone() {
    final plateforme = appareil.platform?.toLowerCase() ?? '';
    if (plateforme.contains('android')) return Icons.phone_android;
    if (plateforme.contains('ios')) return Icons.phone_iphone;
    if (plateforme.contains('web')) return Icons.language;
    if (plateforme.contains('mac') ||
        plateforme.contains('windows') ||
        plateforme.contains('linux')) {
      return Icons.computer;
    }
    return Icons.devices_other;
  }

  /// Heure seule pour aujourd'hui, date sinon : les libellés relatifs
  /// (« il y a 2 h ») demanderaient des chaînes que l'app n'a pas.
  String _date(DateTime date) {
    final locale = LocaleController.instance.resolvedLocale.toLanguageTag();
    final local = date.toLocal();
    final maintenant = DateTime.now();
    final memeJour = local.year == maintenant.year &&
        local.month == maintenant.month &&
        local.day == maintenant.day;
    return memeJour
        ? DateFormat.Hm(locale).format(local)
        : DateFormat.yMMMd(locale).format(local);
  }
}

class _BadgeCetAppareil extends StatelessWidget {
  const _BadgeCetAppareil();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.12),
        borderRadius: AppRadius.brPill,
      ),
      child: Text(
        context.l10n.qrDevicesThisDevice,
        style: context.text.labelSmall?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Ligne de la table `appareils` telle que renvoyée par
/// `GET /api/auth/device-sessions`.
class _AppareilConnecte {
  final int id;
  final String? deviceName;
  final String? platform;

  /// 'password' | 'register' | 'qr'
  final String? loginMethod;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;
  final bool current;

  const _AppareilConnecte({
    required this.id,
    required this.current,
    this.deviceName,
    this.platform,
    this.loginMethod,
    this.createdAt,
    this.lastActiveAt,
  });

  factory _AppareilConnecte.fromJson(Map<String, dynamic> json) =>
      _AppareilConnecte(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        deviceName: _renseigne(json['deviceName']),
        platform: _renseigne(json['platform']),
        loginMethod: _renseigne(json['loginMethod']),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt']?.toString() ?? ''),
        current: json['current'] == true,
      );

  /// 'INDEFINI' est le repli du backend quand l'appareil n'a pas su se nommer :
  /// c'est une absence d'information, pas un libellé à afficher.
  static String? _renseigne(Object? value) {
    final texte = value?.toString().trim() ?? '';
    return texte.isEmpty || texte == 'INDEFINI' ? null : texte;
  }
}
