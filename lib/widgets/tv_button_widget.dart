import 'package:flutter/material.dart';

class TVButtonWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final FocusNode focusNode;
  final VoidCallback onPressed;
  final bool isPrimary;

  const TVButtonWidget({
    super.key,
    required this.icon,
    required this.label,
    required this.focusNode,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onPressed();
            return null;
          },
        ),
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          return Transform.scale(
            scale: focusNode.hasFocus ? 1.1 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: isPrimary
                    ? (focusNode.hasFocus
                        ? Colors.purple[400]?.withOpacity(0.9)
                        : Colors.purple[600])
                    : (focusNode.hasFocus
                        ? Colors.purple[700]?.withOpacity(0.9)
                        : Colors.purple[900]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: focusNode.hasFocus
                    ? [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.7),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ]
                    : [
                        const BoxShadow(
                          color: Colors.transparent,
                        )
                      ],
                border: isPrimary
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: focusNode.hasFocus ? 0.05 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
