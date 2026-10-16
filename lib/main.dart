import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const QitApp());
}

class QitApp extends StatelessWidget {
  const QitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "قط الشارع",
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF87CEEB),
        body: GameWidget(game: QitGame()),
      ),
    );
  }
}

// ============================================================
// GAME
// ============================================================
class QitGame extends FlameGame with DragCallbacks {
  double _score = 0;
  int _highScore = 0;
  bool _gameOver = false;

  late Cat _cat;
  final List<Platform> _platforms = [];
  final List<Food> _foods = [];

  double _cameraY = 0;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);

  @override
  Future<void> onLoad() async {
    await _loadHighScore();

    // القط
    _cat = Cat(game: this);
    _cat.position = Vector2(size.x / 2 - 25, size.y - 300);
    add(_cat);

    // أول مجموعة أسطح
    double y = size.y - 200;
    for (int i = 0; i < 8; i++) {
      _addPlatform(y);
      y -= 100 + math.Random().nextDouble() * 50;
    }
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    _highScore = prefs.getInt('qit_high') ?? 0;
  }

  Future<void> _saveHighScore() async {
    if (_score.toInt() > _highScore) {
      _highScore = _score.toInt();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('qit_high', _highScore);
    }
  }

  void _addPlatform(double y) {
    final rng = math.Random();
    final x = 20 + rng.nextDouble() * (size.x - 120);
    final p = Platform(x: x, y: y);
    _platforms.add(p);
    add(p);

    // 30% فرصة يكون فيه أكل
    if (rng.nextDouble() < 0.3) {
      final type = rng.nextBool() ? FoodType.fish : FoodType.milk;
      final f = Food(
        x: x + p.size.x / 2 - 15,
        y: y - 40,
        type: type,
      );
      _foods.add(f);
      add(f);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_gameOver) return;

    // تحريك الأسطح والأكل لتحت (الكاميرا بتطلع)
    final scrollSpeed = 200.0 * dt;

    for (final p in _platforms) {
      p.position.y += scrollSpeed;
    }
    for (final f in _foods) {
      f.position.y += scrollSpeed;
    }

    // القط بينزل لتحت
    _cat.velocityY += 1200 * dt;
    _cat.position.y += _cat.velocityY * dt;

    // اصطدام مع الأسطح (لو بينزل)
    if (_cat.velocityY > 0) {
      for (final p in _platforms) {
        final catBottom = _cat.position.y + _cat.size.y;
        final catCenterX = _cat.position.x + _cat.size.x / 2;
        final platTop = p.position.y;
        final platLeft = p.position.x;
        final platRight = p.position.x + p.size.x;

        if (catBottom >= platTop &&
            catBottom <= platTop + 30 &&
            catCenterX >= platLeft &&
            catCenterX <= platRight) {
          _cat.velocityY = -700;
          break;
        }
      }
    }

    // جمع الأكل
    for (int i = _foods.length - 1; i >= 0; i--) {
      final f = _foods[i];
      if (_cat.position.x < f.position.x + f.size.x &&
          _cat.position.x + _cat.size.x > f.position.x &&
          _cat.position.y < f.position.y + f.size.y &&
          _cat.position.y + _cat.size.y > f.position.y) {
        _score += f.points;
        f.removeFromParent();
        _foods.removeAt(i);
      }
    }

    // شيل اللي خرج من الشاشة
    _platforms.removeWhere((p) {
      if (p.position.y > size.y + 100) {
        p.removeFromParent();
        return true;
      }
      return false;
    });
    _foods.removeWhere((f) {
      if (f.position.y > size.y + 100) {
        f.removeFromParent();
        return true;
      }
      return false;
    });

    // نضيف أسطح جديدة فوق
    final topMost = _platforms.isEmpty
        ? size.y
        : _platforms.map((p) => p.position.y).reduce(math.min);
    if (topMost > -100) {
      _addPlatform(topMost - 120 - math.Random().nextDouble() * 60);
    }

    // لو القط خرج من تحت الشاشة → خسر
    if (_cat.position.y > size.y + 50) {
      _gameOver = true;
      _saveHighScore();
    }
  }

  void moveLeft() {
    _cat.position.x -= 25;
    if (_cat.position.x < 0) _cat.position.x = 0;
  }

  void moveRight() {
    _cat.position.x += 25;
    if (_cat.position.x > size.x - _cat.size.x) {
      _cat.position.x = size.x - _cat.size.x;
    }
  }

  Vector2? _lastDrag;

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (_gameOver) return;
    if (_lastDrag == null) {
      _lastDrag = event.localEndPosition.clone();
      return;
    }
    final current = event.localEndPosition;
    final dx = current.x - _lastDrag!.x;
    if (dx.abs() > 5) {
      _cat.position.x += dx * 0.5;
      if (_cat.position.x < 0) _cat.position.x = 0;
      if (_cat.position.x > size.x - _cat.size.x) {
        _cat.position.x = size.x - _cat.size.x;
      }
      _lastDrag = current.clone();
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    _lastDrag = null;
  }

  @override
  void onDragStart(DragStartEvent event) {
    _lastDrag = event.localEndPosition.clone();
  }

  @override
  void render(Canvas canvas) {
    // 1. السماء (تدريج أزرق)
    final sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF4A90C2),
          Color(0xFF87CEEB),
          Color(0xFFE8D8B0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), sky);

    // 2. نخل و مباني (خلفية)
    _drawBackground(canvas);

    // 3. HUD
    _drawHud(canvas);

    // 4. Game Over
    if (_gameOver) _drawGameOver(canvas);
  }

  void _drawBackground(Canvas canvas) {
    // مباني بسيطة في الخلف
    final buildingColor = const Color(0xFFB8A88C).withOpacity(0.4);
    canvas.drawRect(
      Rect.fromLTWH(20, size.y * 0.4, 60, size.y * 0.6),
      Paint()..color = buildingColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.x - 80, size.y * 0.3, 60, size.y * 0.7),
      Paint()..color = buildingColor,
    );
  }

  void _drawHud(Canvas canvas) {
    // النقاط
    final scoreTp = TextPainter(
      text: TextSpan(
        text: 'النقاط: ${_score.toInt()}',
        style: const TextStyle(
          color: Color(0xFFFFD54A),
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(15, 15, scoreTp.width + 30, scoreTp.height + 20),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    scoreTp.paint(canvas, const Offset(30, 25));

    // أعلى نتيجة
    final highTp = TextPainter(
      text: TextSpan(
        text: '🏆 أعلى: $_highScore',
        style: const TextStyle(
          color: Color(0xFFFF9B4A),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.x - highTp.width - 45,
          15,
          highTp.width + 30,
          highTp.height + 20,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    highTp.paint(canvas, Offset(size.x - highTp.width - 30, 25));
  }

  void _drawGameOver(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, size.y),
      Paint()..color = Colors.black.withOpacity(0.75),
    );

    final titleTp = TextPainter(
      text: const TextSpan(
        text: 'القط وقع!',
        style: TextStyle(
          color: Color(0xFFE24A4A),
          fontSize: 44,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    titleTp.paint(
      canvas,
      Offset((size.x - titleTp.width) / 2, size.y / 2 - 120),
    );

    final scoreTp = TextPainter(
      text: TextSpan(
        text: 'النقاط: ${_score.toInt()}',
        style: const TextStyle(
          color: Color(0xFFFFD54A),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    scoreTp.paint(
      canvas,
      Offset((size.x - scoreTp.width) / 2, size.y / 2 - 40),
    );

    final highTp = TextPainter(
      text: TextSpan(
        text: '🏆 أعلى نتيجة: $_highScore',
        style: const TextStyle(
          color: Color(0xFFFF9B4A),
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    highTp.paint(
      canvas,
      Offset((size.x - highTp.width) / 2, size.y / 2 + 20),
    );

    final hintTp = TextPainter(
      text: const TextSpan(
        text: 'دوس على الشاشة عشان تلعب تاني',
        style: TextStyle(color: Colors.white70, fontSize: 16),
      ),
      textDirection: TextDirection.rtl,
    )..layout();
    hintTp.paint(
      canvas,
      Offset((size.x - hintTp.width) / 2, size.y / 2 + 90),
    );
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (_gameOver) _reset();
  }

  void _reset() {
    for (final p in _platforms) p.removeFromParent();
    for (final f in _foods) f.removeFromParent();
    _platforms.clear();
    _foods.clear();

    _cat.position = Vector2(size.x / 2 - 25, size.y - 300);
    _cat.velocityY = -700;

    double y = size.y - 200;
    for (int i = 0; i < 8; i++) {
      _addPlatform(y);
      y -= 100 + math.Random().nextDouble() * 50;
    }

    _score = 0;
    _gameOver = false;
  }
}

// ============================================================
// CAT
// ============================================================
class Cat extends PositionComponent {
  final QitGame game;
  double velocityY = -700;

  Cat({required this.game})
      : super(size: Vector2(50, 50));

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // ظل
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w / 2, h + 5),
        width: w * 0.8,
        height: 8,
      ),
      Paint()..color = Colors.black.withOpacity(0.25),
    );

    // جسم القط (رمادي)
    final body = Paint()..color = const Color(0xFF8A8A8A);
    canvas.drawOval(
      Rect.fromLTWH(5, 15, w - 10, h - 25),
      body,
    );

    // راس
    canvas.drawCircle(
      Offset(w / 2, 15),
      12,
      body,
    );

    // ودان
    canvas.drawCircle(
      Offset(w / 2 - 8, 5),
      5,
      body,
    );
    canvas.drawCircle(
      Offset(w / 2 + 8, 5),
      5,
      body,
    );

    // عيون
    final eye = Paint()..color = const Color(0xFF4AD7FF);
    canvas.drawCircle(Offset(w / 2 - 4, 13), 2.5, eye);
    canvas.drawCircle(Offset(w / 2 + 4, 13), 2.5, eye);

    final pupil = Paint()..color = Colors.black;
    canvas.drawCircle(Offset(w / 2 - 4, 13), 1.2, pupil);
    canvas.drawCircle(Offset(w / 2 + 4, 13), 1.2, pupil);

    // أنف
    canvas.drawCircle(
      Offset(w / 2, 17),
      1.5,
      Paint()..color = const Color(0xFFFF9B9B),
    );

    // شنب
    final whisker = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    canvas.drawLine(Offset(w / 2 - 12, 17), Offset(w / 2 - 5, 17), whisker);
    canvas.drawLine(Offset(w / 2 + 5, 17), Offset(w / 2 + 12, 17), whisker);

    // ذيل
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w - 5, 30), radius: 12),
      -1.5,
      2.5,
      false,
      Paint()
        ..color = const Color(0xFF8A8A8A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
  }
}

// ============================================================
// PLATFORM
// ============================================================
class Platform extends PositionComponent {
  Platform({required double x, required double y})
      : super(
          position: Vector2(x, y),
          size: Vector2(100, 20),
        );

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;

    // سطح
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, h),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF8B5A2B),
    );

    // خط أفتح فوق
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, 6),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFC98944),
    );

    // خطوط خشب
    final linePaint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1.5;
    for (double x = 15; x < w; x += 25) {
      canvas.drawLine(Offset(x, 5), Offset(x, h - 3), linePaint);
    }
  }
}

