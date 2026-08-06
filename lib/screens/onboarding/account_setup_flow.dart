import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/onboarding_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';
import 'steps/credentials_step.dart';
import 'steps/personalize_step.dart';
import 'steps/profile_step.dart';
import 'widgets/onboarding_shell.dart';
import '../../core/services/welcome_delivery_service.dart';

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
    // Les deux secrets ne vivaient en mémoire que pour l'écran identifiants.
    OnboardingService.pendingSignupPassword = null;
    OnboardingService.pendingRecoveryCode = null;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(WelcomeDeliveryService.deliverAndOpenChat(context));
    });
  }

  Future<void> _skipAll() async {
    if (_finishing) return;

    final l10n = context.l10n;
    final auth = context.read<AuthProvider>();
    final sansEmail = auth.currentUser?.email.trim().isEmpty ?? true;
    final surIdentifiants =
        _step == 0 && OnboardingService.pendingSignupPassword != null;
    // Un code de récupération encore à l'écran change la nature de l'avertissement :
    // ce n'est plus « vous ne reverrez pas ce mot de passe » mais « vous partez
    // sans la seule clé de secours d'un compte sans e-mail ».
    final codeAffiche =
        sansEmail && OnboardingService.pendingRecoveryCode != null;

    if (surIdentifiants) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.onboardingSkipAllTitle),
          content: Text(
            codeAffiche
                ? l10n.onboardingSkipAllRecoveryBody
                : l10n.onboardingSkipAllCredentialsBody,
          ),
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
              OnboardingHeader(
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
                    CredentialsStep(onContinue: _goNext),
                    ProfileStep(onContinue: _goNext),
                    PersonalizeStep(
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
