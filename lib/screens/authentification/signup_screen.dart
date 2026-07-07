import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/countries_repository.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/country_selector_tile.dart';
import '../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  List<Pays> _countries = const [];
  Pays? _selectedCountry;
  bool _loadingCountries = true;
  String? _countriesError;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pseudoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countriesError = null;
    });
    try {
      final api = context.read<TalkyApiClient>();
      final repo = CountriesRepository(api: api);
      final countries = await repo.fetchCountries(force: _countries.isEmpty);
      if (!mounted) return;
      setState(() {
        _countries = countries;
        _loadingCountries = false;
        _countriesError = countries.isEmpty ? 'Liste des pays indisponible' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCountries = false;
        _countriesError = 'Impossible de charger la liste des pays';
      });
    }
  }

  bool get _canSubmit =>
      !_loadingCountries &&
      _countries.isNotEmpty &&
      _selectedCountry != null &&
      _nameController.text.trim().isNotEmpty &&
      _pseudoController.text.trim().isNotEmpty &&
      _emailController.text.trim().isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _signup() async {
    final country = _selectedCountry;
    if (country == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nom: _nameController.text.trim(),
      pseudo: _pseudoController.text.trim(),
      idPays: country.idPays,
    );

    if (!mounted || !authProvider.isLoggedIn) return;

    final alanyaPhone = authProvider.currentUser?.alanyaPhone ?? '';
    final password = _passwordController.text;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Vos identifiants de connexion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Notez ces informations — elles vous serviront à vous connecter :',
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapXl,
            Text(
              'Téléphone Alanya',
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapSm,
            AlanyaPhoneText(
              alanyaPhone,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: AppColors.brandPrimary,
              ),
            ),
            AppSpacing.vGapXl,
            Text(
              'Mot de passe',
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            AppSpacing.vGapSm,
            Text(
              password,
              textAlign: TextAlign.center,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('J\'ai noté'),
          ),
        ],
      ),
    );

    _passwordController.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.vGapXxl,
              const Center(child: AppLogo(size: 120)),
              AppSpacing.vGapXxl,
              Text(
                'Créer un compte',
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              AppSpacing.vGapSm,
              Text(
                'Rejoignez la communauté Alanya',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxxl + 16),
              TextField(
                controller: _nameController,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _pseudoController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Pseudo',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _emailController,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  hintText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _passwordController,
                onChanged: (_) => setState(() {}),
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              AppSpacing.vGapLg,
              _buildCountryField(),
              AppSpacing.vGapSm,
              Consumer<AuthProvider>(
                builder: (context, auth, _) => auth.error != null
                    ? Container(
                        padding: AppSpacing.card,
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: AppRadius.brSm,
                        ),
                        child: Text(
                          auth.error!,
                          style: TextStyle(color: context.colors.error),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              if (_countriesError != null) ...[
                AppSpacing.vGapSm,
                Container(
                  padding: AppSpacing.card,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _countriesError!,
                        style: TextStyle(color: context.colors.error),
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: _loadCountries,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ],
              AppSpacing.vGapXxl,
              Consumer<AuthProvider>(
                builder: (context, auth, _) => ElevatedButton(
                  onPressed: auth.isLoading || !_canSubmit ? null : _signup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd),
                    elevation: 0,
                  ),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'S\'inscrire',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              AppSpacing.vGapXxl,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Déjà un compte ?'),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Se connecter',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryField() {
    if (_loadingCountries) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: 'Chargement des pays…',
          prefixIcon: Icon(Icons.public_outlined),
          suffixIcon: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_countriesError != null) {
      return const TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: 'Pays indisponible',
          prefixIcon: Icon(Icons.public_outlined),
        ),
      );
    }

    return CountrySelectorTile(
      countries: _countries,
      selected: _selectedCountry,
      onChanged: (p) => setState(() => _selectedCountry = p),
    );
  }
}
