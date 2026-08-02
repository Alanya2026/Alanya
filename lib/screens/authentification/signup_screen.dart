import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';

/// Inscription minimale : nom, pseudo, mot de passe — le reste via onboarding.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pseudoController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _pseudoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final password = _passwordController.text;
    OnboardingService.pendingSignupPassword = password;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.register(
      password: password,
      nom: _nameController.text.trim(),
      pseudo: _pseudoController.text.trim(),
    );

    if (!mounted) return;
    if (!authProvider.isLoggedIn) {
      final msg = authProvider.error ??
          context.l10n.anErrorOccurred('register');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    _passwordController.clear();
    // AuthWrapper bascule sur PostAuthGate : retirer SignupScreen de la pile.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxxl,
          ),
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
                  style: context.text.bodyLarge?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl + 16),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) => Validators.required(v, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: l10n?.signupNameHint ?? context.l10n.signupNameHint,
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _pseudoController,
                  validator: (v) => Validators.required(v, l10n: l10n),
                  decoration: InputDecoration(
                    hintText:
                        l10n?.signupPseudoHint ?? context.l10n.signupPseudoHint,
                    prefixIcon: const Icon(Icons.alternate_email),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (v) => Validators.minLength(v, 6, l10n: l10n),
                  decoration: InputDecoration(
                    hintText:
                        l10n?.signupPasswordHint ?? context.l10n.signupPasswordHint,
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
                AppSpacing.vGapXxl,
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: auth.isLoading ? null : _signup,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd,
                      ),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
}
