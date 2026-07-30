import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Ce que le partage envoie réellement — voir [_QrCodeScreenState._share] pour
/// la raison de cette séparation.
enum _ModePartage { lien, image }

/// Écran d'identité QR : « Mon code » et « Scanner », deux volets d'un geste.
class QrCodeScreen extends StatefulWidget {
  const QrCodeScreen({super.key});

  @override
  State<QrCodeScreen> createState() => _QrCodeScreenState();
}

class _QrCodeScreenState extends State<QrCodeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Ancre de capture de la carte : le partage d'image envoie exactement ce
  /// que l'utilisateur a sous les yeux.
  final GlobalKey _carteKey = GlobalKey();

  QrContactCode? _code;
  String? _loadError;
  bool _isLoading = true;
  bool _isRegenerating = false;
  bool _scannerAlreadyOpened = false;

  /// Instant de réception du code, origine du décompte : on ne compare jamais
  /// l'horloge de l'appareil à celle du serveur (même patron que l'écran de
  /// connexion par QR).
  DateTime? _recueA;
  Duration _restant = Duration.zero;
  Timer? _timerCompteARebours;

  /// Discrimine les réponses tardives d'un code déjà remplacé.
  int _generation = 0;

  /// Mon code vient d'être scanné : il est consommé (usage unique), on en
  /// génère un neuf sans geste de l'utilisateur. Le dialogue « ajouter en
  /// retour », lui, est global (AuthWrapper) — pas ici.
  StreamSubscription<QrContactScan>? _scanSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scanSub = Provider.of<TalkyApiClient>(context, listen: false)
        .qrContactScans
        .listen((_) {
      if (mounted) unawaited(_creerCode());
    });
    unawaited(_creerCode());
  }

  @override
  void dispose() {
    _timerCompteARebours?.cancel();
    _scanSub?.cancel();
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

  // ── Cycle de vie du code éphémère ──────────────────────────────────────

  /// Génère un code neuf (10 minutes, usage unique — le serveur invalide le
  /// précédent). Appelé à l'ouverture, à l'expiration, après consommation, et
  /// par le bouton « Nouveau code ».
  Future<void> _creerCode() async {
    _timerCompteARebours?.cancel();
    final generation = ++_generation;
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final code = await apiClient.createContactQr();
      if (!mounted || generation != _generation) return;
      setState(() {
        _code = code;
        _recueA = DateTime.now();
        _restant = code.ttl;
        _isLoading = false;
        _isRegenerating = false;
        _loadError = null;
      });
      _timerCompteARebours =
          Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    } catch (e, st) {
      AppLog.e('QrCode', 'Création du code QR échouée', e, st);
      if (!mounted || generation != _generation) return;
      setState(() {
        _isLoading = false;
        _isRegenerating = false;
        _loadError = _errorMessage(e);
      });
    }
  }

  Duration _dureeRestante() {
    final code = _code;
    final origine = _recueA;
    if (code == null || origine == null) return Duration.zero;
    final restant = code.ttl - DateTime.now().difference(origine);
    return restant.isNegative ? Duration.zero : restant;
  }

  /// Un code mort ne doit jamais rester sous les yeux de l'utilisateur : à
  /// zéro, on régénère sans lui demander un geste.
  void _tick() {
    final restant = _dureeRestante();
    if (restant > Duration.zero) {
      setState(() => _restant = restant);
      return;
    }
    unawaited(_creerCode());
  }

  void _retryLoad() {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    unawaited(_creerCode());
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
  String _texteDePartage(QrContactCode code) {
    final l10n = context.l10n;
    final user = context.read<AuthProvider>().currentUser;
    final name = user?.nom.trim().isNotEmpty == true
        ? user!.nom.trim()
        : (user?.pseudo.trim() ?? '');
    final phone = (user?.alanyaPhone ?? '').trim();

    return [
      l10n.qrMyCodeShareText(name),
      // Le code meurt en 10 minutes ; l'Alanya ID, lui, reste le chemin
      // permanent — les deux doivent voyager ensemble.
      l10n.qrMyCodeShareValidity,
      if (phone.isNotEmpty) l10n.qrMyCodeShareId(AlanyaPhoneFormatter.formatDisplay(phone)),
      code.payload,
    ].join('\n');
  }

  /// Deux partages distincts plutôt qu'un seul mélangeant image et texte.
  ///
  /// Sur Android, un partage de type `image/*` transporte bien `EXTRA_TEXT`,
  /// mais la plupart des messageries l'ignorent dès qu'il y a une pièce
  /// jointe — le lien et l'identifiant disparaissaient donc silencieusement.
  /// On ne peut pas l'imposer depuis l'app émettrice : autant laisser choisir
  /// explicitement ce qu'on envoie.
  Future<void> _share() async {
    if (_code == null) return;
    final l10n = context.l10n;

    final choix = await showModalBottomSheet<_ModePartage>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
              ),
              child: Text(
                l10n.qrMyCodeShareSheetTitle,
                style: ctx.text.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.qrMyCodeShareLink),
              subtitle: Text(l10n.qrMyCodeShareLinkHint),
              onTap: () => Navigator.pop(ctx, _ModePartage.lien),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.qrMyCodeShareImage),
              subtitle: Text(l10n.qrMyCodeShareImageHint),
              onTap: () => Navigator.pop(ctx, _ModePartage.image),
            ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );

    if (!mounted || choix == null) return;
    await (choix == _ModePartage.lien ? _partagerLien() : _partagerImage());
  }

  Future<void> _partagerLien() async {
    final code = _code;
    if (code == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: _texteDePartage(code),
          sharePositionOrigin: _shareOrigin(),
        ),
      );
    } catch (e, st) {
      AppLog.e('QrCode', 'Partage du lien échoué', e, st);
    }
  }

  Future<void> _partagerImage() async {
    final code = _code;
    if (code == null) return;

    final texte = _texteDePartage(code);
    final origine = _shareOrigin();
    final bytes = await _capturerCarte();
    final fichier = bytes == null ? null : await _ecrireFichierTemporaire(bytes);
    if (!mounted) return;

    // Si la capture échoue, on n'envoie pas un partage vide : on retombe sur
    // le lien, qui suffit à ajouter le contact.
    if (fichier == null) return _partagerLien();

    try {
      await SharePlus.instance.share(
        ShareParams(
          // Texte joint quand même : les applications qui l'honorent
          // (souvent iOS, parfois Android) l'afficheront en légende.
          text: texte,
          files: [XFile(fichier.path)],
          sharePositionOrigin: origine,
        ),
      );
    } catch (e, st) {
      AppLog.e('QrCode', 'Partage de l\'image échoué', e, st);
    }
  }

  /// Ancre du sheet de partage — obligatoire sur iPad, ignorée ailleurs.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// « Nouveau code » : pas de dialogue de confirmation — le code expire de
  /// lui-même en 10 minutes, le renouveler n'a rien d'irréversible.
  Future<void> _regenerate() async {
    if (_isRegenerating) return;
    setState(() => _isRegenerating = true);
    await _creerCode();
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
    final code = _code!;
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
                  _buildQrImage(code.payload),
                  AppSpacing.vGapMd,
                  // Le décompte vit SUR la carte : il fait partie de ce que
                  // dit le code (« je suis temporaire »), y compris sur
                  // l'image partagée.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandContainer,
                      borderRadius: AppRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.brandPrimaryDark,
                        ),
                        AppSpacing.hGapXs,
                        Text(
                          l10n.qrMyCodeExpiresIn(_formatRestant()),
                          style: context.text.labelMedium?.copyWith(
                            color: AppColors.brandPrimaryDark,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vGapMd,
                  Text(
                    l10n.qrMyCodeSubtitle,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    l10n.qrMyCodeValidityNote,
                    textAlign: TextAlign.center,
                    style: context.text.bodySmall
                        ?.copyWith(color: AppColors.textTertiary),
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
                label: Text(l10n.qrMyCodeNewCode),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatRestant() {
    final m = _restant.inMinutes;
    final sec = _restant.inSeconds % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
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
