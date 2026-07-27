import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';

/// Wizard 2 étapes : nouvel email → OTP.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  String _step = 'email';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _clearError() => setState(() => _error = null);

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();
    setState(() => _loading = true);
    try {
      await context
          .read<AuthProvider>()
          .requestEmailChange(_emailController.text.trim());
      if (!mounted) return;
      setState(() {
        _step = 'otp';
        _loading = false;
      });
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.errorColon('$e');
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();
    setState(() => _loading = true);
    try {
      await context.read<AuthProvider>().confirmEmailChange(
            email: _emailController.text.trim(),
            otp: _otpController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.changeEmailSuccess)),
      );
      Navigator.pop(context, true);
    } on TalkyException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = context.l10n.errorColon('$e');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasEmail =
        (context.watch<AuthProvider>().currentUser?.email.trim().isNotEmpty ??
            false);

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(l10n.changeEmailTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xxl,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: _step == 'email' ? 0.5 : 1,
                  borderRadius: AppRadius.brSm,
                ),
                AppSpacing.vGapXxl,
                if (_step == 'email') ...[
                  Text(
                    hasEmail
                        ? l10n.changeEmailSubtitleReplace
                        : l10n.changeEmailSubtitleAdd,
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.vGapXxl,
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: (v) => Validators.email(v, l10n: l10n),
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: context.colors.surface,
                    ),
                  ),
                ] else ...[
                  Text(
                    l10n.changeEmailOtpTitle,
                    style: context.text.headlineSmall,
                  ),
                  AppSpacing.vGapSm,
                  Text(
                    l10n.changeEmailOtpSubtitle(_emailController.text.trim()),
                    style: context.text.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.vGapXxl,
                  TextFormField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 32, letterSpacing: 4),
                    validator: (v) => Validators.otp6(v, l10n: l10n),
                    decoration: InputDecoration(
                      hintText: '000000',
                      filled: true,
                      fillColor: context.colors.surface,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _sendCode,
                    child: Text(l10n.changeEmailResendCode),
                  ),
                ],
                if (_error != null) ...[
                  AppSpacing.vGapLg,
                  Container(
                    padding: AppSpacing.card,
                    decoration: BoxDecoration(
                      color: context.colors.errorContainer,
                      borderRadius: AppRadius.brSm,
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(color: context.colors.onErrorContainer),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                AppSpacing.vGapXxl,
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : (_step == 'email' ? _sendCode : _confirm),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.brMd,
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.colors.onPrimary,
                          ),
                        )
                      : Text(
                          _step == 'email'
                              ? l10n.changeEmailSendCode
                              : l10n.changeEmailConfirm,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
