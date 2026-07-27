import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_logo.dart';
import '../home/home_screen.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _alanyaPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final canonical = AlanyaPhoneField.canonicalFrom(_alanyaPhoneController);
    await authProvider.login(
      alanyaPhone: canonical,
      password: _passwordController.text,
    );

    if (authProvider.isLoggedIn && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _alanyaPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
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
                  l10n?.loginWelcome ?? context.l10n.loginWelcome,
                  textAlign: TextAlign.center,
                  style: context.text.headlineLarge,
                ),
                AppSpacing.vGapSm,
                Text(
                  l10n?.loginSubtitle ?? context.l10n.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodyLarge
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.xxxl + 16),
                AlanyaPhoneField(
                  controller: _alanyaPhoneController,
                  validator: (v) => Validators.alanyaPhone(v, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: '00 00 00 00',
                    labelText: context.l10n.alanyaPhone,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (v) => Validators.minLength(v, 1, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: l10n?.loginPasswordHint ?? context.l10n.signupPasswordHint,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ForgotPasswordScreen()),
                    ),
                    child: Text(l10n?.loginForgotPassword ?? context.l10n.loginForgotPassword),
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
                            style:
                                TextStyle(color: context.colors.error),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                AppSpacing.vGapXxl,
                Consumer<AuthProvider>(
                  builder: (context, auth, _) => ElevatedButton(
                    onPressed: auth.isLoading ? null : _login,
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
                            l10n?.loginSubmit ?? context.l10n.signupLogin,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                AppSpacing.vGapXxl,
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(l10n?.loginNoAccount ?? context.l10n.donTHaveAnAccount),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignupScreen()),
                      ),
                      child: Text(
                        l10n?.loginSignUp ?? context.l10n.signupSubmit,
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
