// custom_button.dart

import 'package:flutter/material.dart';

import '../theme/theme.dart';

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final FocusNode focusNode;
  final bool autofocus;
  final int traversalOrder;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    required this.focusNode,
    this.autofocus = false,
    required this.traversalOrder,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;

    return FocusTraversalOrder(
      order: NumericFocusOrder(widget.traversalOrder.toDouble()),
      child: FocusableActionDetector(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        onShowFocusHighlight: (focused) {
          setState(() {
            _isFocused = focused;
          });
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _isFocused
                ? customColors.buttonBackground.withOpacity(0.9)
                : customColors.buttonBackground,
            borderRadius: BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: customColors.focusBorder, width: 2)
                : null,
          ),
          child: Text(
            widget.text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _isFocused ? Colors.white : Colors.black,
                ),
          ),
        ),
      ),
    );
  }
}
