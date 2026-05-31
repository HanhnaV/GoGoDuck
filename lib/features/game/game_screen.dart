import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../betting/bloc/betting_bloc.dart';
import '../betting/bloc/betting_event.dart';
import '../betting/bloc/betting_state.dart';
import '../auth/bloc/auth_bloc.dart';
import '../auth/bloc/auth_state.dart';
import '../../services/audio_service.dart';
import 'game_logic_service.dart';

enum RaceState { idle, betting, racing, finished }

const List<Color> duckColors = [
  Colors.yellow,
  Colors.cyan,
  Colors.pink,
  Colors.green,
  Colors.orange,
];

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
  int _duckFrame = 0;
  Timer? _duckAnimTimer;
  int _winningDuck = 0;
  int _timeLeft = 10;
  bool _isLoading = false;
  String? _errorMessage;
  final _amountController = TextEditingController(text: '100');
  int _userSelectedDuck = 0;
  int _userBetAmount = 0;
  String? _userBetStatus;
  int? _userReward;
  bool _hasBet = false;

  void _startDuckAnimation() {
    _duckAnimTimer?.cancel();
    _duckAnimTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() {
        _duckFrame = (_duckFrame % 6) + 1;
      });
    });
  }

  void _stopDuckAnimation() {
    _duckAnimTimer?.cancel();
    _duckAnimTimer = null;
  }

  @override
  void initState() {
    super.initState();
    _raceId = widget.raceId ?? 'demo_race';
    _gameService = GameLogicService();
    _listenToRaceStatus();
    AudioService.I.playBGM('assets/nhac_nen_sanh_cho.mp3');
  }

  void _listenToRaceStatus() {
    _statusSubscription?.cancel();
    _statusSubscription = FirebaseDatabase.instance
        .ref('live_races/$_raceId')
        .onValue
        .listen((event) async {
      if (!mounted) return;
      final value = event.snapshot.value;
      if (value == null) return;

      final data = Map<String, dynamic>.from(value as Map);
      final status = data['status'] as String? ?? 'idle';
      final timeLeft = data['time_left'] as int? ?? 10;

      // ignore: avoid_print
      print('[GAME_SCREEN] Race status changed -> status: "$status", timeLeft: $timeLeft');

      if (status == 'finished') {
        final winningDuck = data['winning_duck'] as int? ?? 0;
        String? betStatus;
        int? reward;
        int selectedDuck = 0;
        int betAmount = 0;

        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          final betDoc = await FirebaseFirestore.instance
              .doc('bets/${_raceId}_${authState.user.uid}')
              .get();
          if (betDoc.exists) {
            final bd = betDoc.data()!;
            selectedDuck = bd['duck_index'] as int? ?? 0;
            betAmount = bd['amount'] as int? ?? 0;
            betStatus = bd['status'] as String?;
            if (betStatus == 'rewarded') {
              reward = betAmount * 2;
            }
          }
        }

        if (!mounted) return;

        // Handle audio for finished state
        final isUserWin = betStatus == 'rewarded';
        if (isUserWin) {
          AudioService.I.playSFX('assets/tieng_cuoc_thang.mp3');
        }
        _stopDuckAnimation();
        AudioService.I.stopBGM();

        setState(() {
          _timeLeft = timeLeft;
          _raceState = RaceState.finished;
          _winningDuck = winningDuck;
          _userSelectedDuck = selectedDuck;
          _userBetAmount = betAmount;
          _userBetStatus = betStatus;
          _userReward = reward;
        });
      } else {
        if (!mounted) return;

        // Determine the new state
        final newRaceState = status == 'betting'
            ? RaceState.betting
            : status == 'racing'
                ? RaceState.racing
                : RaceState.idle;

        // Only play audio when state actually CHANGES
        if (newRaceState != _raceState) {
          if (newRaceState == RaceState.betting) {
            _stopDuckAnimation();
            AudioService.I.playBGM('assets/nhac_nen_sanh_cho.mp3');
          } else if (newRaceState == RaceState.racing) {
            // Only play start sound when transitioning from betting to racing
            if (_raceState == RaceState.betting) {
              AudioService.I.playSFX('assets/start.mp3');
            }
            _startDuckAnimation();
            AudioService.I.playBGM('assets/nhac_nen_luc_dua.mp3');
          } else if (newRaceState == RaceState.finished) {
            _stopDuckAnimation();
          }
        }

        setState(() {
          _timeLeft = timeLeft;
          if (status == 'betting') {
            _raceState = RaceState.betting;
            _startDuckListener();
          } else if (status == 'racing') {
            _raceState = RaceState.racing;
            _startDuckListener();
          } else {
            _raceState = RaceState.idle;
          }
        });
      }
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
      AudioService.I.stopBGM();
      AudioService.I.playBGM('assets/nhac_nen_sanh_cho.mp3');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _p1 = _p2 = _p3 = _p4 = _p5 = 0.0;
          _winningDuck = 0;
          _userSelectedDuck = 0;
          _userBetAmount = 0;
          _userBetStatus = null;
          _userReward = null;
          _hasBet = false;
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
    final bettingState = context.read<BettingBloc>().state;
    int? selectedDuck;
    int? amount;

    if (bettingState is BettingInitial) {
      selectedDuck = bettingState.selectedDuck;
      amount = bettingState.betAmount ?? int.tryParse(_amountController.text.trim());
    } else if (bettingState is BettingLoading) {
      selectedDuck = bettingState.selectedDuck;
      amount = bettingState.betAmount;
    } else if (bettingState is BettingFailure) {
      selectedDuck = bettingState.selectedDuck;
      amount = bettingState.betAmount ?? int.tryParse(_amountController.text.trim());
    }

    // ignore: avoid_print
    print('[GAME_SCREEN] _placeBet - selectedDuck: $selectedDuck, amount: $amount');

    if (selectedDuck == null) {
      // ignore: avoid_print
      print('[GAME_SCREEN] FAIL: No duck selected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng chọn một con vịt!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      // ignore: avoid_print
      print('[GAME_SCREEN] FAIL: Invalid amount');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Vui lòng nhập số tiền hợp lệ!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    // ignore: avoid_print
    print('[GAME_SCREEN] AuthState type: ${authState.runtimeType}');

    if (authState is! AuthAuthenticated) {
      // ignore: avoid_print
      print('[GAME_SCREEN] FAIL: Not authenticated');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Chưa đăng nhập!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1500),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            left: 10,
            right: 10,
          ),
        ),
      );
      return;
    }

    final uid = authState.user.uid;
    // ignore: avoid_print
    print('[GAME_SCREEN] User uid: $uid, submitting bet...');

    setState(() {
      _userSelectedDuck = selectedDuck!;
      _userBetAmount = amount!;
      _hasBet = true;
    });

    context.read<BettingBloc>().add(SubmitBetEvent(
      uid: uid,
      raceId: _raceId,
      duckIndex: selectedDuck,
      amount: amount,
    ));
  }

  Future<void> _resetRace() async {
    setState(() => _isLoading = true);
    try {
      await _gameService.resetRace(_raceId);
      AudioService.I.stopBGM();
      _stopDuckAnimation();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _raceState = RaceState.idle;
          _duckFrame = 0;
          _p1 = _p2 = _p3 = _p4 = _p5 = 0.0;
          _winningDuck = 0;
          _timeLeft = 10;
          _userSelectedDuck = 0;
          _userBetAmount = 0;
          _userBetStatus = null;
          _userReward = null;
          _hasBet = false;
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
    _duckAnimTimer?.cancel();
    _amountController.dispose();
    _gameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => AudioService.I.onFirstTap(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trường Đua Vịt 2D'),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
        body: BlocListener<BettingBloc, BettingState>(
          listener: (context, state) {
            if (state is BettingSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Đặt cược thành công!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(milliseconds: 1500),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height - 100,
                    left: 10,
                    right: 10,
                  ),
                ),
              );
              context.read<BettingBloc>().add(ResetBettingState());
            } else if (state is BettingFailure) {
              setState(() => _hasBet = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(milliseconds: 1500),
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height - 100,
                    left: 10,
                    right: 10,
                  ),
                ),
              );
              context.read<BettingBloc>().add(ResetBettingState());
            }
          },
          child: _buildBody(),
        ),
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
            Expanded(child: _buildBettingTrack()),
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

  Widget _buildBettingTrack() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'CHON VAT DE DAT CUOC',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.orange,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: List.generate(5, (index) {
              return Expanded(
                child: _buildDuckCard(index + 1, true),
              );
            }),
          ),
        ),
        const SizedBox(height: 12),
        if (_userSelectedDuck > 0) _buildBetSummary(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildBetSummary() {
    final color = duckColors[_userSelectedDuck - 1];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/duck/duck$_userSelectedDuck.png',
            width: 32,
            height: 32,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          Text(
            'Ban dat cuoc $_userBetAmount cho Vat $_userSelectedDuck',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'DA DAT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuckCard(int duckNum, bool showTrack) {
    final index = duckNum - 1;
    final color = duckColors[index];
    final positions = [_p1, _p2, _p3, _p4, _p5];
    final position = positions[index];
    final pct = position.clamp(0.0, 100.0);

    final bettingState = context.watch<BettingBloc>().state;
    final selectedDuck = bettingState is BettingInitial
        ? bettingState.selectedDuck
        : bettingState is BettingLoading
            ? bettingState.selectedDuck
            : bettingState is BettingFailure
                ? bettingState.selectedDuck
                : null;
    final isSelected = selectedDuck == duckNum;
    final hasBet = _userSelectedDuck == duckNum;

    return GestureDetector(
      onTap: () {
        // Play sound every time user taps to select/change duck
        AudioService.I.playSFX('assets/select_duck.mp3');
        if (!_hasBet) {
          context.read<BettingBloc>().add(SelectDuckEvent(duckNum));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected || hasBet
              ? color.withValues(alpha: 0.12)
              : (_hasBet ? Colors.grey.shade800 : Colors.grey.shade900),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (hasBet ? color.withValues(alpha: 0.6) : Colors.transparent),
            width: isSelected ? 3 : (hasBet ? 2 : 1),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 14, spreadRadius: 1)]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.asset(
                  'assets/duck/duck1.png',
                  width: isSelected ? 64 : 56,
                  height: isSelected ? 64 : 56,
                  fit: BoxFit.contain,
                ),
                if (hasBet)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Vat $duckNum',
              style: TextStyle(
                color: isSelected || hasBet ? color : (_hasBet ? Colors.white30 : Colors.white70),
                fontSize: 12,
                fontWeight: isSelected || hasBet ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            if (showTrack) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct / 100.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownHeader() {
    final isUrgent = _timeLeft <= 3;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: isUrgent ? Colors.red : Colors.orange,
      child: Column(
        children: [
          const Text(
            'THOI GIAN DAT CUOC',
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
            'giay',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildBettingPanel() {
    final authState = context.read<AuthBloc>().state;
    final userId = authState is AuthAuthenticated ? authState.user.uid : null;

    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: BlocBuilder<BettingBloc, BettingState>(
        builder: (context, state) {
          final selectedDuck = state is BettingInitial
              ? state.selectedDuck
              : state is BettingLoading
                  ? state.selectedDuck
                  : state is BettingFailure
                      ? state.selectedDuck
                      : null;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (userId != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.doc('users/$userId').snapshots(),
                  builder: (context, snapshot) {
                    final balance = (snapshot.data?.data() as Map<String, dynamic>?)?['balance'] as int? ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'So du: $balance Xu',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Tien cuoc: ',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      enabled: !_hasBet,
                      onChanged: (val) {
                        final amount = int.tryParse(val);
                        if (amount != null) {
                          context.read<BettingBloc>().add(UpdateAmountEvent(amount));
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Nhap so tien',
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_hasBet || state is BettingLoading || selectedDuck == null)
                      ? null
                      : _placeBet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    disabledBackgroundColor: Colors.grey.shade700,
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
                      : Text(
                          _hasBet ? 'DA DAT CUOC' : 'DAT CUOC',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              if (_hasBet) ...[
                const SizedBox(height: 8),
                Text(
                  'Ban da dat cuoc, doi ket qua!',
                  style: TextStyle(
                    color: Colors.green.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          );
        },
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
            'DANG DUAAAA!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(child: _buildRaceTrack()),
      ],
    );
  }

  Widget _buildFinishedState() {
    final positions = [_p1, _p2, _p3, _p4, _p5];
    final isWin = _userBetStatus == 'rewarded';
    final hasBet = _userSelectedDuck > 0 && _userBetAmount > 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          if (_winningDuck >= 1 && _winningDuck <= 5) ...[
            const Icon(Icons.emoji_events, size: 64, color: Colors.amber),
            const SizedBox(height: 8),
            Text(
              'VAT $_winningDuck CHIEN THANG!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: duckColors[_winningDuck - 1],
              ),
            ),
          ] else ...[
            const Icon(Icons.sports_score, size: 64, color: Colors.grey),
            const SizedBox(height: 8),
            const Text(
              'Khong co vat thang',
              style: TextStyle(fontSize: 22, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: hasBet
                  ? (isWin ? Colors.green.shade900 : Colors.red.shade900)
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasBet
                    ? (isWin ? Colors.green : Colors.red)
                    : Colors.grey,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      hasBet
                          ? (isWin ? Icons.celebration : Icons.sentiment_dissatisfied)
                          : Icons.info_outline,
                      color: hasBet
                          ? (isWin ? Colors.green.shade200 : Colors.red.shade200)
                          : Colors.grey.shade400,
                      size: 28,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      hasBet
                          ? (isWin ? 'CHUC MUNG BAN DA THANG!' : 'BAN DA THUA!')
                          : 'Ban khong dat cuoc',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: hasBet
                            ? (isWin ? Colors.green.shade200 : Colors.red.shade200)
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
                if (hasBet) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Dat cuoc',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Text(
                              '$_userBetAmount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white30,
                        ),
                        Column(
                          children: [
                            const Text(
                              'Nhan duoc',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Text(
                              '${_userReward ?? 0}',
                              style: TextStyle(
                                color: isWin ? Colors.green.shade200 : Colors.red.shade200,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 36,
                          color: Colors.white30,
                        ),
                        Column(
                          children: [
                            const Text(
                              'Loi nhuan',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            Text(
                              isWin ? '+${(_userReward! - _userBetAmount)}' : '-$_userBetAmount',
                              style: TextStyle(
                                color: isWin ? Colors.green.shade200 : Colors.red.shade200,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'KET QUA CAC VAT:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (index) {
              final duckNum = index + 1;
              final isWinner = duckNum == _winningDuck;
              final isUserBet = duckNum == _userSelectedDuck;
              final pct = positions[index].clamp(0.0, 100.0);
              return Expanded(
                child: _buildFinishedDuckCard(duckNum, isWinner, isUserBet, pct),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _resetRace,
              icon: const Icon(Icons.refresh),
              label: const Text('Dua lai'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
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

  Widget _buildFinishedDuckCard(int duckNum, bool isWinner, bool isUserBet, double position) {
    final index = duckNum - 1;
    final color = duckColors[index];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isWinner
            ? color.withValues(alpha: 0.18)
            : (isUserBet ? Colors.red.withValues(alpha: 0.1) : Colors.grey.shade900),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isWinner
              ? color
              : (isUserBet ? Colors.red.withValues(alpha: 0.6) : Colors.grey.shade800),
          width: isWinner ? 2.5 : (isUserBet ? 1.5 : 1),
        ),
        boxShadow: isWinner
            ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isWinner)
            const Icon(Icons.star, color: Colors.amber, size: 16),
          if (isUserBet && !isWinner)
            const Icon(Icons.close, color: Colors.red, size: 16),
          const SizedBox(height: 2),
          Image.asset(
            'assets/duck/duck$duckNum.png',
            width: isWinner ? 48 : 40,
            height: isWinner ? 48 : 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 4),
          Text(
            'Vat $duckNum',
            style: TextStyle(
              color: isWinner ? color : Colors.white70,
              fontSize: 11,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isWinner ? 'THANG' : 'THUA',
            style: TextStyle(
              color: isWinner ? Colors.green.shade300 : Colors.red.shade300,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${position.toStringAsFixed(1)}%',
            style: TextStyle(
              color: isWinner ? color : Colors.grey,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceTrack() {
    const finishLineOffset = 40.0;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            // Top border
            const Image(
              image: AssetImage('assets/background/top.jpg'),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
            // 5 race lanes
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = constraints.maxWidth - finishLineOffset;
                  final positions = [_p1, _p2, _p3, _p4, _p5];
                  return Stack(
                    children: List.generate(5, (i) {
                      final clampedPos = positions[i].clamp(0.0, 100.0);
                      final xPixel = (clampedPos / 100.0) * trackWidth;
                      return Positioned(
                        top: constraints.maxHeight / 5 * i,
                        left: 0,
                        right: 0,
                        height: constraints.maxHeight / 5,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                'assets/background/race.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Duck
                            Positioned(
                              left: xPixel - 20,
                              top: 0,
                              bottom: 0,
                              child: Center(
                                child: SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Image.asset(
                                        'assets/duck/duck$_duckFrame.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.contain,
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: duckColors[i],
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${i + 1}',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
            // Bottom border
            const Image(
              image: AssetImage('assets/background/bottom.jpg'),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}
