import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Shows a full-featured signature pad dialog where the user can draw their
/// signature with a finger or stylus and export it as high-resolution PNG bytes.
Future<Uint8List?> showSignaturePadDialog(
  BuildContext context, {
  required String signerName,
  required String contractNumber,
}) =>
    showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignaturePadDialog(
        signerName: signerName,
        contractNumber: contractNumber,
      ),
    );

class SignaturePadDialog extends StatefulWidget {
  const SignaturePadDialog({
    super.key,
    required this.signerName,
    required this.contractNumber,
  });

  final String signerName;
  final String contractNumber;

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  bool _agreedToTerms = false;
  bool _isSaving = false;

  bool get _hasSignature =>
      _strokes.isNotEmpty && _strokes.any((s) => s.length > 2);

  void _onPanStart(DragStartDetails details, RenderBox box) {
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke = [localPosition];
      _strokes.add(_currentStroke!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details, RenderBox box) {
    final localPosition = box.globalToLocal(details.globalPosition);
    setState(() {
      _currentStroke?.add(localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _currentStroke = null;
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
  }

  Future<void> _confirm(Size canvasSize) async {
    if (!_hasSignature || !_agreedToTerms) return;

    setState(() => _isSaving = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Render crisp white background
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
        bgPaint,
      );

      // Draw baseline guide subtly
      final linePaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(20, canvasSize.height * 0.75),
        Offset(canvasSize.width - 20, canvasSize.height * 0.75),
        linePaint,
      );

      // Draw signature strokes in dark blue ink
      final paint = Paint()
        ..color = const Color(0xFF0D253F)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3.5;

      for (final stroke in _strokes) {
        if (stroke.length == 1) {
          canvas.drawCircle(stroke.first, 1.75, paint);
        } else {
          for (int i = 0; i < stroke.length - 1; i++) {
            canvas.drawLine(stroke[i], stroke[i + 1], paint);
          }
        }
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        canvasSize.width.toInt(),
        canvasSize.height.toInt(),
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null && mounted) {
        Navigator.of(context).pop(byteData.buffer.asUint8List());
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width.clamp(320.0, 560.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: scheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.draw_rounded,
                      color: scheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sign Contract on Phone',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Contract #${widget.contractNumber} • ${widget.signerName}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instructions
              Text(
                'Draw your legal signature inside the box using your finger or stylus.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 10),

              // Canvas Container
              LayoutBuilder(
                builder: (context, constraints) {
                  final canvasWidth = constraints.maxWidth;
                  const canvasHeight = 180.0;
                  final canvasSize = Size(canvasWidth, canvasHeight);

                  return Container(
                    height: canvasHeight,
                    width: canvasWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Stack(
                        children: [
                          // Sign here indicator line
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 40,
                            child: Row(
                              children: [
                                Text(
                                  'X',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 36,
                            bottom: 22,
                            child: Text(
                              'Sign on or above the line',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade400,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),

                          // Touch drawing layer
                          Builder(
                            builder: (canvasContext) => GestureDetector(
                              onPanStart: (d) {
                                final box = canvasContext.findRenderObject()
                                    as RenderBox?;
                                if (box != null) _onPanStart(d, box);
                              },
                              onPanUpdate: (d) {
                                final box = canvasContext.findRenderObject()
                                    as RenderBox?;
                                if (box != null) _onPanUpdate(d, box);
                              },
                              onPanEnd: _onPanEnd,
                              child: CustomPaint(
                                size: canvasSize,
                                painter: _SignaturePainter(strokes: _strokes),
                              ),
                            ),
                          ),

                          // Clear button inside canvas
                          if (_hasSignature)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  backgroundColor:
                                      Colors.grey.shade100.withAlpha(200),
                                ),
                                onPressed: _clear,
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Clear',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Legal acknowledgment checkbox
              InkWell(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) =>
                            setState(() => _agreedToTerms = val ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'I confirm this is my official signature and I agree to the Carmelita\'s Dormitory lease terms and dormitory regulations.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (btnContext) => FilledButton.icon(
                      onPressed: (!_hasSignature ||
                              !_agreedToTerms ||
                              _isSaving)
                          ? null
                          : () {
                              final box = btnContext
                                  .findAncestorRenderObjectOfType<RenderBox>();
                              final canvasWidth =
                                  box != null ? box.size.width : 400.0;
                              _confirm(Size(canvasWidth, 180));
                            },
                      icon: _isSaving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(_isSaving ? 'Signing…' : 'Confirm Signature'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0D253F)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 3.0;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.5, paint);
      } else {
        for (int i = 0; i < stroke.length - 1; i++) {
          canvas.drawLine(stroke[i], stroke[i + 1], paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
