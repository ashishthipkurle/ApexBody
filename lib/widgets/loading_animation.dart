import 'package:flutter/material.dart';

class LoadingAnimation extends StatefulWidget {
  final double size;
  final String? text;

  const LoadingAnimation({
    Key? key,
    this.size = 100,
    this.text,
  }) : super(key: key);

  @override
  State<LoadingAnimation> createState() => _LoadingAnimationState();
}

class _LoadingAnimationState extends State<LoadingAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Infinite rotation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating red circle (background)
          RotationTransition(
            turns: _controller,
            child: Image.asset(
              'assets/ApexBody_circle.png',
              height: widget.size * 0.3,
            ),
          ),
          // Dumbbell (centered over the circle)
          Image.asset(
            'assets/ApexBody_dumbbell.png',
            height: widget.size * 0.2,
          ),
          if (widget.text != null)
            Positioned(
              bottom: widget.size * 0.15,
              left: 0,
              right: 0,
              child: Text(
                widget.text!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
