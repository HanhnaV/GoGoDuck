import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';

import 'game_logic_service.dart';
import 'duck_race_game.dart';

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
  bool _isLoading = false;
  String? _errorMessage;

  DuckRaceGame? _duckRaceGame;

  int _selectedDuck = 1;
  int _betAmount = 10;
  bool _hasPlacedBet = false;

  final List<String> _duckSprites = [
    'assets/images/duck_cyber_orange_spritesheet.png',
    'assets/images/duck_cyber_white_spritesheet.png',
    'assets/images/duck_cyber_yellow_spritesheet.png',
    'assets/images/duck_cyber_green_spritesheet.png',
    'assets/images/duck_cyber_purple_spritesheet.png',
  ];

  @override
  void initState() {
    super.initState();
    FlameAudio.audioCache.loadAll(['sfx_quack.mp3', 'sfx_win.mp3']);
    _raceId = widget.raceId ?? 'demo_race';
    _gameService = GameLogicService();
    _duckRaceGame = DuckRaceGame(
      positions: [_p1, _p2, _p3, _p4, _p5],
      onRaceFinished: _onRaceFinishedLocally,
    );
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

      setState(() {
        if (status == 'betting') {
          _raceState = RaceState.betting;
          _startDuckListener();
        } else if (status == 'racing') {
          _raceState = RaceState.racing;
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
          _hasPlacedBet = false;
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

  Future<void> _runRace() async {
    // Start the LOCAL Flame RNG race instead of Firebase
    _duckRaceGame?.startRace();
    setState(() {
      _raceState = RaceState.racing;
      _errorMessage = null;
    });
  }

  void _onRaceFinishedLocally(int winnerDuckIndex) {
    if (!mounted) return;
    setState(() {
      _raceState = RaceState.finished;
      _winningDuck = winnerDuckIndex;
    });

    final userWon = _hasPlacedBet && (winnerDuckIndex == _selectedDuck);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null && _hasPlacedBet) {
      // Update balance: +betAmount if win, already deducted on bet placement
      if (userWon) {
        FlameAudio.play('sfx_win.mp3');
        FirebaseFirestore.instance.doc('users/$uid').update({
          'balance': FieldValue.increment(_betAmount * 2), // refund + winnings
        });
      }
      // If lost: balance was already deducted when placing bet — no action needed
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(userWon ? '🏆' : '😢', style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Text(
              userWon ? 'THẮNG RỒI!' : 'THUA RỒI!',
              style: TextStyle(
                color: userWon ? Colors.yellowAccent : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vịt $winnerDuckIndex về đích đầu tiên!',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_hasPlacedBet)
              Text(
                userWon
                    ? '✅ Bạn đặt Vịt $_selectedDuck — ĐÚNG! +${_betAmount}xu'
                    : '❌ Bạn đặt Vịt $_selectedDuck — SAI. -${_betAmount}xu',
                style: TextStyle(
                  color: userWon ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Reset everything for a new round
              setState(() {
                _raceState = RaceState.betting;
                _hasPlacedBet = false;
                _winningDuck = 0;
                _errorMessage = null;
              });
              _duckRaceGame?.resetRace();
            },
            child: const Text('🔄 CHƠI LẠI', style: TextStyle(color: Colors.amber, fontSize: 16)),
          ),
        ],
      ),
    );
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
          _hasPlacedBet = false;
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
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trường Đua Vịt 2D')),
      body: _buildBody(),
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

  Future<void> _placeBet(int currentBalance) async {
    if (_betAmount > currentBalance) {
      setState(() => _errorMessage = 'Số dư không đủ để đặt cược!');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final betRef = FirebaseFirestore.instance.collection('bets').doc();
      final userRef = FirebaseFirestore.instance.doc('users/$uid');

      batch.set(betRef, {
        'uid': uid,
        'race_id': _raceId,
        'duck_index': _selectedDuck,
        'amount': _betAmount,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      batch.update(userRef, {
        'balance': FieldValue.increment(-_betAmount),
      });

      await batch.commit();

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPlacedBet = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đặt cược thành công!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Lỗi đặt cược: $e';
        });
      }
    }
  }
  void _showCharacterSelectionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SELECT_CHARACTER_MODEL',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  final duckNum = index + 1;
                  final isSelected = _selectedDuck == duckNum;
                  final duckColors = [
                    Colors.orangeAccent,
                    Colors.white,
                    Colors.yellowAccent,
                    Colors.greenAccent,
                    Colors.purpleAccent
                  ];
                  return GestureDetector(
                    onTap: () {
                      FlameAudio.play('sfx_quack.mp3');
                      setState(() => _selectedDuck = duckNum);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.cyanAccent : Colors.white12,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.5),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: DuckAvatar(assetPath: _duckSprites[index]),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
          ],
          ),
        );
      },
    );
  }

  Widget _buildCharacterSelector() {
    final duckColors = [
      Colors.orangeAccent,
      Colors.white,
      Colors.yellowAccent,
      Colors.greenAccent,
      Colors.purpleAccent
    ];
    return GestureDetector(
      onTap: _showCharacterSelectionBottomSheet,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.15),
              blurRadius: 8,
              spreadRadius: 1,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: duckColors[_selectedDuck - 1], width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DuckAvatar(assetPath: _duckSprites[_selectedDuck - 1]),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SELECTED MODEL',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'VỊT SỐ $_selectedDuck',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.cyanAccent, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBettingState() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Column(
      children: [
        Expanded(child: _buildRaceTrack()),
        Container(
          color: Colors.black87,
            padding: const EdgeInsets.all(16),
            child: uid == null
                ? const Center(child: Text('Chưa đăng nhập', style: TextStyle(color: Colors.red)))
                : StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.doc('users/$uid').snapshots(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data?['balance'] as int? ?? 0;
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'ĐANG ĐẶT CƯỢC',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Số dư: $balance',
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (!_hasPlacedBet) ...[
                            _buildCharacterSelector(),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Cược: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                                DropdownButton<int>(
                                  value: _betAmount,
                                  dropdownColor: Colors.grey[900],
                                  style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
                                  items: [10, 50, 100, 200, 500].map((amount) {
                                    return DropdownMenuItem<int>(
                                      value: amount,
                                      child: Text('$amount xu'),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _betAmount = val);
                                  },
                                ),
                                const SizedBox(width: 24),
                                if (_isLoading)
                                  const CircularProgressIndicator(color: Colors.white)
                                else
                                  ElevatedButton(
                                    onPressed: () => _placeBet(balance),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                    child: const Text('XÁC NHẬN CƯỢC', style: TextStyle(color: Colors.white)),
                                  ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'Đã đặt cược! Đang chờ cuộc đua bắt đầu...',
                              style: TextStyle(color: Colors.greenAccent, fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            if (_isLoading)
                              const CircularProgressIndicator(color: Colors.white)
                            else
                              ElevatedButton.icon(
                                onPressed: _runRace,
                                icon: const Icon(Icons.flag),
                                label: const Text('BẮT ĐẦU ĐUA!'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                ),
                              ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                          ],
                        ],
                      );
                    },
                  ),
        ),
      ],
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
    if (_duckRaceGame == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: GameWidget(
        game: _duckRaceGame!,
        loadingBuilder: (ctx) => Container(
          color: const Color(0xFF2B2D31),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.amber),
                SizedBox(height: 12),
                Text('Đang tải đường đua...', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
        errorBuilder: (ctx, ex) => Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              const Text('Lỗi tải game:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(ex.toString(), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
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
      color: Colors.grey[900],
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
              Text('${d.$2}: $pct%',
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class DuckAvatar extends StatelessWidget {
  final String assetPath;

  const DuckAvatar({super.key, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.fitHeight,
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.hardEdge,
      child: Image.asset(assetPath),
    );
  }
}
