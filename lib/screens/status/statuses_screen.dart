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
        // Trier par date du dernier statut (le plus r
cent en haut)
        final aLast = a.value.isNotEmpty ? a.value.last.createdAt : '';
        final bLast = b.value.isNotEmpty ? b.value.last.createdAt : '';
        return bLast.compareTo(aLast);
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
            // 
 Mon statut 
            _MyStatusTile(
              avatarUrl: me?.avatarUrl,
              name: me?.nom ?? '',
              statuses: myStatuses,
              onCreate: () => _openCreate(context),
              onView: () => _openMine(context, myStatuses),
            ),
            const Divider(height: 1),
            // 
 Header section "R
cents" 
            if (entries.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'R
cents',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            // 
 Liste des statuts 
            if (entries.isEmpty && !provider.loading)
              _EmptyState(),
            for (final entry in entries)
              _ContactStatusTile(
                authorId: entry.key,
                statuses: entry.value,
                totalCount: provider.totalCount(entry.key),
                unseenCount: provider.unseenCount(entry.key),
                onTap: () => _openOther(context, entry.value),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StatusCreateScreen()),
    );
  void _openMine(BuildContext context, List<Statut> statuses) {
    if (statuses.isEmpty) {
      _openCreate(context);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          statuses: statuses,
          startIndex: 0,
          isMine: true,
        ),
      ),
    );
  void _openOther(BuildContext context, List<Statut> statuses) {
    final firstUnseen = statuses.indexWhere((s) => !s.seenByMe);
    final start = firstUnseen >= 0 ? firstUnseen : 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatusViewerScreen(
          statuses: statuses,
          startIndex: start,
          isMine: false,
        ),
      ),
    );
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
                        ? '${statuses.length} statut(s) actif(s) 
 appuyer pour voir'
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
  static String _formatRelative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return '
 l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
class _EmptyState extends StatelessWidget {
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
            'Aucun statut r
cent',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les statuts de vos contacts qui vous ont ajout
 en favori s\'afficheront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );