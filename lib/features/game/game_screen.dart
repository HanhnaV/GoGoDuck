import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../betting/bloc/betting_bloc.dart';
import '../betting/bloc/betting_event.dart';
import '../betting/bloc/betting_state.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_state.dart';
import 'game_logic_service.dart';

enum RaceState { idle, betting, racing, finished }

class GameScreen extends StatefulWidget {
  final String? raceId;

  const GameScreen({super.key, this.raceId});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final String _raceId;
  late final GameLogicService _gameService;

  StreamSubscription<DatabaseEvent>? _duckSubscription;
  StreamSubscription<DatabaseEvent>? _statusSubscription;

  RaceState _raceState = RaceState.idle;
  double _p1 = 0.0, _p2 = 0.0, _p3 = 0.0, _p4 = 0.0, _p5 = 0.0;
  int _winningDuck = 0;
  int _timeLeft = 30;
  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedDuck;
  final _amountController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _raceId = widget.raceId ?? 'demo_race';
    _gameService = GameLogicService();
    _listenToRaceStatus();
  }

  void _listenToRaceStatus() {
    _statusSubscription?.cancel();
    _statusSubscription = FirebaseDatabase.instance
        .ref('live_races/$_raceId')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final value = event.snapshot.value;
      if (value == null) return;

      final data = Map<String, dynamic>.from(value as Map);
      final status = data['status'] as String? ?? 'idle';
      final timeLeft = data['time_left'] as int? ?? 30;

      setState(() {
        _timeLeft = timeLeft;
        if (status == 'betting') {
          _raceState = RaceState.betting;
          _selectedDuck = null;
          _startDuckListener();
        } else if (status == 'racing') {
          _raceState = RaceState.racing;
          _selectedDuck = null;
          _startDuckListener();
        } else if (status == 'finished') {
          _raceState = RaceState.finished;
          _winningDuck = data['winning_duck'] as int? ?? 0;
        } else {
          _raceState = RaceState.idle;
        }
      });
    });
  }

  void _startDuckListener() {
    _duckSubscription?.cancel();
    _duckSubscription = FirebaseDatabase.instance
        .ref('live_races/$_raceId/ducks')
        .onValue
        .listen((event) {
      if (!mounted) return;
      final value = event.snapshot.value;
      if (value == null) return;

      final data = Map<String, dynamic>.from(value as Map);
      setState(() {
        _p1 = _parseDouble(data['duck_1']?['position']);
        _p2 = _parseDouble(data['duck_2']?['position']);
        _p3 = _parseDouble(data['duck_3']?['position']);
        _p4 = _parseDouble(data['duck_4']?['position']);
        _p5 = _parseDouble(data['duck_5']?['position']);
      });
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _startBetting() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _gameService.startNewRacePeriod(_raceId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _p1 = _p2 = _p3 = _p4 = _p5 = 0.0;
          _winningDuck = 0;
          _selectedDuck = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể bắt đầu cược: $e';
        });
      }
    }
  }

  void _placeBet() {
    if (_selectedDuck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một con vịt!')),
      );
      return;
    }

    final amountText = _amountController.text.trim();
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ!')),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa đăng nhập!')),
      );
      return;
    }

    context.read<BettingBloc>().add(SubmitBetEvent(
      uid: authState.user.uid,
      raceId: _raceId,
      duckIndex: _selectedDuck!,
      amount: amount,
    ));
  }

  Future<void> _runRace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _gameService.runDuckRaceLoop(_raceId);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể chạy đua: $e';
        });
      }
    }
  }

  Future<void> _resetRace() async {
    setState(() => _isLoading = true);
    try {
      await _gameService.resetRace(_raceId);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _raceState = RaceState.idle;
          _p1 = _p2 = _p3 = _p4 = _p5 = 0.0;
          _winningDuck = 0;
          _timeLeft = 30;
          _selectedDuck = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Không thể reset: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _duckSubscription?.cancel();
    _statusSubscription?.cancel();
    _amountController.dispose();
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trường Đua Vịt 2D'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: BlocListener<BettingBloc, BettingState>(
        listener: (context, state) {
          if (state is BettingSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Đặt cược thành công!'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<BettingBloc>().add(ResetBettingState());
          } else if (state is BettingFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error),
                backgroundColor: Colors.red,
              ),
            );
            context.read<BettingBloc>().add(ResetBettingState());
          }
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_raceState) {
      case RaceState.idle:
        return _buildIdleState();
      case RaceState.betting:
        return _buildBettingState();
      case RaceState.racing:
        return _buildRacingState();
      case RaceState.finished:
        return _buildFinishedState();
    }
  }

  Widget _buildIdleState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sports_score, size: 80, color: Colors.orange),
          const SizedBox(height: 24),
          const Text(
            'Sẵn sàng đua vịt!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          if (_isLoading)
            const CircularProgressIndicator()
          else ...[
            ElevatedButton.icon(
              onPressed: _startBetting,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Bắt đầu đặt cược'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBettingState() {
    return Stack(
      children: [
        Column(
          children: [
            _buildCountdownHeader(),
            Expanded(child: _buildRaceTrack()),
          ],
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBettingPanel(),
        ),
      ],
    );
  }

  Widget _buildCountdownHeader() {
    final isUrgent = _timeLeft <= 10;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isUrgent ? Colors.red : Colors.orange,
      child: Column(
        children: [
          const Text(
            'THỜI GIAN ĐẶT CƯỢC',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$_timeLeft',
            style: TextStyle(
              color: Colors.white,
              fontSize: isUrgent ? 56 : 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'giây',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBettingPanel() {
    final duckColors = [
      Colors.yellow.shade700,
      Colors.cyan.shade700,
      Colors.pink.shade700,
      Colors.green.shade700,
      Colors.orange.shade700,
    ];

    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Chọn vịt bạn tin sẽ thắng!',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final duckNum = index + 1;
              final isSelected = _selectedDuck == duckNum;
              return GestureDetector(
                onTap: () => setState(() => _selectedDuck = duckNum),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: duckColors[index],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: isSelected
                            ? [BoxShadow(color: duckColors[index], blurRadius: 12)]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$duckNum',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vịt $duckNum',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Tiền cược: ',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Nhập số tiền',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<BettingBloc, BettingState>(
            builder: (context, state) {
              return Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: state is BettingLoading ? null : _placeBet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: state is BettingLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'ĐẶT CƯỢC',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _runRace,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'BẮT ĐẦU ĐUA',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              );
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRacingState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.red,
          child: const Text(
            '🦆 ĐANG ĐUA! 🦆',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(child: _buildRaceTrack()),
        _buildLegend(),
      ],
    );
  }

  Widget _buildFinishedState() {
    final duckColors = [
      Colors.yellow,
      Colors.cyan,
      Colors.pink,
      Colors.green,
      Colors.orange,
    ];
    final winnerColor =
        _winningDuck >= 1 && _winningDuck <= 5
            ? duckColors[_winningDuck - 1]
            : Colors.grey;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'KẾT QUẢ',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          if (_winningDuck >= 1 && _winningDuck <= 5) ...[
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: winnerColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Center(
                child: Text(
                  '$_winningDuck',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'VỊT $_winningDuck THẮNG CUỘC!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: winnerColor,
              ),
            ),
          ] else ...[
            const Text(
              'Không có vịt thắng',
              style: TextStyle(fontSize: 22, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 40),
          if (_isLoading)
            const CircularProgressIndicator()
          else
            ElevatedButton.icon(
              onPressed: _resetRace,
              icon: const Icon(Icons.refresh),
              label: const Text('Đua lại'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }

  Widget _buildRaceTrack() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: CustomPaint(
        painter: DuckRacePainter(p1: _p1, p2: _p2, p3: _p3, p4: _p4, p5: _p5),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildLegend() {
    final ducks = [
      (Colors.yellow, 'Vịt 1', _p1),
      (Colors.cyan, 'Vịt 2', _p2),
      (Colors.pink, 'Vịt 3', _p3),
      (Colors.green, 'Vịt 4', _p4),
      (Colors.orange, 'Vịt 5', _p5),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey.shade900,
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: ducks.map((d) {
          final pct = d.$3.clamp(0.0, 100.0).toStringAsFixed(1);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: d.$1, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                '${d.$2}: $pct%',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class DuckRacePainter extends CustomPainter {
  final double p1, p2, p3, p4, p5;

  DuckRacePainter({
    required this.p1,
    required this.p2,
    required this.p3,
    required this.p4,
    required this.p5,
  });

  static const double _finishLineOffset = 40.0;
  static const List<Color> _duckColors = [
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
    Colors.green,
    Colors.orange,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final laneHeight = size.height / 5;
    final trackWidth = size.width - _finishLineOffset;

    paint.color = Colors.white24;
    paint.strokeWidth = 1;
    for (int i = 1; i < 5; i++) {
      final y = i * laneHeight;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), paint);
    }

    paint.color = Colors.red;
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width - _finishLineOffset, 0),
      Offset(size.width - _finishLineOffset, size.height),
      paint,
    );

    final positions = [p1, p2, p3, p4, p5];
    for (int i = 0; i < 5; i++) {
      final laneCenterY = laneHeight * i + laneHeight / 2;
      final clampedPos = positions[i].clamp(0.0, 100.0);
      final xPixel = (clampedPos / 100.0) * trackWidth;

      paint.color = _duckColors[i];
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(xPixel, laneCenterY), 16, paint);

      final textSpan = TextSpan(
        text: '${i + 1}',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(xPixel - textPainter.width / 2, laneCenterY - textPainter.height / 2),
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final totalDist = math.sqrt(dx * dx + dy * dy);
    if (totalDist < 1) return;
    final dirX = dx / totalDist;
    final dirY = dy / totalDist;
    const step = 8.0;
    const dashLen = 4.0;
    var t = 0.0;
    while (t < totalDist) {
      final endT = math.min(t + dashLen, totalDist);
      canvas.drawLine(
        Offset(a.dx + dirX * t, a.dy + dirY * t),
        Offset(a.dx + dirX * endT, a.dy + dirY * endT),
        paint,
      );
      t += step;
    }
  }

  @override
  bool shouldRepaint(covariant DuckRacePainter oldDelegate) => true;
}
