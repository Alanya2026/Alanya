import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
class AdminUserDetailScreen extends StatefulWidget {
  final int userId;
  const AdminUserDetailScreen({super.key, required this.userId});
  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  User? _user;
  Map<String, dynamic>? _activity;
  List<dynamic> _logins = [];
  bool _isLoading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _loadAll();
  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = context.read<TalkyApiClient>();
      final results = await Future.wait([
        api.adminGetUserById(widget.userId),
        api.adminGetUserActivity(widget.userId),
        api.adminGetUserLogins(widget.userId, limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(Map<String, dynamic>.from(results[0] as Map));
        _activity = Map<String, dynamic>.from(results[1] as Map);
        _logins = results[2] as List;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  // 
 Actions 
  Future<void> _toggleBan() async {
    final u = _user;
    if (u == null) return;
    final provider = context.read<AdminProvider>();
    String? reason;
    if (!u.exclus) {
      reason = await _askReason();
      if (reason == null) return;
    }
    await provider.toggleBan(u, reason: reason);
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(u.exclus ? 'D
banni' : 'Banni')),
    );
  Future<String?> _askReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Raison du bannissement (optionnel)'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex : spam, abus
          maxLength: 200,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Bannir'),
          ),
        ],
      ),
    );
  Future<void> _changeRole(int type) async {
    await context.read<AdminProvider>().setAccountType(widget.userId, type);
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_roleLabel(type))),
    );
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text(
          '
tes-vous s
r ? ${_user?.nom ?? "Cet utilisateur"} et toutes ses donn
es seront supprim
s. Cette action est irr
versible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    await context.read<AdminProvider>().deleteUser(widget.userId);
    if (!mounted) return;
    Navigator.pop(context);
  // 
 Build 
  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    final isSuper = AdminProvider.isSuperAdmin(me);
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(_user?.nom ?? 'Utilisateur'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _loadAll)
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      _profileCard(),
                      const SizedBox(height: 16),
                      _activityCard(),
                      const SizedBox(height: 16),
                      _loginsCard(),
                      const SizedBox(height: 16),
                      _actionsCard(isSuper: isSuper),
                    ],
                  ),
                ),
    );
  // 
 Sections 
  Widget _profileCard() {
    final u = _user!;
    return _Card(
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: u.avatarUrl.isNotEmpty
                    ? NetworkImage(u.avatarUrl)
                    : null,
                child: u.avatarUrl.isEmpty
                    ? Text(
                        u.nom.isNotEmpty ? u.nom[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.indigo,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (u.isOnline)
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            u.nom.isNotEmpty ? u.nom : u.pseudo,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (u.pseudo.isNotEmpty)
            Text('@${u.pseudo}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _Pill(label: _roleLabel(u.typeCompte), color: _roleColor(u.typeCompte)),
              if (u.exclus) const _Pill(label: 'Banni', color: Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _InfoRow(label: 'ID', value: '${u.alanyaID}'),
          _InfoRow(label: 'T
phone', value: u.alanyaPhone),
          _InfoRow(label: 'Email', value: u.email.isEmpty ? '
' : u.email),
          _InfoRow(
              label: 'Pays', value: u.paysLibelle ?? '
          _InfoRow(label: 'Inscrit le', value: _fmtDate(u.createdAt)),
          _InfoRow(label: 'Derni
re vue', value: _fmtDate(u.lastSeen)),
          if (u.exclus && (u.excludeReason?.isNotEmpty ?? false))
            _InfoRow(label: 'Raison ban', value: u.excludeReason!),
          if (u.exclus && (u.excludeAt?.isNotEmpty ?? false))
            _InfoRow(label: 'Banni le', value: _fmtDate(u.excludeAt)),
        ],
      ),
    );
  Widget _activityCard() {
    final a = _activity ?? const {};
    return _Card(
      title: 'Activit
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: [
          _ActivityTile(
            icon: CupertinoIcons.chat_bubble_2_fill,
            color: Colors.blue,
            label: 'Messages',
            value: a['messagesSent'] ?? 0,
          ),
          _ActivityTile(
            icon: CupertinoIcons.bubble_left_bubble_right,
            color: Colors.teal,
            label: 'Conversations',
            value: a['conversations'] ?? 0,
          ),
          _ActivityTile(
            icon: CupertinoIcons.phone_arrow_up_right,
            color: Colors.orange,
            label: 'Appels 
mis',
            value: a['callsMade'] ?? 0,
          ),
          _ActivityTile(
            icon: CupertinoIcons.phone_arrow_down_left,
            color: Colors.deepOrange,
            label: 'Appels re
us',
            value: a['callsReceived'] ?? 0,
          ),
          _ActivityTile(
            icon: CupertinoIcons.sparkles,
            color: Colors.pink,
            label: 'Statuts',
            value: a['statusesPublished'] ?? 0,
          ),
        ],
      ),
    );
  Widget _loginsCard() {
    return _Card(
      title: 'Connexions r
centes',
      child: _logins.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Aucune connexion enregistr
                style: TextStyle(color: Colors.grey.shade600),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _logins.length; i++) ...[
                  if (i > 0) const Divider(height: 12),
                  _LoginRow(entry: Map<String, dynamic>.from(_logins[i])),
                ],
              ],
            ),
    );
  Widget _actionsCard({required bool isSuper}) {
    final u = _user!;
    return _Card(
      title: 'Actions',
      child: Column(
        children: [
          _ActionButton(
            icon: u.exclus
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.nosign,
            label: u.exclus ? 'D
bannir' : 'Bannir',
            color: u.exclus ? Colors.green : Colors.red,
            onTap: _toggleBan,
          ),
          if (isSuper) ...[
            const Divider(height: 1),
            if (u.typeCompte < 1)
              _ActionButton(
                icon: CupertinoIcons.shield_lefthalf_fill,
                label: 'Promouvoir admin',
                color: Colors.indigo,
                onTap: () => _changeRole(1),
              ),
            if (u.typeCompte == 1)
              _ActionButton(
                icon: CupertinoIcons.arrow_up_circle_fill,
                label: 'Promouvoir super-admin',
                color: Colors.deepPurple,
                onTap: () => _changeRole(2),
              ),
            if (u.typeCompte >= 1)
              _ActionButton(
                icon: CupertinoIcons.person_fill,
                label: 'R
trograder utilisateur',
                color: Colors.grey.shade700,
                onTap: () => _changeRole(0),
              ),
            const Divider(height: 1),
            _ActionButton(
              icon: CupertinoIcons.trash_fill,
              label: 'Supprimer le compte',
              color: Colors.red,
              onTap: _confirmDelete,
            ),
          ],
        ],
      ),
    );
  // 
 Helpers 
  String _roleLabel(int t) {
    switch (t) {
      case 2: return 'Super-admin';
      case 1: return 'Administrateur';
      default: return 'Utilisateur';
    }
  Color _roleColor(int t) {
    switch (t) {
      case 2: return Colors.deepPurple;
      case 1: return Colors.indigo;
      default: return Colors.grey.shade700;
    }
  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return '
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
 Composants 
class _Card extends StatelessWidget {
  final String? title;
  final Widget child;
  const _Card({this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final dynamic value;
  const _ActivityTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
class _LoginRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LoginRow({required this.entry});
  @override
  Widget build(BuildContext context) {
    final ip = entry['ipAdress']?.toString() ?? '
    final os = entry['os_system']?.toString() ?? '
    final device = entry['device']?.toString() ?? '
    final date = entry['dateLogin']?.toString() ?? '';
    final dt = DateTime.tryParse(date)?.toLocal();
    final dateStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : date;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(CupertinoIcons.bolt_circle, size: 18, color: Colors.indigo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$os 
 $device',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '$ip 
 $dateStr',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('R
essayer')),
        ],
      ),
    );