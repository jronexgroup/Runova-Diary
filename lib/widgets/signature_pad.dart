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

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullScreenSignature(
          strokes: _strokes.map((s) => List<Offset>.from(s)).toList(),
        ),
      ),
    ).then((result) {
      if (result != null && result is List<List<Offset>>) {
        setState(() {
          _strokes.clear();
          _strokes.addAll(result);
        });
        _save();
      }
    });
  }

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
            IconButton(
              icon: Icon(Icons.fullscreen, size: 20),
              onPressed: _openFullscreen,
              tooltip: 'Full screen',
              visualDensity: VisualDensity.compact,
            ),
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
            child: _SignatureCanvas(
              strokes: _strokes,
              currentStroke: _currentStroke,
              onPanStart: (pos) {
                setState(() => _currentStroke = [pos]);
              },
              onPanUpdate: (pos) {
                setState(() => _currentStroke.add(pos));
              },
              onPanEnd: () {
                setState(() {
                  _strokes.add(List.from(_currentStroke));
                  _currentStroke = [];
                });
                _save();
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SignatureCanvas extends StatelessWidget {
  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final void Function(Offset) onPanStart;
  final void Function(Offset) onPanUpdate;
  final VoidCallback onPanEnd;

  const _SignatureCanvas({
    required this.strokes,
    required this.currentStroke,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => onPanStart(d.localPosition),
      onPanUpdate: (d) => onPanUpdate(d.localPosition),
      onPanEnd: (_) => onPanEnd(),
      child: LayoutBuilder(
        builder: (_, constraints) => CustomPaint(
          painter: _SignaturePainter(strokes, currentStroke),
          size: Size(constraints.maxWidth, constraints.maxHeight),
        ),
      ),
    );
  }
}

class _FullScreenSignature extends StatefulWidget {
  final List<List<Offset>> strokes;

  const _FullScreenSignature({required this.strokes});

  @override
  State<_FullScreenSignature> createState() => _FullScreenSignatureState();
}

class _FullScreenSignatureState extends State<_FullScreenSignature> {
  late List<List<Offset>> _strokes;
  List<Offset> _currentStroke = [];

  @override
  void initState() {
    super.initState();
    _strokes = widget.strokes.map((s) => List<Offset>.from(s)).toList();
  }

  void _saveAndClose() {
    Navigator.of(context).pop(_strokes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Sign here'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_strokes.isNotEmpty || _currentStroke.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                _strokes.clear();
                _currentStroke.clear();
              }),
            ),
          TextButton.icon(
            onPressed: _strokes.isEmpty ? null : _saveAndClose,
            icon: const Icon(Icons.check),
            label: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Sign with your finger',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _SignatureCanvas(
                      strokes: _strokes,
                      currentStroke: _currentStroke,
                      onPanStart: (pos) {
                        setState(() => _currentStroke = [pos]);
                      },
                      onPanUpdate: (pos) {
                        setState(() => _currentStroke.add(pos));
                      },
                      onPanEnd: () {
                        setState(() {
                          _strokes.add(List.from(_currentStroke));
                          _currentStroke = [];
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
