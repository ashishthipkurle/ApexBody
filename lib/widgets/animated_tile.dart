import 'package:flutter/material.dart';

class AnimatedTile extends StatefulWidget {
  final Widget child;
  const AnimatedTile({required this.child, Key? key}) : super(key: key);

  @override
  State<AnimatedTile> createState() => _AnimatedTileState();
}

class _AnimatedTileState extends State<AnimatedTile> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(_anim), child: widget.child));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
