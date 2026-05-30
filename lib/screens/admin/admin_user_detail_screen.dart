import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/admin_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/utils/avatar_utils.dart';

class AdminUserDetailScreen extends StatefulWidget {
  final int userId;

  const AdminUserDetailScreen({super.key, required this.userId});

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<_UserDetailData> _future;
  String _appBarName = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_UserDetailData> _load() async {
    final provider = context.read<AdminProvider>();
    final api = context.read<TalkyApiClient>();
    final user = await provider.getUserById(widget.userId);
    if (mounted) {
      setState(() {
        _appBarName = user.nom.isNotEmpty ? user.nom : 'Utilisateur';
      });
    }
    Map<String, dynamic> activity = const {};
    List<dynamic> logins = const [];
    try {
      activity = await api.adminGetUserActivity(widget.userId);
    } catch (_) {}
    try {
      logins = await api.adminGetUserLogins(widget.userId, limit: 10);
    } catch (_) {}
    return _UserDetailData(user: user, activity: activity, logins: logins);
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF4F5F8),
        foregroundColor: Colors.black,
        centerTitle: true,
        title: Text(
          _appBarName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: FutureBuilder<_UserDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Erreur: ${snapshot.error ?? "données indisponibles"}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ),
            );
          }
          final data = snapshot.data!;
          final user = data.user;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: 16),
                _ActivityCard(activity: data.activity),
                const SizedBox(height: 16),
                _LoginsCard(logins: data.logins),
                const SizedBox(height: 16),
                _ActionsCard(user: user, onChanged: _reload),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _UserDetailData {
  final User user;
  final Map<String, dynamic> activity;
  final List<dynamic> logins;
  _UserDetailData({
    required this.user,
    required this.activity,
    required this.logins,
  });
}

// ── PROFILE CARD ──────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User user;
  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Column(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: const Color(0xFFCBD0E8),
            backgroundImage: hasValidAvatarUrl(user.avatarUrl)
                ? NetworkImage(user.avatarUrl)
                : null,
            child: !hasValidAvatarUrl(user.avatarUrl)
                ? Text(
                    user.nom.isNotEmpty ? user.nom[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 14),
          Text(
            user.nom.isNotEmpty ? user.nom : '—',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          if (user.pseudo.isNotEmpty)
            Text(
              '@${user.pseudo}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          const SizedBox(height: 10),
          _RoleBadge(typeCompte: user.typeCompte, banned: user.exclus),
          const SizedBox(height: 16),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),
          _InfoRow(label: 'ID', value: '${user.alanyaID}'),
          _InfoRow(label: 'Téléphone', value: user.alanyaPhone),
          _InfoRow(label: 'Email', value: user.email),
          if ((user.paysLibelle ?? '').isNotEmpty)
            _InfoRow(label: 'Pays', value: user.paysLibelle!),
          _InfoRow(label: 'Inscrit(e) le', value: _formatDate(user.createdAt)),
          _InfoRow(label: 'Dernière vue', value: _formatDate(user.lastSeen)),
          if (user.exclus && (user.excludeReason ?? '').isNotEmpty)
            _InfoRow(label: 'Motif ban', value: user.excludeReason!),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _RoleBadge extends StatelessWidget {
  final int typeCompte;
  final bool banned;
  const _RoleBadge({required this.typeCompte, required this.banned});

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = banned
        ? ('Banni', const Color(0xFFD8453E), const Color(0xFFFDECEC))
        : typeCompte >= 2
            ? ('Super Admin', const Color(0xFF6B3CD2), const Color(0xFFEDE3FC))
            : typeCompte >= 1
                ? ('Admin', const Color(0xFF1E66D8), const Color(0xFFE3EEFE))
                : ('Utilisateur', Colors.grey.shade700, const Color(0xFFEDEDF1));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── ACTIVITY CARD ─────────────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  const _ActivityCard({required this.activity});

  int _i(String key) {
    final v = activity[key];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityItem(
        label: 'Messages',
        value: _i('messagesSent'),
        icon: CupertinoIcons.chat_bubble_2_fill,
        iconColor: const Color(0xFF3B82F6),
        bg: const Color(0xFFEAF2FE),
      ),
      _ActivityItem(
        label: 'Conversations',
        value: _i('conversations'),
        icon: CupertinoIcons.chat_bubble_2,
        iconColor: const Color(0xFF14B8A6),
        bg: const Color(0xFFE6F6F3),
      ),
      _ActivityItem(
        label: 'Appels émis',
        value: _i('callsMade'),
        icon: Icons.phone_forwarded,
        iconColor: const Color(0xFFF59E0B),
        bg: const Color(0xFFFDF3E2),
      ),
      _ActivityItem(
        label: 'Appels reçus',
        value: _i('callsReceived'),
        icon: Icons.phone_callback,
        iconColor: const Color(0xFFEF4444),
        bg: const Color(0xFFFDECEC),
      ),
      _ActivityItem(
        label: 'Statuts',
        value: _i('statusesPublished'),
        icon: CupertinoIcons.sparkles,
        iconColor: const Color(0xFFEC4899),
        bg: const Color(0xFFFCE7F1),
      ),
    ];
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activité',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: items,
          ),
        ],
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconColor;
  final Color bg;
  const _ActivityItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    height: 1.15,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── LOGINS CARD ───────────────────────────────────────────────────────

class _LoginsCard extends StatelessWidget {
  final List<dynamic> logins;
  const _LoginsCard({required this.logins});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connexions récentes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          if (logins.isEmpty)
            Text(
              'Aucune connexion enregistrée',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            )
          else
            ...logins.take(5).map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              return _LoginRow(
                date: m['dateLogin']?.toString() ?? '',
                device: m['device']?.toString() ?? '',
                ip: m['ipAdress']?.toString() ?? '',
                os: m['os_system']?.toString() ?? '',
              );
            }),
        ],
      ),
    );
  }
}

