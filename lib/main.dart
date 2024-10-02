import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

void main() => runApp(ArcanoidGame());

class ArcanoidGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcanoid Game',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: GameScreen(),
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
  Offset ballVelocity = Offset(3, -3);
  
  late AnimationController _animationController;
  FocusNode _focusNode = FocusNode();

  List<Brick> bricks = [];
  int rows = 5;
  int columns = 8;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _animationController.addListener(_updateGame);
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
    super.dispose();
  }

  void _initializeGame() {
    paddlePosition = 0.0;
    ballPosition = Offset(0, -50); // Start the ball above the paddle
    _initializeBricks();
  }

  void _initializeBricks() {
    bricks.clear();
    final size = MediaQuery.of(context).size;
    double brickWidth = size.width / columns;
    double brickHeight = 30.0;
    for (int i = 0; i < rows; i++) {
      for (int j = 0; j < columns; j++) {
        bricks.add(Brick(
          Rect.fromLTWH(
            j * brickWidth,
            i * brickHeight + 50, // Start 50 pixels from the top
            brickWidth,
            brickHeight,
          ),
          Colors.primaries[i % Colors.primaries.length],
        ));
      }
    }
  }

  void _updateGame() {
    setState(() {
      ballPosition += ballVelocity;
      _checkCollisions();
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

  // Calculate the bottom of the ball
  double ballBottom = ballPosition.dy + ballRadius;

  // Check if the bottom of the ball is at or below the top of the paddle,
  // and if the ball's center is within the paddle's width
  if (ballBottom >= paddleTop && ballBottom <= paddleTop + paddleHeight &&
      ballPosition.dx >= paddleLeft && ballPosition.dx <= paddleRight) {
    
    // Reverse the vertical direction
    ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy.abs());
    
    // Adjust horizontal velocity based on where the ball hit the paddle
    double hitPosition = (ballPosition.dx - paddleLeft) / paddleWidth;
    double newAngle = (hitPosition - 0.5) * math.pi / 3; // -30 to 30 degrees
    double speed = ballVelocity.distance;
    ballVelocity = Offset(speed * math.sin(newAngle), -speed * math.cos(newAngle));
    
    // Ensure the ball is above the paddle
    ballPosition = Offset(ballPosition.dx, paddleTop - ballRadius);
  }

  // Ball-Brick collisions
  for (var brick in bricks) {
    if (brick.isVisible) {
      if (_ballIntersectsBrick(brick)) {
        brick.isVisible = false;
        // Reverse ball direction
        ballVelocity = Offset(ballVelocity.dx, -ballVelocity.dy);
        break; // Assume the ball can only hit one brick per frame
      }
    }
  }

  // Ball falls below paddle
  if (ballPosition.dy + ballRadius > size.height / 2) {
    _initializeGame();
  }
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
      appBar: AppBar(title: Text('Arcanoid Game')),
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
          child: CustomPaint(
            painter: GamePainter(
              paddlePosition: paddlePosition,
              paddleWidth: paddleWidth,
              paddleHeight: paddleHeight,
              ballPosition: ballPosition,
              ballRadius: ballRadius,
              bricks: bricks,
            ),
            child: Container(),
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
      }
    }

    // Draw paddle
    paint.color = Colors.blue;
    final paddleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2 + paddlePosition, size.height - 30),
        width: paddleWidth,
        height: paddleHeight,
      ),
      Radius.circular(8),
    );
    canvas.drawRRect(paddleRect, paint);

    // Draw ball
    canvas.drawCircle(
      Offset(size.width / 2 + ballPosition.dx, size.height / 2 + ballPosition.dy),
      ballRadius,
      paint,
    );
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) =>
      oldDelegate.paddlePosition != paddlePosition ||
      oldDelegate.ballPosition != ballPosition ||
      oldDelegate.bricks != bricks;
}