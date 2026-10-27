import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/media_album.dart';

/// Ce que rend l'aperçu : les fichiers retenus (dans l'ordre) et la légende.
class ApercuDocumentsResult {
  const ApercuDocumentsResult({required this.items, this.caption});

  final List<AlbumSendItem> items;

  /// Portée par le premier message ; `null` si vide.
  final String? caption;
}

/// L'APERÇU AVANT L'ENVOI DE DOCUMENTS SENSIBLES (comme Alanya Work) : on
/// passe d'un fichier à l'autre, on en retire, on ajoute une légende.
///
/// Pas de retouche : un document sensible part tel qu'il a été choisi. Une
/// photo se montre telle quelle et un PDF par sa première page — l'expéditeur
/// voit son propre fichier, sur son téléphone ; aucune vignette ne part avec
/// le message.
///
/// Un fichier qui n'est PAS sensible (copie déjà signée, renvoyée en
/// ordinaire) est signalé comme tel.
class ApercuDocumentsSensibles extends StatefulWidget {
  const ApercuDocumentsSensibles({
    super.key,
    required this.items,
    this.recipientName,
  });

  final List<AlbumSendItem> items;
  final String? recipientName;

  @override
  State<ApercuDocumentsSensibles> createState() =>
      _ApercuDocumentsSensiblesState();
}

class _ApercuDocumentsSensiblesState extends State<ApercuDocumentsSensibles> {
  late final List<AlbumSendItem> _items = [...widget.items];
  final _legende = TextEditingController();
  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _legende.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _retirer(int i) {
    if (_items.length == 1) {
      // Retirer le dernier fichier, c'est renoncer à l'envoi.
      Navigator.pop(context);
      return;
    }
    setState(() {
      _items.removeAt(i);
      _page = _page.clamp(0, _items.length - 1);
    });
    if (_pages.hasClients) _pages.jumpToPage(_page);
  }

  void _envoyer() {
    final texte = _legende.text.trim();
    Navigator.pop(
      context,
      ApercuDocumentsResult(
        items: List.unmodifiable(_items),
        caption: texte.isEmpty ? null : texte,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final courant = _items[_page];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _items.length > 1
              ? l10n.sensitivePreviewTitleMany(_items.length)
              : l10n.sensitivePreviewTitle,
        ),
        actions: [
          IconButton(
            key: const ValueKey('apercu-sensible-retirer'),
            tooltip: l10n.sensitivePreviewRemove,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _retirer(_page),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Bandeau(sensible: courant.sensible != null),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _items.length,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (_, i) => _Page(item: _items[i]),
              ),
            ),
            if (_items.length > 1)
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => AppSpacing.hGapSm,
                  itemBuilder: (_, i) => _Vignette(
                    item: _items[i],
                    selectionnee: i == _page,
                    onTap: () => _pages.jumpToPage(i),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('apercu-sensible-legende'),
                      controller: _legende,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.onSurface.withValues(alpha: 0.08),
                        hintText: l10n.addACaption,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  AppSpacing.hGapSm,
                  Material(
                    color: colors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      key: const ValueKey('apercu-sensible-envoyer'),
                      customBorder: const CircleBorder(),
                      onTap: _envoyer,
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(Icons.send,
                            semanticLabel: l10n.commonSend,
                            color: colors.onPrimary,
                            size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.recipientName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  widget.recipientName!,
                  style: context.text.labelSmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Ce que deviendra le fichier chez le destinataire.
class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.sensible});

  final bool sensible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final couleur = sensible ? colors.error : colors.onSurfaceVariant;
    return Container(
      width: double.infinity,
      color: couleur.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(sensible ? Icons.lock_outline : Icons.lock_open_outlined,
              size: 18, color: couleur),
          AppSpacing.hGapSm,
          Expanded(
            child: Text(
              sensible
                  ? context.l10n.sensitivePreviewBanner
                  : context.l10n.sensitivePreviewOrdinary,
              style: context.text.bodySmall?.copyWith(color: couleur),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _icone(int type) => switch (type) {
      1 => Icons.image_outlined,
      2 => Icons.videocam_outlined,
      3 => Icons.audiotrack_outlined,
      _ => Icons.description_outlined,
    };

bool _estPdf(AlbumSendItem item) =>
    (item.mediaName ?? item.file.path).toLowerCase().endsWith('.pdf');

/// Un fichier en grand : la photo, la première page d'un PDF, sinon sa fiche.
class _Page extends StatelessWidget {
  const _Page({required this.item});

  final AlbumSendItem item;

  @override
  Widget build(BuildContext context) {
    final nom = item.mediaName ?? item.file.path.split('/').last;
    final taille = item.file.existsSync() ? item.file.lengthSync() : 0;
    final Widget visuel;
    if (item.type == 1) {
      visuel = Image.file(item.file,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _Fiche(icone: _icone(item.type)));
    } else if (_estPdf(item)) {
      visuel = _PremierePagePdf(chemin: item.file.path);
    } else {
      visuel = _Fiche(icone: _icone(item.type));
    }
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Expanded(child: Center(child: visuel)),
          AppSpacing.vGapMd,
          Text(nom,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: context.text.titleSmall),
          if (taille > 0)
            Text(formatBytes(taille, context.l10n),
                style: context.text.labelSmall
                    ?.copyWith(color: context.colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Fiche extends StatelessWidget {
  const _Fiche({required this.icone});

  final IconData icone;

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: 48,
        backgroundColor: context.colors.error.withValues(alpha: 0.10),
        child: Icon(icone, size: 48, color: context.colors.error),
      );
}

class _PremierePagePdf extends StatefulWidget {
  const _PremierePagePdf({required this.chemin});

  final String chemin;

  @override
  State<_PremierePagePdf> createState() => _PremierePagePdfState();
}

class _PremierePagePdfState extends State<_PremierePagePdf> {
  late final Future<Uint8List?> _image = _rendre();

  Future<Uint8List?> _rendre() async {
    try {
      final doc = await PdfDocument.openFile(widget.chemin);
      try {
        final page = await doc.getPage(1);
        try {
          final r = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );
          return r?.bytes;
        } finally {
          await page.close();
        }
      } finally {
        await doc.close();
      }
    } catch (_) {
      // Un PDF chiffré ou abîmé s'envoie quand même : on montre sa fiche.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
        future: _image,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const CircularProgressIndicator();
          }
          final o = s.data;
          if (o == null) return const _Fiche(icone: Icons.picture_as_pdf_outlined);
          return DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Image.memory(o, fit: BoxFit.contain),
          );
        },
      );
}

class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.item,
    required this.selectionnee,
    required this.onTap,
  });

  final AlbumSendItem item;
  final bool selectionnee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selectionnee ? colors.primary : colors.outlineVariant,
            width: selectionnee ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: item.type == 1
            ? Image.file(item.file,
                fit: BoxFit.cover,
                cacheWidth: 112,
                errorBuilder: (_, __, ___) => Icon(_icone(item.type)))
            : Icon(_estPdf(item) ? Icons.picture_as_pdf_outlined : _icone(item.type),
                color: item.sensible != null ? colors.error : colors.onSurfaceVariant),
      ),
    );
  }
}
