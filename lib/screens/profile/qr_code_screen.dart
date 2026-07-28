import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_log.dart';
import '../../models/qr_models.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../widgets/common/common.dart';
import '../../widgets/alanya_qr_view.dart';
import 'qr_scanner_screen.dart';

/// Diamètre du médaillon d'avatar qui déborde le haut de la carte.
const double _kMedallionSize = 88;

/// Écran d'identité QR : « Mon code » et « Scanner », deux volets d'un geste.
class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Ancre de capture de la carte : partage et enregistrement produisent la
  /// même image, celle que l'utilisateur a sous les yeux.
  final GlobalKey _carteKey = GlobalKey();

  bool _isSaving = false;

  QrIdentity? _identity;
  String? _loadError;
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _scannerAlreadyOpened = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    unawaited(_loadIdentity());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// Le volet « Scanner » n'est qu'un tremplin vers la caméra plein écran :
  /// on l'ouvre dès la première bascule pour tenir la promesse d'un seul geste,
  /// et on retombe ensuite sur le panneau au retour (bouton de relance).
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index != 1 || _scannerAlreadyOpened) return;
    _scannerAlreadyOpened = true;
    unawaited(_openScanner());
  }

  Future<void> _openScanner() async {
    await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
  }

  // ── Chargement du code d'identité ──────────────────────────────────────

  Future<void> _loadIdentity() async {
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final identity = await apiClient.getMyQr();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLog.e('QrCode', 'Chargement du code QR échoué', e, st);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = _errorMessage(e);
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    unawaited(_loadIdentity());
  }

  String _errorMessage(Object error) => error is TalkyException
      ? error.message
      : context.l10n.qrLoginNetworkError;

  // ── Actions ────────────────────────────────────────────────────────────

  /// Capture la carte telle qu'elle est affichée, en PNG.
  ///
  /// `pixelRatio` 3 plutôt que celui de l'écran : l'image doit rester nette une
  /// fois agrandie sur un autre appareil pour être scannable, et un QR flou ne
  /// se lit pas.
  Future<Uint8List?> _capturerCarte() async {
    try {
      final boundary =
          _carteKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (e, st) {
      AppLog.e('QrCode', 'Capture de la carte échouée', e, st);
      return null;
    }
  }

  Future<File?> _ecrireFichierTemporaire(Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      // Nom stable : réécrire le même fichier évite d'accumuler des captures
      // dans le cache à chaque partage.
      final file = File('${dir.path}/alanya-mon-code.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e, st) {
      AppLog.e('QrCode', 'Écriture du fichier temporaire échouée', e, st);
      return null;
    }
  }

  /// Légende du partage : le lien ET l'Alanya ID, en plus de l'image.
  /// Les trois véhiculent la même identité par des chemins différents — le
  /// destinataire scanne, tape le lien, ou saisit l'ID à la main selon ce dont
  /// il dispose.
  String _texteDePartage(QrIdentity identity) {
    final l10n = context.l10n;
    final user = context.read<AuthProvider>().currentUser;
    final name = user?.nom.trim().isNotEmpty == true
        ? user!.nom.trim()
        : (user?.pseudo.trim() ?? '');
    final phone = (user?.alanyaPhone ?? '').trim();

    return [
      l10n.qrMyCodeShareText(name),
      if (phone.isNotEmpty) l10n.qrMyCodeShareId(AlanyaPhoneFormatter.formatDisplay(phone)),
      identity.payload,
    ].join('\n');
  }

  Future<void> _share() async {
    final identity = _identity;
    if (identity == null) return;

    final texte = _texteDePartage(identity);
    final origine = _shareOrigin();
    final bytes = await _capturerCarte();
    final fichier = bytes == null ? null : await _ecrireFichierTemporaire(bytes);
    if (!mounted) return;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: texte,
          // L'image est un bonus : si la capture échoue, le partage part quand
          // même avec le lien et l'identifiant, qui suffisent à ajouter.
          files: fichier == null ? null : [XFile(fichier.path)],
          sharePositionOrigin: origine,
        ),
      );
    } catch (e, st) {
      AppLog.e('QrCode', 'Partage du code QR échoué', e, st);
    }
  }

  Future<void> _enregistrerDansGalerie() async {
    if (_isSaving || _identity == null) return;
    final l10n = context.l10n;
    setState(() => _isSaving = true);
    try {
      final bytes = await _capturerCarte();
      if (bytes == null) throw StateError('capture vide');
      final fichier = await _ecrireFichierTemporaire(bytes);
      if (fichier == null) throw StateError('écriture impossible');

      if (!await Gal.hasAccess(toAlbum: true)) {
        await Gal.requestAccess(toAlbum: true);
      }
      await Gal.putImage(fichier.path, album: 'Alanya');
      if (!mounted) return;
      _showSnack(l10n.qrMyCodeSaveDone, AppColors.success);
    } on GalException catch (e, st) {
      AppLog.w('QrCode', 'Enregistrement galerie refusé', e, st);
      if (!mounted) return;
      _showSnack(
        e.type == GalExceptionType.accessDenied
            ? l10n.qrMyCodeSaveDenied
            : l10n.qrMyCodeSaveFailed,
        AppColors.error,
      );
    } catch (e, st) {
      AppLog.e('QrCode', 'Enregistrement du code échoué', e, st);
      if (!mounted) return;
      _showSnack(l10n.qrMyCodeSaveFailed, AppColors.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Ancre du sheet de partage — obligatoire sur iPad, ignorée ailleurs.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _regenerate() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.qrMyCodeRegenerateConfirmTitle),
        content: Text(l10n.qrMyCodeRegenerateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.qrMyCodeRegenerate,
              style: TextStyle(color: ctx.colors.error),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => _isRegenerating = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final identity = await apiClient.regenerateQr();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _isRegenerating = false;
      });
      _showSnack(l10n.qrMyCodeRegenerateDone, AppColors.success);
    } catch (e, st) {
      AppLog.e('QrCode', 'Régénération du code QR échouée', e, st);
      if (!mounted) return;
      setState(() => _isRegenerating = false);
      _showSnack(_errorMessage(e), AppColors.error);
    }
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
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.qrMyCodeTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.qrMyCodeTabCode),
            Tab(text: l10n.qrMyCodeTabScan),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyCode(),
          _buildScanTab(),
        ],
      ),
    );
  }

  Widget _buildMyCode() {
    if (_isLoading) return const LoadingState();

    final error = _loadError;
    if (error != null) {
      return Padding(
        padding: AppSpacing.screenH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2_outlined,
              size: AppIconSize.xl,
              color: context.colors.onSurfaceVariant,
            ),
            AppSpacing.vGapLg,
            Text(
              error,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            AppSpacing.vGapXl,
            OutlinedButton(
              onPressed: _retryLoad,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    final l10n = context.l10n;
    final identity = _identity!;
    final user = context.watch<AuthProvider>().currentUser;
    final displayName = user?.nom.trim().isNotEmpty == true
        ? user!.nom.trim()
        : (user?.pseudo.trim() ?? l10n.userFallback);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxxl,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        RepaintBoundary(
          key: _carteKey,
          child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.topCenter,
          children: [
            Container(
              margin: const EdgeInsets.only(top: _kMedallionSize / 2),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                _kMedallionSize / 2 + AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              decoration: BoxDecoration(
                // Dérogation assumée au thème : la carte reste blanche même en
                // sombre, un QR sur fond foncé se scanne beaucoup moins bien.
                color: AppColors.white,
                borderRadius: AppRadius.brMd,
                boxShadow: AppShadows.subtle,
              ),
              child: Column(
                children: [
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                  if ((user?.alanyaPhone ?? '').isNotEmpty) ...[
                    AppSpacing.vGapXs,
                    AlanyaPhoneText(
                      user!.alanyaPhone,
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  AppSpacing.vGapXl,
                  _buildQrImage(identity.payload),
                  AppSpacing.vGapLg,
                  Text(
                    l10n.qrMyCodeSubtitle,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
              child: AppAvatar(
                imageUrl: (user?.avatarUrl ?? '').isNotEmpty
                    ? user!.avatarUrl
                    : null,
                name: displayName,
                size: _kMedallionSize - AppSpacing.sm,
                backgroundColor: AppColors.brandContainer,
                foregroundColor: AppColors.brandPrimary,
              ),
            ),
          ],
          ),
        ),
        AppSpacing.vGapXl,
        // Partager et Enregistrer sont deux façons d'exporter la même carte :
        // même rangée, même poids visuel. Régénérer est plus bas et en faible
        // emphase — c'est une action rare, et surtout irréversible : elle
        // invalide le code déjà partagé. Lui donner l'allure d'un bouton
        // courant inviterait à la déclencher par mégarde.
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.ios_share, size: AppIconSize.sm),
                label: Text(l10n.qrMyCodeShare),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _enregistrerDansGalerie,
                icon: _isSaving
                    ? SizedBox(
                        width: AppIconSize.sm,
                        height: AppIconSize.sm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : const Icon(Icons.download_outlined, size: AppIconSize.sm),
                label: Text(l10n.qrMyCodeSave),
              ),
            ),
          ],
        ),
        AppSpacing.vGapMd,
        Center(
          child: TextButton.icon(
            onPressed: _isRegenerating ? null : _regenerate,
            icon: _isRegenerating
                ? SizedBox(
                    width: AppIconSize.sm,
                    height: AppIconSize.sm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.onSurfaceVariant,
                    ),
                  )
                : const Icon(Icons.autorenew, size: AppIconSize.sm),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.onSurfaceVariant,
            ),
            label: Text(l10n.qrMyCodeRegenerate),
          ),
        ),
      ],
    );
  }

  Widget _buildQrImage(String payload) {
    final side = math.min(260.0, MediaQuery.sizeOf(context).width - 96);
    return AlanyaQrView(payload: payload, size: side);
  }

  Widget _buildScanTab() {
    final l10n = context.l10n;
    return Padding(
      padding: AppSpacing.screenH,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: context.semantic.brandContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner,
              size: AppIconSize.xl,
              color: context.semantic.onBrandContainer,
            ),
          ),
          AppSpacing.vGapXl,
          Text(
            l10n.qrScanInstruction,
            textAlign: TextAlign.center,
            style: context.text.bodyLarge
                ?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          AppSpacing.vGapXxl,
          FilledButton.icon(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner, size: AppIconSize.sm),
            label: Text(l10n.qrScanEntryButton),
          ),
        ],
      ),
    );
  }
}
