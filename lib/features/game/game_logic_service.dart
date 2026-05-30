import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class GameLogicService {
  static const int _duckCount = 5;
  static const double _positionIncrementMin = 0.5;
  static const double _positionIncrementMax = 2.5;
  static const double _winThreshold = 100.0;
  static const int _tickIntervalMs = 100;
  static const int _bettingDurationSeconds = 10;

  Timer? _raceTimer;
  Timer? _countdownTimer;
  final Random _random = Random();
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> startNewRacePeriod(String raceId) async {
    await _firestore.collection('races').doc(raceId).set({
      'status': 'betting',
      'winning_duck': 0,
      'total_pool': 0,
      'created_at': FieldValue.serverTimestamp(),
    });

    final ducksMap = <String, dynamic>{};
    for (int i = 1; i <= _duckCount; i++) {
      ducksMap['duck_$i'] = {'position': 0.0};
    }

    await _rtdb.ref('live_races/$raceId').update({
      'status': 'betting',
      'time_left': _bettingDurationSeconds,
      'ducks': ducksMap,
    });

    _startCountdown(raceId);
  }

  void _startCountdown(String raceId) {
    _countdownTimer?.cancel();
    int secondsLeft = _bettingDurationSeconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      secondsLeft--;

      if (secondsLeft <= 0) {
        timer.cancel();
        await _rtdb.ref('live_races/$raceId').update({'status': 'racing'});
        await _firestore.collection('races').doc(raceId).update({'status': 'racing'});
        await runDuckRaceLoop(raceId);
        return;
      }

      await _rtdb.ref('live_races/$raceId').update({
        'time_left': secondsLeft,
      });
    });
  }

  Future<void> runDuckRaceLoop(String raceId) async {
    await _rtdb.ref('live_races/$raceId').update({'status': 'racing'});
    await _firestore.collection('races').doc(raceId).update({'status': 'racing'});

    final positions = List<double>.filled(_duckCount, 0.0);

    _raceTimer?.cancel();
    _raceTimer = Timer.periodic(
      Duration(milliseconds: _tickIntervalMs),
      (timer) async {
        for (int i = 0; i < _duckCount; i++) {
          positions[i] += _random.nextDouble() * (_positionIncrementMax - _positionIncrementMin) + _positionIncrementMin;
        }

        final ducksMap = <String, dynamic>{};
        for (int i = 0; i < _duckCount; i++) {
          ducksMap['duck_${i + 1}/position'] = positions[i];
        }

        await _rtdb.ref('live_races/$raceId/ducks').update(ducksMap);

        for (int i = 0; i < _duckCount; i++) {
          if (positions[i] >= _winThreshold) {
            timer.cancel();
            final winner = i + 1;
            await _rtdb.ref('live_races/$raceId').update({
              'status': 'finished',
              'winning_duck': winner,
            });
            await _firestore.collection('races').doc(raceId).update({
              'status': 'finished',
              'winning_duck': winner,
            });
            await _distributeRewards(raceId, winner);
            return;
          }
        }
      },
    );
  }

  Future<void> _distributeRewards(String raceId, int winningDuckIndex) async {
    final betsSnapshot = await _firestore
        .collection('bets')
        .where('race_id', isEqualTo: raceId)
        .where('status', isEqualTo: 'pending')
        .get();

    final WriteBatch batch = _firestore.batch();

    for (final betDoc in betsSnapshot.docs) {
      final betData = betDoc.data();
      final uid = betData['uid'] as String;
      final duckIndex = betData['duck_index'] as int;
      final amount = betData['amount'] as int;

      final betRef = _firestore.doc('bets/${betDoc.id}');
      final userRef = _firestore.doc('users/$uid');

      if (duckIndex == winningDuckIndex) {
        final rewardAmount = amount * 2;
        batch.update(betRef, {'status': 'rewarded'});
        batch.update(userRef, {
          'balance': FieldValue.increment(rewardAmount),
          'total_wins': FieldValue.increment(1),
        });
      } else {
        batch.update(betRef, {'status': 'lost'});
      }
    }

    await batch.commit();
    // ignore: avoid_print
    print('Đã hoàn thành trả thưởng tự động cho trận đấu $raceId');
  }

  void dispose() {
    _raceTimer?.cancel();
    _countdownTimer?.cancel();
  }

  Future<void> resetRace(String raceId) async {
    _raceTimer?.cancel();
    _countdownTimer?.cancel();
    await _rtdb.ref('live_races/$raceId').remove();
    await _firestore.collection('races').doc(raceId).delete();
  }
}
