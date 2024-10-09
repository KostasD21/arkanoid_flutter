import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(ArcanoidGame());
  });
}

class ArcanoidGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcanoid Game',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainMenu(),
    );
  }
}

class MainMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Arcanoid Game')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
              child: Text('Start Game'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GameScreen()),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('Settings'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isMusicOn = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isMusicOn = prefs.getBool('isMusicOn') ?? true;
    });
  }

  _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isMusicOn', isMusicOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Music'),
            Switch(
              value: isMusicOn,
              onChanged: (value) {
                setState(() {
                  isMusicOn = value;
                });
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class Brick {
  final Rect rect;
  final Color color;
  bool isVisible;

  Brick(this.rect, this.color, {this.isVisible = true});
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  double paddlePosition = 0.0;
  double paddleWidth = 80.0;
  double paddleHeight = 15.0;
  double paddleSpeed = 10.0;
  
  Offset ballPosition = Offset.zero;
  double ballRadius = 10.0;
  Offset ballVelocity = Offset(3, 3);  // Initial downward direction
  
  late AnimationController _animationController;
  FocusNode _focusNode = FocusNode();

  List<Brick> bricks = [];
  int columns = 8;

  bool _isInitialized = false;

  late AudioPlayer effectPlayer;
  late AudioPlayer musicPlayer;

  double musicVolume = 0.5;

  int currentLevel = 1;
  int lives = 3;
  int maxLevels = 3;
  int score = 0;

  bool isMusicOn = true;

  ui.Image? ballImage;
  ui.Image? paddleImage;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _animationController.addListener(_updateGame);
    effectPlayer = AudioPlayer();
    musicPlayer = AudioPlayer();
    _loadSettings();
  }

  Future<void> _loadImages() async {
    setState(() {}); // Trigger a rebuild once images are loaded
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }

  _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isMusicOn = prefs.getBool('isMusicOn') ?? true;
    });
    if (isMusicOn) {
      _playBackgroundMusic();
    }
  }

  void _playBackgroundMusic() async {
    await musicPlayer.setReleaseMode(ReleaseMode.loop);
    await musicPlayer.setVolume(musicVolume);
    await musicPlayer.play(AssetSource('background_music.mp3'));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeGame();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    effectPlayer.dispose();
    musicPlayer.dispose();
    super.dispose();
  }

  void _initializeGame() {
    paddlePosition = 0.0;
    ballPosition = Offset(0, -50);
    _initializeBricks();
    lives = 3;
    currentLevel = 1;
    score = 0;
    _resetBall();
  }

  void _initializeBricks() {
    bricks.clear();
    final size = MediaQuery.of(context).size;
    double brickWidth = (size.width - (columns + 1) * 2) / columns;
    double brickHeight = 25.0;
    double gap = 2.0;

    int rows;
    switch (currentLevel) {
      case 1:
        rows = 3;
        break;
      case 2:
        rows = 4;
        break;
      case 3:
        rows = 5;
        break;
      default:
        rows = 3;
    }

    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        bricks.add(Brick(
          Rect.fromLTWH(
            j * (brickWidth + gap) + gap,
            i * (brickHeight + gap) + 50,
            brickWidth,
            brickHeight,
          ),
          Colors.primaries[(i * columns + j) % Colors.primaries.length],
        ));
      }
    }
  }

  void _updateGame() {
    setState(() {
      ballPosition += ballVelocity;
      _checkCollisions();
      _checkLevelCompletion();
    });
  }

  void _checkCollisions() {
    final size = MediaQuery.of(context).size;

    // Ball-Wall collisions
    if (ballPosition.dx - ballRadius <= -size.width / 2 ||
        ballPosition.dx + ballRadius >= size.width / 2) {
      ballVelocity = Offset(-ballVelocity.dx, ballVelocity.dy);
    }
    if (ballPosition.dy - ballRadius <= -size.height / 2) {
      ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy);
    }

    // Ball-Paddle collision
    double paddleTop = size.height / 2 - paddleHeight - 50;
    double paddleLeft = paddlePosition - paddleWidth / 2;
    double paddleRight = paddlePosition + paddleWidth / 2;

    double ballBottom = ballPosition.dy + ballRadius;

    if (ballBottom >= paddleTop && ballBottom <= paddleTop + paddleHeight &&
        ballPosition.dx >= paddleLeft && ballPosition.dx <= paddleRight) {
      ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy.abs());
      
      double hitPosition = (ballPosition.dx - paddleLeft) / paddleWidth;
      double newAngle = (hitPosition - 0.5) * math.pi / 3;
      double speed = ballVelocity.distance;
      ballVelocity = Offset(speed * math.sin(newAngle), -speed * math.cos(newAngle));
      
      ballPosition = Offset(ballPosition.dx, paddleTop - ballRadius);
    }

    // Ball-Brick collisions
    for (var brick in bricks) {
      if (brick.isVisible) {
        if (_ballIntersectsBrick(brick)) {
          brick.isVisible = false;
          effectPlayer.play(AssetSource('brick_break.mp3'));
          ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy);
          score += 10;
          break;
        }
      }
    }

    // Ball falls below paddle
    if (ballPosition.dy + ballRadius > size.height / 2) {
      lives--;
      if (lives > 0) {
        _resetBall();
      } else {
        _gameOver();
      }
    }
  }

  void _resetBall() {
    setState(() {
      ballPosition = Offset(0, -50);
      ballVelocity = Offset(3, 3);  // Ensure downward direction
    });
  }

  void _gameOver() {
    _animationController.stop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Game Over'),
          content: Text('You have lost all your lives. Final score: $score'),
          actions: <Widget>[
            TextButton(
              child: Text('Restart'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeGame();
                _animationController.repeat();
              },
            ),
          ],
        );
      },
    );
  }

  void _checkLevelCompletion() {
    if (bricks.every((brick) => !brick.isVisible)) {
      if (currentLevel < maxLevels) {
        _nextLevel();
      } else {
        _victoryScreen();
      }
    }
  }

  void _nextLevel() {
    currentLevel++;
    lives = 3;
    _resetBall();
    _initializeBricks();
    // Increase ball speed for higher difficulty, maintaining downward direction
    ballVelocity = Offset(ballVelocity.dx * 1.2, ballVelocity.dy.abs() * 1.2);
  }

  void _victoryScreen() {
    _animationController.stop();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Congratulations!'),
          content: Text('You have completed all levels! Final score: $score'),
          actions: <Widget>[
            TextButton(
              child: Text('Play Again'),
              onPressed: () {
                Navigator.of(context).pop();
                _initializeGame();
                _animationController.repeat();
              },
            ),
          ],
        );
      },
    );
  }

  bool _ballIntersectsBrick(Brick brick) {
    final ballRect = Rect.fromCircle(
      center: Offset(MediaQuery.of(context).size.width / 2.1 + ballPosition.dx, 
                     MediaQuery.of(context).size.height / 2.1 + ballPosition.dy),
      radius: ballRadius,
    );
    return ballRect.overlaps(brick.rect);
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      setState(() {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          paddlePosition -= paddleSpeed;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          paddlePosition += paddleSpeed;
        }
        _clampPaddlePosition();
      });
    }
  }

  void _clampPaddlePosition() {
    final size = MediaQuery.of(context).size;
    paddlePosition = paddlePosition.clamp(
      -size.width / 2 + paddleWidth / 2,
      size.width / 2 - paddleWidth / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arcanoid Game - Level $currentLevel'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            _animationController.stop();
            musicPlayer.stop();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: RawKeyboardListener(
              focusNode: _focusNode,
              onKey: _handleKeyEvent,
              autofocus: true,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    paddlePosition += details.delta.dx;
                    _clampPaddlePosition();
                  });
                },
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: GamePainter(
                        paddlePosition: paddlePosition,
                        paddleWidth: paddleWidth,
                        paddleHeight: paddleHeight,
                        ballPosition: ballPosition,
                        ballRadius: ballRadius,
                        bricks: bricks
                      ),
                      child: Container(),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Row(
                        children: List.generate(
                          lives,
                          (index) => Padding(
                            padding: const EdgeInsets.all(2.0),
                            child: Icon(Icons.sports_baseball, color: Colors.red, size: 20),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Text(
                        'Score: $score',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class GamePainter extends CustomPainter {
  final double paddlePosition;
  final double paddleWidth;
  final double paddleHeight;
  final Offset ballPosition;
  final double ballRadius;
  final List<Brick> bricks;

  GamePainter({
    required this.paddlePosition,
    required this.paddleWidth,
    required this.paddleHeight,
    required this.ballPosition,
    required this.ballRadius,
    required this.bricks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw bricks
    for (var brick in bricks) {
      if (brick.isVisible) {
        paint.color = brick.color;
        canvas.drawRect(brick.rect, paint);

        paint.color = Colors.black;
        paint.style = PaintingStyle.stroke;
        paint.strokeWidth = 1.0;
        canvas.drawRect(brick.rect, paint);
        paint.style = PaintingStyle.fill;
      }
    }

    // Draw metallic paddle
    final paddleRect = Rect.fromCenter(
      center: Offset(size.width / 2 + paddlePosition, size.height - 30),
      width: paddleWidth,
      height: paddleHeight,
    );
    _drawMetallicPaddle(canvas, paddleRect);

    // Draw metallic ball
    final ballCenter = Offset(size.width / 2 + ballPosition.dx, size.height / 2 + ballPosition.dy);
    _drawMetallicBall(canvas, ballCenter, ballRadius);
  }

  void _drawMetallicPaddle(Canvas canvas, Rect rect) {
    // Base metallic color
    final baseColor = Color(0xFF8E8E8E);

    // Gradient for metallic effect
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        baseColor.withOpacity(0.9),
        baseColor,
        baseColor.withOpacity(0.8),
      ],
      stops: [0.0, 0.5, 1.0],
    );

    // Draw main paddle body
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(paddleHeight / 2));
    canvas.drawRRect(rrect, paint);

    // Add highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final highlightRect = rect.deflate(2);
    final highlightRRect = RRect.fromRectAndRadius(highlightRect, Radius.circular((paddleHeight - 4) / 2));
    canvas.drawRRect(highlightRRect, highlightPaint);

    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final shadowRect = rect.inflate(1);
    final shadowRRect = RRect.fromRectAndRadius(shadowRect, Radius.circular((paddleHeight + 2) / 2));
    canvas.drawRRect(shadowRRect, shadowPaint);
  }

  void _drawMetallicBall(Canvas canvas, Offset center, double radius) {
    // Base metallic color for the ball
    final baseColor = Color(0xFFB0B0B0);

    // Gradient for metallic effect
    final gradient = RadialGradient(
      center: Alignment(-0.3, -0.3),
      radius: 0.8,
      colors: [
        Colors.white,
        baseColor,
        baseColor.withOpacity(0.8),
      ],
      stops: [0.0, 0.3, 1.0],
    );

    // Draw main ball body
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, radius, paint);

    // Add highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center.translate(-radius * 0.2, -radius * 0.2), radius * 0.2, highlightPaint);

    // Add shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    canvas.drawCircle(center, radius, shadowPaint);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) =>
      oldDelegate.paddlePosition != paddlePosition ||
      oldDelegate.ballPosition != ballPosition ||
      oldDelegate.bricks != bricks;
}