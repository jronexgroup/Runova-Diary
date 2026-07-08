import 'dart:convert';
import 'package:flutter/material.dart';

class SignaturePad extends StatefulWidget {
  final ValueNotifier<String?> notifier;
  final String? initialData;

  const SignaturePad({
    super.key,
    required this.notifier,
    this.initialData,
  });

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadFromJson(widget.initialData!);
    }
  }

  void _loadFromJson(String json) {
    try {
      final data = jsonDecode(json) as List;
      for (final s in data) {
        final stroke = (s as List).map((p) {
          final pt = p as List;
          return Offset((pt[0] as num).toDouble(), (pt[1] as num).toDouble());
        }).toList();
        _strokes.add(stroke);
      }
    } catch (_) {}
  }

  String? get _toJson {
    if (_strokes.isEmpty) return null;
    final data = _strokes.map((s) => s.map((p) => [p.dx, p.dy]).toList()).toList();
    return jsonEncode(data);
  }

  void _save() {
    widget.notifier.value = _toJson;
  }

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke.clear();
    });
    _save();
  }

  bool get isEmpty => _strokes.isEmpty && _currentStroke.isEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text('Signature', style: theme.textTheme.labelLarge),
            const Spacer(),
            if (!isEmpty)
              TextButton.icon(
                onPressed: clear,
                icon: const Icon(Icons.clear, size: 18),
                label: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 160,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerLowest,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _currentStroke = [details.localPosition];
                });
              },
              onPanUpdate: (details) {
                setState(() {
                  _currentStroke.add(details.localPosition);
                });
              },
              onPanEnd: (_) {
                setState(() {
                  _strokes.add(List.from(_currentStroke));
                  _currentStroke = [];
                });
                _save();
              },
              child: CustomPaint(
                painter: _SignaturePainter(_strokes, _currentStroke),
                size: const Size(double.infinity, 160),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;

  _SignaturePainter(this.strokes, this.currentStroke);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke, paint);
    }
    if (currentStroke.isNotEmpty) {
      _drawStroke(canvas, currentStroke, paint);
    }
  }

  void _drawStroke(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      canvas.drawCircle(points.first, paint.strokeWidth / 2, paint);
      return;
    }
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
