import 'package:flutter/material.dart';

const Color _kNeuBase  = Color(0xFFE8F5E9);
const Color _kNeuDark  = Color(0xFFC3D4C5);
const Color _kNeuLight = Color(0xFFFFFFFF);
const Color _kPrimary  = Color(0xFF2E7D32);
const Color _kTextMid  = Color(0xFF4E7C52);

/// An inset neumorphic text field — shows a concave shadow effect.
class NeumorphicTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const NeumorphicTextField({
    super.key,
    this.controller,
    required this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.textInputAction,
    this.focusNode,
  });

  @override
  State<NeumorphicTextField> createState() => _NeumorphicTextFieldState();
}

class _NeumorphicTextFieldState extends State<NeumorphicTextField> {
  bool _focused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inset shadow (concave) — reversed offsets
    final insetShadows = [
      BoxShadow(
        color: _kNeuDark,
        offset: const Offset(-3, -3),
        blurRadius: 8,
        spreadRadius: 1,
      ),
      const BoxShadow(
        color: _kNeuLight,
        offset: Offset(3, 3),
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _kNeuBase,
        borderRadius: BorderRadius.circular(14),
        boxShadow: insetShadows,
        border: _focused
            ? Border.all(color: _kPrimary.withOpacity(0.5), width: 1.5)
            : Border.all(color: Colors.transparent, width: 1.5),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        focusNode: _focusNode,
        style: const TextStyle(color: Color(0xFF1B5E20), fontSize: 15),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: _kTextMid, fontSize: 14),
          prefixIcon: widget.prefixIcon != null
              ? IconTheme(
                  data: const IconThemeData(color: _kPrimary, size: 20),
                  child: widget.prefixIcon!)
              : null,
          suffixIcon: widget.suffixIcon != null
              ? IconTheme(
                  data: const IconThemeData(color: _kPrimary, size: 20),
                  child: widget.suffixIcon!)
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
