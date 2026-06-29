import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/utils/alanya_phone_formatter.dart';

/// Affiche un numéro Alanya formaté (read-only).
class AlanyaPhoneText extends StatelessWidget {
  final String phone;
  final TextStyle? style;
  final TextAlign? textAlign;

  const AlanyaPhoneText(
    this.phone, {
    super.key,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      AlanyaPhoneFormatter.formatDisplay(phone),
      style: style,
      textAlign: textAlign,
    );
  }
}

/// Champ de saisie avec formatage live (3 / 4 / 8 chiffres).
class AlanyaPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  const AlanyaPhoneField({
    super.key,
    required this.controller,
    this.decoration,
    this.onChanged,
    this.autofocus = false,
  });

  static String canonicalFrom(TextEditingController controller) =>
      AlanyaPhoneFormatter.normalize(controller.text);

  @override
  State<AlanyaPhoneField> createState() => _AlanyaPhoneFieldState();
}

class _AlanyaPhoneFieldState extends State<AlanyaPhoneField> {
  bool _formatting = false;

  void _applyFormat(String raw) {
    if (_formatting) return;
    final digits = AlanyaPhoneFormatter.normalize(raw);
    final limited =
        digits.length > 8 ? digits.substring(0, 8) : digits;
    final formatted = AlanyaPhoneFormatter.formatLiveInput(limited);
    if (formatted == widget.controller.text) {
      widget.onChanged?.call(limited);
      return;
    }
    _formatting = true;
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    _formatting = false;
    widget.onChanged?.call(limited);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
      decoration: widget.decoration ??
          const InputDecoration(
            hintText: '00 00 00 00',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
      onChanged: _applyFormat,
    );
  }
}
