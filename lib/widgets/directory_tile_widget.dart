import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

class DirectoryTileWidget extends StatelessWidget {
  final Directory directory;
  final FocusNode focusNode;
  final VoidCallback onNavigate;

  const DirectoryTileWidget({
    super.key,
    required this.directory,
    required this.focusNode,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: focusNode,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onNavigate();
            return null;
          },
        ),
      },
      child: AnimatedBuilder(
        animation: focusNode,
        builder: (context, child) {
          final isFocused = focusNode.hasFocus;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Transform.scale(
              scale: isFocused ? 1.05 : 1.0,
            ).transform,
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.purple[600]?.withOpacity(0.9)
                  : Colors.purple[900]?.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: isFocused
                  ? Border.all(color: Colors.purple[300]!, width: 2)
                  : null,
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.all(isFocused ? 12 : 8),
                        decoration: BoxDecoration(
                          color: isFocused
                              ? Colors.purple[300]
                              : Colors.purple[700],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.folder,
                          color: Colors.white,
                          size: isFocused ? 40 : 36,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              directory.path.split('/').last.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isFocused ? 26 : 24,
                                fontWeight: isFocused
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            if (isFocused) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Press OK to view PDFs',
                                style: TextStyle(
                                  color: Colors.purple[100],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: isFocused ? 40 : 36,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
