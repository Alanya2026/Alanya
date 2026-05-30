import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
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
  final _captionCtrl = TextEditingController();
  File? _mediaFile;
  Color _bgColor = const Color(0xFFE53935);
  bool _publishing = false;

  // Audio (onglet 4) : enregistrement vocal + import de fichier.
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  int? _audioDurationMs;
  String? _audioName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      final next = _StatusType.values[_tabController.index];
      if (next == _type) return;
      if (_isRecording) {
        _recordTimer?.cancel();
        _recorder.stop();
      }
      setState(() {
        _type = next;
        _mediaFile = null;
        _captionCtrl.clear();
        _isRecording = false;
        _recordSeconds = 0;
        _audioDurationMs = null;
        _audioName = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textCtrl.dispose();
    _captionCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
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
        // Compression : une photo plein format (surtout prise à l'instant via
        // l'appareil) est trop lourde et l'upload échoue. On la réduit comme le chat.
        : await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1920);
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  // ── Audio : enregistrement vocal ─────────────────────────────────
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission micro refusée')),
        );
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/status_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      _mediaFile = null;
      _audioDurationMs = null;
      _audioName = null;
    });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({required bool keep}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final seconds = _recordSeconds;
    if (!mounted) return;
    if (keep && path != null && seconds >= 1) {
      setState(() {
        _isRecording = false;
        _mediaFile = File(path);
        _audioDurationMs = seconds * 1000;
        _audioName = 'Message vocal';
      });
    } else {
      if (path != null) {
        try {
          File(path).deleteSync();
        } catch (_) {}
      }
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }
  }

  // ── Audio : import d'un fichier audio uniquement ─────────────────
  Future<void> _pickAudioFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = res?.files.single.path;
    if (path != null && mounted) {
      setState(() {
        _mediaFile = File(path);
        _audioDurationMs = null;
        _audioName = res!.files.single.name;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
          await provider.createMedia(
              file: _mediaFile!, type: 1, caption: _captionCtrl.text.trim());
        case _StatusType.video:
          await provider.createMedia(
              file: _mediaFile!, type: 2, caption: _captionCtrl.text.trim());
        case _StatusType.audio:
          await provider.createMedia(
              file: _mediaFile!, type: 3, mediaDurationMs: _audioDurationMs);
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
          onTap: _pickAudioFile,
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

          // Description optionnelle (champ `text` en BD) — facultative.
          Positioned(
            left: 16,
            right: 16,
            bottom: 84 + MediaQuery.of(context).padding.bottom,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _captionCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                cursorColor: Colors.white,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Ajouter une description…',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ),
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
    final Color circleColor = _isRecording
        ? Colors.red
        : (hasFile ? Colors.indigo : Colors.indigo.shade50);
    final IconData circleIcon = _isRecording
        ? Icons.graphic_eq_rounded
        : (hasFile ? Icons.audiotrack_rounded : Icons.mic_rounded);

    return Container(
      color: const Color(0xFFF4F5F8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  circleIcon,
                  size: 44,
                  color: (_isRecording || hasFile) ? Colors.white : Colors.indigo,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _isRecording
                    ? 'Enregistrement… ${_formatDuration(_recordSeconds)}'
                    : hasFile
                        ? (_audioName ?? 'Message vocal')
                        : 'Enregistrez un vocal ou importez un fichier audio',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              if (hasFile && !_isRecording && _audioDurationMs != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _formatDuration((_audioDurationMs! / 1000).round()),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ),
              const SizedBox(height: 18),
              if (_isRecording)
                Wrap(
                  spacing: 12,
                  children: [
                    _ChoiceButton(
                      icon: Icons.delete_outline,
                      label: 'Annuler',
                      onTap: () => _stopRecording(keep: false),
                    ),
                    _ChoiceButton(
                      icon: Icons.check_rounded,
                      label: 'Terminer',
                      onTap: () => _stopRecording(keep: true),
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  children: [
                    _ChoiceButton(
                      icon: Icons.mic_rounded,
                      label: hasFile ? 'Réenregistrer' : 'Enregistrer',
                      onTap: _startRecording,
                    ),
                    _ChoiceButton(
                      icon: Icons.upload_file_rounded,
                      label: 'Importer',
                      onTap: _pickAudioFile,
                    ),
                  ],
                ),
            ],
          ),
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
