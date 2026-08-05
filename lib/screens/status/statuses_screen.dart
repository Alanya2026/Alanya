import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/status_provider.dart';
import '../../talky_models.dart';
import '../../widgets/animated_search_bar.dart';
import '../../widgets/common/account_badge.dart';
import '../../widgets/common/empty_state.dart';
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
      appBar: AppBar(
        title: Text(context.l10n.navStatuses, style: context.text.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
            tooltip: _searchOpen ? context.l10n.closeSearch : context.l10n.commonSearch,
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
                  if (recents.isNotEmpty) _SectionHeader(label: context.l10n.recent),
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
                  if (viewed.isNotEmpty) _SectionHeader(label: context.l10n.alreadyViewed),
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
                  if (recents.isEmpty && viewed.isEmpty && !provider.loading)
                    EmptyState(
                      icon: CupertinoIcons.sparkles,
                      title: context.l10n.noRecentStatus,
                      message:
                          context.l10n.statusesFromContactsWhoFavoritedYou,
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openCreate(context),
        child: const Icon(Icons.add),
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
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
      child: Text(
        label,
        style: context.text.labelMedium
            ?.copyWith(color: context.colors.onSurfaceVariant),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          children: [
            StatusRingAvatar(
              avatarUrl: avatarUrl,
              fallbackText: name,
              totalCount: statuses.length,
              unseenCount: 0,
              size: AppSizes.avatarLg,
              previewUrl: statuses.isNotEmpty && statuses.last.type == 1
                  ? statuses.last.mediaUrl
                  : null,
              statusType: statuses.isNotEmpty ? statuses.last.type : null,
              overlay: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.surface, width: 2),
                ),
                child: Icon(Icons.add, color: context.colors.onPrimary, size: 14),
              ),
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.myStatus, style: context.text.titleSmall),
                  AppSpacing.vGapXs,
                  Text(
                    hasStatus
                        ? context.l10n.activeStatusesTapToView(statuses.length)
                        : context.l10n.tapToAddYourStatus,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (hasStatus)
              IconButton(
                icon: Icon(CupertinoIcons.plus_circle,
                    color: context.colors.primary),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AccountBadgeLabel(
                    name: last.nom ?? context.l10n.contact2,
                    accountType: last.accountType ?? 0,
                    verificationStatus: last.verificationStatus ?? 0,
                    style: context.text.titleSmall,
                  ),
                  AppSpacing.vGapXs,
                  Text(
                    _formatRelative(context, last.createdAt),
                    style: context.text.bodySmall
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatRelative(BuildContext context, String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt.toLocal());
    if (diff.inMinutes < 1) return context.l10n.justNow;
    if (diff.inMinutes < 60) return context.l10n.timeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return context.l10n.timeAgoHours(diff.inHours);
    return context.l10n.timeAgoDays(diff.inDays);
  }
}
