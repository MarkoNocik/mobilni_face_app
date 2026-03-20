import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

import '../models/filter_model.dart';

// ─── Camera Stream Painter ────────────────────────────────────────────────────

/// Painter for live camera mode.
/// imageSize = Size(previewSize.height, previewSize.width) — i.e. sensor H×W
/// so that the transform formulas match ML Kit's post-rotation coordinate space.
class FaceFilterPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  final FilterType filterType;

  FaceFilterPainter({
    required this.faces,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
    required this.filterType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (filterType == FilterType.none || faces.isEmpty) return;
    for (final face in faces) {
      FilterDrawer(
        canvas: canvas,
        faceRect: _transformRect(face.boundingBox, size),
        filterType: filterType,
        getLandmark: (type) => _landmark(face, type, size),
      ).draw();
    }
  }

  @override
  bool shouldRepaint(FaceFilterPainter old) =>
      old.faces != faces || old.filterType != filterType || old.rotation != rotation;

  // imageSize.width = sensorH, imageSize.height = sensorW
  // ML Kit post-rotation coords for rotation90/270:
  //   x ∈ [0, sensorH=imageSize.width], y ∈ [0, sensorW=imageSize.height]

  double _tx(double x, Size cs) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * cs.width / imageSize.width;
      case InputImageRotation.rotation270deg:
        return cs.width - x * cs.width / imageSize.width;
      case InputImageRotation.rotation180deg:
        return cs.width - x * cs.width / imageSize.height;
      default:
        if (cameraLensDirection == CameraLensDirection.front) {
          return cs.width - x * cs.width / imageSize.height;
        }
        return x * cs.width / imageSize.height;
    }
  }

  double _ty(double y, Size cs) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y * cs.height / imageSize.height;
      default:
        return y * cs.height / imageSize.width;
    }
  }

  Offset _tp(double x, double y, Size cs) => Offset(_tx(x, cs), _ty(y, cs));

  Rect _transformRect(Rect r, Size cs) {
    final p1 = _tp(r.left, r.top, cs);
    final p2 = _tp(r.right, r.bottom, cs);
    return Rect.fromPoints(
      Offset(min(p1.dx, p2.dx), min(p1.dy, p2.dy)),
      Offset(max(p1.dx, p2.dx), max(p1.dy, p2.dy)),
    );
  }

  Offset? _landmark(Face face, FaceLandmarkType type, Size cs) {
    final lm = face.landmarks[type];
    if (lm == null) return null;
    return _tp(lm.position.x.toDouble(), lm.position.y.toDouble(), cs);
  }
}

// ─── Gallery / Preview Image Painter ─────────────────────────────────────────

/// Painter for a static image displayed with BoxFit.contain.
class ImageFaceFilterPainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final FilterType filterType;

  ImageFaceFilterPainter({
    required this.faces,
    required this.imageSize,
    required this.filterType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (filterType == FilterType.none || faces.isEmpty) return;
    for (final face in faces) {
      FilterDrawer(
        canvas: canvas,
        faceRect: _transformRect(face.boundingBox, size),
        filterType: filterType,
        getLandmark: (type) => _landmark(face, type, size),
      ).draw();
    }
  }

  @override
  bool shouldRepaint(ImageFaceFilterPainter old) =>
      old.faces != faces || old.filterType != filterType;

  double _scale(Size cs) =>
      min(cs.width / imageSize.width, cs.height / imageSize.height);
  double _ox(Size cs) => (cs.width - imageSize.width * _scale(cs)) / 2;
  double _oy(Size cs) => (cs.height - imageSize.height * _scale(cs)) / 2;

  Offset _tp(double x, double y, Size cs) {
    final s = _scale(cs);
    return Offset(x * s + _ox(cs), y * s + _oy(cs));
  }

  Rect _transformRect(Rect r, Size cs) {
    return Rect.fromPoints(_tp(r.left, r.top, cs), _tp(r.right, r.bottom, cs));
  }

  Offset? _landmark(Face face, FaceLandmarkType type, Size cs) {
    final lm = face.landmarks[type];
    if (lm == null) return null;
    return _tp(lm.position.x.toDouble(), lm.position.y.toDouble(), cs);
  }
}

// ─── Filter Drawer ───────────────────────────────────────────────────────────
// All filter drawing logic lives here. Both painters delegate to this class
// so there is zero duplication and both camera and image modes stay in sync.

