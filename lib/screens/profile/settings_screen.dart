import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/countries_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_controller.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/common/common.dart';
import '../../widgets/country_selector_tile.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;
  bool _isLoading = true;
  List<Pays> _countries = const [];
  Pays? _selectedCountry;
  bool _loadingCountries = true;
  bool _savingCountry = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
    final repo = CountriesRepository(
      api: context.read<TalkyApiClient>(),
    );
    _selectedCountry = repo.findById(user.idPays, countries: _countries);
  }

  Future<void> _loadUserData() async {
    final cached =
        Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (cached != null && mounted) {
      setState(() {
        _user = cached;
        _isLoading = false;
      });
    }

    try {
      final apiClient = Provider.of<TalkyApiClient>(context, listen: false);
      final data = await apiClient.getMe();
      if (!mounted) return;
      setState(() {
        _user = User.fromJson(data);
        _isLoading = false;
        _syncSelectedCountry();
      });
    } catch (_) {
      if (mounted && _user == null) setState(() => _isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          AppSpacing.vGapLg,
          // User Info Section
          Container(
            color: context.colors.surface,
            padding: AppSpacing.card,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(
                            imageUrl: _user?.avatarUrl,
                            name: _user?.nom ?? 'U',
                            size: AppSizes.avatarSm,
                          ),
                          AppSpacing.hGapLg,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _user?.nom ?? 'User',
                                  style: context.text.titleLarge,
                                ),
                                AppSpacing.vGapXs,
                                Text(
                                  '@${_user?.pseudo ?? 'pseudo'}',
                                  style: context.text.bodyMedium?.copyWith(
                                      color: context.colors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.vGapLg,
                      Container(
                        padding: AppSpacing.card,
                        decoration: BoxDecoration(
                          color: context.semantic.surfaceMuted,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.phone,
                                color: context.colors.primary,
                                size: AppIconSize.sm),
                            AppSpacing.hGapMd,
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Téléphone Alanya',
                                  style: context.text.labelSmall?.copyWith(
                                      color: context.colors.onSurfaceVariant),
                                ),
                                Text(
                                  _user?.alanyaPhone ?? 'Non défini',
                                  style: context.text.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AppSpacing.vGapMd,
                      if (_loadingCountries)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (_countries.isNotEmpty)
                        CountrySelectorTile(
                          countries: _countries,
                          selected: _selectedCountry,
                          style: CountrySelectorStyle.settingsRow,
                          enabled: !_savingCountry,
                          onChanged: _changeCountry,
                        ),
                    ],
                  ),
          ),
          AppSpacing.vGapXxl,
          _buildThemeGroup(),
          AppSpacing.vGapXxl,
          _buildSettingsGroup(
            title: 'Général',
            items: [
              _buildSettingsItem(Icons.chat, 'Discussions',
                  'Thème, fonds d\'écran, historique des discussions'),
              _buildSettingsItem(Icons.notifications, 'Notifications',
                  'Sonneries de message, groupe et appel'),
              _buildSettingsItem(Icons.data_usage, 'Stockage et données',
                  'Utilisation du réseau, téléchargement auto'),
            ],
          ),
          AppSpacing.vGapXxl,
          _buildSettingsGroup(
            title: 'Compte',
            items: [
              _buildSettingsItem(Icons.security, 'Sécurité',
                  'Vérification en deux étapes'),
              _buildSettingsItem(Icons.lock, 'Confidentialité',
                  'Bloquer les contacts, messages éphémères'),
              _buildSettingsItem(Icons.delete_outline, 'Supprimer le compte',
                  '',
                  isDestructive: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          child: Text(
            'Apparence',
            style: context.text.labelMedium?.copyWith(
                color: context.colors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          color: context.colors.surface,
          padding: AppSpacing.card,
          child: Consumer<ThemeController>(
            builder: (_, tc, __) => SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, AppSizes.buttonHeight),
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.wb_sunny_outlined),
                  label: Text('Clair'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.nights_stay_outlined),
                  label: Text('Sombre'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Système'),
                ),
              ],
              selected: {tc.mode},
              onSelectionChanged: (s) => tc.setMode(s.first),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(
      {required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
          child: Text(
            title,
            style: context.text.labelMedium
                ?.copyWith(color: context.colors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          color: context.colors.surface,
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, String subtitle,
      {bool isDestructive = false}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
      leading: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDestructive ? AppColors.errorContainer : context.semantic.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? context.colors.error
              : context.colors.onSurfaceVariant,
          size: AppIconSize.md,
        ),
      ),
      title: Text(
        title,
        style: context.text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: isDestructive ? context.colors.error : context.colors.onSurface,
        ),
      ),
      subtitle: subtitle.isNotEmpty
          ? Text(
              subtitle,
              style: context.text.bodySmall
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            )
          : null,
      onTap: () {},
    );
  }
}
