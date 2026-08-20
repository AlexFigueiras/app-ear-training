import 'package:flutter/material.dart';

/// Botão com visual industrial dark para escolhas clínicas e respostas
class IndustrialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double height;
  final Color? borderColor;
  final Color? backgroundColor;

  const IndustrialButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 60,
    this.borderColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor ?? const Color(0xFF1A1A1A),
            border: Border.all(color: borderColor ?? const Color(0xFF333333)),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
