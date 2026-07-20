import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/countries_repository.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
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
  final _formKey = GlobalKey<FormState>();
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
        _countriesError = countries.isEmpty ? context.l10n.countryListUnavailable : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingCountries = false;
        _countriesError = context.l10n.unableToLoadCountryList;
      });
    }
  }

  bool get _canSubmit =>
      !_loadingCountries &&
      _countries.isNotEmpty &&
      _selectedCountry != null;

  Future<void> _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
        title: Text(context.l10n.yourSignInCredentials),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.saveTheseDetailsYouWillNeed,
              textAlign: TextAlign.center,
            ),
            AppSpacing.vGapXl,
            Text(
              context.l10n.alanyaPhone,
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
              context.l10n.signupPasswordHint,
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
            child: Text(context.l10n.gotIt),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xxxl),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.vGapXxl,
              const Center(child: AppLogo(size: 120)),
              AppSpacing.vGapXxl,
              Text(
                l10n?.signupTitle ?? context.l10n.signupTitle,
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              AppSpacing.vGapSm,
              Text(
                l10n?.signupSubtitle ?? context.l10n.signupSubtitle,
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxxl + 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, l10n: l10n),
                decoration: InputDecoration(
                  hintText: l10n?.signupNameHint ?? context.l10n.signupNameHint,
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              AppSpacing.vGapLg,
              TextFormField(
                controller: _pseudoController,
                validator: (v) => Validators.required(v, l10n: l10n),
                decoration: InputDecoration(
                  hintText: l10n?.signupPseudoHint ?? context.l10n.signupPseudoHint,
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              AppSpacing.vGapLg,
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                validator: (v) => Validators.email(v, l10n: l10n),
                decoration: InputDecoration(
                  hintText: l10n?.signupEmailHint ?? context.l10n.signupEmailHint,
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              AppSpacing.vGapLg,
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                validator: (v) => Validators.minLength(v, 6, l10n: l10n),
                decoration: InputDecoration(
                  hintText: l10n?.signupPasswordHint ?? context.l10n.signupPasswordHint,
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
                        child: Text(l10n?.retry ?? context.l10n.commonRetry),
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
                      : Text(
                          l10n?.signupSubmit ?? context.l10n.signupSubmit,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              AppSpacing.vGapXxl,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(l10n?.signupHasAccount ?? context.l10n.signupHasAccount),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      l10n?.signupLogin ?? context.l10n.signupLogin,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryField() {
    if (_loadingCountries) {
      return TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: context.l10n.loadingCountries,
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
      return TextField(
        enabled: false,
        decoration: InputDecoration(
          hintText: context.l10n.countryUnavailable,
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
