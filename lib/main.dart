import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(ArcanoidGame());

class ArcanoidGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arcanoid Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // Game state variables
  double paddlePosition = 0.0;
  double paddleWidth = 80.0;
  double paddleHeight = 15.0;
  double paddleSpeed = 10.0; // Speed for keyboard movement

  FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  void _initializeGame() {
    paddlePosition = 0.0;
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
    paddlePosition = paddlePosition.clamp(
      -MediaQuery.of(context).size.width / 2 + paddleWidth / 2,
      MediaQuery.of(context).size.width / 2 - paddleWidth / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Arcanoid Game'),
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
          child: CustomPaint(
            painter: GamePainter(
              paddlePosition: paddlePosition,
              paddleWidth: paddleWidth,
              paddleHeight: paddleHeight,
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

  GamePainter({
    required this.paddlePosition,
    required this.paddleWidth,
    required this.paddleHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw paddle
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final paddleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2 + paddlePosition, size.height - 30),
        width: paddleWidth,
        height: paddleHeight,
      ),
      Radius.circular(8),
    );

    canvas.drawRRect(paddleRect, paint);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) =>
      oldDelegate.paddlePosition != paddlePosition;
}