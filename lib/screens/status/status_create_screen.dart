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

class _StatusCreateScreenState extends State<StatusCreateScreen> {
  _StatusType _type = _StatusType.text;
  final _textCtrl = TextEditingController();
  File? _mediaFile;
  Color _bgColor = Colors.indigo;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _canPublish {
    switch (_type) {
      case _StatusType.text:
        return _textCtrl.text.trim().isNotEmpty;
      case _StatusType.photo:
      case _StatusType.video:
      case _StatusType.audio:
        return _mediaFile != null;
    }
  }

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    final picker = ImagePicker();
    final file = video
        ? await picker.pickVideo(source: source)
        : await picker.pickImage(source: source);
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  Future<void> _pickAudio() async {
    // En l'absence de sélecteur audio dédié, on ouvre un file picker
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _mediaFile = File(file.path));
  }

  Future<void> _publish() async {
    if (!_canPublish) return;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Nouveau statut',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Sélecteur de type
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _typeOption(_StatusType.text, Icons.text_fields, 'Texte'),
                _typeOption(_StatusType.photo, Icons.photo, 'Photo'),
                _typeOption(_StatusType.video, Icons.videocam, 'Vidéo'),
                _typeOption(_StatusType.audio, Icons.mic, 'Audio'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Zone de saisie
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildInputArea(),
            ),
          ),

          // Bouton Publier
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _canPublish ? _publish : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Publier',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeOption(_StatusType t, IconData icon, String label) {
    final selected = _type == t;
    return GestureDetector(
      onTap: () => setState(() {
        _type = t;
        _mediaFile = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.indigo.withAlpha(20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.indigo : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: selected ? Colors.indigo : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.indigo : Colors.grey.shade600,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    switch (_type) {
      case _StatusType.text:
        return _buildTextInput();
      case _StatusType.photo:
        return _buildMediaInput(label: 'Photo', icon: Icons.add_a_photo);
      case _StatusType.video:
        return _buildMediaInput(label: 'Vidéo', icon: Icons.videocam);
      case _StatusType.audio:
        return _buildAudioInput();
    }
  }

  Widget _buildTextInput() {
    return Column(
      children: [
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _textCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tapez votre statut…',
                hintStyle: TextStyle(color: Colors.white60),
              ),
              maxLines: null,
              expands: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final color in [
                Colors.indigo,
                Colors.red,
                Colors.teal,
                Colors.orange,
                Colors.purple,
                Colors.blue,
                Colors.pink,
                Colors.amber,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _bgColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 50,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(12),
                        border: _bgColor == color
                            ? Border.all(color: Colors.black, width: 3)
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaInput({required String label, required IconData icon}) {
    return Column(
      children: [
        if (_mediaFile != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.file(
              _mediaFile!,
              height: 350,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          )
        else
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  'Ajouter une $label',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickMedia(ImageSource.gallery,
                    video: _type == _StatusType.video),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickMedia(ImageSource.camera,
                    video: _type == _StatusType.video),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Appareil photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAudioInput() {
    return Column(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _mediaFile != null ? Icons.audiotrack : Icons.mic,
                size: 48,
                color:
                    _mediaFile != null ? Colors.indigo : Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                _mediaFile != null
                    ? _mediaFile!.path.split('/').last
                    : 'Ajouter un fichier audio',
                style: TextStyle(
                  color: _mediaFile != null
                      ? Colors.indigo
                      : Colors.grey.shade500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _pickAudio,
            icon: const Icon(Icons.upload_file),
            label: Text(_mediaFile != null
                ? 'Changer le fichier'
                : 'Choisir un fichier audio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.indigo,
              side: const BorderSide(color: Colors.indigo),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}
