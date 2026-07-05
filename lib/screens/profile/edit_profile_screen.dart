import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/services/countries_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/country_selector_tile.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  User? _user;
  bool _isLoading = true;
  bool _uploadingAvatar = false;

  final _nameController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _picker = ImagePicker();
  bool _saving = false;
  List<Pays> _countries = const [];
  Pays? _selectedCountry;
  bool _loadingCountries = true;
  bool _savingCountry = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromAuth();
    unawaited(context.read<AuthProvider>().refreshProfile().then((_) {
      if (!mounted) return;
      _hydrateFromAuth();
      if (_user == null) setState(() => _isLoading = false);
    }));
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final api = context.read<TalkyApiClient>();
      final repo = CountriesRepository(api: api);
      final countries = await repo.fetchCountries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _loadingCountries = false;
        _syncSelectedCountry();
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  void _syncSelectedCountry() {
    final user = _user;
    if (user == null || _countries.isEmpty) return;
    final repo = CountriesRepository(api: context.read<TalkyApiClient>());
    _selectedCountry = repo.findById(user.idPays, countries: _countries);
  }

  Future<void> _changeCountry(Pays country) async {
    if (_user?.idPays == country.idPays) return;
    setState(() => _savingCountry = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AuthProvider>().updateCountry(country.idPays);
      if (!mounted) return;
      setState(() {
        _selectedCountry = country;
        _user = context.read<AuthProvider>().currentUser;
        _savingCountry = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingCountry = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('Impossible de mettre à jour le pays')),
      );
    }
  }

  void _hydrateFromAuth() {
    final cached = context.read<AuthProvider>().currentUser;
    if (cached == null) return;
    setState(() {
      _user = cached;
      _nameController.text = cached.nom;
      _pseudoController.text = cached.pseudo;
      _isLoading = false;
      _syncSelectedCountry();
    });
  }

  // ── Photo de profil ─────────────────────────────────────────────────

  Future<void> _openAvatarSheet() async {
    if (_uploadingAvatar) return;
    final hasPhoto = _user?.avatarUrl.isNotEmpty == true;

    final choice = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSpacing.vGapSm,
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            AppSpacing.vGapLg,
            ListTile(
              leading: Icon(Icons.photo_camera_outlined,
                  color: context.colors.primary),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, _AvatarAction.camera),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined,
                  color: context.colors.primary),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, _AvatarAction.gallery),
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: context.colors.error),
                title: Text(
                  'Supprimer la photo',
                  style: TextStyle(color: context.colors.error),
                ),
                onTap: () => Navigator.pop(context, _AvatarAction.remove),
              ),
            AppSpacing.vGapSm,
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case _AvatarAction.camera:
        await _pickAndUpload(ImageSource.camera);
        break;
      case _AvatarAction.gallery:
        await _pickAndUpload(ImageSource.gallery);
        break;
      case _AvatarAction.remove:
        await _removeAvatar();
        break;
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      setState(() => _uploadingAvatar = true);

      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.updateAvatar(File(picked.path));
      if (!mounted) return;

      setState(() {
        _user = auth.currentUser ?? _user;
        _uploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'upload : $e')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            const RoundedRectangleBorder(borderRadius: AppRadius.brMd),
        title: const Text('Supprimer la photo ?'),
        content: const Text('Votre photo de profil sera retirée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.removeAvatar();
      if (!mounted) return;
      setState(() {
        _user = auth.currentUser ?? _user;
        _uploadingAvatar = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo supprimée')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec : $e')),
      );
    }
  }

  // ── Sauvegarde ──────────────────────────────────────────────────────

  Future<void> _save() async {
    final nom = _nameController.text.trim();
    final pseudo = _pseudoController.text.trim();

    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom ne peut pas être vide')),
      );
      return;
    }

    final nomChanged = nom != (_user?.nom ?? '');
    final pseudoChanged = pseudo != (_user?.pseudo ?? '');
    if (!nomChanged && !pseudoChanged) {
      Navigator.pop(context);
      return;
    }

    setState(() => _saving = true);
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      await auth.updateProfile(
        nom: nomChanged ? nom : null,
        pseudo: pseudoChanged ? pseudo : null,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'enregistrement : $e')),
      );
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Modifier le profil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.colors.primary),
                  )
                : Text(
                    'Enregistrer',
                    style: TextStyle(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
          ),
          AppSpacing.hGapSm,
        ],
      ),
      body: _isLoading
          ? const LoadingState()
          : SingleChildScrollView(
              padding: AppSpacing.card,
              child: Column(
                children: [
                  Center(child: _buildAvatar()),
                  const SizedBox(height: AppSpacing.xxxl + 8),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Nom',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    controller: _nameController,
                  ),
                  AppSpacing.vGapXxl,
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Pseudo',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    controller: _pseudoController,
                  ),
                  AppSpacing.vGapXxl,
                  TextField(
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone (Téléphone Alanya)',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    controller: TextEditingController(
                        text: AlanyaPhoneFormatter.formatDisplay(
                            _user?.alanyaPhone ?? '')),
                  ),
                  AppSpacing.vGapXxl,
                  if (_loadingCountries)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (_countries.isNotEmpty)
                    CountrySelectorTile(
                      countries: _countries,
                      selected: _selectedCountry,
                      enabled: !_savingCountry,
                      onChanged: _changeCountry,
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _openAvatarSheet,
      child: Stack(
        children: [
          AppAvatar(
            imageUrl: _user?.avatarUrl,
            name: _user?.nom.isNotEmpty == true ? _user!.nom : 'U',
            size: 120,
          ),
          if (_uploadingAvatar)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.surface, width: 3),
              ),
              child: const Icon(Icons.camera_alt, color: AppColors.white,
                  size: AppIconSize.sm),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pseudoController.dispose();
    super.dispose();
  }
}

enum _AvatarAction { camera, gallery, remove }
