import 'package:flutter/material.dart';

/// Construit l'emoji drapeau à partir du libellé du pays (table `pays`).
String countryFlagEmoji(String country) {
  const iso = {
    'france': 'FR',
    'united states': 'US',
    'united kingdom': 'GB',
    'germany': 'DE',
    'spain': 'ES',
    'italy': 'IT',
    'belgium': 'BE',
    'switzerland': 'CH',
    'canada': 'CA',
    'cameroun': 'CM',
    'congo': 'CD',
    'gabon': 'GA',
    "côte d'ivoire": 'CI',
    'senegal': 'SN',
    'mali': 'ML',
    'burkina faso': 'BF',
    'niger': 'NE',
    'chad': 'TD',
    'central african republic': 'CF',
    'equatorial guinea': 'GQ',
    'china': 'CN',
    'japan': 'JP',
    'india': 'IN',
    'brazil': 'BR',
    'argentina': 'AR',
    'mexico': 'MX',
    'australia': 'AU',
    'russia': 'RU',
    'south africa': 'ZA',
    'nigeria': 'NG',
  };
  final code = iso[country.toLowerCase().trim()];
  if (code == null || code.length != 2) return '🌍';
  const base = 0x1F1E6;
  final a = 'A'.codeUnitAt(0);
  return String.fromCharCodes(code.runes.map((r) => base + r - a));
}

/// Ligne centrée drapeau + nom du pays.
class CountryRow extends StatelessWidget {
  final String country;
  const CountryRow({super.key, required this.country});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(countryFlagEmoji(country), style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 6),
        Text(
          country,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }
}
