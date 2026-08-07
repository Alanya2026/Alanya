import 'dart:convert';

/// Type de message porteur de boutons de bienvenue.
///
/// Son `content` est du JSON, jamais du texte : tout affichage qui l'ignore
/// expose `{"buttons":[…]}` à l'écran. Nommer la valeur évite d'oublier ce type
/// dans l'un des rendus, ce qui s'est déjà produit.
/// Aligné sur `WELCOME_CTA_MSG_TYPE` (welcomeService.js).
const int kWelcomeCtaMessageType = 8;

/// Payload JSON des boutons CTA (bienvenue officiel).
class WelcomeCtaButton {
  const WelcomeCtaButton({
    required this.label,
    required this.action,
    required this.target,
  });

  final String label;
  final String action;
  final String target;

  bool get isUrl => action == 'url';
  bool get isRoute => action == 'route';
}

class WelcomeCtaPayload {
  const WelcomeCtaPayload({required this.buttons});

  final List<WelcomeCtaButton> buttons;

  static WelcomeCtaPayload? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final list = map['buttons'];
      if (list is! List) return null;
      final buttons = <WelcomeCtaButton>[];
      for (final item in list) {
        if (item is! Map) continue;
        final label = item['label']?.toString() ?? '';
        final target = item['target']?.toString() ?? '';
        final action = item['action']?.toString() ?? 'route';
        if (label.isEmpty || target.isEmpty) continue;
        buttons.add(WelcomeCtaButton(label: label, action: action, target: target));
      }
      if (buttons.isEmpty) return null;
      return WelcomeCtaPayload(buttons: buttons);
    } catch (_) {
      return null;
    }
  }
}
