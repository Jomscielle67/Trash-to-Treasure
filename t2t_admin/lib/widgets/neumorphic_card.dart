import 'package:flutter/material.dart';

const Color _kNeuBase  = Color(0xFFE8F5E9);
const Color _kNeuDark  = Color(0xFFC3D4C5);
const Color _kNeuLight = Color(0xFFFFFFFF);

class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color? color;
  final EdgeInsetsGeometry padding;
  /// When true renders an inset (concave) shadow — used for text fields & pressed states.
  final bool isInset;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.isInset = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? _kNeuBase;

    final List<BoxShadow> raisedShadows = [
      BoxShadow(
        color: _kNeuDark,
        offset: const Offset(6, 6),
        blurRadius: 15,
        spreadRadius: 1,
      ),
      const BoxShadow(
        color: _kNeuLight,
        offset: Offset(-6, -6),
        blurRadius: 15,
        spreadRadius: 1,
      ),
    ];

    // Inset effect: reverse offsets and reduce alpha so it looks pressed in.
    final List<BoxShadow> insetShadows = [
      BoxShadow(
        color: _kNeuDark,
        offset: const Offset(-4, -4),
        blurRadius: 10,
        spreadRadius: 1,
      ),
      const BoxShadow(
        color: _kNeuLight,
        offset: Offset(4, 4),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ];

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: isInset ? insetShadows : raisedShadows,
      ),
      child: child,
    );
  }
}
