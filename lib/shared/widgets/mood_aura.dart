import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../features/settings/models/mood.dart';

class MoodAura extends StatefulWidget {
  final MoodType mood;
  final Color color;

  const MoodAura({
    super.key,
    required this.mood,
    required this.color,
  });

  @override
  State<MoodAura> createState() => _MoodAuraState();
}

class _MoodAuraState extends State<MoodAura> with SingleTickerProviderStateMixin {
  FragmentProgram? _program;
  late Ticker _ticker;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      if (mounted) {
        setState(() {
          _time = elapsed.inMilliseconds / 1000.0;
        });
      }
    });
    _ticker.start();
  }

  Future<void> _loadShader() async {
    try {
      final program = await FragmentProgram.fromAsset('assets/shaders/mood_aura.frag');
      if (mounted) {
        setState(() {
          _program = program;
        });
      }
    } catch (e) {
      debugPrint("Failed to load shader: $e");
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_program == null) {
      // Fallback to a nice gradient while loading or if it fails
      return AnimatedContainer(
        duration: const Duration(seconds: 1),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.color.withOpacity(0.2),
              Colors.black,
            ],
          ),
        ),
      );
    }

    return CustomPaint(
      painter: _MoodAuraPainter(
        shader: _program!.fragmentShader(),
        time: _time,
        mood: widget.mood,
        color: widget.color,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MoodAuraPainter extends CustomPainter {
  final FragmentShader shader;
  final double time;
  final MoodType mood;
  final Color color;

  _MoodAuraPainter({
    required this.shader,
    required this.time,
    required this.mood,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    shader.setFloat(0, time);
    shader.setFloat(1, size.width);
    shader.setFloat(2, size.height);
    shader.setFloat(3, mood.index.toDouble());
    shader.setFloat(4, color.red / 255.0);
    shader.setFloat(5, color.green / 255.0);
    shader.setFloat(6, color.blue / 255.0);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(covariant _MoodAuraPainter oldDelegate) {
    return oldDelegate.time != time || 
           oldDelegate.mood != mood || 
           oldDelegate.color != color;
  }
}
