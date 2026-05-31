import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

typedef OnRaceFinished = void Function(int winnerIndex);

class DuckRaceGame extends FlameGame {
  final List<double> positions;
  final OnRaceFinished? onRaceFinished;

  DuckRaceGame({required this.positions, this.onRaceFinished});

  // ── Internal state ──────────────────────────────────────────────────────────
  final List<DuckComponent> _ducks = [];
  TrackComponent? _track;
  final _rng = Random();
  final List<double> _speeds = [0, 0, 0, 0, 0];
  bool _racing = false;
  bool _finished = false;
  double _startX = 0;
  double _finishX = 0;

  // Khai báo danh sách ảnh (Không cần cấu hình cứng thông số nữa)
  static const _duckAssets = [
    'duck_cyber_orange_spritesheet.png', // Vịt 1
    'duck_cyber_white_spritesheet.png',  // Vịt 2
    'duck_cyber_yellow_spritesheet.png', // Vịt 3
    'duck_cyber_green_spritesheet.png',  // Vịt 4
    'duck_cyber_purple_spritesheet.png', // Vịt 5
  ];

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
      _track = TrackComponent();
      add(_track!);

      for (int i = 0; i < 5; i++) {
        final sheet = await images.load(_duckAssets[i]);

        // 🔥 CÔNG THỨC VÀNG: Ảnh dải ngang (Single-row strip)
        // Mỗi frame là 1 hình vuông nên Width/Height của 1 frame chính bằng sheet.height
        final frameSize = sheet.height.toDouble();

        // Tự động tính số lượng khung hình (Ví dụ: ảnh 3072px / 256px = 12 khung hình)
        final exactFrameCount = (sheet.width / sheet.height).round();

        final animation = SpriteAnimation.fromFrameData(
          sheet,
          SpriteAnimationData.sequenced(
            amount: exactFrameCount,
            amountPerRow: exactFrameCount, // Tất cả nằm trên 1 hàng ngang
            stepTime: 0.05,                // Tốc độ vỗ cánh
            textureSize: Vector2(frameSize, frameSize),
            loop: true,
          ),
        );

        final duck = DuckComponent(animation: animation, laneIndex: i);
        _ducks.add(duck);
        add(duck);
      }

      _resetPositions();
      onGameResize(size);
    } catch (e) {
      debugPrint('DuckRaceGame.onLoad() ERROR: $e');
      rethrow;
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────
  void startRace() {
    if (_finished) _resetPositions();
    _finished = false;
    _racing = true;
    for (int i = 0; i < 5; i++) {
      _speeds[i] = 0.12 + _rng.nextDouble() * 0.10;
    }
    for (final d in _ducks) {
      d.playing = true;
    }
  }

  void stopRace() {
    _racing = false;
    for (final d in _ducks) {
      d.playing = false;
      d.animationTicker?.reset();
    }
  }

  void resetRace() {
    _racing = false;
    _finished = false;
    _resetPositions();
  }

  // ── Internal ────────────────────────────────────────────────────────────────
  void _resetPositions() {
    for (int i = 0; i < 5; i++) {
      positions[i] = 0.0;
    }
    _layoutDucks();
    for (final d in _ducks) {
      d.playing = false;
      d.animationTicker?.reset();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _track?.size = size;
    _startX = size.x * 0.12;
    _finishX = size.x * 0.88;
    if (_ducks.isNotEmpty) _layoutDucks();
  }

  void _layoutDucks() {
    if (_ducks.isEmpty) return;
    final laneH = size.y / 5;

    const kAspect = 1.0;
    final duckH = laneH * 0.82;
    final duckW = duckH * kAspect;

    for (int i = 0; i < _ducks.length; i++) {
      final duck = _ducks[i];
      duck.size = Vector2(duckW, duckH);
      final usable = _finishX - _startX - duckW;
      duck.position = Vector2(
        _startX + positions[i].clamp(0.0, 1.0) * usable,
        i * laneH + (laneH - duckH) / 2,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_racing || _finished) return;

    const kAspect = 1.0;
    final laneH = size.y / 5;
    final duckH = laneH * 0.82;
    final duckW = duckH * kAspect;
    final usable = _finishX - _startX - duckW;

    bool someoneFinished = false;
    int winnerIdx = -1;

    for (int i = 0; i < 5; i++) {
      positions[i] += (_speeds[i] + _rng.nextDouble() * 0.04) * dt;

      if (positions[i] >= 1.0) {
        positions[i] = 1.0;
        if (!someoneFinished) {
          someoneFinished = true;
          winnerIdx = i;
        }
      }

      final duck = _ducks[i];
      duck.x = _startX + positions[i] * usable;
      duck.y = i * laneH + (laneH - duckH) / 2;
    }

    if (someoneFinished) {
      _finished = true;
      _racing = false;
      for (final d in _ducks) {
        d.playing = false;
      }
      onRaceFinished?.call(winnerIdx + 1);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Track Component
// ─────────────────────────────────────────────────────────────────────────────
class TrackComponent extends PositionComponent {
  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final laneH = h / 5;

    canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2B2D31));

    final dashPaint = Paint()
      ..color = Colors.white.withAlpha(100)
      ..strokeWidth = 2;
    for (int i = 1; i < 5; i++) {
      final y = i * laneH;
      for (double x = 0; x < w; x += 36) {
        canvas.drawLine(Offset(x, y), Offset(x + 18, y), dashPaint);
      }
    }

    final grassPaint = Paint()..color = const Color(0xFF388E3C);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 8), grassPaint);
    canvas.drawRect(Rect.fromLTWH(0, h - 8, w, 8), grassPaint);

    _drawFlagLine(canvas, w * 0.12, h);
    _drawLabel(canvas, 'START', w * 0.12, h, isStart: true);

    _drawFlagLine(canvas, w * 0.88, h);
    _drawLabel(canvas, 'FINISH', w * 0.88, h, isStart: false);
  }

  void _drawFlagLine(Canvas canvas, double x, double h) {
    const sq = 14.0;
    final black = Paint()..color = Colors.black;
    final white = Paint()..color = Colors.white;
    for (double y = 0; y < h; y += sq) {
      final row = (y / sq).floor();
      for (int col = 0; col < 2; col++) {
        canvas.drawRect(
          Rect.fromLTWH(x + col * sq - sq, y, sq, sq),
          (row + col) % 2 == 0 ? black : white,
        );
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, double x, double h,
      {required bool isStart}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.yellowAccent,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    final dx = isStart ? x - tp.height - 2 : x + 2;
    canvas.translate(dx, h / 2 + tp.width / 2);
    canvas.rotate(-1.5708);
    tp.paint(canvas, Offset.zero);
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Duck Component
// ─────────────────────────────────────────────────────────────────────────────
class DuckComponent extends SpriteAnimationComponent {
  final int laneIndex;
  final Paint? tintPaint;

  DuckComponent({
    required SpriteAnimation animation,
    required this.laneIndex,
    this.tintPaint,
  }) : super(animation: animation);

  @override
  void render(Canvas canvas) {
    if (tintPaint != null) paint = tintPaint!;
    super.render(canvas);
  }
}