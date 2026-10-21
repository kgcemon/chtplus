import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// The area of the picture the user framed, as 0–1 fractions of the image —
/// what the server's `readCropFields` expects (`cropX`, `cropY`, …).
class PhotoCrop {
  const PhotoCrop({required this.x, required this.y, required this.width, required this.height});

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, String> toFields() => {
        'cropX': x.toString(),
        'cropY': y.toString(),
        'cropWidth': width.toString(),
        'cropHeight': height.toString(),
      };
}

/// Crop editor shown after a profile or cover photo is picked, like the site's
/// `PhotoCropDialog`: drag to move, pinch or use the slider to zoom, "Update"
/// to save. The picture always covers the frame. Returns null on Cancel.
class PhotoCropScreen extends StatefulWidget {
  const PhotoCropScreen({
    super.key,
    required this.filePath,
    required this.aspect,
    required this.title,
    this.round = false,
  });

  final String filePath;

  /// Frame width / height: 3 for the cover, 1 for the profile photo.
  final double aspect;
  final bool round;
  final String title;

  static Future<PhotoCrop?> open(
    BuildContext context, {
    required String filePath,
    required double aspect,
    required String title,
    bool round = false,
  }) {
    return Navigator.of(context, rootNavigator: true).push<PhotoCrop>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PhotoCropScreen(filePath: filePath, aspect: aspect, title: title, round: round),
      ),
    );
  }

  @override
  State<PhotoCropScreen> createState() => _PhotoCropScreenState();
}

class _PhotoCropScreenState extends State<PhotoCropScreen> {
  static const _maxZoom = 4.0;

  late final FileImage _image = FileImage(File(widget.filePath));
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _natural = Size(info.image.width.toDouble(), info.image.height.toDouble()));
    },
    onError: (_, __) {
      if (mounted) setState(() => _failed = true);
    },
  );

  Size? _natural;
  bool _failed = false;
  double _zoom = 1;
  Offset _offset = Offset.zero;

  // Gesture start values.
  double _startZoom = 1;
  Offset _startOffset = Offset.zero;
  Offset _startFocal = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_stream == null) {
      _stream = _image.resolve(createLocalImageConfiguration(context));
      _stream!.addListener(_listener);
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  double _baseScale(Size frame) {
    final n = _natural!;
    return math.max(frame.width / n.width, frame.height / n.height);
  }

  Offset _clamp(Offset o, double zoom, Size frame) {
    final n = _natural!;
    final s = _baseScale(frame) * zoom;
    final maxX = (n.width * s - frame.width) / 2;
    final maxY = (n.height * s - frame.height) / 2;
    return Offset(o.dx.clamp(-maxX, maxX), o.dy.clamp(-maxY, maxY));
  }

  void _setZoom(double z, Size frame) {
    final next = z.clamp(1.0, _maxZoom);
    setState(() {
      _zoom = next;
      _offset = _clamp(_offset, next, frame);
    });
  }

  PhotoCrop _crop(Size frame) {
    final n = _natural!;
    final s = _baseScale(frame) * _zoom;
    final dispW = n.width * s;
    final dispH = n.height * s;
    final left = frame.width / 2 + _offset.dx - dispW / 2;
    final top = frame.height / 2 + _offset.dy - dispH / 2;
    return PhotoCrop(
      x: math.max(0, -left / dispW),
      y: math.max(0, -top / dispH),
      width: math.min(1, frame.width / dispW),
      height: math.min(1, frame.height / dispH),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameW = math.max(
              160.0,
              math.min(constraints.maxWidth - 32, (constraints.maxHeight - 170) * widget.aspect),
            );
            final frame = Size(frameW, frameW / widget.aspect);
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    'Drag to move · pinch or use the slider to zoom',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Expanded(child: Center(child: _frame(frame))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.remove_rounded, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _zoom,
                          min: 1,
                          max: _maxZoom,
                          activeColor: AppColors.forest,
                          onChanged: _natural == null ? null : (v) => _setZoom(v, frame),
                        ),
                      ),
                      const Icon(Icons.add_rounded, color: Colors.white70),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _natural == null ? null : () => Navigator.of(context).pop(_crop(frame)),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text('Update', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _frame(Size frame) {
    final n = _natural;
    Widget child;
    if (_failed) {
      child = const Center(child: Text("Couldn't open this photo.", style: TextStyle(color: Colors.white70)));
    } else if (n == null) {
      child = const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2));
    } else {
      final s = _baseScale(frame) * _zoom;
      final dispW = n.width * s;
      final dispH = n.height * s;
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: (d) {
          _startZoom = _zoom;
          _startOffset = _offset;
          _startFocal = d.localFocalPoint;
        },
        onScaleUpdate: (d) {
          final z = (_startZoom * d.scale).clamp(1.0, _maxZoom);
          setState(() {
            _zoom = z;
            _offset = _clamp(_startOffset + (d.localFocalPoint - _startFocal), z, frame);
          });
        },
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: frame.width / 2 + _offset.dx - dispW / 2,
              top: frame.height / 2 + _offset.dy - dispH / 2,
              width: dispW,
              height: dispH,
              child: Image(image: _image, fit: BoxFit.fill, gaplessPlayback: true),
            ),
          ],
        ),
      );
    }
    final radius = widget.round ? BorderRadius.circular(frame.width / 2) : BorderRadius.circular(6);
    return Container(
      width: frame.width,
      height: frame.height,
      decoration: BoxDecoration(color: Colors.white10, borderRadius: radius),
      // Drawn on top so the picture never covers the frame's outline.
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}
