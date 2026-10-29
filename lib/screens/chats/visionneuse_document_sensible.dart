import 'dart:async';
import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';

/// LA VISIONNEUSE D'UN DOCUMENT SENSIBLE (plan : PLAN-DOCUMENTS-SENSIBLES.md,
/// reprise d'Alanya Work).
///
/// * Le document s'ouvre ICI seulement, jamais dans une autre application :
///   PDF, image, vidéo ou audio. Un autre format ne se lit pas dans Alanya ;
///   seule sa copie signée peut sortir.
/// * L'écran est protégé : ni capture ni enregistrement (Android FLAG_SECURE,
///   iOS).
/// * Une signature court aux QUATRE BORDS — « Consulté par Alanya `numéro` ·
///   `appareil` · `date` » : une photo de l'écran dit qui regardait.
/// * La consultation est notée par le serveur. Son échec n'empêche jamais la
///   lecture.
class VisionneuseDocumentSensible extends StatefulWidget {
  const VisionneuseDocumentSensible({
    super.key,
    required this.msgID,
    required this.type,
    required this.fichier,
    required this.titre,
    this.onEnregistrer,
  });

  final int msgID;

  /// Type du message : 1 image, 2 vidéo, 3 audio, 4 document.
  final int type;
  final File fichier;
  final String titre;

  /// Fait sortir une copie signée ; `null` = pas de bouton.
  final Future<void> Function()? onEnregistrer;

  @override
  State<VisionneuseDocumentSensible> createState() =>
      _VisionneuseDocumentSensibleState();
}

class _VisionneuseDocumentSensibleState
    extends State<VisionneuseDocumentSensible> {
  String? _signature;
  PdfControllerPinch? _pdf;
  VideoPlayerController? _video;
  ChewieController? _chewie;
  bool _videoEnErreur = false;
  bool _enregistrement = false;

  bool get _estPdf =>
      widget.titre.toLowerCase().endsWith('.pdf') ||
      widget.fichier.path.toLowerCase().endsWith('.pdf');

  @override
  void initState() {
    super.initState();
    unawaited(_proteger(true));
    if (widget.type == 4 && _estPdf) {
      _pdf = PdfControllerPinch(document: PdfDocument.openFile(widget.fichier.path));
    } else if (widget.type == 2 || widget.type == 3) {
      unawaited(_preparerLecteur());
    }
    unawaited(_signerEtTracer());
  }

  @override
  void dispose() {
    _pdf?.dispose();
    _chewie?.dispose();
    _video?.dispose();
    unawaited(_proteger(false));
    super.dispose();
  }

  /// Best-effort : une plateforme qui ne sait pas protéger l'écran n'empêche
  /// pas la lecture.
  Future<void> _proteger(bool oui) async {
    try {
      if (oui) {
        await ScreenProtector.preventScreenshotOn();
      } else {
        await ScreenProtector.preventScreenshotOff();
      }
    } catch (_) {/* non supporté — ignoré */}
  }

  Future<void> _preparerLecteur() async {
    final c = VideoPlayerController.file(widget.fichier);
    _video = c;
    try {
      await c.initialize();
      if (!mounted) return;
      setState(() {
        _chewie = ChewieController(
          videoPlayerController: c,
          autoPlay: true,
          // Le plein écran pousse une autre route : la signature des bords ne
          // la suivrait pas.
          allowFullScreen: false,
          allowMuting: true,
        );
      });
    } catch (_) {
      if (mounted) setState(() => _videoEnErreur = true);
    }
  }

  Future<void> _signerEtTracer() async {
    final api = context.read<TalkyApiClient>();
    final numero = AlanyaPhoneFormatter.formatDisplay(
        context.read<AuthProvider>().currentUser?.alanyaPhone);
    final l10n = context.l10n;
    final appareil = await api.appareilCourant();
    if (!mounted) return;
    setState(() {
      _signature = l10n.sensitiveViewedBy(numero, appareil, _dateLisible(DateTime.now()));
    });
    try {
      await api.noterGesteSensible(msgID: widget.msgID);
    } catch (_) {
      // La trace ne doit jamais empêcher la lecture.
    }
  }

  static String _deux(int n) => n.toString().padLeft(2, '0');

  static String _dateLisible(DateTime d) =>
      '${_deux(d.day)}/${_deux(d.month)}/${d.year} ${_deux(d.hour)}:${_deux(d.minute)}';

  Future<void> _enregistrer() async {
    final f = widget.onEnregistrer;
    if (f == null || _enregistrement) return;
    setState(() => _enregistrement = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: AppColors.black,
        foregroundColor: AppColors.white,
        title: Text(widget.titre, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.onEnregistrer != null)
            IconButton(
              tooltip: context.l10n.sensitiveSaveSigned,
              onPressed: _enregistrement ? null : _enregistrer,
              icon: _enregistrement
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: AppColors.white),
                    )
                  : const Icon(Icons.download_rounded),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          _contenu(context),
          if (_signature != null) SignatureBords(texte: _signature!),
        ],
      ),
    );
  }

  Widget _contenu(BuildContext context) {
    switch (widget.type) {
      case 1:
        return InteractiveViewer(
          maxScale: 6,
          child: Center(child: Image.file(widget.fichier)),
        );
      case 2:
      case 3:
        if (_videoEnErreur) return _illisible(context);
        final chewie = _chewie;
        if (chewie == null) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.white));
        }
        return Padding(
          // La signature des bords ne doit pas couvrir les commandes.
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Chewie(controller: chewie),
        );
      default:
        final pdf = _pdf;
        if (pdf == null) return _illisible(context);
        return ColoredBox(
          color: context.colors.surface,
          child: PdfViewPinch(controller: pdf),
        );
    }
  }

  /// Un format que la visionneuse ne sait pas lire : on ne l'ouvre pas
  /// ailleurs, on le dit.
  Widget _illisible(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.white, size: 48),
            AppSpacing.vGapMd,
            Text(
              context.l10n.sensitiveCannotPreview,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: AppColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le texte de la signature le long des quatre bords, au-dessus du document,
/// sans capter les gestes. Blanc cerné de noir : lisible sur une page claire
/// comme sur une photo sombre.
class SignatureBords extends StatelessWidget {
  const SignatureBords({super.key, required this.texte});

  final String texte;

  static const _epaisseur = 18.0;

  @override
  Widget build(BuildContext context) {
    Widget ligne() => SizedBox(
          height: _epaisseur,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                texte,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xCCFFFFFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Color(0xCC000000), blurRadius: 2),
                    Shadow(color: Color(0xCC000000), offset: Offset(0.6, 0.6)),
                  ],
                ),
              ),
            ),
          ),
        );

    return IgnorePointer(
      child: Stack(
          children: [
            Positioned(left: _epaisseur, right: _epaisseur, top: 0, child: ligne()),
            Positioned(left: _epaisseur, right: _epaisseur, bottom: 0, child: ligne()),
            // Les côtés laissent libres, à leurs deux bouts, la bande du texte
            // perpendiculaire : les coins ne se chevauchent pas.
            Positioned(
              left: 0,
              top: _epaisseur,
              bottom: _epaisseur,
              width: _epaisseur,
              child: RotatedBox(quarterTurns: 3, child: ligne()),
            ),
            Positioned(
              right: 0,
              top: _epaisseur,
              bottom: _epaisseur,
              width: _epaisseur,
              child: RotatedBox(quarterTurns: 1, child: ligne()),
            ),
          ],
      ),
    );
  }
}
