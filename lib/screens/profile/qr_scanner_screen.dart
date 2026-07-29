import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/services/chat/message_sound_service.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/services/qr_contact_flow.dart';
import '../../widgets/qr_added_sheet.dart';
import '../../widgets/qr_scan_result_card.dart';
import '../chats/chat_detail_screen.dart';
import '../chats/contact_detail_screen.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../models/qr_models.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import 'qr_login_confirm_screen.dart';

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

  /// Contact ajouté par le dernier scan, affiché en carte de résultat.
  User? _resultat;
  bool _resultatDejaContact = false;

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

    final raw = _premierCode(capture);
    if (raw == null) return;

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
    await _resoudre(raw);
  }

  /// Premier code non vide d'une capture, quelle qu'en soit l'origine — cadre
  /// de la caméra ou image importée.
  static String? _premierCode(BarcodeCapture capture) {
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    return raw.isEmpty ? null : raw;
  }

  /// Résolution serveur d'un payload déjà reconnu comme code Alanya. Commun
  /// aux deux sources : caméra et galerie doivent produire exactement le même
  /// résultat, le même son et la même carte — l'origine du code ne regarde pas
  /// l'utilisateur.
  ///
  /// L'appelant est responsable d'avoir armé `_isHandling`.
  Future<void> _resoudre(String raw) async {
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

  // ── Import d'une image de la galerie ───────────────────────────────────

  /// Analyse un QR déjà présent dans la pellicule : capture d'écran d'un code
  /// reçu, ou photo d'un code affiché sur un autre écran. C'est le secours
  /// quand le cadrage échoue — ou quand il n'y a rien à cadrer, le code ayant
  /// été reçu par message.
  Future<void> _importerDepuisGalerie() async {
    if (_isHandling) return;
    _isHandling = true;

    final l10n = context.l10n;
    setState(() => _isBusy = true);

    String? chemin;
    try {
      final fichier =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      chemin = fichier?.path;
    } catch (e, st) {
      AppLog.w('QrScanner', 'Sélection d\'image échouée', e, st);
      if (!mounted) return;
      await _reprendreCamera();
      _resume(l10n.qrScanImportFailed);
      return;
    }

    if (!mounted) return;

    // Le sélecteur a mis l'app en arrière-plan, donc didChangeAppLifecycleState
    // a coupé la caméra sans la relancer (`_isHandling` était armé). Il faut la
    // rallumer nous-même, sinon l'écran reste noir derrière la carte.
    await _reprendreCamera();
    if (!mounted) return;

    // Choix abandonné : ce n'est pas une erreur, on se contente de réarmer.
    if (chemin == null) {
      setState(() => _isBusy = false);
      _isHandling = false;
      return;
    }

    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(chemin);
    } catch (e, st) {
      AppLog.w('QrScanner', 'Analyse de l\'image importée échouée', e, st);
      if (!mounted) return;
      _resume(l10n.qrScanImportFailed);
      return;
    }
    if (!mounted) return;

    // Trois issues distinctes, trois messages : confondre « pas de code » et
    // « code d'une autre app » laisse croire que l'import est cassé.
    final raw = capture == null ? null : _premierCode(capture);
    if (raw == null) {
      _resume(l10n.qrScanImportNoCode);
      return;
    }
    if (!_estUnCodeAlanya(raw)) {
      _resume(l10n.qrScanImportNotAlanya);
      return;
    }

    await _resoudre(raw);
  }

  /// Relance la caméra si elle est à l'arrêt. Redémarrer un contrôleur déjà
  /// démarré lève, d'où le test préalable.
  Future<void> _reprendreCamera() async {
    if (_controller.value.isRunning) return;
    try {
      await _controller.start();
    } catch (e, st) {
      AppLog.w('QrScanner', 'Reprise de la caméra échouée', e, st);
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

    _playScanSuccessFeedback();

    // On ne referme plus le scanner : la carte de résultat s'affiche par-dessus
    // la caméra restée vivante, pour pouvoir enchaîner plusieurs personnes.
    setState(() {
      _isBusy = false;
      _resultat = user;
      _resultatDejaContact = result.alreadyContact;
    });
  }

  /// Retire la carte et réarme la détection.
  void _fermerResultat() {
    if (!mounted) return;
    setState(() => _resultat = null);
    _isHandling = false;
  }

  Future<void> _messagerResultat(User user) async {
    final convId = await conversationDirecteLocale(context, user.alanyaID);
    if (!mounted) return;
    _fermerResultat();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          userName: user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo,
          conversationId: convId,
          userId: user.alanyaID,
          avatarUrl: user.avatarUrl,
        ),
      ),
    );
  }

  void _voirDetails(User user) {
    _fermerResultat();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailScreen(
          userId: user.alanyaID,
          initialName: user.nom.trim().isNotEmpty ? user.nom.trim() : user.pseudo,
          initialAvatar: user.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _annulerResultat(User user) async {
    final messenger = ScaffoldMessenger.of(context);
    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final cache = Provider.of<LocalCacheRepository>(context, listen: false);
    final l10n = context.l10n;
    _fermerResultat();
    await QrContactFlow.undoAdd(
      messenger: messenger,
      apiClient: apiClient,
      cache: cache,
      l10n: l10n,
      user: user,
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
    _playScanSuccessFeedback();
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

  /// Accusé sonore + haptic au scan réussi (contact ou connexion appareil).
  /// Coupé automatiquement en silencieux via le canal notification.
  void _playScanSuccessFeedback() {
    MessageSoundService.instance.playQrScanSuccess();
    HapticFeedback.mediumImpact();
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

          if (_resultat != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: QrScanResultCard(
                  key: ValueKey(_resultat!.alanyaID),
                  user: _resultat!,
                  alreadyContact: _resultatDejaContact,
                  onMessage: () => unawaited(_messagerResultat(_resultat!)),
                  onDetails: () => _voirDetails(_resultat!),
                  onUndo: () => unawaited(_annulerResultat(_resultat!)),
                  onDismissed: _fermerResultat,
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 0,
            right: 0,
            child: _buildTopBar(),
          ),

          // Instruction et secours au même endroit : c'est là que le regard
          // revient quand le cadrage ne prend pas.
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.qrScanInstruction,
                  textAlign: TextAlign.center,
                  style:
                      context.text.bodyMedium?.copyWith(color: AppColors.white),
                ),
                AppSpacing.vGapSm,
                TextButton.icon(
                  onPressed: () => unawaited(_importerDepuisGalerie()),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.white,
                    backgroundColor: AppColors.black.withAlpha(100),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  icon: const Icon(Icons.photo_library_outlined,
                      size: AppIconSize.sm),
                  label: Text(context.l10n.qrScanImportImage),
                ),
              ],
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
