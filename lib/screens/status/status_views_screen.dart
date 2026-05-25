import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';

class StatusViewsScreen extends StatefulWidget {
  final int statusId;

  const StatusViewsScreen({super.key, required this.statusId});

  @override
  State<StatusViewsScreen> createState() => _StatusViewsScreenState();
}

class _StatusViewsScreenState extends State<StatusViewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<StatusProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Views & Likes'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'Viewed'),
            Tab(text: 'Liked'),
          ],
        ),
      ),
      body: FutureBuilder<List<StatutView>>(
        future: provider.getViews(widget.statusId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final views = snapshot.data!;
          final viewed = views.where((v) => !v.liked).toList();
          final liked = views.where((v) => v.liked).toList();

          return TabBarView(
            controller: _tabCtrl,
            children: [
              // Viewed tab
              viewed.isEmpty
                  ? const Center(child: Text('No views yet'))
                  : ListView.separated(
                      itemCount: viewed.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, idx) {
                        final v = viewed[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(v.nom.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(v.nom),
                          subtitle: Text(v.pseudo),
                          trailing: Text(
                            v.seenAt ?? '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),

              // Liked tab
              liked.isEmpty
                  ? const Center(child: Text('No likes yet'))
                  : ListView.separated(
                      itemCount: liked.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, idx) {
                        final v = liked[idx];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(v.nom.substring(0, 1).toUpperCase()),
                          ),
                          title: Text(v.nom),
                          subtitle: Text(v.pseudo),
                          trailing: const Icon(
                            CupertinoIcons.heart_fill,
                            color: Colors.red,
                          ),
                        );
                      },
                    ),
            ],
          );
        },
      ),
    );
  }
}
