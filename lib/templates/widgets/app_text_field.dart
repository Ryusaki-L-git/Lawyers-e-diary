import 'package:flutter/material.dart';

import '../../widgets/app_palette.dart';

/// Labelled text field used by the authentication and registration flows.
///
/// The visual identity is resolved from the active [ThemeData] through
/// [EditorialComponentTheme], so the Android build keeps its existing
/// legacy-gold appearance while the Windows build uses the Modern Legal
/// Editorial palette.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final tokens =
        Theme.of(context).extension<EditorialComponentTheme>() ??
        EditorialComponentTheme.legacy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.fieldLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: TextStyle(color: tokens.fieldText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: tokens.fieldHint),
            prefixIcon: Icon(icon, color: tokens.fieldIcon),
            filled: true,
            fillColor: tokens.fieldFill,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: tokens.fieldFocusBorder,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
