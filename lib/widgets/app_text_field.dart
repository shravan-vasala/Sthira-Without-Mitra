import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final bool obscureText;
  final Widget? suffixIcon;
  final bool centerText;
  final Function(String)? onChanged;

  const AppTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = '',
    this.prefixIcon,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.none,
    this.obscureText = false,
    this.suffixIcon,
    this.centerText = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (labelText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 4),
            child: Text(
              labelText,
              style: TextStyle(
                color: context.colors.textMedium,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          obscureText: obscureText,
          textAlign: centerText ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: context.colors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: context.colors.textLight,
              fontSize: 16,
            ),
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: context.colors.textMedium)
                : null,
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: context.colors.inputFill,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.border.withOpacity(0.5),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: context.colors.primary,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
          ),
        ),
      ],
    );
  }
}
