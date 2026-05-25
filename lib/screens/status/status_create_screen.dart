import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../providers/status_provider.dart';
class StatusCreateScreen extends StatefulWidget {
  const StatusCreateScreen({super.key});
  @override
  State<StatusCreateScreen> createState() => _StatusCreateScreenState();
class _StatusCreateScreenState extends State<StatusCreateScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Nouveau statut',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.indigo,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.text_fields), text: 'Texte'),
            Tab(icon: Icon(Icons.photo), text: 'Photo'),
            Tab(icon: Icon(Icons.videocam), text: 'Vid
o'),
            Tab(icon: Icon(Icons.mic), text: 'Audio'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TextStatusPage(),
          _MediaStatusPage(type: 1),
          _MediaStatusPage(type: 2),
          _AudioStatusPage(),
        ],
      ),
    );
 TEXTE 
class _TextStatusPage extends StatefulWidget {
  const _TextStatusPage();
  @override
  State<_TextStatusPage> createState() => _TextStatusPageState();
class _TextStatusPageState extends State<_TextStatusPage> {
  static const List<Color> _palette = [
    Color(0xFFE53935), // rouge
    Color(0xFF1E88E5), // bleu
    Color(0xFF43A047), // vert
    Color(0xFF8E24AA), // violet
    Color(0xFFF4511E), // orange
    Color(0xFFD81B60), // rose
    Color(0xFF00ACC1), // turquoise
    Color(0xFF263238), // noir/slate
  ];
  final TextEditingController _ctrl = TextEditingController();
  int _colorIdx = 0;
  bool _publishing = false;
  String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  Future<void> _publish() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _publishing = true);
    final ok = await context.read<StatusProvider>().createText(
          text: text,
          backgroundColor: _hex(_palette[_colorIdx]),
        );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (ok != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('
chec de publication')),
      );
    }
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _palette[_colorIdx],
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Center(
                  child: TextField(
                    controller: _ctrl,
                    maxLength: 250,
                    maxLines: 6,
                    minLines: 1,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: 'Tapez votre statut
                      hintStyle: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
            // 
 Palette 
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(
                      () => _colorIdx = (_colorIdx + 1) % _palette.length,
                    ),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _palette[(_colorIdx + 1) % _palette.length],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.palette, color: Colors.white),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Publier'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white24,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
 PHOTO / VID
class _MediaStatusPage extends StatefulWidget {
  final int type; // 1=image, 2=video
  const _MediaStatusPage({required this.type});
  @override
  State<_MediaStatusPage> createState() => _MediaStatusPageState();
class _MediaStatusPageState extends State<_MediaStatusPage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _captionCtrl = TextEditingController();
  File? _file;
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  int? _durationMs;
  bool _publishing = false;
  bool get _isVideo => widget.type == 2;
  @override
  void dispose() {
    _captionCtrl.dispose();
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  Future<void> _pick({required ImageSource source}) async {
    final picked = _isVideo
        ? await _picker.pickVideo(
            source: source,
            maxDuration: const Duration(seconds: 60),
          )
        : await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    final file = File(picked.path);
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _chewieCtrl = null;
    _durationMs = null;
    if (_isVideo) {
      final v = VideoPlayerController.file(file);
      await v.initialize();
      _durationMs = v.value.duration.inMilliseconds;
      _videoCtrl = v;
      _chewieCtrl = ChewieController(
        videoPlayerController: v,
        autoPlay: true,
        looping: true,
        showControls: true,
      );
    }
    if (!mounted) return;
    setState(() => _file = file);
  Future<void> _publish() async {
    if (_file == null) return;
    setState(() => _publishing = true);
    final ok = await context.read<StatusProvider>().createMedia(
          file: _file!,
          type: widget.type,
          caption: _captionCtrl.text.trim(),
          mediaDurationMs: _durationMs,
        );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (ok != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('
chec de publication')),
      );
    }
  @override
  Widget build(BuildContext context) {
    if (_file == null) return _pickerView();
    return _previewView();
  Widget _pickerView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isVideo ? Icons.video_camera_back : Icons.add_a_photo,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            _isVideo
                ? 'Choisir ou capturer une vid
                : 'Choisir ou prendre une photo',
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pick(source: ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Cam
ra'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pick(source: ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
              ),
            ],
          ),
        ],
      ),
    );
  Widget _previewView() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: _isVideo
                ? (_chewieCtrl != null ? Chewie(controller: _chewieCtrl!) : const SizedBox())
                : Image.file(_file!, fit: BoxFit.contain),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: TextField(
            controller: _captionCtrl,
            maxLength: 250,
            decoration: const InputDecoration(
              hintText: 'Ajouter une l
gende
              counterText: '',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _file = null),
                icon: const Icon(Icons.refresh),
                label: const Text('Reprendre'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _publishing ? null : _publish,
                icon: _publishing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: const Text('Publier'),
                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              ),
            ],
          ),
        ),
      ],
    );
 AUDIO 
class _AudioStatusPage extends StatefulWidget {
  const _AudioStatusPage();
  @override
  State<_AudioStatusPage> createState() => _AudioStatusPageState();
class _AudioStatusPageState extends State<_AudioStatusPage> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  bool _isRecording = false;
  int _seconds = 0;
  File? _file;
  bool _publishing = false;
  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission micro refus
e')),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/status_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() {
      _isRecording = true;
      _seconds = 0;
      _file = null;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path != null && _seconds >= 1) {
      setState(() => _file = File(path));
    } else if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
  Future<void> _publish() async {
    if (_file == null) return;
    setState(() => _publishing = true);
    final ok = await context.read<StatusProvider>().createMedia(
          file: _file!,
          type: 3,
          mediaDurationMs: _seconds * 1000,
        );
    if (!mounted) return;
    setState(() => _publishing = false);
    if (ok != null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('
chec de publication')),
      );
    }
  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red.shade50 : Colors.indigo.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isRecording
                    ? Icons.mic
                    : (_file != null ? Icons.audiotrack : Icons.mic_none),
                color: _isRecording ? Colors.red : Colors.indigo,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isRecording ? 'Enregistrement
' : _fmt(_seconds),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            if (!_isRecording && _file == null)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Enregistrer'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
              ),
            if (_isRecording)
              FilledButton.icon(
                onPressed: _stop,
                icon: const Icon(Icons.stop),
                label: const Text('Arr
ter'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 14),
                ),
              ),
            if (!_isRecording && _file != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      try {
                        _file!.deleteSync();
                      } catch (_) {}
                      setState(() {
                        _file = null;
                        _seconds = 0;
                      });
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Refaire'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _publishing ? null : _publish,
                    icon: _publishing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Publier'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );