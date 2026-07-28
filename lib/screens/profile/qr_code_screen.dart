import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
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

  Future<void> _share() async {
    final identity = _identity;
    if (identity == null) return;
    final user = context.read<AuthProvider>().currentUser;
    final name = user?.nom.trim().isNotEmpty == true
        ? user!.nom.trim()
        : (user?.pseudo.trim() ?? '');
    final text =
        '${context.l10n.qrMyCodeShareText(name)}\n${identity.payload}';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: _shareOrigin()),
      );
    } catch (e, st) {
      AppLog.e('QrCode', 'Partage du code QR échoué', e, st);
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
        Stack(
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
        AppSpacing.vGapXl,
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
                onPressed: _isRegenerating ? null : _regenerate,
                icon: _isRegenerating
                    ? SizedBox(
                        width: AppIconSize.sm,
                        height: AppIconSize.sm,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : const Icon(Icons.autorenew, size: AppIconSize.sm),
                label: Text(l10n.qrMyCodeRegenerate),
              ),
            ),
          ],
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