// ============================================================
// FOOD
// ============================================================
enum FoodType { fish, milk }

class Food extends PositionComponent {
  final FoodType type;

  Food({
    required double x,
    required double y,
    required this.type,
  }) : super(
          position: Vector2(x, y),
          size: Vector2(30, 30),
        );

  int get points => type == FoodType.fish ? 10 : 20;

  @override
  void render(Canvas canvas) {
    if (type == FoodType.fish) {
      _drawFish(canvas);
    } else {
      _drawMilk(canvas);
    }
  }

  void _drawFish(Canvas canvas) {
    // جسم السمكة
    canvas.drawOval(
      Rect.fromLTWH(3, 8, size.x - 6, size.y - 16),
      Paint()..color = const Color(0xFF4A90E2),
    );
    // راس
    canvas.drawCircle(
      Offset(size.x - 8, size.y / 2),
      5,
      Paint()..color = const Color(0xFF4A90E2),
    );
    // عين
    canvas.drawCircle(
      Offset(size.x - 8, size.y / 2 - 1),
      1.5,
      Paint()..color = Colors.white,
    );
    // زعنفة
    canvas.drawPath(
      Path()
        ..moveTo(3, size.y / 2)
        ..lineTo(-3, size.y / 2 - 5)
        ..lineTo(-3, size.y / 2 + 5)
        ..close(),
      Paint()..color = const Color(0xFF2A6BAA),
    );
  }

  void _drawMilk(Canvas canvas) {
    // علبة لبن
    canvas.drawRect(
      Rect.fromLTWH(7, 5, size.x - 14, size.y - 8),
      Paint()..color = Colors.white,
    );
    // خط أزرق
    canvas.drawRect(
      Rect.fromLTWH(7, size.y - 14, size.x - 14, 6),
      Paint()..color = const Color(0xFF4A90E2),
    );
    // إطار
    canvas.drawRect(
      Rect.fromLTWH(7, 5, size.x - 14, size.y - 8),
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}