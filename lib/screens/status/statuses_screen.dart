import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/status_ring_avatar.dart';
import '../home/glass_nav_bar.dart' show kGlassNavBarSpace;
import 'status_create_screen.dart';
import 'status_viewer_screen.dart';

class StatusesScreen extends StatefulWidget {
  const StatusesScreen({super.key});

  @override
  State<StatusesScreen> createState() => _StatusesScreenState();
}

class _StatusesScreenState extends State<StatusesScreen> {
  bool _searchOpen = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchCtrl.clear();
        _search = '';
      }
    });
  }

  bool _matchesSearch(List<Statut> statuses) {
    if (_search.isEmpty) return true;
    if (statuses.isEmpty) return false;
    final name = (statuses.last.nom ?? '').toLowerCase();
    return name.contains(_search);
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final provider = context.watch<StatusProvider>();
    final myStatuses = provider.mine;

    // Tri par date du dernier statut (le plus récent en haut), puis partition
    // en "récents" (au moins un élément non vu) et "déjà vus" (tout est vu).
    final entries = provider.byAuthor.entries.toList()
      ..sort((a, b) {
        final aLast = a.value.isNotEmpty ? a.value.last.createdAt : '';
        final bLast = b.value.isNotEmpty ? b.value.last.createdAt : '';
        return bLast.compareTo(aLast);
      });
    final recents = <MapEntry<int, List<Statut>>>[];
    final viewed = <MapEntry<int, List<Statut>>>[];
    for (final e in entries) {
      if (e.value.isEmpty) continue;
      if (!_matchesSearch(e.value)) continue;
      if (provider.unseenCount(e.key) > 0) {
        recents.add(e);
      } else {
        viewed.add(e);
      }
    }

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
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search, color: Colors.black),
            tooltip: _searchOpen ? 'Fermer la recherche' : 'Rechercher',
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          AnimatedSearchBar(
            open: _searchOpen,
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            onClose: _toggleSearch,
          ),
          Expanded(
            child: RefreshIndicator(
        onRefresh: () => provider.refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: kGlassNavBarSpace),
          children: [
            // Mon statut (toujours visible — non filtré par la recherche)
            if (_search.isEmpty) ...[
              _MyStatusTile(
                avatarUrl: me?.avatarUrl,
                name: me?.nom ?? '',
                statuses: myStatuses,
                onCreate: () => _openCreate(context),
                onView: () => _openMine(context, myStatuses),
              ),
              const Divider(height: 1),
            ],
            // Section "Récents" (contient au moins un statut non vu)
            if (recents.isNotEmpty) _SectionHeader(label: 'Récents'),
            for (var i = 0; i < recents.length; i++)
              _ContactStatusTile(
                authorId: recents[i].key,
                statuses: recents[i].value,
                totalCount: provider.totalCount(recents[i].key),
                unseenCount: provider.unseenCount(recents[i].key),
                onTap: () => _openOther(
                  context,
                  bucket: recents.map((e) => e.value).toList(),
                  contactIndex: i,
                ),
              ),
            // Section "Déjà vus" (tous les éléments ont été vus)
            if (viewed.isNotEmpty) _SectionHeader(label: 'Déjà vus'),
            for (var i = 0; i < viewed.length; i++)
              _ContactStatusTile(
                authorId: viewed[i].key,
                statuses: viewed[i].value,
                totalCount: provider.totalCount(viewed[i].key),
                unseenCount: 0,
                onTap: () => _openOther(
                  context,
                  bucket: viewed.map((e) => e.value).toList(),
                  contactIndex: i,
                ),
              ),
            // État vide si aucune entrée
            if (recents.isEmpty && viewed.isEmpty && !provider.loading)
              const _EmptyState(),
            const SizedBox(height: 80),
          ],
        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context),
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatusCreateScreen()),
    );
  }

  void _openMine(BuildContext context, List<Statut> statuses) {
    if (statuses.isEmpty) {
      _openCreate(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          contactGroups: [statuses],
          startContactIndex: 0,
          isMine: true,
        ),
      ),
    );
  }

  /// Ouvre le visualiseur sur le contact [contactIndex] dans la section [bucket].
  /// Permet le swipe horizontal entre contacts de la même section.
  void _openOther(
    BuildContext context, {
    required List<List<Statut>> bucket,
    required int contactIndex,
  }) {
    final statuses = bucket[contactIndex];
    final firstUnseen = statuses.indexWhere((s) => !s.seenByMe);
    final start = firstUnseen >= 0 ? firstUnseen : 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          contactGroups: bucket,
          startContactIndex: contactIndex,
          startItemIndex: start,
          isMine: false,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MyStatusTile extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final List<Statut> statuses;
  final VoidCallback onCreate;
  final VoidCallback onView;

  const _MyStatusTile({
    required this.avatarUrl,
    required this.name,
    required this.statuses,
    required this.onCreate,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final hasStatus = statuses.isNotEmpty;
    return InkWell(
      onTap: hasStatus ? onView : onCreate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            StatusRingAvatar(
              avatarUrl: avatarUrl,
              fallbackText: name,
              totalCount: statuses.length,
              unseenCount: 0,
              size: 56,
              previewUrl: statuses.isNotEmpty && statuses.last.type == 1
                  ? statuses.last.mediaUrl
                  : null,
              statusType: statuses.isNotEmpty ? statuses.last.type : null,
              overlay: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.indigo,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mon statut',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasStatus
                        ? '${statuses.length} statut(s) actif(s) — appuyer pour voir'
                        : 'Appuyer pour ajouter votre statut',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (hasStatus)
              IconButton(
                icon: const Icon(CupertinoIcons.plus_circle, color: Colors.indigo),
                onPressed: onCreate,
              ),
          ],
        ),
      ),
    );
  }
}

class _ContactStatusTile extends StatelessWidget {
  final int authorId;
  final List<Statut> statuses;
  final int totalCount;
  final int unseenCount;
  final VoidCallback onTap;

  const _ContactStatusTile({
    required this.authorId,
    required this.statuses,
    required this.totalCount,
    required this.unseenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (statuses.isEmpty) return const SizedBox.shrink();
    final last = statuses.last;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            StatusRingAvatar(
              avatarUrl: last.avatarUrl,
              fallbackText: last.nom ?? '?',
              totalCount: totalCount,
              unseenCount: unseenCount,
              previewUrl: last.type == 1 ? last.mediaUrl : null,
              statusType: last.type,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    last.nom ?? 'Contact',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatRelative(last.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.sparkles,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun statut récent',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les statuts de vos contacts qui vous ont ajouté en favori s\'afficheront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
