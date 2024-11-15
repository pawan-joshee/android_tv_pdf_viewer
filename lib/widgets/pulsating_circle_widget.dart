import 'package:flutter/material.dart';

class PulsatingCircle extends StatefulWidget {
  const PulsatingCircle({super.key});

  @override
  PulsatingCircleState createState() => PulsatingCircleState();
}

class PulsatingCircleState extends State<PulsatingCircle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 20.0, end: 30.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: _animation.value,
          height: _animation.value,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
