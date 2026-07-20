import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../providers/admin_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../widgets/common/app_skeleton.dart';
import 'admin_create_user_screen.dart';
import '../../core/theme/app_theme.dart';

class AdminReservedPhonesScreen extends StatefulWidget {
  const AdminReservedPhonesScreen({super.key});

  @override
  State<AdminReservedPhonesScreen> createState() =>
      _AdminReservedPhonesScreenState();
}

class _AdminReservedPhonesScreenState extends State<AdminReservedPhonesScreen> {
  static const _limit = 20;

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  int _page = 1;
  int _total = 0;

  final _phoneCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  String? _availableFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _phoneCtrl.dispose();
    _labelCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({int? page}) async {
    final nextPage = page ?? _page;
    if (!mounted) return;

    setState(() {
      _fetching = true;
      _error = null;
      if (page != null) _page = page;
      if (_items.isEmpty) _loading = true;
    });

    try {
      final result =
          await context.read<AdminProvider>().loadReservedPhones(
                page: nextPage,
                limit: _limit,
                q: _searchCtrl.text.trim().isEmpty
                    ? null
                    : _searchCtrl.text.trim(),
                available: _availableFilter,
              );
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = result.page;
      });
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.loadErrorWithDetails('$e'))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _fetching = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _load(page: 1);
    });
  }

  Future<void> _add() async {
    final canonical = AlanyaPhoneField.canonicalFrom(_phoneCtrl);
    final err = AlanyaPhoneFormatter.validateReservedCandidate(canonical);
    if (err != null || _labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? context.l10n.labelRequired)),
      );
      return;
    }
    try {
      await context.read<AdminProvider>().addReservedPhone(
            canonical,
            _labelCtrl.text.trim(),
          );
      _phoneCtrl.clear();
      _labelCtrl.clear();
      await _load(page: 1);
    } on TalkyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _remove(String phone) async {
    try {
      await context.read<AdminProvider>().removeReservedPhone(phone);
      await _load();
    } on TalkyException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _assign(String phone) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateUserScreen(initialReservedPhone: phone),
      ),
    );
    if (created == true && mounted) await _load();
  }

  int get _pageCount => (_total / _limit).ceil().clamp(1, 1 << 30);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.reservedNumbers),
        actions: [
          IconButton(
            tooltip: context.l10n.refresh,
            onPressed: _fetching ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _load(page: _page),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.lg,
                      ),
                      children: [
                        AlanyaPhoneField(
                          controller: _phoneCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.number,
                            hintText: context.l10n.n34DigitsOrXxyyzztt,
                          ),
                        ),
                        AppSpacing.vGapSm,
                        Text(
                          context.l10n.reservedPhoneOnlyHint,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        AppSpacing.vGapMd,
                        TextField(
                          controller: _labelCtrl,
                          decoration:
                              InputDecoration(labelText: context.l10n.label),
                        ),
                        AppSpacing.vGapMd,
                        FilledButton(
                          onPressed: _add,
                          child: Text(context.l10n.add),
                        ),
                        AppSpacing.vGapXxl,
                        Text(
                          _loading ? context.l10n.listLabel : context.l10n.listWithCount(_total),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        AppSpacing.vGapMd,
                        if (_loading) ...[
                          const ReservedPhonesListSectionSkeleton(count: 8),
                        ] else ...[
                          TextField(
                            controller: _searchCtrl,
                            decoration: InputDecoration(
                              labelText: context.l10n.commonSearch,
                              hintText: context.l10n.numberOrLabel,
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: _onSearchChanged,
                          ),
                          AppSpacing.vGapSm,
                          DropdownButtonFormField<String?>(
                            value: _availableFilter,
                            decoration:
                                InputDecoration(labelText: context.l10n.filterLabel),
                            items: [
                              DropdownMenuItem(
                                  value: null, child: Text(context.l10n.allFilter)),
                              DropdownMenuItem(
                                  value: '1', child: Text(context.l10n.freePlural)),
                              DropdownMenuItem(
                                  value: '0', child: Text(context.l10n.used)),
                            ],
                            onChanged: (value) {
                              setState(() => _availableFilter = value);
                              _load(page: 1);
                            },
                          ),
                          AppSpacing.vGapMd,
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.md),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          if (_fetching)
                            const ReservedPhoneListSkeleton(count: 6)
                          else if (_items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.xl),
                              child: Text(
                                _error != null
                                    ? context.l10n.unableToLoadNumbers
                                    : context.l10n.noReservedNumbers,
                                textAlign: TextAlign.center,
                              ),
                            )
                          else
                            Column(
                              children: _items.map(_buildItem).toList(),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_total > _limit && !_loading) _buildPagination(),
              ],
            ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item) {
    final phone = (item['phone_canonical'] ?? item['phoneCanonical'] ?? '')
        as String;
    final label = (item['label'] ?? '') as String;
    final isUsed = item['is_used'] == true ||
        item['isUsed'] == true ||
        item['is_used'] == 1 ||
        item['isUsed'] == 1;
    final usedByNom = (item['used_by_nom'] ?? item['usedByNom']) as String?;
    final usedByPseudo =
        (item['used_by_pseudo'] ?? item['usedByPseudo']) as String?;
    final usedById = item['used_by_alanya_id'] ?? item['usedByAlanyaId'];
    final ownerLabel = usedByNom?.trim().isNotEmpty == true
        ? usedByNom!
        : (usedByPseudo?.trim().isNotEmpty == true
            ? usedByPseudo!
            : (usedById != null ? context.l10n.userHashId(usedById) : null));
    final statusText = isUsed
        ? (ownerLabel != null ? context.l10n.usedByOwner(ownerLabel) : context.l10n.usedLabel)
        : context.l10n.freeUnassigned;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(AlanyaPhoneFormatter.formatDisplay(phone)),
      subtitle: Text('$label\n$statusText'),
      isThreeLine: true,
      trailing: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isUsed)
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _assign(phone),
                child: Text(context.l10n.assignAction),
              ),
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _remove(phone),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination() {
    final canPrev = _page > 1 && !_fetching;
    final canNext = _page < _pageCount && !_fetching;
    final from = ((_page - 1) * _limit) + 1;
    final to = (_page * _limit).clamp(0, _total);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: canPrev ? () => _load(page: _page - 1) : null,
              icon: const Icon(CupertinoIcons.chevron_left),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(context.l10n.pageOf(_page, _pageCount)),
                  Text(
                    context.l10n.rangeOfTotal(from, to, _total),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: canNext ? () => _load(page: _page + 1) : null,
              icon: const Icon(CupertinoIcons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}
