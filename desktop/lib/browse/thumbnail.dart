import 'dart:typed_data';

import 'package:alanya_safebox/alanya_safebox.dart';
import 'package:flutter/material.dart';

import '../ui/common.dart';

/// L'aperçu déchiffré d'un fichier, ou l'icône de son type.
class Thumbnail extends StatefulWidget {
  const Thumbnail({super.key, required this.file, this.radius = 8});
  final SafeboxFile file;
  final double radius;

  @override
  State<Thumbnail> createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  Uint8List? _octets;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _charger();
  }

  @override
  void didUpdateWidget(Thumbnail old) {
    super.didUpdateWidget(old);
    if (old.file.id != widget.file.id) _charger();
  }

  void _charger() {
    final cache = context.vault.previews;
    final id = widget.file.id;
    _octets = cache.peek(id);
    if (_octets != null || widget.file.previewUrl == null) return;
    cache.load(widget.file).then((b) {
      if (mounted && b != null && widget.file.id == id) setState(() => _octets = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final b = _octets;
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Stack(fit: StackFit.expand, children: [
        if (b != null)
          Image.memory(b, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => _Icone(f.family))
        else
          _Icone(f.family),
        if (f.family == SafeboxFamily.videos)
          const Align(
            alignment: Alignment.center,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Color(0x99000000),
              child: Icon(Icons.play_arrow, color: Colors.white),
            ),
          ),
      ]),
    );
  }
}

class _Icone extends StatelessWidget {
  const _Icone(this.family);
  final SafeboxFamily family;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Palette.brandContainer,
        child: Center(child: Icon(familyIcon(family), color: Palette.brand, size: 32)),
      );
}
