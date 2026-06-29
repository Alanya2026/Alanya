import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/alanya_phone_formatter.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/alanya_phone_field.dart';
import 'admin_create_user_screen.dart';

class AdminReservedPhonesScreen extends StatefulWidget {
  const AdminReservedPhonesScreen({super.key});

  @override
  State<AdminReservedPhonesScreen> createState() =>
      _AdminReservedPhonesScreenState();
}

class _AdminReservedPhonesScreenState extends State<AdminReservedPhonesScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  final _phoneCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await context.read<AdminProvider>().loadReservedPhones();
      if (mounted) setState(() => _items = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final canonical = AlanyaPhoneField.canonicalFrom(_phoneCtrl);
    final err = AlanyaPhoneFormatter.validate(canonical);
    if (err != null || _labelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Libellé requis')),
      );
      return;
    }
    await context.read<AdminProvider>().addReservedPhone(
          canonical,
          _labelCtrl.text.trim(),
        );
    _phoneCtrl.clear();
    _labelCtrl.clear();
    await _load();
  }

  Future<void> _remove(String phone) async {
    await context.read<AdminProvider>().removeReservedPhone(phone);
    await _load();
  }

  Future<void> _assign(String phone) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminCreateUserScreen(initialReservedPhone: phone),
      ),
    );
    if (created == true && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Numéros réservés')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.lg,
              ),
              children: [
                AlanyaPhoneField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Numéro'),
                ),
                AppSpacing.vGapMd,
                TextField(
                  controller: _labelCtrl,
                  decoration: const InputDecoration(labelText: 'Libellé'),
                ),
                AppSpacing.vGapMd,
                FilledButton(onPressed: _add, child: const Text('Ajouter')),
                AppSpacing.vGapXxl,
                ..._items.map((item) {
                  final phone = (item['phone_canonical'] ?? item['phoneCanonical'] ?? '') as String;
                  final label = (item['label'] ?? '') as String;
                  final isUsed =
                      item['is_used'] == true ||
                      item['isUsed'] == true ||
                      item['is_used'] == 1 ||
                      item['isUsed'] == 1;
                  final usedByNom = (item['used_by_nom'] ?? item['usedByNom']) as String?;
                  final usedByPseudo = (item['used_by_pseudo'] ?? item['usedByPseudo']) as String?;
                  final usedById = item['used_by_alanya_id'] ?? item['usedByAlanyaId'];
                  final ownerLabel = usedByNom?.trim().isNotEmpty == true
                      ? usedByNom!
                      : (usedByPseudo?.trim().isNotEmpty == true
                          ? usedByPseudo!
                          : (usedById != null ? 'Utilisateur #$usedById' : null));
                  final statusText = isUsed
                      ? (ownerLabel != null ? 'Utilisé · $ownerLabel' : 'Utilisé')
                      : 'Libre · non assigné';
                  return ListTile(
                    title: Text(AlanyaPhoneFormatter.formatDisplay(phone)),
                    subtitle: Text('$label\n$statusText'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isUsed)
                          TextButton(
                            onPressed: () => _assign(phone),
                            child: const Text('Attribuer'),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _remove(phone),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
