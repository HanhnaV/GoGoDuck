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

  Timer? _raceTimer;
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
      'ducks': ducksMap,
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
            await _rtdb.ref('live_races/$raceId').update({'status': 'finished'});
            await _firestore.collection('races').doc(raceId).update({
              'status': 'finished',
              'winning_duck': winner,
            });
            return;
          }
        }
      },
    );
  }

  void dispose() {
    _raceTimer?.cancel();
  }

  Future<void> resetRace(String raceId) async {
    _raceTimer?.cancel();
    await _rtdb.ref('live_races/$raceId').remove();
    await _firestore.collection('races').doc(raceId).delete();
  }
}
