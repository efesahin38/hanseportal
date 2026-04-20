import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';

class SignaturePadWidget extends StatefulWidget {
  final Color color;
  final double strokeWidth;
  final Function(String base64Signature)? onSigned;

  const SignaturePadWidget({
    super.key,
    this.color = Colors.black,
    this.strokeWidth = 3.0,
    this.onSigned,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  final List<Offset?> _points = [];
  double _currentWidth = 300;
  double _currentHeight = 150;

  Future<void> _exportSignature() async {
    if (_points.isEmpty) return;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..color = widget.color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = widget.strokeWidth;

    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i] != null && _points[i + 1] != null) {
        canvas.drawLine(_points[i]!, _points[i + 1]!, paint);
      }
    }

    // Capture as image using dynamic widget size
    final picture = recorder.endRecording();
    final img = await picture.toImage(_currentWidth.toInt(), _currentHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    if (byteData != null && widget.onSigned != null) {
      final base64String = base64Encode(byteData.buffer.asUint8List());
      widget.onSigned!(base64String);
    }
  }

  void _clear() {
    setState(() => _points.clear());
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _currentWidth = constraints.maxWidth > 0 ? constraints.maxWidth : 300;
        return Column(
          children: [
            Container(
              height: _currentHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: GestureDetector(
            onPanStart: (details) {
              setState(() => _points.add(details.localPosition));
            },
            onPanUpdate: (details) {
              setState(() => _points.add(details.localPosition));
            },
            onPanEnd: (details) {
              setState(() => _points.add(null));
              _exportSignature();
            },
            child: CustomPaint(
              painter: _SignaturePainter(_points, widget.color, widget.strokeWidth),
              size: Size.infinite,
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _clear,
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Löschen', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ],
    );
  });
}
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color color;
  final double strokeWidth;

  _SignaturePainter(this.points, this.color, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}
