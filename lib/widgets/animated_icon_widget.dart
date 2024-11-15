import 'package:flutter/material.dart';

class AnimatedIconWidget extends StatefulWidget {
  final IconData icon;
  final double size;

  const AnimatedIconWidget({super.key, required this.icon, required this.size});

  @override
  AnimatedIconWidgetState createState() => AnimatedIconWidgetState();
}

class AnimatedIconWidgetState extends State<AnimatedIconWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _iconController, curve: Curves.linear));
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _rotationAnimation,
      child: Icon(
        widget.icon,
        size: widget.size,
        color: Colors.purple[100],
      ),
    );
  }
}
