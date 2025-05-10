import 'package:flutter/material.dart';

class ScoreButton extends StatelessWidget {
  final int value;
  final String? label;
  final bool disabled;
  final double fontSize;
  final double verticalPadding;
  final VoidCallback onPressed;

  const ScoreButton({
    super.key,
    required this.value,
    this.label,
    this.disabled = false,
    this.fontSize = 16,
    this.verticalPadding = 8,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        textStyle: TextStyle(fontSize: fontSize),
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
      ),
      onPressed: disabled ? null : onPressed,
      child: Text(label ?? '$value', style: TextStyle(fontSize: fontSize)),
    );
  }
}