import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../core/services/call_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common/common.dart';
import 'ongoing_call_screen.dart';

class KeypadScreen extends StatefulWidget {
  const KeypadScreen({super.key});

  @override
  State<KeypadScreen> createState() => _KeypadScreenState();
}

class _KeypadScreenState extends State<KeypadScreen> {
  String _phoneNumber = '';
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
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getContacts();
      if (!mounted) return;
      setState(() {
        _preferredContacts = (data as List?)
                ?.map((json) => User.fromJson(json as Map<String, dynamic>))
                .toList() ??
            [];
      });
    } catch (_) {
      // Silencieux : la recherche serveur reste disponible.
    }
  }

  Set<int> get _preferredIds =>
      _preferredContacts.map((u) => u.alanyaID).toSet();

  String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Contacts préférés dont le numéro contient les chiffres tapés.
  List<User> get _matchedPreferred {
    final digits = _digitsOnly(_phoneNumber);
    if (digits.isEmpty) return [];
    return _preferredContacts
        .where((u) => _digitsOnly(u.alanyaPhone).contains(digits))
        .toList();
  }

  /// Résultats serveur en excluant ceux déjà présents dans les préférés.
  List<User> get _otherResults {
    final ids = _matchedPreferred.map((u) => u.alanyaID).toSet();
    return _serverResults.where((u) => !ids.contains(u.alanyaID)).toList();
  }

  // ── Saisie ───────────────────────────────────────────────────────────

  void _onKeyPress(String value) {
    if (_phoneNumber.length >= 15) return;
    setState(() {
      _phoneNumber += value;
      _foundUser = null;
    });
    _onQueryChanged();
  }

  void _onDelete() {
    if (_phoneNumber.isEmpty) return;
    setState(() {
      _phoneNumber = _phoneNumber.substring(0, _phoneNumber.length - 1);
      _foundUser = null;
    });
    _onQueryChanged();
  }

  void _clearAll() {
    setState(() {
      _phoneNumber = '';
      _foundUser = null;
      _serverResults = [];
    });
  }

  void _onQueryChanged() {
    final query = _phoneNumber.trim();
    _currentQuery = query;
    if (query.isEmpty) {
      setState(() => _serverResults = []);
      return;
    }
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_currentQuery == _phoneNumber.trim() && mounted) {
        _searchServer(query);
      }
    });
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
      _phoneNumber = user.alanyaPhone;
      _foundUser = user;
      _serverResults = [];
    });
  }

  // ── Appels ───────────────────────────────────────────────────────────

  Future<void> _searchUser() async {
    if (_phoneNumber.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final userData = await apiClient.getUserByPhone(_phoneNumber);
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
          const SnackBar(content: Text('Utilisateur introuvable')),
        );
      }
    }
  }

  void _showCallTypeSheet() {
    if (_foundUser == null && _phoneNumber.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entrez un numéro ou choisissez un contact'),
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
            Text('Lancer un appel', style: context.text.titleLarge),
            AppSpacing.vGapLg,
            Row(
              children: [
                Expanded(
                  child: _callOption(
                    sheetContext,
                    icon: CupertinoIcons.phone_fill,
                    label: 'Audio',
                    color: context.semantic.success,
                    isVideo: false,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: _callOption(
                    sheetContext,
                    icon: CupertinoIcons.videocam_fill,
                    label: 'Vidéo',
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

    final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
    final userData = await apiClient.getMe();
    final myId = userData['alanyaID'] ?? 0;

    final callService = Provider.of<CallService>(context, listen: false);
    await callService.initiateCall(
      targetUserId: _foundUser!.alanyaID,
      myId: myId,
      myName: userData['nom'] ?? userData['pseudo'] ?? '',
      myPhoto: userData['avatar_url'],
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
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const OngoingCallScreen(),
        ),
      );
    }
  }

  /// Ajoute le numéro tapé (ou le contact sélectionné) aux contacts préférés.
  Future<void> _addCurrentNumber() async {
    if (_addingContact) return;
    final phone = _phoneNumber.trim();
    if (_foundUser == null && phone.isEmpty) {
      _showSnack('Entrez un numéro à ajouter');
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
        _showSnack('Utilisateur introuvable');
        return;
      }
      if (_preferredIds.contains(user.alanyaID)) {
        _showSnack('Déjà dans vos contacts préférés');
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
        '${added.nom.isNotEmpty ? added.nom : added.pseudo} ajouté aux contacts préférés',
        success: true,
      );
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
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
        title: const Text('Clavier'),
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
    if (_phoneNumber.isEmpty) return const SizedBox.shrink();

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
          _sectionLabel('Contacts préférés'),
          ...preferred.map(_buildContactTile),
        ],
        if (others.isNotEmpty) ...[
          _sectionLabel('Autres résultats'),
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
      ),
      title: Text(
        user.nom.isNotEmpty ? user.nom : user.pseudo,
        style: context.text.titleSmall,
      ),
      subtitle: Text(
        '@${user.pseudo} • ${user.alanyaPhone}',
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
                        _phoneNumber,
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
              child: _phoneNumber.isEmpty
                  ? null
                  : GestureDetector(
                      onLongPress: _clearAll,
                      child: IconButton(
                        onPressed: _onDelete,
                        tooltip: 'Effacer',
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
