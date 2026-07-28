import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/services/local_cache_repository.dart';
import '../../core/services/qr_contact_flow.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../models/qr_models.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'qr_login_confirm_screen.dart';

/// Résultat rendu par [QrScannerScreen] quand le code scanné était une identité.
/// L'appelant s'en sert pour rafraîchir sa liste sans refaire d'appel réseau.
class QrScanContactResult {
  final User contact;
  final bool alreadyContact;

  const QrScanContactResult({
    required this.contact,
    required this.alreadyContact,
  });
}

/// Scanner de code QR plein écran : identité d'un contact ou demande de
/// connexion d'un nouvel appareil. La résolution du payload est faite par le
/// serveur, on ne fait qu'envoyer la chaîne brute.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  /// Verrou de traitement : sans lui, un code resté dans le cadre est résolu
  /// plusieurs dizaines de fois par seconde.
  bool _isHandling = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  /// Le cycle de vie n'est pas géré automatiquement quand on fournit son propre
  /// contrôleur : sans ça, la caméra reste noire au retour d'arrière-plan.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_isHandling) unawaited(_controller.start());
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        unawaited(_controller.stop());
    }
  }

  // ── Traitement d'un code détecté ───────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandling) return;

    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (raw.isEmpty) return;

    // Pré-filtrage local avant tout envoi. Sans lui, cadrer par mégarde un QR
    // Wi-Fi (`WIFI:S:…;P:motdepasse;`), un `otpauth://…?secret=…` ou un code de
    // paiement téléverserait son contenu en clair vers /api/qr/resolve. Le
    // serveur reste l'autorité de résolution : on ne décide rien ici, on refuse
    // seulement d'exfiltrer ce qui ne nous concerne pas.
    if (!_estUnCodeAlanya(raw)) {
      _isHandling = true;
      _resume(context.l10n.qrScanErrorUnreadable);
      return;
    }

    _isHandling = true;
    setState(() => _isBusy = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final result = await apiClient.resolveQr(raw);
      if (!mounted) return;

      if (result.isLogin) {
        await _handleLogin(result.session, result.scanSecret);
        return;
      }
      await _handleContact(result);
    } on TalkyException catch (e) {
      if (!mounted) return;
      _resume(switch (e.statusCode) {
        400 => context.l10n.qrScanErrorUnreadable,
        404 => context.l10n.qrScanErrorUnknown,
        _ => e.message,
      });
    } catch (e, st) {
      AppLog.e('QrScanner', 'Résolution du code scanné échouée', e, st);
      if (!mounted) return;
      _resume(context.l10n.qrLoginNetworkError);
    }
  }

  /// Reconnaît la forme d'un code Alanya (`…/q/u/<jeton>` ou `…/q/l/<jeton>`)
  /// sans chercher à le résoudre — c'est le rôle du serveur.
  static bool _estUnCodeAlanya(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return false;
    if (uri.scheme != 'https' && uri.scheme != 'http') return false;
    final segments = uri.pathSegments;
    if (segments.length < 3) return false;
    return segments[0] == 'q' && (segments[1] == 'u' || segments[1] == 'l');
  }

  Future<void> _handleContact(QrResolveResult result) async {
    final l10n = context.l10n;

    // Son propre code : succès doux, la caméra reste active.
    if (result.isSelf) {
      _resume(l10n.qrScanOwnCode, isError: false);
      return;
    }

    final contact = result.contact;
    if (contact == null) {
      _resume(l10n.qrScanErrorUnknown);
      return;
    }

    final user = User.fromJson(contact);
    await QrContactFlow.cacheContact(
      Provider.of<LocalCacheRepository>(context, listen: false),
      user,
    );
    if (!mounted) return;

    // L'ajout est instantané, sans écran de confirmation : le filet de sécurité
    // promis par la conception est ce bandeau annulable. Sans lui, cadrer par
    // réflexe un code affiché en public écrit un contact sans recours.
    // Les dépendances sont capturées AVANT le pop : le bandeau survit à cet
    // écran (le ScaffoldMessenger est au-dessus de la route), donc son callback
    // ne peut plus s'appuyer sur `context`.
    final messenger = ScaffoldMessenger.of(context);
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);

    QrContactFlow.showAddedSnack(
      messenger: messenger,
      apiClient: apiClient,
      cache: cache,
      l10n: l10n,
      user: user,
      alreadyContact: result.alreadyContact,
    );

    Navigator.pop(
      context,
      QrScanContactResult(
        contact: user,
        alreadyContact: result.alreadyContact,
      ),
    );
  }

  /// Aucune approbation ici : le scan ne fait que révéler la demande, seul
  /// l'écran de confirmation peut autoriser la connexion.
  Future<void> _handleLogin(
    QrLoginSessionInfo? session,
    String? scanSecret,
  ) async {
    if (session == null || scanSecret == null || scanSecret.isEmpty) {
      _resume(context.l10n.qrScanErrorUnreadable);
      return;
    }
    await _controller.stop();
    if (!mounted) return;
    await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => QrLoginConfirmScreen(
          session: session,
          scanSecret: scanSecret,
        ),
      ),
    );
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Réarme la détection après une erreur récupérable. Le délai évite que le
  /// même code, resté dans le cadre, ne relance aussitôt le même message.
  void _resume(String message, {bool isError = true}) {
    _showSnack(message, isError ? AppColors.error : AppColors.brandPrimary);
    setState(() => _isBusy = false);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _isHandling = false;
    });
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final window = _scanWindow(constraints.biggest);
              return MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: window,
                errorBuilder: (ctx, error) => _CameraError(error: error),
              );
            },
          ),

          // Viseur : voile sombre percé d'un carré arrondi.
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) => CustomPaint(
                painter: _ViewfinderPainter(
                  window: _scanWindow(constraints.biggest),
                ),
              ),
            ),
          ),

          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            child: Text(
              context.l10n.qrScanInstruction,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: AppColors.white),
            ),
          ),

          if (_isBusy)
            const ColoredBox(
              color: AppColors.overlayScrim,
              child: Center(
                child: CircularProgressIndicator(color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }

  /// Carré de détection centré — limite le scan à ce que l'utilisateur cadre.
  Rect _scanWindow(Size layout) {
    final side = math.min(layout.width, layout.height) * 0.66;
    return Rect.fromCenter(
      center: layout.center(Offset.zero),
      width: side,
      height: side,
    );
  }

  Widget _buildTopBar() {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          _circleButton(
            icon: Icons.close,
            tooltip: l10n.commonClose,
            onTap: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              l10n.qrScanTitle,
              textAlign: TextAlign.center,
              style: context.text.titleSmall?.copyWith(color: AppColors.white),
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (_, state, __) {
              final isOn = state.torchState == TorchState.on;
              return _circleButton(
                icon: isOn ? Icons.flash_on : Icons.flash_off,
                tooltip: isOn ? l10n.qrScanTorchOn : l10n.qrScanTorchOff,
                onTap: () => unawaited(_controller.toggleTorch()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.black.withAlpha(100),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.white, size: 22),
        ),
      ),
    );
  }
}

/// Écran d'erreur de la caméra — le refus de permission est le cas principal,
/// et le seul pour lequel on propose les réglages système.
class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final isDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: AppColors.black,
      child: Padding(
        padding: AppSpacing.screenH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDenied ? Icons.no_photography_outlined : Icons.error_outline,
              size: AppIconSize.xl,
              color: AppColors.white,
            ),
            AppSpacing.vGapLg,
            Text(
              isDenied
                  ? context.l10n.qrScanCameraDenied
                  : context.l10n.cameraErrorPleaseCheckYourPermissions,
              textAlign: TextAlign.center,
              style:
                  context.text.bodyMedium?.copyWith(color: AppColors.white),
            ),
            AppSpacing.vGapXl,
            FilledButton(
              onPressed: () => unawaited(openAppSettings()),
              child: Text(context.l10n.qrScanOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}

/// Voile sombre percé du carré de visée, avec quatre équerres de marque.
class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.window});

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      window,
      const Radius.circular(AppRadius.lg),
    );

    final scrim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(hole),
    );
    canvas.drawPath(scrim, Paint()..color = AppColors.black.withAlpha(140));

    final bracket = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final arm = window.width * 0.16;

    // Haut gauche
    canvas.drawLine(
        window.topLeft.translate(0, arm), window.topLeft, bracket);
    canvas.drawLine(
        window.topLeft, window.topLeft.translate(arm, 0), bracket);
    // Haut droit
    canvas.drawLine(
        window.topRight.translate(-arm, 0), window.topRight, bracket);
    canvas.drawLine(
        window.topRight, window.topRight.translate(0, arm), bracket);
    // Bas droit
    canvas.drawLine(
        window.bottomRight.translate(0, -arm), window.bottomRight, bracket);
    canvas.drawLine(
        window.bottomRight, window.bottomRight.translate(-arm, 0), bracket);
    // Bas gauche
    canvas.drawLine(
        window.bottomLeft.translate(arm, 0), window.bottomLeft, bracket);
    canvas.drawLine(
        window.bottomLeft, window.bottomLeft.translate(0, -arm), bracket);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.window != window;
}
