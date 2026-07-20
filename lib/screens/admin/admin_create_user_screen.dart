import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/countries_repository.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../providers/admin_provider.dart';
import '../../providers/auth_provider.dart';
import '../../talky_api_client.dart';
import '../../talky_models.dart';
import '../../widgets/alanya_phone_field.dart';
import '../../widgets/common/app_skeleton.dart';
import '../../widgets/country_selector_tile.dart';
import '../../core/theme/app_theme.dart';

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({super.key, this.initialReservedPhone});

  /// Numéro réservé pré-sélectionné (ex. depuis la liste des réservés).
  final String? initialReservedPhone;

  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  final _nomCtrl = TextEditingController();
  final _pseudoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _reservedSearchCtrl = TextEditingController();

  List<Pays> _countries = const [];
  List<Map<String, dynamic>> _reservedPhones = const [];
  Map<String, dynamic>? _patternSuggestion;
  Map<String, dynamic>? _manualPhoneCheck;
  bool _loadingManualCheck = false;
  Timer? _manualCheckDebounce;
  Pays? _selectedCountry;
  String? _selectedReservedPhone;
  bool _loadingCountries = true;
  bool _loadingReserved = false;
  bool _manualPhone = false;
  String _avatarGender = 'male';
  int _typeCompte = 0;
  bool _saving = false;
  Timer? _reservedSearchDebounce;

  bool get _isSuper =>
      AdminProvider.isSuperAdmin(context.read<AuthProvider>().currentUser);

  bool get _isAdmin =>
      AdminProvider.isAdmin(context.read<AuthProvider>().currentUser);

  List<Map<String, dynamic>> get _availableReservedPhones => _reservedPhones;

  @override
  void initState() {
    super.initState();
    _selectedReservedPhone = widget.initialReservedPhone;
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final api = context.read<TalkyApiClient>();
      final repo = CountriesRepository(api: api);
      final countries = await repo.fetchCountries();
      if (!mounted) return;
      final defaultCountry = repo.findById(10, countries: countries) ??
          (countries.isNotEmpty ? countries.first : null);
      setState(() {
        _countries = countries;
        _selectedCountry = defaultCountry;
        _loadingCountries = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  Future<void> _loadReservedPhones({String? q}) async {
    if (!AdminProvider.isAdmin(
        Provider.of<AuthProvider>(context, listen: false).currentUser)) {
      return;
    }
    setState(() => _loadingReserved = true);
    try {
      final result = await context.read<AdminProvider>().loadReservedPhones(
            page: 1,
            limit: 20,
            q: q,
            available: '1',
          );
      if (!mounted) return;
      setState(() {
        _reservedPhones = result.items;
        _patternSuggestion = result.patternSuggestion;
      });
    } on TalkyException catch (e) {
      if (!mounted) return;
      _show(e.message);
    } catch (_) {
      // Liste optionnelle — ignorée si indisponible.
    } finally {
      if (mounted) setState(() => _loadingReserved = false);
    }
  }

  void _onReservedSearchChanged(String value) {
    _reservedSearchDebounce?.cancel();
    _reservedSearchDebounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (q.isEmpty) {
        if (mounted) {
          setState(() {
            _reservedPhones = const [];
            _patternSuggestion = null;
          });
        }
        return;
      }
      _loadReservedPhones(q: q);
    });
  }

  void _onManualPhoneChanged(String value) {
    _manualCheckDebounce?.cancel();
    _manualCheckDebounce = Timer(const Duration(milliseconds: 300), () {
      final canonical = AlanyaPhoneFormatter.normalize(value);
      if (!AlanyaPhoneFormatter.isCompletePhone(canonical)) {
        if (mounted) {
          setState(() {
            _manualPhoneCheck = null;
            _loadingManualCheck = false;
          });
        }
        return;
      }
      _checkManualPhone(canonical);
    });
  }

  Future<void> _checkManualPhone(String canonical) async {
    setState(() => _loadingManualCheck = true);
    try {
      final result =
          await context.read<AdminProvider>().checkAssignablePhone(canonical);
      if (!mounted) return;
      setState(() => _manualPhoneCheck = result);
    } catch (_) {
      if (mounted) setState(() => _manualPhoneCheck = null);
    } finally {
      if (mounted) setState(() => _loadingManualCheck = false);
    }
  }

  String? _patternSuggestionCanonical() {
    final raw = _patternSuggestion?['phone_canonical'] ??
        _patternSuggestion?['phoneCanonical'];
    return raw is String && raw.isNotEmpty ? raw : null;
  }

  bool _patternSuggestionAssignable() {
    if (_patternSuggestion == null) return false;
    if (_patternSuggestion!['assignable'] == false) return false;
    if (_patternSuggestion!['is_used'] == true) return false;
    return true;
  }

  String _patternSuggestionLabel() {
    final label = _patternSuggestion?['label'];
    return label is String && label.isNotEmpty
        ? label
        : context.l10n.reservedPatternDirectAssignment;
  }

  String _reservedLabel(Map<String, dynamic> item) {
    final phone = (item['phone_canonical'] ?? item['phoneCanonical'] ?? '') as String;
    final label = (item['label'] ?? '') as String;
    return '${AlanyaPhoneFormatter.formatDisplay(phone)} — $label';
  }

  String _reservedCanonical(Map<String, dynamic> item) {
    return (item['phone_canonical'] ?? item['phoneCanonical'] ?? '') as String;
  }

  @override
  void dispose() {
    _reservedSearchDebounce?.cancel();
    _manualCheckDebounce?.cancel();
    _nomCtrl.dispose();
    _pseudoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _reservedSearchCtrl.dispose();
    super.dispose();
  }

  String _randomPassword() {
    const chars = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> _submit() async {
    if (_nomCtrl.text.trim().isEmpty ||
        _pseudoCtrl.text.trim().isEmpty ||
        _passwordCtrl.text.isEmpty) {
      _show(context.l10n.nameUsernamePasswordRequired);
      return;
    }
    final country = _selectedCountry;
    if (country == null) {
      _show(context.l10n.selectACountry);
      return;
    }

    final body = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'pseudo': _pseudoCtrl.text.trim(),
      'password': _passwordCtrl.text,
      'idPays': country.idPays,
      'avatarGender': _avatarGender,
    };
    if (_emailCtrl.text.trim().isNotEmpty) {
      body['email'] = _emailCtrl.text.trim().toLowerCase();
    }
    if (_selectedReservedPhone != null && _selectedReservedPhone!.isNotEmpty) {
      body['alanyaPhone'] = _selectedReservedPhone;
    } else if (_manualPhone) {
      final canonical = AlanyaPhoneField.canonicalFrom(_phoneCtrl);
      final err = AlanyaPhoneFormatter.validate(canonical);
      if (err != null) {
        _show(err);
        return;
      }
      if (_manualPhoneCheck != null && _manualPhoneCheck!['assignable'] == false) {
        final reason = _manualPhoneCheck!['reason'];
        _show(reason is String && reason.isNotEmpty
            ? reason
            : context.l10n.thisNumberCannotBeAssigned);
        return;
      }
      body['alanyaPhone'] = canonical;
    }
    if (_isSuper) body['type_compte'] = _typeCompte;

    setState(() => _saving = true);
    try {
      await context.read<AdminProvider>().createUser(body);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _show('$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final reservedSelected =
        _selectedReservedPhone != null && _selectedReservedPhone!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.createUser)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        children: [
          TextField(
            controller: _nomCtrl,
            decoration: InputDecoration(labelText: context.l10n.name),
          ),
          AppSpacing.vGapMd,
          TextField(
            controller: _pseudoCtrl,
            decoration: InputDecoration(labelText: context.l10n.username),
          ),
          AppSpacing.vGapMd,
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: context.l10n.email,
              hintText: context.l10n.requiredExceptTier3,
            ),
          ),
          AppSpacing.vGapMd,
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passwordCtrl,
                  decoration: InputDecoration(labelText: context.l10n.password),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _passwordCtrl.text = _randomPassword()),
                icon: const Icon(Icons.refresh),
                tooltip: context.l10n.generate,
              ),
            ],
          ),
          AppSpacing.vGapLg,
          if (_isAdmin) ...[
            if (_selectedReservedPhone != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.reservedNumber),
                subtitle: Text(
                  AlanyaPhoneFormatter.formatDisplay(_selectedReservedPhone!),
                ),
                trailing: TextButton(
                  onPressed: () => setState(() => _selectedReservedPhone = null),
                  child: Text(context.l10n.clearAction),
                ),
              ),
            ] else ...[
              Text(
context.l10n.reservedPhoneSearchHelp,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              AppSpacing.vGapSm,
              TextField(
                controller: _reservedSearchCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.assignAReservedNumberOptional,
                  hintText: context.l10n.eG112233441234OrLabel,
                ),
                onChanged: _onReservedSearchChanged,
              ),
              if (_loadingReserved)
                const ReservedPhoneSearchSkeleton(count: 4)
              else ...[
                if (_patternSuggestionCanonical() != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: _patternSuggestionAssignable(),
                    title: Text(
                      '${AlanyaPhoneFormatter.formatDisplay(_patternSuggestionCanonical()!)} — ${_patternSuggestionLabel()}',
                      style: TextStyle(
                        color: _patternSuggestionAssignable()
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface
                                .withValues(alpha: 0.5),
                      ),
                    ),
                    subtitle: _patternSuggestionAssignable()
                        ? null
                        : Text(context.l10n.alreadyUsed),
                    onTap: _patternSuggestionAssignable()
                        ? () {
                            setState(() {
                              _selectedReservedPhone =
                                  _patternSuggestionCanonical();
                              _reservedPhones = const [];
                              _patternSuggestion = null;
                              _reservedSearchCtrl.clear();
                            });
                          }
                        : null,
                  ),
                ..._availableReservedPhones.map((item) {
                  final canonical = _reservedCanonical(item);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_reservedLabel(item)),
                    onTap: () {
                      setState(() {
                        _selectedReservedPhone = canonical;
                        _reservedPhones = const [];
                        _patternSuggestion = null;
                        _reservedSearchCtrl.clear();
                      });
                    },
                  );
                }),
              ],
              if (!_loadingReserved &&
                  _reservedSearchCtrl.text.trim().isNotEmpty &&
                  _availableReservedPhones.isEmpty &&
                  _patternSuggestionCanonical() == null)
                Text(
                  AlanyaPhoneFormatter.isAssignableQuery(
                          _reservedSearchCtrl.text)
                      ? context.l10n.noFreeNumberFoundInThe
                      : '${context.l10n.noResultsEnterAFullPattern}(${context.l10n.n34DigitsOrXxyyzztt})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
            ],
            AppSpacing.vGapMd,
          ],
          Opacity(
            opacity: reservedSelected ? 0.5 : 1,
            child: IgnorePointer(
              ignoring: reservedSelected,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.manualNumberEntry),
                    value: _manualPhone,
                    onChanged: (v) => setState(() => _manualPhone = v),
                  ),
                  if (_manualPhone) ...[
                    AlanyaPhoneField(
                      controller: _phoneCtrl,
                      onChanged: _onManualPhoneChanged,
                    ),
                    if (_loadingManualCheck &&
                        AlanyaPhoneFormatter.isCompletePhone(
                            AlanyaPhoneFormatter.normalize(_phoneCtrl.text)))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.l10n.verifying,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      )
                    else if (_manualPhoneCheck != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _manualPhoneCheck!['assignable'] == true
                              ? ((_manualPhoneCheck!['hint'] as String?) ??
                                  context.l10n.numberAvailable)
                              : ((_manualPhoneCheck!['reason'] as String?) ??
                                  context.l10n.numberUnavailable),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _manualPhoneCheck!['assignable'] == true
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        context.l10n.freeEntryReservedPatternsOrStandard,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  ] else
                    Text(
                      context.l10n.n8DigitsAutoGeneratedExcludingReserved,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ),
          if (reservedSelected) ...[
            AppSpacing.vGapSm,
            Text(
              context.l10n.numberAssigned(AlanyaPhoneFormatter.formatDisplay(_selectedReservedPhone!)),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          AppSpacing.vGapMd,
          if (_loadingCountries)
            const LinearProgressIndicator()
          else if (_countries.isEmpty)
            Text(context.l10n.countryListUnavailable)
          else
            CountrySelectorTile(
              countries: _countries,
              selected: _selectedCountry,
              onChanged: (p) => setState(() => _selectedCountry = p),
            ),
          AppSpacing.vGapMd,
          DropdownButtonFormField<String>(
            value: _avatarGender,
            decoration: InputDecoration(labelText: context.l10n.avatarLabel),
            items: [
              DropdownMenuItem(value: 'male', child: Text(context.l10n.genderMale)),
              DropdownMenuItem(value: 'female', child: Text(context.l10n.genderFemale)),
            ],
            onChanged: (v) => setState(() => _avatarGender = v ?? 'male'),
          ),
          if (_isSuper) ...[
            AppSpacing.vGapMd,
            DropdownButtonFormField<int>(
              value: _typeCompte,
              decoration: InputDecoration(labelText: context.l10n.role),
              items: [
                DropdownMenuItem(value: 0, child: Text(context.l10n.userFallback)),
                DropdownMenuItem(value: 1, child: Text(context.l10n.admin)),
                DropdownMenuItem(value: 2, child: Text(context.l10n.superAdmin)),
              ],
              onChanged: (v) => setState(() => _typeCompte = v ?? 0),
            ),
          ],
          AppSpacing.vGapXxl,
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.create),
          ),
        ],
      ),
    );
  }
}