class FilterDrawer {
  final Canvas canvas;
  final Rect faceRect;
  final FilterType filterType;
  final Offset? Function(FaceLandmarkType) getLandmark;

  FilterDrawer({
    required this.canvas,
    required this.faceRect,
    required this.filterType,
    required this.getLandmark,
  });

  void draw() {
    switch (filterType) {
      case FilterType.dog:        _drawDog();        break;
      case FilterType.cat:        _drawCat();        break;
      case FilterType.crown:      _drawCrown();      break;
      case FilterType.bunny:      _drawBunny();      break;
      case FilterType.flowerCrown:_drawFlowerCrown();break;
      case FilterType.alien:      _drawAlien();      break;
      case FilterType.sparkle:    _drawSparkle();    break;
      case FilterType.rainbow:    _drawRainbow();    break;
      case FilterType.fire:       _drawFire();       break;
      case FilterType.devil:      _drawDevil();      break;
      default: break;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  double get _w => faceRect.width;
  double get _h => faceRect.height;
  Offset get _center => faceRect.center;

  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _circle(Offset c, double r, Color color) =>
      canvas.drawCircle(c, r, _fill(color));

  void _oval(Offset c, double w, double h, Color color) =>
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), _fill(color));

  // ─── Dog ───────────────────────────────────────────────────────────────────

  void _drawDog() {
    final ew = _w * 0.38;
    final eh = _h * 0.42;
    _dogEar(Offset(faceRect.left + _w * 0.17, faceRect.top), ew, eh);
    _dogEar(Offset(faceRect.right - _w * 0.17, faceRect.top), ew, eh);

    final nose = getLandmark(FaceLandmarkType.noseBase);
    if (nose != null) {
      final nr = _w * 0.08;
      _oval(nose, nr * 2.6, nr * 1.6, const Color(0xFF4A2800));
      _circle(Offset(nose.dx - nr * 0.5, nose.dy - nr * 0.3), nr * 0.3,
          Colors.white.withAlpha(130));
    }
    _dogSpots();
  }

  void _dogEar(Offset tip, double w, double h) {
    final outer = Path()
      ..moveTo(tip.dx - w / 2, tip.dy + h * 0.9)
      ..quadraticBezierTo(tip.dx - w * 0.55, tip.dy - h * 0.4, tip.dx, tip.dy - h * 0.25)
      ..quadraticBezierTo(tip.dx + w * 0.55, tip.dy - h * 0.4, tip.dx + w / 2, tip.dy + h * 0.9)
      ..close();
    final inner = Path()
      ..moveTo(tip.dx - w * 0.28, tip.dy + h * 0.75)
      ..quadraticBezierTo(tip.dx - w * 0.3, tip.dy - h * 0.1, tip.dx, tip.dy + h * 0.05)
      ..quadraticBezierTo(tip.dx + w * 0.3, tip.dy - h * 0.1, tip.dx + w * 0.28, tip.dy + h * 0.75)
      ..close();
    canvas.drawPath(outer, _fill(const Color(0xFF8B6914)));
    canvas.drawPath(inner, _fill(const Color(0xFFCDA45E)));
  }

  void _dogSpots() {
    final p = _fill(const Color(0xFF8B6914).withAlpha(140));
    final r = _w * 0.045;
    canvas.drawCircle(Offset(faceRect.left + _w * 0.18, faceRect.top + _h * 0.62), r, p);
    canvas.drawCircle(Offset(faceRect.left + _w * 0.27, faceRect.top + _h * 0.67), r * 0.75, p);
    canvas.drawCircle(Offset(faceRect.right - _w * 0.18, faceRect.top + _h * 0.62), r, p);
    canvas.drawCircle(Offset(faceRect.right - _w * 0.27, faceRect.top + _h * 0.67), r * 0.75, p);
  }

  // ─── Cat ───────────────────────────────────────────────────────────────────

