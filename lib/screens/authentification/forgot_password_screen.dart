import 'package:flutter/material.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../talky_api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _step = 'email'; // 'email', 'otp', 'password'
  bool _isLoading = false;
  String? _error;
  String? _resetToken;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TalkyApiClient _apiClient = TalkyApiClient();

  void _clearError() => setState(() => _error = null);

  Future<void> _requestOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();
    setState(() => _isLoading = true);
    try {
      await _apiClient.requestPasswordReset(_emailController.text.trim());
      setState(() {
        _step = 'otp';
        _isLoading = false;
      });
    } on TalkyException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = context.l10n.errorColon('$e');
        _isLoading = false;
      });
    }
  }

  Future<void> _validateOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();
    setState(() => _isLoading = true);
    try {
      final response = await _apiClient.validateOTP(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      setState(() {
        _resetToken = response['resetToken'];
        _step = 'password';
        _isLoading = false;
      });
    } on TalkyException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = context.l10n.errorColon('$e');
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();
    setState(() => _isLoading = true);
    try {
      await _apiClient.completePasswordReset(
        _resetToken!,
        _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.passwordResetSuccessfully)),
        );
        Navigator.pop(context);
      }
    } on TalkyException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = context.l10n.errorColon('$e');
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n?.forgotPasswordTitle ?? context.l10n.forgotPasswordTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Étape 1: Email
              if (_step == 'email') ...[
                AppSpacing.vGapXxl,
                Text(
                  l10n?.forgotEmailTitle ?? context.l10n.forgotEmailTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  l10n?.forgotEmailSubtitle ??
                      context.l10n.forgotEmailSubtitle,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => Validators.email(v, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: l10n?.forgotEmailHint ?? context.l10n.forgotEmailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
              ],

              // Étape 2: OTP
              if (_step == 'otp') ...[
                AppSpacing.vGapXxl,
                Text(
                  l10n?.forgotOtpTitle ?? context.l10n.forgotOtpTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  l10n?.forgotOtpSubtitle(_emailController.text) ??
                      context.l10n.forgotOtpSubtitle(_emailController.text),
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, letterSpacing: 4),
                  validator: (v) => Validators.otp6(v, l10n: l10n),
                  decoration: const InputDecoration(hintText: '000000'),
                ),
                AppSpacing.vGapLg,
                TextButton(
                  onPressed: _requestOTP,
                  child: Text(l10n?.forgotResendCode ?? context.l10n.forgotResendCode),
                ),
              ],

              // Étape 3: Nouveau mot de passe
              if (_step == 'password') ...[
                AppSpacing.vGapXxl,
                Text(
                  l10n?.forgotNewPasswordTitle ?? context.l10n.forgotNewPasswordHint,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  l10n?.forgotNewPasswordSubtitle ??
                      context.l10n.forgotNewPasswordSubtitle,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: (v) => Validators.minLength(v, 6, l10n: l10n),
                  decoration: InputDecoration(
                    hintText: l10n?.forgotNewPasswordHint ??
                        context.l10n.forgotNewPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                AppSpacing.vGapLg,
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  validator: (v) => Validators.passwordMatch(
                    v,
                    _passwordController.text,
                    l10n: l10n,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n?.forgotConfirmPasswordHint ??
                        context.l10n.forgotConfirmPasswordHint,
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(() =>
                          _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                ),
              ],

              // Erreur
              if (_error != null) ...[
                AppSpacing.vGapLg,
                Container(
                  padding: AppSpacing.card,
                  decoration: BoxDecoration(
                    color: AppColors.errorContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              AppSpacing.vGapXxl,
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_step == 'email'
                        ? _requestOTP
                        : _step == 'otp'
                            ? _validateOTP
                            : _resetPassword),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                  shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        _step == 'email'
                            ? context.l10n.sendCode
                            : _step == 'otp'
                                ? context.l10n.verifyCode
                                : context.l10n.resetPassword,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
