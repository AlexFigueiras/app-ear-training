import 'package:flutter/material.dart';

// Elementos visuais da tela de Discriminação Fonêmica.

class PulseIcon extends StatefulWidget {
  const PulseIcon({super.key});

  @override
  State<PulseIcon> createState() => PulseIconState();
}

class PulseIconState extends State<PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.15).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulse,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent.withValues(alpha: 0.05),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.1)),
        ),
        child: const Icon(Icons.hearing, size: 64, color: Colors.blueAccent),
      ),
    );
  }
}

class AnimatedOptionCard extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const AnimatedOptionCard({
    super.key,required this.label, required this.onTap});

  @override
  State<AnimatedOptionCard> createState() => AnimatedOptionCardState();
}

class AnimatedOptionCardState extends State<AnimatedOptionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E24),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