  void _drawCat() {
    _catEar(Offset(faceRect.left + _w * 0.2, faceRect.top), _w * 0.26, _h * 0.38);
    _catEar(Offset(faceRect.right - _w * 0.2, faceRect.top), _w * 0.26, _h * 0.38);

    final nose = getLandmark(FaceLandmarkType.noseBase);
    if (nose != null) {
      final ns = _w * 0.055;
      canvas.drawPath(
        Path()
          ..moveTo(nose.dx, nose.dy - ns)
          ..lineTo(nose.dx - ns * 1.1, nose.dy + ns * 0.6)
          ..quadraticBezierTo(nose.dx, nose.dy + ns * 0.2, nose.dx + ns * 1.1, nose.dy + ns * 0.6)
          ..close(),
        _fill(const Color(0xFFFF6B9D)),
      );
    }
    _whiskers();
  }

  void _catEar(Offset tip, double w, double h) {
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - w / 2, tip.dy + h)
        ..lineTo(tip.dx, tip.dy - h * 0.15)
        ..lineTo(tip.dx + w / 2, tip.dy + h)
        ..close(),
      _fill(const Color(0xFFFF6B00)),
    );
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx - w * 0.28, tip.dy + h * 0.85)
        ..lineTo(tip.dx, tip.dy + h * 0.12)
        ..lineTo(tip.dx + w * 0.28, tip.dy + h * 0.85)
        ..close(),
      _fill(const Color(0xFFFFB3B3)),
    );
  }

  void _whiskers() {
    final p = _stroke(Colors.white.withAlpha(224), _w * 0.013);
    final cx = _center.dx;
    final ny = faceRect.top + _h * 0.63;
    final wl = _w * 0.46;
    final ox = _w * 0.06;
    for (final m in [-1.0, 1.0]) {
      final sx = cx + m * ox;
      final ex = cx + m * wl;
      canvas.drawLine(Offset(sx, ny - _h * 0.03), Offset(ex, ny - _h * 0.055), p);
      canvas.drawLine(Offset(sx, ny),              Offset(ex, ny),              p);
      canvas.drawLine(Offset(sx, ny + _h * 0.03), Offset(ex, ny + _h * 0.055), p);
    }
  }

  // ─── Crown ─────────────────────────────────────────────────────────────────

  void _drawCrown() {
    final cw   = _w;
    final ch   = _h * 0.45;
    final base = faceRect.top - _h * 0.02;
    final left = _center.dx - cw / 2;
    final right= _center.dx + cw / 2;

    final path = Path()
      ..moveTo(left, base)
      ..lineTo(left, base - ch * 0.45)
      ..lineTo(left + cw * 0.18, base - ch * 0.15)
      ..lineTo(left + cw * 0.32, base - ch * 0.85)
      ..lineTo(left + cw * 0.46, base - ch * 0.35)
      ..lineTo(_center.dx, base - ch)
      ..lineTo(right - cw * 0.46, base - ch * 0.35)
      ..lineTo(right - cw * 0.32, base - ch * 0.85)
      ..lineTo(right - cw * 0.18, base - ch * 0.15)
      ..lineTo(right, base - ch * 0.45)
      ..lineTo(right, base)
      ..close();

    canvas.drawPath(path, _fill(const Color(0xFFFFD700)));
    canvas.drawPath(path, _stroke(const Color(0xFF8B6914), _w * 0.012));
    canvas.drawRect(Rect.fromLTWH(left, base - ch * 0.45, cw, ch * 0.14),
        _fill(const Color(0xFFDAA520)));

    for (final (pos, col) in [
      (Offset(_center.dx, base - ch * 0.38), Colors.red),
      (Offset(left + cw * 0.22, base - ch * 0.3), Colors.blue),
      (Offset(right - cw * 0.22, base - ch * 0.3), Colors.green),
    ]) {
      _circle(pos, _w * 0.04, col as Color);
      canvas.drawCircle(pos, _w * 0.04,
          _stroke(Colors.white.withAlpha(100), 1.5));
    }
  }

  // ─── Bunny ─────────────────────────────────────────────────────────────────

  void _drawBunny() {
    final ew  = _w * 0.22;
    final eh  = _h * 0.9;
    final gap = _w * 0.1;
    _bunnyEar(Offset(_center.dx - gap - ew / 2, faceRect.top), ew, eh);
    _bunnyEar(Offset(_center.dx + gap + ew / 2, faceRect.top), ew, eh);

    final nose = getLandmark(FaceLandmarkType.noseBase);
    if (nose != null) {
      _oval(nose, _w * 0.08, _w * 0.055, const Color(0xFFFF69B4));
    }
  }

  void _bunnyEar(Offset c, double w, double h) {
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - h / 2), width: w, height: h),
        _fill(Colors.white));
    canvas.drawOval(Rect.fromCenter(center: Offset(c.dx, c.dy - h / 2), width: w * 0.5, height: h * 0.7),
        _fill(const Color(0xFFFFB6C1)));
  }

  // ─── Flower Crown ──────────────────────────────────────────────────────────

  void _drawFlowerCrown() {
    final cx   = _center.dx;
    final topY = faceRect.top - _h * 0.08;
    final spread = _w * 0.55;
    final flowerR = _w * 0.1;
    final positions = [
      Offset(cx - spread, topY + _h * 0.05),
      Offset(cx - spread * 0.65, topY - _h * 0.1),
      Offset(cx - spread * 0.3, topY - _h * 0.18),
      Offset(cx, topY - _h * 0.22),
      Offset(cx + spread * 0.3, topY - _h * 0.18),
      Offset(cx + spread * 0.65, topY - _h * 0.1),
      Offset(cx + spread, topY + _h * 0.05),
    ];
    final colors = [Colors.red, Colors.yellow, Colors.pink, Colors.orange,
                    Colors.purple, Colors.cyan, Colors.green];

    final vinePaint = _stroke(const Color(0xFF228B22), _w * 0.022);
    final vine = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (int i = 1; i < positions.length; i++) {
      final p = positions[i - 1]; final c = positions[i];
      vine.quadraticBezierTo((p.dx + c.dx) / 2, p.dy, c.dx, c.dy);
    }
    canvas.drawPath(vine, vinePaint);

    for (int i = 0; i < positions.length; i++) {
      _flower(positions[i], flowerR, colors[i]);
    }
  }

  void _flower(Offset center, double r, Color color) {
    for (int i = 0; i < 5; i++) {
      final a = (2 * pi * i / 5) - pi / 2;
      _circle(Offset(center.dx + cos(a) * r * 0.7, center.dy + sin(a) * r * 0.7), r * 0.55, color);
    }
    _circle(center, r * 0.45, Colors.yellow);
    _circle(center, r * 0.2, Colors.orange);
  }

  // ─── Alien ─────────────────────────────────────────────────────────────────

  void _drawAlien() {
    final cx = _center.dx;
    final ah = _h * 0.55;
    final sp = _stroke(const Color(0xFF76FF03), _w * 0.028);

    canvas.drawLine(Offset(cx - _w * 0.12, faceRect.top), Offset(cx - _w * 0.28, faceRect.top - ah), sp);
    _circle(Offset(cx - _w * 0.28, faceRect.top - ah), _w * 0.07,
        const Color(0xFF76FF03).withAlpha(90));
    _circle(Offset(cx - _w * 0.28, faceRect.top - ah), _w * 0.05, const Color(0xFF76FF03));

    canvas.drawLine(Offset(cx + _w * 0.12, faceRect.top), Offset(cx + _w * 0.28, faceRect.top - ah), sp);
    _circle(Offset(cx + _w * 0.28, faceRect.top - ah), _w * 0.07,
        const Color(0xFF76FF03).withAlpha(90));
    _circle(Offset(cx + _w * 0.28, faceRect.top - ah), _w * 0.05, const Color(0xFF76FF03));

    canvas.drawOval(faceRect.inflate(_w * 0.02),
        _fill(const Color(0xFF76FF03).withAlpha(20)));

    for (final type in [FaceLandmarkType.leftEye, FaceLandmarkType.rightEye]) {
      final eye = getLandmark(type);
      if (eye != null) {
        _oval(eye, _w * 0.22, _h * 0.12, Colors.black.withAlpha(178));
        canvas.drawOval(Rect.fromCenter(center: eye, width: _w * 0.22, height: _h * 0.12),
            _stroke(const Color(0xFF76FF03), 1.5));
      }
    }
  }

  // ─── ✨ Sparkle ─────────────────────────────────────────────────────────────

  void _drawSparkle() {
    final sr = _w * 0.065;
    final positions = [
      Offset(faceRect.left - _w * 0.06, faceRect.top + _h * 0.08),
      Offset(faceRect.right + _w * 0.06, faceRect.top + _h * 0.08),
      Offset(faceRect.left + _w * 0.12, faceRect.top - _h * 0.06),
      Offset(faceRect.right - _w * 0.12, faceRect.top - _h * 0.06),
      Offset(_center.dx, faceRect.top - _h * 0.14),
      Offset(faceRect.left - _w * 0.1,  _center.dy),
      Offset(faceRect.right + _w * 0.1, _center.dy),
      Offset(faceRect.left + _w * 0.05, faceRect.bottom + _h * 0.04),
      Offset(faceRect.right - _w * 0.05,faceRect.bottom + _h * 0.04),
      Offset(_center.dx - _w * 0.3,     faceRect.top - _h * 0.02),
      Offset(_center.dx + _w * 0.3,     faceRect.top - _h * 0.02),
      Offset(faceRect.left - _w * 0.04, faceRect.top + _h * 0.55),
      Offset(faceRect.right + _w * 0.04,faceRect.top + _h * 0.55),
    ];
    final scales = [1.0, 0.9, 0.75, 0.8, 1.3, 0.65, 0.7, 0.7, 0.75, 0.6, 0.65, 0.55, 0.6];

    for (int i = 0; i < positions.length; i++) {
      _star(positions[i], sr * scales[i]);
    }
  }

  void _star(Offset center, double r) {
    const outerR = 1.0;
    const innerR = 0.42;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = (i * pi / 4) - pi / 2;
      final radius = i.isEven ? outerR : innerR;
      final p = Offset(center.dx + r * radius * cos(a), center.dy + r * radius * sin(a));
      if (i == 0) path.moveTo(p.dx, p.dy);
      else path.lineTo(p.dx, p.dy);
    }
    path.close();
    // Glow
    canvas.drawCircle(center, r * 1.6,
        Paint()
          ..color = const Color(0xFFFFD700).withAlpha(50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawPath(path, _fill(const Color(0xFFFFD700)));
    // Cross lines
    final cp = _stroke(Colors.white, r * 0.18);
    canvas.drawLine(Offset(center.dx - r * 1.35, center.dy),
                    Offset(center.dx + r * 1.35, center.dy), cp);
    canvas.drawLine(Offset(center.dx, center.dy - r * 1.35),
                    Offset(center.dx, center.dy + r * 1.35), cp);
    // White center dot
    _circle(center, r * 0.22, Colors.white);
  }

  // ─── 🌈 Rainbow ─────────────────────────────────────────────────────────────

  void _drawRainbow() {
    final cx    = _center.dx;
    final arcCy = faceRect.top + _h * 0.05;   // center of the arcs (just below top)
    final bandW = _w * 0.055;

    final colors = [
      const Color(0xFFFF0000), // red   (outermost)
      const Color(0xFFFF7700), // orange
      const Color(0xFFFFDD00), // yellow
      const Color(0xFF00CC00), // green
      const Color(0xFF0088FF), // blue
      const Color(0xFF6600CC), // indigo
      const Color(0xFFCC44FF), // violet (innermost)
    ];

    for (int i = 0; i < colors.length; i++) {
      final radius = _w * 0.58 + (colors.length - i) * bandW;
      final rect   = Rect.fromCenter(
        center: Offset(cx, arcCy + radius * 0.1),
        width:  radius * 2,
        height: radius * 1.6,
      );
      canvas.drawArc(
        rect, pi, pi, false,
        Paint()
          ..color = colors[i].withAlpha(210)
          ..style = PaintingStyle.stroke
          ..strokeWidth = bandW * 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  // ─── 🔥 Fire ────────────────────────────────────────────────────────────────

  void _drawFire() {
    final base = faceRect.top + _h * 0.04;
    final cx   = _center.dx;
    final fw   = _w * 1.05;

    // Draw flames back-to-front (outer first, center last)
    _flame(Offset(cx - fw * 0.32, base), fw * 0.3,  _h * 0.42,
        const Color(0xFFFF6B2B), const Color(0xFFFFD700));
    _flame(Offset(cx + fw * 0.3,  base), fw * 0.32, _h * 0.44,
        const Color(0xFFFF4500), const Color(0xFFFFDD00));
    _flame(Offset(cx - fw * 0.12, base), fw * 0.42, _h * 0.62,
        const Color(0xFFFF3300), const Color(0xFFFFAA00));
    _flame(Offset(cx + fw * 0.1,  base), fw * 0.38, _h * 0.58,
        const Color(0xFFFF4500), const Color(0xFFFFCC00));
    _flame(Offset(cx,             base), fw * 0.52, _h * 0.75,
        const Color(0xFFFF1A00), const Color(0xFFFFEE00));
  }

  void _flame(Offset base, double w, double h, Color colorBase, Color colorTip) {
    final path = Path()
      ..moveTo(base.dx - w / 2, base.dy)
      ..cubicTo(
        base.dx - w * 0.55, base.dy - h * 0.25,
        base.dx - w * 0.28, base.dy - h * 0.65,
        base.dx + w * 0.05, base.dy - h,
      )
      ..cubicTo(
        base.dx + w * 0.3,  base.dy - h * 0.65,
        base.dx + w * 0.55, base.dy - h * 0.25,
        base.dx + w / 2,    base.dy,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end:   Alignment.topCenter,
          colors: [colorBase, colorTip],
        ).createShader(Rect.fromLTWH(base.dx - w / 2, base.dy - h, w, h))
        ..style = PaintingStyle.fill,
    );
  }

  // ─── 😈 Devil ───────────────────────────────────────────────────────────────

  void _drawDevil() {
    // Horns
    _devilHorn(Offset(faceRect.left  + _w * 0.18, faceRect.top), _w * 0.22, _h * 0.52);
    _devilHorn(Offset(faceRect.right - _w * 0.18, faceRect.top), _w * 0.22, _h * 0.52);

    // Red tint over face
    canvas.drawOval(faceRect, _fill(Colors.red.withAlpha(35)));

    // Glowing red eyes
    for (final type in [FaceLandmarkType.leftEye, FaceLandmarkType.rightEye]) {
      final eye = getLandmark(type);
      if (eye != null) {
        // Glow
        canvas.drawCircle(eye, _w * 0.09,
            Paint()
              ..color = Colors.red.withAlpha(100)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        // Iris
        _circle(eye, _w * 0.055, const Color(0xFFCC0000));
        _circle(eye, _w * 0.028, Colors.black);
        _circle(Offset(eye.dx - _w * 0.015, eye.dy - _w * 0.015), _w * 0.012,
            Colors.white.withAlpha(180));
      }
    }

    // Goatee / forked beard
    final chin = getLandmark(FaceLandmarkType.bottomMouth)
        ?? Offset(_center.dx, faceRect.top + _h * 0.88);
    _goatee(chin);
  }

  void _devilHorn(Offset base, double w, double h) {
    // Shadow
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - w / 2, base.dy)
        ..quadraticBezierTo(base.dx - w * 0.3, base.dy - h * 0.6, base.dx + w * 0.05, base.dy - h)
        ..quadraticBezierTo(base.dx + w * 0.5, base.dy - h * 0.5, base.dx + w / 2, base.dy)
        ..close(),
      _fill(const Color(0xFF6B0000).withAlpha(160)),
    );
    // Horn body
    final hornPath = Path()
      ..moveTo(base.dx - w / 2, base.dy)
      ..quadraticBezierTo(base.dx - w * 0.35, base.dy - h * 0.55, base.dx, base.dy - h)
      ..quadraticBezierTo(base.dx + w * 0.35, base.dy - h * 0.55, base.dx + w / 2, base.dy)
      ..close();
    canvas.drawPath(hornPath, _fill(const Color(0xFFDD0000)));
    canvas.drawPath(hornPath, _stroke(const Color(0xFF8B0000), _w * 0.014));
    // Tip highlight
    _circle(Offset(base.dx, base.dy - h), _w * 0.018, const Color(0xFFFF6666));
  }

  void _goatee(Offset chin) {
    final p = _stroke(const Color(0xFF6B0000), _w * 0.02);
    final tw = _w * 0.12;
    // Left fork
    canvas.drawPath(
      Path()
        ..moveTo(chin.dx, chin.dy)
        ..quadraticBezierTo(chin.dx - tw * 0.5, chin.dy + _h * 0.06, chin.dx - tw, chin.dy + _h * 0.15),
      p,
    );
    // Right fork
    canvas.drawPath(
      Path()
        ..moveTo(chin.dx, chin.dy)
        ..quadraticBezierTo(chin.dx + tw * 0.5, chin.dy + _h * 0.06, chin.dx + tw, chin.dy + _h * 0.15),
      p,
    );
  }
}
