import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../l10n/app_localizations.dart';
import '../../talky_api_client.dart';
import '../../widgets/account/warning_banner.dart';
import '../../widgets/alanya_phone_field.dart';

/// Deux voies vers un nouveau mot de passe, qui convergent sur le même écran
/// final :
///   - par e-mail : OTP à 6 chiffres (parcours historique) ;
///   - par code de récupération : ID Alanya + code noté à l'inscription, pour
///     les comptes créés sans adresse e-mail — qui n'avaient jusqu'ici aucune
///     voie de retour.
///
/// Les deux produisent le même `resetToken` côté serveur, si bien que la
/// dernière étape est rigoureusement partagée : un seul chemin de changement de
/// mot de passe, donc une seule occasion d'oublier une garde.
enum _ForgotStep { choice, email, otp, code, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();
  final _recoveryCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotStep _step = _ForgotStep.choice;
  bool _isLoading = false;
  String? _error;
  String? _resetToken;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final TalkyApiClient _apiClient = TalkyApiClient();

  void _clearError() => setState(() => _error = null);

  void _goTo(_ForgotStep step) {
    setState(() {
      _step = step;
      _error = null;
    });
  }

  /// Enveloppe commune : le corps ne se soucie plus ni du spinner, ni du
  /// mapping d'erreur, qui étaient recopiés à l'identique dans chaque étape.
  Future<void> _run(Future<void> Function() action) async {
    _clearError();
    setState(() => _isLoading = true);
    try {
      await action();
    } on TalkyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = context.l10n.errorColon('$e'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      await _apiClient.requestPasswordReset(_emailController.text.trim());
      if (mounted) setState(() => _step = _ForgotStep.otp);
    });
  }

  Future<void> _validateOTP() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final response = await _apiClient.validateOTP(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = response['resetToken'];
        _step = _ForgotStep.password;
      });
    });
  }

  Future<void> _validateRecoveryCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      final response = await _apiClient.validateRecoveryCode(
        alanyaPhone: AlanyaPhoneField.canonicalFrom(_phoneController),
        recoveryCode: _recoveryCodeController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = response['resetToken'];
        _step = _ForgotStep.password;
      });
    });
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _run(() async {
      await _apiClient.completePasswordReset(
        _resetToken!,
        _passwordController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.passwordResetSuccessfully)),
      );
      Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _phoneController.dispose();
    _recoveryCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Le bouton du bas n'existe pas à l'étape « choice » : ce sont les deux
  /// tuiles qui font office d'action.
  ({VoidCallback action, String label})? get _primaryAction {
    final l10n = context.l10n;
    return switch (_step) {
      _ForgotStep.choice => null,
      _ForgotStep.email => (action: _requestOTP, label: l10n.sendCode),
      _ForgotStep.otp => (action: _validateOTP, label: l10n.verifyCode),
      _ForgotStep.code => (
          action: _validateRecoveryCode,
          label: l10n.forgotCodeSubmit
        ),
      _ForgotStep.password => (
          action: _resetPassword,
          label: l10n.resetPassword
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primary = _primaryAction;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Revenir au choix plutôt que quitter l'écran : se tromper de voie ne
          // doit pas obliger à tout reprendre depuis la connexion.
          onPressed: _step == _ForgotStep.choice
              ? () => Navigator.pop(context)
              : () => _goTo(_ForgotStep.choice),
        ),
        title: Text(l10n?.forgotPasswordTitle ?? context.l10n.forgotPasswordTitle),
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
                AppSpacing.vGapXxl,
                ..._buildStep(context, l10n),
                if (_error != null) ...[
                  AppSpacing.vGapLg,
                  WarningBanner(
                    variant: WarningBannerVariant.error,
                    message: _error!,
                  ),
                ],
                if (primary != null) ...[
                  AppSpacing.vGapXxl,
                  ElevatedButton(
                    onPressed: _isLoading ? null : primary.action,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.brMd,
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.colors.onPrimary,
                            ),
                          )
                        : Text(
                            primary.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep(BuildContext context, AppLocalizations? l10n) {
    final t = context.l10n;
    return switch (_step) {
      _ForgotStep.choice => [
          _Heading(
            title: l10n?.forgotMethodTitle ?? t.forgotMethodTitle,
            subtitle: l10n?.forgotMethodSubtitle ?? t.forgotMethodSubtitle,
          ),
          AppSpacing.vGapXxl,
          _MethodTile(
            icon: Icons.email_outlined,
            title: l10n?.forgotMethodEmail ?? t.forgotMethodEmail,
            subtitle:
                l10n?.forgotMethodEmailSubtitle ?? t.forgotMethodEmailSubtitle,
            onTap: () => _goTo(_ForgotStep.email),
          ),
          AppSpacing.vGapMd,
          _MethodTile(
            icon: Icons.vpn_key_outlined,
            title: l10n?.forgotMethodCode ?? t.forgotMethodCode,
            subtitle:
                l10n?.forgotMethodCodeSubtitle ?? t.forgotMethodCodeSubtitle,
            onTap: () => _goTo(_ForgotStep.code),
          ),
        ],
      _ForgotStep.email => [
          _Heading(
            title: l10n?.forgotEmailTitle ?? t.forgotEmailTitle,
            subtitle: l10n?.forgotEmailSubtitle ?? t.forgotEmailSubtitle,
          ),
          AppSpacing.vGapXxl,
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => Validators.email(v, l10n: l10n),
            decoration: InputDecoration(
              hintText: l10n?.forgotEmailHint ?? t.forgotEmailHint,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
          ),
        ],
      _ForgotStep.otp => [
          _Heading(
            title: l10n?.forgotOtpTitle ?? t.forgotOtpTitle,
            subtitle: t.forgotOtpSubtitle(_emailController.text),
          ),
          AppSpacing.vGapXxl,
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, letterSpacing: 4),
            validator: (v) => Validators.otp6(v, l10n: l10n),
            decoration: const InputDecoration(
              hintText: '000000',
              counterText: '',
            ),
          ),
          AppSpacing.vGapLg,
          TextButton(
            onPressed: _isLoading ? null : _requestOTP,
            child: Text(l10n?.forgotResendCode ?? t.forgotResendCode),
          ),
        ],
      _ForgotStep.code => [
          _Heading(
            title: l10n?.forgotCodeTitle ?? t.forgotCodeTitle,
            subtitle: l10n?.forgotCodeSubtitle ?? t.forgotCodeSubtitle,
          ),
          AppSpacing.vGapXxl,
          AlanyaPhoneField(
            controller: _phoneController,
            validator: (v) => Validators.alanyaPhone(v, l10n: l10n),
            decoration: InputDecoration(
              labelText: l10n?.alanyaPhone ?? t.alanyaPhone,
              hintText: '00 00 00 00',
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          AppSpacing.vGapLg,
          TextFormField(
            controller: _recoveryCodeController,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            // Le serveur normalise (majuscules, tirets ignorés) ; on aide juste
            // la saisie à ressembler à ce qui a été noté.
            inputFormatters: [UpperCaseTextFormatter()],
            validator: (v) => Validators.recoveryCode(v, l10n: l10n),
            style: const TextStyle(fontSize: 20, letterSpacing: 2),
            decoration: InputDecoration(
              labelText: l10n?.recoveryCodeTitle ?? t.recoveryCodeTitle,
              hintText: l10n?.forgotCodeHint ?? t.forgotCodeHint,
              prefixIcon: const Icon(Icons.vpn_key_outlined),
            ),
          ),
        ],
      _ForgotStep.password => [
          _Heading(
            title: l10n?.forgotNewPasswordTitle ?? t.forgotNewPasswordHint,
            subtitle:
                l10n?.forgotNewPasswordSubtitle ?? t.forgotNewPasswordSubtitle,
          ),
          AppSpacing.vGapXxl,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            validator: (v) => Validators.minLength(v, 6, l10n: l10n),
            decoration: InputDecoration(
              hintText: l10n?.forgotNewPasswordHint ?? t.forgotNewPasswordHint,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
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
              hintText:
                  l10n?.forgotConfirmPasswordHint ?? t.forgotConfirmPasswordHint,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
          ),
        ],
    };
  }
}

/// Force la saisie en majuscules — un code noté à la main l'est presque
/// toujours, et le voir se transformer à l'écran confirme qu'il est bien lu.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.brMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.brMd,
        child: Ink(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: AppRadius.brMd,
            boxShadow: AppShadows.subtle,
          ),
          child: Padding(
            padding: AppSpacing.card,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.semantic.brandContainer,
                    borderRadius: AppRadius.brSm,
                  ),
                  child: Icon(
                    icon,
                    size: AppIconSize.md,
                    color: context.colors.primary,
                  ),
                ),
                AppSpacing.hGapMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      AppSpacing.vGapXs,
                      Text(
                        subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.colors.outlineVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
