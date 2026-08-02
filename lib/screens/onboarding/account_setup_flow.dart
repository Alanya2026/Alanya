import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_settings_sync_service.dart';
import '../../core/services/biometric_lock_service.dart';
import '../../core/services/countries_repository.dart';
import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/locale_controller.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/utils/backend_url.dart';
import '../../core/utils/profile_bio.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../widgets/country_selector_tile.dart';
import '../home/home_screen.dart';

/// Parcours post-inscription : identifiants → profil (optionnel) → personnalisation.
class AccountSetupFlow extends StatefulWidget {
  const AccountSetupFlow({super.key});

  static const stepCount = 3;

  @override
  State<AccountSetupFlow> createState() => _AccountSetupFlowState();
}

class _AccountSetupFlowState extends State<AccountSetupFlow> {
  final _onboarding = OnboardingService();
  final _pageController = PageController();
  int _step = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _restoreStep();
  }

  Future<void> _restoreStep() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final saved = await _onboarding.getStepIndex(user.alanyaID);
    final normalized = OnboardingService.normalizeStepIndex(
      saved,
      stepCount: AccountSetupFlow.stepCount,
    );
    if (normalized > 0 && mounted) {
      setState(() => _step = normalized);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(normalized);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _persistStep(int index) async {
    final id = context.read<AuthProvider>().currentUser?.alanyaID;
    if (id != null) await _onboarding.setStepIndex(id, index);
  }

  Future<void> _goNext() async {
    if (_step >= AccountSetupFlow.stepCount - 1) {
      await _complete();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goBack() async {
    if (_step <= 0 || _finishing || !_pageController.hasClients) return;
    await _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    if (_step == index) return;
    setState(() => _step = index);
    _persistStep(index);
  }

  Future<void> _complete() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await _ensureDefaultBio();
    if (!mounted) return;
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      await _onboarding.markCompleted(user.alanyaID);
    }
    if (mounted) {
      context.read<AuthProvider>().clearPendingOnboardingAfterRegister();
    }
    OnboardingService.pendingSignupPassword = null;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _skipAll() async {
    if (_finishing) return;

    final l10n = context.l10n;
    final onCredentialsStep =
        _step == 0 && OnboardingService.pendingSignupPassword != null;

    if (onCredentialsStep) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.onboardingSkipAllTitle),
          content: Text(l10n.onboardingSkipAllCredentialsBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.onboardingSkipAll),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    await _complete();
  }

  Future<void> _ensureDefaultBio() async {
    if (!mounted) return;
    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || user.bio.trim().isNotEmpty) return;
    try {
      await auth.updateProfile(bio: l10n.profileBioDefault);
    } catch (_) {
      // L'accueil reste accessible même si la bio par défaut échoue.
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _step == 0) return;
        await _goBack();
      },
      child: Scaffold(
        backgroundColor: context.semantic.surfaceMuted,
        body: SafeArea(
          child: Column(
            children: [
              _OnboardingHeader(
                current: _step,
                total: AccountSetupFlow.stepCount,
                onBack: _step > 0 && !_finishing ? _goBack : null,
                onSkipAll: _finishing ? null : _skipAll,
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: _finishing
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: _onPageChanged,
                  children: [
                    _CredentialsStep(onContinue: _goNext),
                    _ProfileStep(onContinue: _goNext),
                    _PersonalizeStep(
                      onFinish: _complete,
                      loading: _finishing,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({
    required this.current,
    required this.total,
    this.onBack,
    this.onSkipAll,
  });

  final int current;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onSkipAll;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: l10n.back,
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              if (onSkipAll != null)
                TextButton(
                  onPressed: onSkipAll,
                  child: Text(l10n.onboardingSkipAll),
                ),
            ],
          ),
          Text(
            l10n.onboardingStepOf(current + 1, total),
            style: context.text.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              final active = i == current;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? context.colors.primary
                      : context.colors.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _OnboardingShell extends StatelessWidget {
  const _OnboardingShell({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.onContinue,
    this.continueLabel,
    this.continueLoading = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback onContinue;
  final String? continueLabel;
  final bool continueLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: AppSpacing.screenH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.text.headlineSmall),
              AppSpacing.vGapSm,
              Text(
                subtitle,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        AppSpacing.vGapLg,
        Expanded(
          child: SingleChildScrollView(
            padding: AppSpacing.screenH.copyWith(
              bottom: AppSpacing.xxxl + AppSpacing.lg,
            ),
            child: child,
          ),
        ),
        Padding(
          padding: AppSpacing.screenH,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton(
                onPressed: continueLoading ? null : onContinue,
                child: continueLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.onPrimary,
                        ),
                      )
                    : Text(continueLabel ?? l10n.onboardingContinue),
              ),
              AppSpacing.vGapMd,
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.text.labelLarge?.copyWith(
        color: context.colors.onSurface,
      ),
    );
  }
}

InputDecoration _prominentFieldDecoration(
  BuildContext context, {
  String? hintText,
  String? labelText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final colors = context.colors;
  final outline = OutlineInputBorder(
    borderRadius: AppRadius.brMd,
    borderSide: BorderSide(color: colors.outline),
  );
  return InputDecoration(
    hintText: hintText,
    labelText: labelText,
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: colors.surface,
    contentPadding: const EdgeInsets.all(AppSpacing.lg),
    border: outline,
    enabledBorder: outline,
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.brMd,
      borderSide: BorderSide(color: colors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: AppRadius.brMd,
      borderSide: BorderSide(color: colors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: AppRadius.brMd,
      borderSide: BorderSide(color: colors.error, width: 2),
    ),
    hintStyle: context.text.bodyLarge?.copyWith(
      color: colors.onSurfaceVariant.withValues(alpha: 0.7),
    ),
  );
}

class _CredentialsStep extends StatelessWidget {
  const _CredentialsStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().currentUser;
    final password = OnboardingService.pendingSignupPassword ?? '••••••••';

    return _OnboardingShell(
      title: l10n.onboardingCredentialsTitle,
      subtitle: l10n.onboardingCredentialsSubtitle,
      onContinue: onContinue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WarningBanner(message: l10n.onboardingCredentialsBanner),
          AppSpacing.vGapXl,
          Container(
            padding: AppSpacing.card,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: AppRadius.brMd,
              boxShadow: AppShadows.subtle,
            ),
            child: Column(
              children: [
                Text(
                  l10n.alanyaPhone,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapSm,
                AlanyaPhoneText(
                  user?.alanyaPhone ?? '',
                  textAlign: TextAlign.center,
                  style: context.text.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: context.colors.primary,
                  ),
                ),
                AppSpacing.vGapXxl,
                Text(
                  l10n.signupPasswordHint,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapSm,
                SelectableText(
                  password,
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pays, photo, bio et e-mail sur un seul écran scrollable.
class _ProfileStep extends StatefulWidget {
  const _ProfileStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<_ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<_ProfileStep> {
  final _picker = ImagePicker();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  List<Pays> _countries = const [];
  Pays? _selectedCountry;
  bool _countriesLoading = true;
  bool _otpSent = false;
  bool _busy = false;
  bool _photoUploading = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null && user.bio.isNotEmpty) {
      _bioController.text = user.bio;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final api = context.read<TalkyApiClient>();
      final repo = CountriesRepository(api: api);
      final countries = await repo.fetchCountries();
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser;
      Pays? selected;
      if (user != null && user.idPays > 0) {
        for (final c in countries) {
          if (c.idPays == user.idPays) {
            selected = c;
            break;
          }
        }
      }
      setState(() {
        _countries = countries;
        _selectedCountry =
            selected ?? (countries.isNotEmpty ? countries.first : null);
        _countriesLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _countriesLoading = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final auth = context.read<AuthProvider>();
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() => _photoUploading = true);
      await auth.updateAvatar(File(picked.path));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.onboardingPhotoFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _photoUploading = false);
    }
  }

  Future<void> _saveProfileFields() async {
    final auth = context.read<AuthProvider>();
    final defaultBio = context.l10n.profileBioDefault;
    final country = _selectedCountry;
    if (country != null) {
      await auth.updateCountry(country.idPays);
    }
    final bio = _bioController.text.trim();
    await auth.updateProfile(bio: ProfileBio.valueToSave(bio, defaultBio));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      final validationError =
          Validators.optionalEmail(email, l10n: context.l10n);
      if (validationError != null) {
        setState(() => _emailError = validationError);
        return;
      }
    }

    setState(() {
      _busy = true;
      _emailError = null;
    });

    try {
      final auth = context.read<AuthProvider>();

      if (email.isNotEmpty) {
        if (!_otpSent) {
          await auth.requestEmailChange(email);
          if (!mounted) return;
          setState(() => _otpSent = true);
          return;
        }
        await auth.confirmEmailChange(
          email: email,
          otp: _otpController.text.trim(),
        );
      }

      await _saveProfileFields();
      if (mounted) widget.onContinue();
    } catch (e) {
      if (mounted) setState(() => _emailError = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().currentUser;
    final avatarUrl = normalizeAvatarUrl(user?.avatarUrl);
    final initial = user?.nom.isNotEmpty == true
        ? user!.nom[0].toUpperCase()
        : 'U';

    return _OnboardingShell(
      title: l10n.onboardingProfileTitle,
      subtitle: l10n.onboardingProfileSubtitle,
      onContinue: _submit,
      continueLoading: _busy || _photoUploading,
      continueLabel: _otpSent ? l10n.onboardingEmailVerify : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(l10n.onboardingPhotoTitle),
          AppSpacing.vGapMd,
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: context.semantic.brandContainer,
                  backgroundImage:
                      avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl.isEmpty
                      ? Text(
                          initial,
                          style: context.text.headlineMedium?.copyWith(
                            color: context.colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                if (_photoUploading)
                  const SizedBox(
                    width: 96,
                    height: 96,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          AppSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _photoUploading || _busy
                      ? null
                      : () => _pickPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(l10n.onboardingPhotoChooseGallery),
                ),
              ),
              AppSpacing.hGapSm,
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _photoUploading || _busy
                      ? null
                      : () => _pickPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(l10n.onboardingPhotoCamera),
                ),
              ),
            ],
          ),
          AppSpacing.vGapXxl,
          const Divider(height: 1),
          AppSpacing.vGapXxl,
          _SectionLabel(l10n.country),
          AppSpacing.vGapSm,
          if (_countriesLoading)
            const Center(child: CircularProgressIndicator())
          else
            CountrySelectorTile(
              countries: _countries,
              selected: _selectedCountry,
              label: l10n.country,
              onChanged: (p) => setState(() => _selectedCountry = p),
              decoration: _prominentFieldDecoration(
                context,
                labelText: l10n.country,
                prefixIcon: const Icon(Icons.public_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
            ),
          AppSpacing.vGapXxl,
          const Divider(height: 1),
          AppSpacing.vGapXxl,
          _SectionLabel(l10n.onboardingBioTitle),
          AppSpacing.vGapSm,
          Text(
            l10n.onboardingBioSubtitle,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapMd,
          TextField(
            controller: _bioController,
            maxLength: 500,
            minLines: 3,
            maxLines: 5,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
            decoration: _prominentFieldDecoration(
              context,
              hintText: l10n.onboardingBioHint,
            ).copyWith(counterText: ''),
            style: context.text.bodyLarge,
          ),
          AppSpacing.vGapLg,
          const Divider(height: 1),
          AppSpacing.vGapXxl,
          _SectionLabel(l10n.onboardingEmailTitle),
          AppSpacing.vGapSm,
          if (!_otpSent)
            WarningBanner(
              variant: WarningBannerVariant.error,
              message: l10n.signupNoEmailWarningBody,
            ),
          AppSpacing.vGapMd,
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            enabled: !_otpSent && !_busy,
            style: context.text.bodyLarge,
            decoration: _prominentFieldDecoration(
              context,
              labelText: l10n.emailLabel,
              errorText: _emailError,
            ),
          ),
          if (_otpSent) ...[
            AppSpacing.vGapLg,
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              enabled: !_busy,
              style: context.text.bodyLarge,
              decoration: _prominentFieldDecoration(
                context,
                labelText: l10n.changeEmailOtpTitle,
              ),
            ),
          ],
          AppSpacing.vGapXxl,
        ],
      ),
    );
  }
}

/// Thème, langue, biométrie et CTA final sur un seul écran.
class _PersonalizeStep extends StatefulWidget {
  const _PersonalizeStep({
    required this.onFinish,
    required this.loading,
  });

  final VoidCallback onFinish;
  final bool loading;

  @override
  State<_PersonalizeStep> createState() => _PersonalizeStepState();
}

class _PersonalizeStepState extends State<_PersonalizeStep> {
  ThemeMode _theme = ThemeMode.system;
  AppLocalePreference _locale = AppLocalePreference.system;
  bool _saving = false;
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    _theme = context.read<ThemeController>().mode;
    _locale = context.read<LocaleController>().preference;
  }

  Future<void> _toggleBiometric(bool value) async {
    if (_bioBusy) return;
    setState(() => _bioBusy = true);
    try {
      final bio = context.read<BiometricLockService>();
      if (value) {
        await bio.setEnabled(
          true,
          confirmationReason: context.l10n.biometricLockEnableConfirm,
        );
      } else {
        await bio.setEnabled(false);
      }
    } catch (_) {
      // Matériel indisponible → skip silencieux.
    } finally {
      if (mounted) setState(() => _bioBusy = false);
    }
  }

  Future<void> _saveAndFinish() async {
    if (widget.loading || _saving) return;
    setState(() => _saving = true);
    try {
      final sync = context.read<AppSettingsSyncService>();
      final theme = context.read<ThemeController>();
      final locale = context.read<LocaleController>();
      await sync.patchAndSync(
        {
          'themeMode': sync.themeModeToString(_theme),
          'locale': sync.localeToString(_locale),
        },
        theme: theme,
        locale: locale,
      );
      if (mounted) widget.onFinish();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.onboardingSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bio = context.watch<BiometricLockService>();
    final available = bio.hasBiometricHardware;
    final busy = widget.loading || _saving;

    return _OnboardingShell(
      title: l10n.onboardingPersonalizeTitle,
      subtitle: l10n.onboardingPersonalizeSubtitle,
      onContinue: _saveAndFinish,
      continueLabel: l10n.onboardingCompleteCta,
      continueLoading: busy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.onboardingThemeLabel),
          AppSpacing.vGapSm,
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.settingsThemeLight),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.settingsThemeDark),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.settingsThemeSystem),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
            ],
            selected: {_theme},
            onSelectionChanged: busy
                ? null
                : (s) => setState(() => _theme = s.first),
          ),
          AppSpacing.vGapXxl,
          _SectionLabel(l10n.onboardingLanguageLabel),
          AppSpacing.vGapSm,
          SegmentedButton<AppLocalePreference>(
            segments: [
              ButtonSegment(
                value: AppLocalePreference.french,
                label: Text(l10n.settingsLangFr),
              ),
              ButtonSegment(
                value: AppLocalePreference.english,
                label: Text(l10n.settingsLangEn),
              ),
              ButtonSegment(
                value: AppLocalePreference.system,
                label: Text(l10n.settingsLangSystem),
              ),
            ],
            selected: {_locale},
            onSelectionChanged: busy
                ? null
                : (s) => setState(() => _locale = s.first),
          ),
          AppSpacing.vGapXxl,
          const Divider(height: 1),
          AppSpacing.vGapXxl,
          _SectionLabel(l10n.onboardingBiometricTitle),
          AppSpacing.vGapSm,
          if (available)
            _BiometricFriendlyTile(
              enabled: bio.isEnabled,
              busy: _bioBusy || busy,
              onToggle: _toggleBiometric,
            )
          else
            Text(
              l10n.onboardingBiometricUnavailable,
              style: context.text.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _BiometricFriendlyTile extends StatelessWidget {
  const _BiometricFriendlyTile({
    required this.enabled,
    required this.busy,
    required this.onToggle,
  });

  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.brMd,
        side: BorderSide(color: context.colors.outlineVariant),
      ),
      child: InkWell(
        onTap: busy ? null : () => onToggle(!enabled),
        borderRadius: AppRadius.brMd,
        child: Padding(
          padding: AppSpacing.card,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.semantic.brandContainer,
                  borderRadius: AppRadius.brSm,
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: AppIconSize.lg,
                  color: context.colors.primary,
                ),
              ),
              AppSpacing.hGapMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.onboardingBiometricFriendlyTitle,
                      style: context.text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AppSpacing.vGapXs,
                    Text(
                      l10n.onboardingBiometricFriendlyBody,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              AppSpacing.hGapSm,
              Switch(
                value: enabled,
                onChanged: busy ? null : onToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Garde post-auth : onboarding ou accueil.
class PostAuthGate extends StatefulWidget {
  const PostAuthGate({super.key});

  @override
  State<PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<PostAuthGate> {
  final _onboarding = OnboardingService();
  bool? _needsOnboarding;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _evaluate();
  }

  Future<void> _evaluate() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _needsOnboarding = false;
        _checking = false;
      });
      return;
    }
    final needs = await _onboarding.needsOnboarding(
      user,
      afterRegister: auth.pendingOnboardingAfterRegister,
    );
    if (auth.pendingOnboardingAfterRegister) {
      auth.clearPendingOnboardingAfterRegister();
    }
    if (!mounted) return;
    setState(() {
      _needsOnboarding = needs;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_needsOnboarding == true) {
      return const AccountSetupFlow();
    }
    return const HomeScreen();
  }
}
