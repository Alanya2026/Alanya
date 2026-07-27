import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';

/// Wizard guidé en 2 étapes : nouvelle adresse → code OTP.
class ChangeEmailScreen extends StatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  State<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends State<ChangeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailFocus = FocusNode();
  final _otpFocus = FocusNode();

  /// `email` | `otp`
  String _step = 'email';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error != null) setState(() => _error = null);
  }

  void _goBackToEmail() {
    setState(() {
      _step = 'email';
      _otpController.clear();
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocus.requestFocus();
    });
  }

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
        _otpController.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
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
    final currentEmail =
        context.watch<AuthProvider>().currentUser?.email.trim() ?? '';
    final hasEmail = currentEmail.isNotEmpty;
    final isOtp = _step == 'otp';

    return Scaffold(
      backgroundColor: context.semantic.surfaceMuted,
      appBar: AppBar(
        backgroundColor: context.semantic.surfaceMuted,
        title: Text(
          hasEmail ? l10n.changeEmailTitle : l10n.changeEmailAddLabel,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (isOtp) {
              _goBackToEmail();
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StepHeader(
                        step1Label: l10n.changeEmailStep1,
                        step2Label: l10n.changeEmailStep2,
                        activeStep: isOtp ? 2 : 1,
                      ),
                      AppSpacing.vGapXxl,
                      if (!isOtp) ...[
                        _CurrentEmailCard(
                          hasEmail: hasEmail,
                          currentEmail: currentEmail,
                          notSetLabel: l10n.emailNotSet,
                          currentLabel: l10n.changeEmailCurrentLabel,
                        ),
                        AppSpacing.vGapLg,
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hasEmail
                                    ? l10n.changeEmailNewLabel
                                    : l10n.changeEmailAddLabel,
                                style: context.text.titleSmall,
                              ),
                              AppSpacing.vGapSm,
                              Text(
                                hasEmail
                                    ? l10n.changeEmailSubtitleReplace
                                    : l10n.changeEmailSubtitleAdd,
                                style: context.text.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                              AppSpacing.vGapLg,
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocus,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _sendCode(),
                                validator: (v) =>
                                    Validators.email(v, l10n: l10n),
                                decoration: InputDecoration(
                                  hintText: 'exemple@email.com',
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  filled: true,
                                  fillColor:
                                      context.semantic.surfaceMuted,
                                ),
                              ),
                              AppSpacing.vGapLg,
                              WarningBanner(
                                variant: WarningBannerVariant.info,
                                icon: Icons.mark_email_unread_outlined,
                                message: l10n.changeEmailWhyOtp,
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                        AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: context.semantic.brandContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.mark_email_read_outlined,
                                      color: context.colors.primary,
                                      size: AppIconSize.md,
                                    ),
                                  ),
                                  AppSpacing.hGapMd,
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.changeEmailOtpTitle,
                                          style: context.text.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        AppSpacing.vGapXs,
                                        Text(
                                          _emailController.text.trim(),
                                          style: context.text.bodyMedium
                                              ?.copyWith(
                                            color: context.colors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.vGapMd,
                              Text(
                                l10n.changeEmailCheckInbox,
                                style: context.text.bodySmall?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                              AppSpacing.vGapXl,
                              TextFormField(
                                controller: _otpController,
                                focusNode: _otpFocus,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                textAlign: TextAlign.center,
                                style: context.text.headlineMedium?.copyWith(
                                  letterSpacing: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                validator: (v) =>
                                    Validators.otp6(v, l10n: l10n),
                                onChanged: (v) {
                                  _clearError();
                                  if (v.trim().length == 6 && !_loading) {
                                    _confirm();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: '• • • • • •',
                                  counterText: '',
                                  filled: true,
                                  fillColor: context.semantic.surfaceMuted,
                                ),
                              ),
                              AppSpacing.vGapMd,
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: _loading ? null : _goBackToEmail,
                                    icon: const Icon(Icons.edit_outlined,
                                        size: AppIconSize.sm),
                                    label: Text(l10n.changeEmailEditAddress),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: _loading ? null : _sendCode,
                                    child: Text(l10n.changeEmailResendCode),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_error != null) ...[
                        AppSpacing.vGapLg,
                        WarningBanner(
                          message: _error!,
                          icon: Icons.error_outline,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // CTA collé en bas pour le rendre toujours visible
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: ElevatedButton(
                    onPressed: _loading
                        ? null
                        : (isOtp ? _confirm : _sendCode),
                    style: ElevatedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.buttonHeight),
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
                            isOtp
                                ? l10n.changeEmailConfirm
                                : l10n.changeEmailSendCode,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Cartes & étapes ─────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: isDark
            ? context.colors.surfaceContainerHigh
            : context.colors.surface,
        borderRadius: AppRadius.brMd,
        boxShadow: isDark ? null : AppShadows.subtle,
        border: isDark
            ? Border.all(
                color: context.colors.outline.withValues(alpha: 0.55))
            : null,
      ),
      child: child,
    );
  }
}

class _StepHeader extends StatelessWidget {
  final String step1Label;
  final String step2Label;
  final int activeStep;

  const _StepHeader({
    required this.step1Label,
    required this.step2Label,
    required this.activeStep,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepChip(
            label: step1Label,
            active: activeStep == 1,
            done: activeStep > 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Icon(
            Icons.arrow_forward,
            size: AppIconSize.sm,
            color: context.colors.outlineVariant,
          ),
        ),
        Expanded(
          child: _StepChip(
            label: step2Label,
            active: activeStep == 2,
            done: false,
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final bool active;
  final bool done;

  const _StepChip({
    required this.label,
    required this.active,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active || done
        ? context.semantic.brandContainer
        : context.colors.surface;
    final fg = active || done
        ? context.colors.primary
        : context.colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.brSm,
        border: Border.all(
          color: active
              ? context.colors.primary.withValues(alpha: 0.45)
              : context.colors.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (done) ...[
            Icon(Icons.check_circle, size: AppIconSize.sm, color: fg),
            AppSpacing.hGapXs,
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.text.labelMedium?.copyWith(
                color: fg,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentEmailCard extends StatelessWidget {
  final bool hasEmail;
  final String currentEmail;
  final String notSetLabel;
  final String currentLabel;

  const _CurrentEmailCard({
    required this.hasEmail,
    required this.currentEmail,
    required this.notSetLabel,
    required this.currentLabel,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: hasEmail
                  ? context.semantic.brandContainer
                  : context.colors.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasEmail
                  ? Icons.email_outlined
                  : Icons.warning_amber_rounded,
              color: hasEmail
                  ? context.colors.primary
                  : context.colors.error,
              size: AppIconSize.md,
            ),
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentLabel,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
                AppSpacing.vGapXs,
                Text(
                  hasEmail ? currentEmail : notSetLabel,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasEmail
                        ? context.colors.onSurface
                        : context.colors.onSurfaceVariant,
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
