import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../chats/contact_detail_screen.dart';
class StatusViewsScreen extends StatefulWidget {
  final Statut statut;
  const StatusViewsScreen({super.key, required this.statut});
  @override
  State<StatusViewsScreen> createState() => _StatusViewsScreenState();
class _StatusViewsScreenState extends State<StatusViewsScreen> {
  late Future<List<StatutView>> _future;
  @override
  void initState() {
    super.initState();
    _future = context.read<StatusProvider>().getViews(widget.statut.id, force: true);
  Future<void> _refresh() async {
    setState(() {
      _future = context.read<StatusProvider>().getViews(
            widget.statut.id,
            force: true,
          );
    });
    await _future;
  @override
  Widget build(BuildContext context) {
    // Watch pour mises 
 jour live (likes/vues entrants via socket)
    final provider = context.watch<StatusProvider>();
    // R
re les compteurs depuis le statut le plus 
 jour
    final liveStatut = provider.mine.firstWhere(
      (s) => s.id == widget.statut.id,
      orElse: () => widget.statut,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vues du statut'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 
 Compteurs 
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _Stat(
                  icon: Icons.visibility,
                  color: Colors.indigo,
                  label: '${liveStatut.viewedBy} vue${liveStatut.viewedBy > 1 ? 's' : ''}',
                ),
                const SizedBox(width: 20),
                _Stat(
                  icon: Icons.favorite,
                  color: Colors.redAccent,
                  label: '${liveStatut.likedBy} j\'aime',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 
 Liste 
          Expanded(
            child: FutureBuilder<List<StatutView>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final views = snap.data ?? const <StatutView>[];
                if (views.isEmpty) {
                  return _EmptyState();
                }
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    itemCount: views.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (_, i) => _ViewerTile(
                      view: views[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ContactDetailScreen(
                            userId: views[i].alanyaID,
                            initialName: views[i].nom,
                            initialAvatar: views[i].avatarUrl ?? '',
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
class _Stat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Stat({required this.icon, required this.color, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
class _ViewerTile extends StatelessWidget {
  final StatutView view;
  final VoidCallback onTap;
  const _ViewerTile({required this.view, required this.onTap});
  String _relative(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return '
 l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey.shade300,
        backgroundImage: view.avatarUrl != null && view.avatarUrl!.isNotEmpty
            ? NetworkImage(view.avatarUrl!)
            : null,
        child: view.avatarUrl == null || view.avatarUrl!.isEmpty
            ? Text(
                view.nom.isNotEmpty ? view.nom[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(view.nom, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(_relative(view.seenAt)),
      trailing: view.liked
          ? const Icon(Icons.favorite, color: Colors.redAccent)
          : null,
    );
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility_off_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Personne n\'a encore vu ce statut',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );