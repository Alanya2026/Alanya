import 'package:flutter/material.dart';
import '../core/utils/country_flag.dart';
import '../talky_models.dart';
/// Feuille modale de s
lection de pays, avec recherche par nom ou pr
fixe.
/// Renvoie le [Pays] choisi via Navigator.pop.
class CountryPickerSheet extends StatefulWidget {
  const CountryPickerSheet({super.key, required this.countries, this.selectedId});
  final List<Pays> countries;
  final int? selectedId;
  /// Ouvre la feuille et renvoie le pays s
lectionn
 (ou null si annul
  static Future<Pays?> show(
    BuildContext context, {
    required List<Pays> countries,
    int? selectedId,
  }) {
    return showModalBottomSheet<Pays>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CountryPickerSheet(countries: countries, selectedId: selectedId),
    );
  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
class _CountryPickerSheetState extends State<CountryPickerSheet> {
  String _query = '';
  List<Pays> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.countries;
    return widget.countries
        .where((p) =>
            p.libelle.toLowerCase().contains(q) || p.prefix.toLowerCase().contains(q))
        .toList();
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un pays
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(
                        child: Text('Aucun pays trouv
                            style: TextStyle(color: Colors.black45)))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final p = _filtered[i];
                          final flag = CountryFlags.flagFor(p);
                          final selected = p.idPays == widget.selectedId;
                          return ListTile(
                            leading: Text(
                              flag.isNotEmpty ? flag : '
                              style: const TextStyle(fontSize: 26),
                            ),
                            title: Text(p.libelle),
                            subtitle: p.prefix.isNotEmpty ? Text('+${p.prefix}') : null,
                            trailing: selected
                                ? const Icon(Icons.check_circle, color: Colors.indigo)
                                : null,
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );