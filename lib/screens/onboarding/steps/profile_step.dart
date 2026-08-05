import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/countries_repository.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/backend_url.dart';
import '../../../core/utils/profile_bio.dart';
import '../../../core/utils/profile_identity.dart';
import '../../../widgets/profile/profile_identity_fields.dart';
import '../../../providers/auth_provider.dart';
import '../../../talky_api_client.dart';
import '../../../talky_models.dart';
import '../../../widgets/account/warning_banner.dart';
import '../../../widgets/common/app_bottom_sheet.dart';
import '../../../widgets/country_selector_tile.dart';
import '../widgets/onboarding_shell.dart';

/// Étape 2 : photo, genre, âge, pays, bio — tout facultatif, un seul écran.
///
/// L'e-mail a quitté cette étape pour la page d'inscription : il conditionne
/// l'affichage du code de récupération à l'étape précédente, il ne pouvait donc
/// plus être demandé après. Ajouter ou changer une adresse reste possible dans
/// Mon compte → Sécurité, avec sa vérification par OTP.
class ProfileStep extends StatefulWidget {
  const ProfileStep({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  State<ProfileStep> createState() => _ProfileStepState();
}

class _ProfileStepState extends State<ProfileStep> {
  final _picker = ImagePicker();
  final _bioController = TextEditingController();
  final _ageController = TextEditingController();

  List<Pays> _countries = const [];
  Pays? _selectedCountry;
  bool _countriesLoading = true;
  bool _busy = false;
  bool _photoUploading = false;
  ProfileGender? _genre;
  String? _ageError;
  String? _saveError;

  /// Verrouillés dès qu'ils ont une valeur côté serveur : le backend refuse une
  /// seconde écriture (409), autant ne pas laisser croire que c'est modifiable.
  bool _genreLocked = false;
  bool _ageLocked = false;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    final user = context.read<AuthProvider>().currentUser;
    if (user != null) {
      if (user.bio.isNotEmpty) _bioController.text = user.bio;
      _genre = ProfileGenderApi.fromApi(user.genre);
      _genreLocked = user.genre != null;
      if (user.age != null) _ageController.text = '${user.age}';
      _ageLocked = user.age != null;
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _ageController.dispose();
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

  /// Galerie ou appareil photo, via une feuille : la photo se choisit en
  /// touchant l'avatar, ce qui évite deux boutons permanents pour une action
  /// que la plupart des gens ne feront qu'une fois.
  Future<void> _choisirSource() async {
    if (_photoUploading || _busy) return;
    final l10n = context.l10n;
    final source = await showAppBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => AppBottomSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: Text(l10n.onboardingPhotoChooseGallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.onboardingPhotoCamera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickPhoto(source);
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

  int? get _ageSaisi {
    final brut = _ageController.text.trim();
    if (brut.isEmpty) return null;
    return int.tryParse(brut);
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final age = _ageSaisi;

    // L'âge est facultatif, mais s'il est saisi il doit être plausible : le
    // serveur refuse hors bornes, autant le dire avant l'aller-retour.
    if (_ageController.text.trim().isNotEmpty &&
        (age == null || age < kAgeMin || age > kAgeMax)) {
      setState(() => _ageError = l10n.profileAgeInvalid(kAgeMin, kAgeMax));
      return;
    }

    setState(() {
      _busy = true;
      _ageError = null;
      _saveError = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      // Un seul aller-retour pour pays + bio + genre + âge : trois appels
      // successifs laissaient le profil à moitié enregistré si l'un échouait.
      await auth.updateProfile(
        bio: ProfileBio.valueToSave(
          _bioController.text.trim(),
          l10n.profileBioDefault,
        ),
        idPays: _selectedCountry?.idPays,
        genre: _genreLocked ? null : _genre?.apiValue,
        age: _ageLocked ? null : age,
      );
      if (mounted) widget.onContinue();
    } catch (e) {
      if (mounted) setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthProvider>().currentUser;
    final avatarUrl = normalizeAvatarUrl(user?.avatarUrl);
    final initial =
        user?.nom.isNotEmpty == true ? user!.nom[0].toUpperCase() : 'U';

    return OnboardingShell(
      title: l10n.onboardingProfileTitle,
      subtitle: l10n.onboardingProfileSubtitle,
      onContinue: _submit,
      continueLoading: _busy || _photoUploading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _AvatarPicker(
              avatarUrl: avatarUrl,
              initial: initial,
              uploading: _photoUploading,
              onTap: _choisirSource,
            ),
          ),
          AppSpacing.vGapMd,
          Text(
            l10n.onboardingPhotoAdd,
            textAlign: TextAlign.center,
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          AppSpacing.vGapXxl,

          ProfileIdentityFields(
            genre: _genre,
            genreLocked: _genreLocked,
            onGenreSelected: (g) => setState(() => _genre = g),
            ageController: _ageController,
            ageLocked: _ageLocked,
            ageError: _ageError,
            enabled: !_busy,
            onAgeChanged: () => setState(() => _ageError = null),
          ),
          AppSpacing.vGapXxl,

          OnboardingSectionLabel(l10n.country),
          AppSpacing.vGapMd,
          if (_countriesLoading)
            const Center(child: CircularProgressIndicator())
          else
            CountrySelectorTile(
              countries: _countries,
              selected: _selectedCountry,
              label: l10n.country,
              enabled: !_busy,
              onChanged: (p) => setState(() => _selectedCountry = p),
            ),
          AppSpacing.vGapXxl,

          OnboardingSectionLabel(l10n.onboardingBioTitle),
          AppSpacing.vGapXs,
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
            style: context.text.bodyLarge,
            decoration: InputDecoration(
              hintText: l10n.onboardingBioHint,
              counterText: '',
            ),
          ),
          if (_saveError != null) ...[
            AppSpacing.vGapLg,
            WarningBanner(
              variant: WarningBannerVariant.error,
              message: _saveError!,
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.avatarUrl,
    required this.initial,
    required this.uploading,
    required this.onTap,
  });

  final String avatarUrl;
  final String initial;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: uploading ? null : onTap,
      customBorder: const CircleBorder(),
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
          if (uploading)
            const SizedBox(
              width: 96,
              height: 96,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          // Pastille appareil photo, reprise du header de l'écran Profil.
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: context.colors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: context.colors.surface, width: 2),
              ),
              child: Icon(
                Icons.camera_alt_outlined,
                size: AppIconSize.sm,
                color: context.colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
