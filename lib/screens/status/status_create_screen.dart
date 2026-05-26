import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';

enum _StatusType { text, photo, video, audio }

class StatusCreateScreen extends StatefulWidget {
  const StatusCreateScreen({super.key});

  @override
  State<StatusCreateScreen> createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends State<StatusCreateScreen>
    with SingleTickerProviderStateMixin {
  static const List<Color> _palette = [
    Color(0xFFE53935), // red
    Color(0xFF3949AB), // indigo
    Color(0xFF00897B), // teal
    Color(0xFFFB8C00), // orange
    Color(0xFF8E24AA), // purple
    Color(0xFF1E88E5), // blue
    Color(0xFFD81B60), // pink
    Color(0xFFFFB300), // amber
    Color(0xFF424242), // grey-dark
    Color(0xFF6D4C41), // brown
  ];

  late final TabController _tabController;
  _StatusType _type = _StatusType.text;
  final _textCtrl = TextEditingController();
  File? _mediaFile;
  Color _bgColor = const Color(0xFFE53935);
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final next = _StatusType.values[_tabController.index];
      if (next == _type) return;
      setState(() {
        _type = next;
        _mediaFile = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _canPublish {
    if (_publishing) return false;
    switch (_type) {
      case _StatusType.text:
        return _textCtrl.text.trim().isNotEmpty;
      case _StatusType.photo:
      case _StatusType.video:
      case _StatusType.audio:
        return _mediaFile != null;
    }
  }

  // ── Actions médias ───────────────────────────────────────────────

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  Future<void> _pickAudio() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  // ── Color picker (bottom sheet) ──────────────────────────────────

  Future<void> _openColorPicker() async {
    final picked = await showModalBottomSheet<Color>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Couleur de fond',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final color in _palette)
                    GestureDetector(
                      onTap: () => Navigator.pop(context, color),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _bgColor.toARGB32() == color.toARGB32()
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _bgColor.toARGB32() == color.toARGB32()
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _bgColor = picked);
  }

  // ── Publication ──────────────────────────────────────────────────

  Future<void> _publish() async {
    if (!_canPublish) return;
    setState(() => _publishing = true);
    final provider = context.read<StatusProvider>();
    try {
      switch (_type) {
        case _StatusType.text:
          await provider.createText(
            text: _textCtrl.text.trim(),
            backgroundColor: _bgColor.toARGB32().toRadixString(16).padLeft(8, '0'),
          );
        case _StatusType.photo:
          await provider.createMedia(file: _mediaFile!, type: 1);
        case _StatusType.video:
          await provider.createMedia(file: _mediaFile!, type: 2);
        case _StatusType.audio:
          await provider.createMedia(file: _mediaFile!, type: 3);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _publishing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Nouveau statut',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Icons.send_rounded,
              color: _canPublish ? Colors.indigo : Colors.grey.shade300,
            ),
            onPressed: _canPublish ? _publish : null,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: Colors.indigo,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.text_fields, size: 22), text: 'Texte'),
              Tab(icon: Icon(Icons.photo, size: 22), text: 'Photo'),
              Tab(icon: Icon(Icons.videocam, size: 22), text: 'Vidéo'),
              Tab(icon: Icon(Icons.mic, size: 22), text: 'Audio'),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildCanvas()),

          // FAB bottom-left contextuel selon le mode
          Positioned(
            left: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            child: _buildLeftAction(),
          ),

          // Pill "Publier" bottom-right
          Positioned(
            right: 16,
            bottom: 18 + MediaQuery.of(context).padding.bottom,
            child: _PublishPill(
              color: _type == _StatusType.text ? _bgColor : Colors.indigo,
              enabled: _canPublish,
              loading: _publishing,
              onTap: _publish,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftAction() {
    switch (_type) {
      case _StatusType.text:
        return _CircleAction(
          icon: Icons.palette_rounded,
          color: Colors.indigo,
          onTap: _openColorPicker,
        );
      case _StatusType.photo:
        return _CircleAction(
          icon: Icons.photo_library_rounded,
          color: Colors.indigo,
          onTap: () => _pickMedia(ImageSource.gallery),
        );
      case _StatusType.video:
        return _CircleAction(
          icon: Icons.video_library_rounded,
          color: Colors.indigo,
          onTap: () => _pickMedia(ImageSource.gallery, video: true),
        );
      case _StatusType.audio:
        return _CircleAction(
          icon: Icons.audio_file_rounded,
          color: Colors.indigo,
          onTap: _pickAudio,
        );
    }
  }

  // ── Canvas par mode ──────────────────────────────────────────────

  Widget _buildCanvas() {
    switch (_type) {
      case _StatusType.text:
        return _buildTextCanvas();
      case _StatusType.photo:
        return _buildPhotoCanvas(isVideo: false);
      case _StatusType.video:
        return _buildPhotoCanvas(isVideo: true);
      case _StatusType.audio:
        return _buildAudioCanvas();
    }
  }

  Widget _buildTextCanvas() {
    return Container(
      color: _bgColor,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 100),
      child: Center(
        child: TextField(
          controller: _textCtrl,
          onChanged: (_) => setState(() {}),
          maxLines: null,
          textAlign: TextAlign.center,
          cursorColor: Colors.white,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.3,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Tapez votre statut…',
            hintStyle: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCanvas({required bool isVideo}) {
    if (_mediaFile != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_mediaFile!, fit: BoxFit.cover),
          // Voile bas pour assurer la lisibilité des contrôles
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 140,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isVideo)
            const Positioned(
              top: 16,
              right: 16,
              child: _Chip(icon: Icons.movie, label: 'Vidéo'),
            ),
        ],
      );
    }
    return Container(
      color: const Color(0xFFF4F5F8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.add_a_photo_rounded,
                size: 44,
                color: Colors.indigo,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              isVideo ? 'Ajouter une vidéo' : 'Ajouter une photo',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              children: [
                _ChoiceButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galerie',
                  onTap: () =>
                      _pickMedia(ImageSource.gallery, video: isVideo),
                ),
                _ChoiceButton(
                  icon: Icons.camera_alt_outlined,
                  label: isVideo ? 'Caméra' : 'Appareil',
                  onTap: () =>
                      _pickMedia(ImageSource.camera, video: isVideo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioCanvas() {
    final hasFile = _mediaFile != null;
    return Container(
      color: const Color(0xFFF4F5F8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: hasFile ? Colors.indigo : Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasFile ? Icons.audiotrack_rounded : Icons.mic_rounded,
                size: 44,
                color: hasFile ? Colors.white : Colors.indigo,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              hasFile
                  ? (_mediaFile!.path.split('/').last)
                  : 'Ajouter un fichier audio',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            _ChoiceButton(
              icon: Icons.upload_file_rounded,
              label: hasFile ? 'Changer le fichier' : 'Choisir un fichier',
              onTap: _pickAudio,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sous-composants ──────────────────────────────────────────────

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CircleAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _PublishPill extends StatelessWidget {
  final Color color;
  final bool enabled;
  final bool loading;
  final VoidCallback onTap;

  const _PublishPill({
    required this.color,
    required this.enabled,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = Colors.white;
    final bg = enabled ? color : color.withValues(alpha: 0.45);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              )
            else
              Icon(Icons.send_rounded, color: fg, size: 20),
            const SizedBox(width: 8),
            Text(
              loading ? 'Envoi…' : 'Publier',
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        side: const BorderSide(color: Colors.indigo),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
