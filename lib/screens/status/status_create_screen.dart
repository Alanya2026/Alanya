import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';
import 'dart:io';

class StatusCreateScreen extends StatefulWidget {
  const StatusCreateScreen({super.key});

  @override
  State<StatusCreateScreen> createState() => _StatusCreateScreenState();
}

class _StatusCreateScreenState extends State<StatusCreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _textCtrl = TextEditingController();
  File? _selectedImage;
  File? _selectedVideo;
  Color _bgColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedImage = File(file.path));
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() => _selectedVideo = File(file.path));
    }
  }

  Future<void> _createStatus() async {
    final provider = context.read<StatusProvider>();
    final tab = _tabCtrl.index;

    try {
      if (tab == 0 && _textCtrl.text.isNotEmpty) {
        // Text status
        await provider.createText(
          _textCtrl.text,
          backgroundColor: _bgColor.value.toRadixString(16),
        );
        if (mounted) Navigator.pop(context);
      } else if (tab == 1 && _selectedImage != null) {
        // Image status
        await provider.createImage(_selectedImage!);
        if (mounted) Navigator.pop(context);
      } else if (tab == 2 && _selectedVideo != null) {
        // Video status
        await provider.createVideo(_selectedVideo!);
        if (mounted) Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select content')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Status'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'Text'),
            Tab(text: 'Image'),
            Tab(text: 'Video'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // Text tab
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _textCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'What\'s on your mind?',
                          hintStyle: TextStyle(color: Colors.white70),
                        ),
                        maxLines: null,
                        expands: true,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final color in [
                        Colors.indigo,
                        Colors.red,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.blue,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => setState(() => _bgColor = color),
                            child: Container(
                              width: 60,
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
            ),
          ),

          // Image tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedImage != null)
                  Expanded(child: Image.file(_selectedImage!))
                else
                  const Icon(Icons.image, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo),
                  label: const Text('Pick Image'),
                ),
              ],
            ),
          ),

          // Video tab
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_selectedVideo != null)
                  Text(_selectedVideo!.path.split('/').last)
                else
                  const Icon(Icons.video_library, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_camera_back),
                  label: const Text('Pick Video'),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createStatus,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.check),
      ),
    );
  }
}
