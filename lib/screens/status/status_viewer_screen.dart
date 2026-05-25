import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import 'status_views_screen.dart';

class StatusViewerScreen extends StatefulWidget {
  final List<Statut> statuses;
  final int initialIndex;

  const StatusViewerScreen({
    super.key,
    required this.statuses,
    required this.initialIndex,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> {
  late int _currentIdx;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _currentIdx = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);

    // Mark as viewed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsViewed();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsViewed() async {
    final provider = context.read<StatusProvider>();
    final s = widget.statuses[_currentIdx];
    if (!s.seenByMe) {
      await provider.viewStatut(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StatusProvider>();
    final s = widget.statuses[_currentIdx];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (idx) {
              setState(() => _currentIdx = idx);
              _markAsViewed();
            },
            itemCount: widget.statuses.length,
            itemBuilder: (_, idx) {
              final status = widget.statuses[idx];
              return _StatusView(status: status);
            },
          ),
          // Header with progress
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.black.withAlpha(100),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // Progress bars
                  SizedBox(
                    height: 3,
                    child: Row(
                      children: List.generate(
                        widget.statuses.length,
                        (i) => Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: _currentIdx > i
                                  ? Colors.white
                                  : _currentIdx == i
                                  ? Colors.white70
                                  : Colors.white30,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // User info + menu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User ${s.alanyaID}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${s.createdAt}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            CupertinoIcons.ellipsis_vertical,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (_) => Container(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      title: const Text('View who saw this'),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StatusViewsScreen(
                                              statusId: s.id,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    if (s.likedByMe == 0)
                                      ListTile(
                                        title: const Text('Like'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          provider.toggleLike(s.id);
                                        },
                                      )
                                    else
                                      ListTile(
                                        title: const Text('Unlike'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          provider.toggleLike(s.id);
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusView extends StatelessWidget {
  final Statut status;

  const _StatusView({required this.status});

  @override
  Widget build(BuildContext context) {
    if (status.mediaUrl != null && status.mediaUrl!.isNotEmpty) {
      // Image or video
      return Image.network(
        status.mediaUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.error, color: Colors.white)),
      );
    } else if (status.text != null && status.text!.isNotEmpty) {
      // Text
      return Container(
        color: status.backgroundColor != null
            ? Color(int.parse(status.backgroundColor!))
            : Colors.indigo,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              status.text!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return const Center(
      child: Icon(Icons.image_not_supported, color: Colors.white),
    );
  }
}
