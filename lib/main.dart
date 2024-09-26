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

  @override
  void initState() {
    super.initState();
    _initializeGame();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _animationController.addListener(_updateGame);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initializeGame() {
    paddlePosition = 0.0;
    ballPosition = Offset(0, -50); // Start the ball above the paddle
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
    if (ballPosition.dy + ballRadius >= size.height / 2 - paddleHeight - 30) {
      if (ballPosition.dx >= paddlePosition - paddleWidth / 2 &&
          ballPosition.dx <= paddlePosition + paddleWidth / 2) {
        ballVelocity = Offset(
          (ballPosition.dx - paddlePosition) / (paddleWidth / 2) * 5,
          -ballVelocity.dy.abs()
        );
      } else if (ballPosition.dy > size.height / 2) {
        // Ball fell below paddle, reset the game
        _initializeGame();
      }
    }
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

  GamePainter({
    required this.paddlePosition,
    required this.paddleWidth,
    required this.paddleHeight,
    required this.ballPosition,
    required this.ballRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    // Draw paddle
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
      oldDelegate.ballPosition != ballPosition;
}