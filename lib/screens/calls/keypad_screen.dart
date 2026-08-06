import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import '../../core/services/local_cache_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../core/utils/user_search.dart';
import '../../widgets/common/common.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _phoneDigits = '';
  User? _foundUser;
  bool _isSearching = false;

  List<User> _preferredContacts = [];
  List<User> _serverResults = [];
  bool _loadingSuggestions = false;
  bool _addingContact = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ── Données ──────────────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    try {
      final cache = Provider.of<LocalCacheRepository>(context, listen: false);
      final local = await cache.getPreferredContactsOnce();
      if (!mounted) return;
      setState(() {
        _preferredContacts = local.map(localUserToUser).toList();
      });
      unawaited(_refreshPreferredFromServer(cache));
    } catch (_) {
      // Silencieux : la recherche serveur reste disponible.
    }
  }

  Future<void> _refreshPreferredFromServer(LocalCacheRepository cache) async {
    final updated = await cache.syncAndGetPreferredContacts();
    if (!mounted) return;
    setState(() {
      _preferredContacts = updated.map(localUserToUser).toList();
    });
  }

  Set<int> get _preferredIds =>
      _preferredContacts.map((u) => u.alanyaID).toSet();

  String get _phoneDisplay =>
      AlanyaPhoneFormatter.formatLiveInput(_phoneDigits);

  /// Contacts préférés — correspondance exacte si longueur valide.
  List<User> get _matchedPreferred {
    if (_phoneDigits.isEmpty) return [];
    if (AlanyaPhoneFormatter.validate(_phoneDigits) != null) return [];
    return _preferredContacts
        .where((u) => u.alanyaPhone == _phoneDigits)
        .toList();
  }

  /// Résultats serveur en excluant ceux déjà présents dans les préférés.
  List<User> get _otherResults {
    final ids = _matchedPreferred.map((u) => u.alanyaID).toSet();
    return _serverResults.where((u) => !ids.contains(u.alanyaID)).toList();
  }

  // ── Saisie ───────────────────────────────────────────────────────────

  void _onKeyPress(String value) {
    if (_phoneDigits.length >= 8) return;
    setState(() {
      _phoneDigits += value;
      _foundUser = null;
    });
    _onQueryChanged();
  }

  void _onDelete() {
    if (_phoneDigits.isEmpty) return;
    setState(() {
      _phoneDigits = _phoneDigits.substring(0, _phoneDigits.length - 1);
      _foundUser = null;
    });
    _onQueryChanged();
  }

  void _clearAll() {
    setState(() {
      _phoneDigits = '';
      _foundUser = null;
      _serverResults = [];
    });
  }

  void _onQueryChanged() {
    _currentQuery = _phoneDigits;
    if (_phoneDigits.isEmpty) {
      setState(() => _serverResults = []);
      return;
    }
    if (AlanyaPhoneFormatter.validate(_phoneDigits) == null) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_currentQuery == _phoneDigits && mounted) {
          _searchServer(_phoneDigits);
        }
      });
    } else {
      setState(() => _serverResults = []);
    }
  }

  Future<void> _searchServer(String query) async {
    setState(() => _loadingSuggestions = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _serverResults = data
            .map((e) => e is User ? e : User.fromJson(e as Map<String, dynamic>))
            .toList();
        _loadingSuggestions = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  void _selectContact(User user) {
    setState(() {
      _phoneDigits = user.alanyaPhone;
      _foundUser = user;
      _serverResults = [];
    });
  }

  // ── Appels ───────────────────────────────────────────────────────────

  Future<void> _searchUser() async {
    if (_phoneDigits.isEmpty) return;
    if (AlanyaPhoneFormatter.validate(_phoneDigits) != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.invalidNumber34Or8),
          ),
        );
      }
      return;
    }

    setState(() => _isSearching = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final userData = await apiClient.getUserByPhone(_phoneDigits);
      setState(() {
        _foundUser = userData.isNotEmpty
            ? User.fromJson(userData[0] as Map<String, dynamic>)
            : null;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _foundUser = null;
        _isSearching = false;
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.userNotFound)),
        );
      }
    }
  }

  void _showCallTypeSheet() {
    if (_foundUser == null && _phoneDigits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.enterANumberOrChooseA),
        ),
      );
      return;
    }
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      builder: (sheetContext) => AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.placeACall, style: context.text.titleLarge),
            AppSpacing.vGapLg,
            Row(
              children: [
                Expanded(
                  child: _callOption(
                    sheetContext,
                    icon: CupertinoIcons.phone_fill,
                    label: context.l10n.audio2,
                    color: context.semantic.success,
                    isVideo: false,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: _callOption(
                    sheetContext,
                    icon: CupertinoIcons.videocam_fill,
                    label: context.l10n.video2,
                    color: context.colors.primary,
                    isVideo: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCall({bool isVideo = false}) async {
    if (_foundUser == null) {
      await _searchUser();
      if (_foundUser == null) return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final me = auth.currentUser;
    if (me == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileUnavailableTryAgain)),
      );
      return;
    }

    // Composer son propre numéro Alanya : le refuser ici donne un message
    // clair, plutôt que l'erreur générique remontée par le service.
    if (_foundUser!.alanyaID == me.alanyaID) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotCallYourself)),
      );
      return;
    }

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: _foundUser!.alanyaID,
      myId: me.alanyaID,
      myName: me.nom.isNotEmpty ? me.nom : me.pseudo,
      myPhoto: me.avatarUrl,
      targetUserName: _foundUser!.nom,
      targetUserPhoto: _foundUser!.avatarUrl,
      isVideo: isVideo,
    );
    if (context.mounted) {
      // Vérifier s'il y a eu une erreur (ex: permissions refusées)
      if (callService.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(callService.errorMessage!),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
      await callService.navigateToCallUi(context);
    }
  }

  /// Ajoute le numéro tapé (ou le contact sélectionné) aux contacts préférés.
  Future<void> _addCurrentNumber() async {
    if (_addingContact) return;
    final phone = _phoneDigits;
    if (_foundUser == null && phone.isEmpty) {
      _showSnack(context.l10n.enterANumberToAdd);
      return;
    }

    setState(() => _addingContact = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      User? user = _foundUser;
      if (user == null) {
        final data = await apiClient.getUserByPhone(phone);
        user = data.isNotEmpty
            ? User.fromJson(data[0] as Map<String, dynamic>)
            : null;
      }

      if (!mounted) return;
      if (user == null) {
        _showSnack(context.l10n.userNotFound);
        return;
      }
      if (_preferredIds.contains(user.alanyaID)) {
        _showSnack(context.l10n.alreadyInYourPreferredContacts);
        return;
      }

      await apiClient.addContact(user.alanyaID);
      if (!mounted) return;
      final added = user;
      setState(() {
        _foundUser = added;
        _preferredContacts = [..._preferredContacts, added];
      });
      _showSnack(
        context.l10n.addedToPreferredContacts(added.nom.isNotEmpty ? added.nom : added.pseudo),
        success: true,
      );
    } catch (e) {
      if (mounted) _showSnack(context.l10n.errorColon('$e'));
    } finally {
      if (mounted) setState(() => _addingContact = false);
    }
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? AppColors.success : null,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(context.l10n.keypadTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildSuggestions()),
            _buildDisplayRow(),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], ['', 'ABC', 'DEF']),
                  const SizedBox(height: 20),
                  _buildRow(['4', '5', '6'], ['GHI', 'JKL', 'MNO']),
                  const SizedBox(height: 20),
                  _buildRow(['7', '8', '9'], ['PQRS', 'TUV', 'WXYZ']),
                  const SizedBox(height: 20),
                  _buildRow(['*', '0', '#'], ['', '+', '']),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildActionRow(),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_phoneDigits.isEmpty) return const SizedBox.shrink();

    final preferred = _matchedPreferred;
    final others = _otherResults;

    if (preferred.isEmpty && others.isEmpty) {
      if (_loadingSuggestions) {
        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        if (preferred.isNotEmpty) ...[
          _sectionLabel(context.l10n.preferredContacts),
          ...preferred.map(_buildContactTile),
        ],
        if (others.isNotEmpty) ...[
          _sectionLabel(context.l10n.otherResults),
          ...others.map(_buildContactTile),
        ],
        if (_loadingSuggestions)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xs),
      child: Text(
        text,
        style: context.text.labelMedium?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildContactTile(User user) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      leading: AppAvatar(
        imageUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
        name: user.nom.isNotEmpty ? user.nom : user.pseudo,
        size: AppSizes.avatarMd,
        qrBadge: user.addedViaQr == true,
      ),
      title: Text(
        user.nom.isNotEmpty ? user.nom : user.pseudo,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        '@${user.pseudo} • ${AlanyaPhoneFormatter.formatDisplay(user.alanyaPhone)}',
        style: context.text.bodySmall
            ?.copyWith(color: context.colors.onSurfaceVariant),
      ),
      onTap: () => _selectContact(user),
    );
  }

  Widget _buildDisplayRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: SizedBox(
        height: 72,
        child: Row(
          children: [
            // Espace miroir pour garder le numéro centré.
            const SizedBox(width: 48),
            Expanded(
              child: Center(
                child: _isSearching
                    ? const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _phoneDisplay,
                        style: context.text.headlineLarge?.copyWith(
                          fontSize: 40,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ),
            SizedBox(
              width: 48,
              child: _phoneDigits.isEmpty
                  ? null
                  : GestureDetector(
                      onLongPress: _clearAll,
                      child: IconButton(
                        onPressed: _onDelete,
                        tooltip: context.l10n.clearAction,
                        icon: Icon(
                          CupertinoIcons.delete_left,
                          size: AppIconSize.lg,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Ajouter le numéro tapé aux contacts préférés
          GestureDetector(
            onTap: _addCurrentNumber,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: context.semantic.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: _addingContact
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      Icons.person_add_alt_1,
                      color: context.colors.onSurface,
                      size: AppIconSize.lg,
                    ),
            ),
          ),
          // Appel
          GestureDetector(
            onTap: _showCallTypeSheet,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.semantic.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: AppColors.white,
                size: 36,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _callOption(
    BuildContext sheetContext, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isVideo,
  }) {
    return InkWell(
      borderRadius: AppRadius.brMd,
      onTap: () {
        Navigator.pop(sheetContext);
        _onCall(isVideo: isVideo);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.brMd,
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            AppSpacing.vGapSm,
            Text(
              label,
              style: context.text.titleSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> numbers, List<String> letters) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return GestureDetector(
          onTap: () => _onKeyPress(numbers[index]),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.semantic.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  numbers[index],
                  style: context.text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w500),
                ),
                if (letters[index].isNotEmpty)
                  Text(
                    letters[index],
                    style: context.text.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
