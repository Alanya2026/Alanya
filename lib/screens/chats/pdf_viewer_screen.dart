import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import '../../core/theme/app_theme.dart';

/// Visionneuse PDF intégrée (défilement + zoom pincé).
///
/// Elle lit TOUJOURS depuis un fichier local déjà téléchargé (`path`), jamais
/// depuis l'URL réseau : le serveur `158.220.107.211` utilise un certificat
/// auto-signé que la couche native de pdfx rejetterait. Le téléchargement
/// (via `ensureCached`, qui gère le certificat) est fait par l'appelant.
class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String title;

  const PdfViewerScreen({super.key, required this.path, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  late final PdfControllerPinch _controller;
  int _pages = 0;
  int _current = 1;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(document: PdfDocument.openFile(widget.path));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_pages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_current / $_pages'),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: context.l10n.openWith,
            onPressed: () => OpenFilex.open(widget.path),
          ),
        ],
      ),
      body: PdfViewPinch(
        controller: _controller,
        onDocumentLoaded: (doc) {
          if (mounted) setState(() => _pages = doc.pagesCount);
        },
        onPageChanged: (page) {
          if (mounted) setState(() => _current = page);
        },
      ),
    );
  }
}