class _LoginRow extends StatelessWidget {
  final String date;
  final String device;
  final String ip;
  final String os;
  const _LoginRow({
    required this.date,
    required this.device,
    required this.ip,
    required this.os,
  });

  String _fmt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final l = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (os.isNotEmpty) os,
      if (device.isNotEmpty) device,
      if (ip.isNotEmpty) ip,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE3EEFE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              CupertinoIcons.device_phone_portrait,
              size: 16,
              color: Color(0xFF1E66D8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmt(date),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (subtitleParts.isNotEmpty)
                  Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ACTIONS CARD ──────────────────────────────────────────────────────

class _ActionsCard extends StatelessWidget {
  final User user;
  final Future<void> Function() onChanged;
  const _ActionsCard({required this.user, required this.onChanged});

  Future<void> _toggleBan(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    await provider.toggleBan(user);
    await onChanged();
  }

  Future<void> _toggleAdmin(BuildContext context) async {
    final provider = context.read<AdminProvider>();
    final newType = user.typeCompte >= 1 ? 0 : 1;
    await provider.setAccountType(user.alanyaID, newType);
    await onChanged();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final provider = context.read<AdminProvider>();
    await provider.deleteUser(user.alanyaID);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8, bottom: 4),
            child: Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
          ),
          _ActionRow(
            icon: user.exclus
                ? CupertinoIcons.checkmark_circle_fill
                : CupertinoIcons.nosign,
            label: user.exclus ? 'Débannir' : 'Bannir',
            iconColor: user.exclus
                ? const Color(0xFF16A34A)
                : const Color(0xFFEF4444),
            iconBg: user.exclus
                ? const Color(0xFFE7F6EC)
                : const Color(0xFFFDECEC),
            labelColor: user.exclus
                ? const Color(0xFF16A34A)
                : const Color(0xFFEF4444),
            onTap: () => _toggleBan(context),
          ),
          _ActionRow(
            icon: user.typeCompte >= 1
                ? CupertinoIcons.shield_slash_fill
                : CupertinoIcons.shield_fill,
            label: user.typeCompte >= 1 ? 'Rétrograder' : 'Rendre admin',
            iconColor: const Color(0xFF1E66D8),
            iconBg: const Color(0xFFE3EEFE),
            onTap: () => _toggleAdmin(context),
          ),
          _ActionRow(
            icon: CupertinoIcons.trash_fill,
            label: 'Supprimer',
            iconColor: const Color(0xFFB91C1C),
            iconBg: const Color(0xFFFDECEC),
            labelColor: const Color(0xFFB91C1C),
            onTap: () => _delete(context),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final Color iconBg;
  final Color? labelColor;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.iconBg,
    required this.onTap,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: labelColor ?? Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}

// ── CARD CONTAINER ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _Card({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
