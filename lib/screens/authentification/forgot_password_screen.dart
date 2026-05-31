import 'package:flutter/material.dart';
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
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _validateOTP() async {
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
        _error = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    _clearError();
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(
          () => _error = 'Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _apiClient.completePasswordReset(
        _resetToken!,
        _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Mot de passe réinitialisé avec succès')),
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
        _error = 'Erreur: $e';
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Récupération du mot de passe'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxl, vertical: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Étape 1: Email
              if (_step == 'email') ...[
                AppSpacing.vGapXxl,
                Text(
                  'Entrez votre email',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  'Un code OTP sera envoyé à votre email',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'E-mail',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
              ],

              // Étape 2: OTP
              if (_step == 'otp') ...[
                AppSpacing.vGapXxl,
                Text(
                  'Vérification du code',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  'Entrez le code 6 chiffres envoyé à ${_emailController.text}',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, letterSpacing: 4),
                  decoration: const InputDecoration(hintText: '000000'),
                ),
                AppSpacing.vGapLg,
                TextButton(
                  onPressed: _requestOTP,
                  child: const Text('Renvoyer le code'),
                ),
              ],

              // Étape 3: Nouveau mot de passe
              if (_step == 'password') ...[
                AppSpacing.vGapXxl,
                Text(
                  'Nouveau mot de passe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                AppSpacing.vGapSm,
                Text(
                  'Entrez votre nouveau mot de passe',
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                AppSpacing.vGapXxl,
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Nouveau mot de passe',
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
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    hintText: 'Confirmer le mot de passe',
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
                            ? 'Envoyer le code'
                            : _step == 'otp'
                                ? 'Vérifier le code'
                                : 'Réinitialiser le mot de passe',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
