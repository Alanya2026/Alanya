import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../../widgets/status_ring_avatar.dart';
import 'status_create_screen.dart';
import 'status_viewer_screen.dart';

class StatusesScreen extends StatefulWidget {
  const StatusesScreen({super.key});

  @override
  State<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends State<StatusesScreen> {
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<StatusProvider>();
    final myStatuses = provider.mine;

    final entries = provider.byAuthor.entries.toList()
      ..sort((a, b) {
        final aUnseen = provider.unseenCount(a.key) > 0;
        final bUnseen = provider.unseenCount(b.key) > 0;
        if (aUnseen != bUnseen) return bUnseen ? 1 : -1;
        return 0;
      });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Statuts',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            // Create status button
            if (me != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StatusCreateScreen(),
                      ),
                    );
                  },
                  icon: const Icon(CupertinoIcons.plus),
                  label: const Text('Create Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            const SizedBox(height: 8),

            // My statuses section
            if (myStatuses.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'My Statuses',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            if (myStatuses.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: myStatuses.length,
                  itemBuilder: (_, idx) {
                    final s = myStatuses[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StatusViewerScreen(
                                statuses: [s],
                                initialIndex: 0,
                              ),
                            ),
                          );
                        },
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: s.mediaUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(s.mediaUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                color: s.backgroundColor != null
                                    ? Color(int.parse(s.backgroundColor!))
                                    : Colors.grey.shade300,
                              ),
                              child: s.mediaUrl == null
                                  ? Center(
                                      child: Text(
                                        s.text ?? '',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View (${s.viewedBy})',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            const SizedBox(height: 16),

            // Other users' statuses
            if (entries.isEmpty && myStatuses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No statuses yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...entries.map((entry) {
                final authorId = entry.key;
                final statuses = entry.value;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatusViewerScreen(
                          statuses: statuses,
                          initialIndex: 0,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        StatusRingAvatar(
                          authorId: authorId,
                          hasUnseen: provider.hasUnseenFrom(authorId),
                          unseenCount: provider.unseenCount(authorId),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Author Name',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${statuses.length} statue(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (provider.hasUnseenFrom(authorId))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.indigo,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${provider.unseenCount(authorId)} new',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
