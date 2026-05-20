import 'package:flutter/material.dart';

const Color _kNeuBase  = Color(0xFFE8F5E9);
const Color _kNeuDark  = Color(0xFFC3D4C5);
const Color _kNeuLight = Color(0xFFFFFFFF);

/// A neumorphic button that animates between raised and pressed (inset) shadows on tap.
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
    this.color,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  List<BoxShadow> get _raisedShadows => [
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

  List<BoxShadow> get _pressedShadows => [
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

  @override
  Widget build(BuildContext context) {
    final bg = widget.color ?? _kNeuBase;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: _pressed ? _pressedShadows : _raisedShadows,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A full-width primary neumorphic button with deep-green background.
class NeumorphicPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool isLoading;

  const NeumorphicPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.isLoading = false,
  });

  @override
  State<NeumorphicPrimaryButton> createState() => _NeumorphicPrimaryButtonState();
}

class _NeumorphicPrimaryButtonState extends State<NeumorphicPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF2E7D32);
    final shadows = _pressed
        ? [
            const BoxShadow(
              color: Color(0xFF1B5E20),
              offset: Offset(-3, -3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.15),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
          ]
        : [
            const BoxShadow(
              color: Color(0xFF1B5E20),
              offset: Offset(5, 5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.25),
              offset: const Offset(-5, -5),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ];

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: shadows,
        ),
        child: Center(
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
