import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
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

  void _signup() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      nom: _nameController.text.trim(),
      pseudo: _pseudoController.text.trim(),
    );

    if (authProvider.isLoggedIn && mounted) {
      final alanyaPhone = authProvider.currentUser?.alanyaPhone ?? '';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Votre identifiant Alanya'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Notez ce numéro — il vous servira à vous connecter :',
                textAlign: TextAlign.center,
              ),
              AppSpacing.vGapXl,
              Text(
                alanyaPhone,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: AppColors.brandPrimary,
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
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSpacing.vGapLg,
              Text(
                'Créer un compte',
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              AppSpacing.vGapSm,
              Text(
                'Rejoignez la communauté Alanya !',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge
                    ?.copyWith(color: context.colors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xxxl + 16),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Nom complet',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _pseudoController,
                decoration: const InputDecoration(
                  hintText: 'Pseudo',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'Adresse e-mail',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              AppSpacing.vGapLg,
              TextField(
                controller: _passwordController,
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
              AppSpacing.vGapXxl,
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
              AppSpacing.vGapLg,
              Consumer<AuthProvider>(
                builder: (context, auth, _) => ElevatedButton(
                  onPressed: auth.isLoading ? null : _signup,
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
                          'Inscription',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              AppSpacing.vGapXxl,
            ],
          ),
        ),
      ),
    );
  }
}
