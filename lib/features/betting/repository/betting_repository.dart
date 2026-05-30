import 'package:cloud_firestore/cloud_firestore.dart';

class BettingRepository {
  Future<void> placeBet({
    required String uid,
    required String raceId,
    required int duckIndex,
    required int amount,
  }) async {
    // ignore: avoid_print
    print('[BETTING_REPO] placeBet called - uid: $uid, raceId: $raceId, duck: $duckIndex, amount: $amount');

    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final raceRef = FirebaseFirestore.instance.doc('races/$raceId');
      final raceSnapshot = await transaction.get(raceRef);

      // ignore: avoid_print
      print('[BETTING_REPO] Transaction step 1 - raceSnapshot exists: ${raceSnapshot.exists}');

      if (!raceSnapshot.exists) {
        // ignore: avoid_print
        print('[BETTING_REPO] FAIL: Race does not exist');
        throw Exception('Trận đấu không tồn tại!');
      }

      final raceStatus = raceSnapshot.data()?['status'] as String? ?? '';
      // ignore: avoid_print
      print('[BETTING_REPO] Race status: "$raceStatus" (expecting "betting")');

      if (raceStatus != 'betting') {
        // ignore: avoid_print
        print('[BETTING_REPO] FAIL: Race status is not "betting"');
        throw Exception('Đã hết thời gian đặt cược!');
      }

      final userRef = FirebaseFirestore.instance.doc('users/$uid');
      final betRef = FirebaseFirestore.instance.doc('bets/${raceId}_$uid');

      // ignore: avoid_print
      print('[BETTING_REPO] Checking existing bet at: bets/${raceId}_$uid');

      final betSnapshot = await transaction.get(betRef);
      // ignore: avoid_print
      print('[BETTING_REPO] betSnapshot exists: ${betSnapshot.exists}');

      if (betSnapshot.exists) {
        // ignore: avoid_print
        print('[BETTING_REPO] FAIL: Bet already exists');
        throw Exception('Bạn đã đặt cược cho trận này rồi!');
      }

      final userSnapshot = await transaction.get(userRef);
      // ignore: avoid_print
      print('[BETTING_REPO] Transaction step 2 - userSnapshot exists: ${userSnapshot.exists}');

      if (!userSnapshot.exists) {
        // ignore: avoid_print
        print('[BETTING_REPO] FAIL: User does not exist');
        throw Exception('Tài khoản không tồn tại!');
      }

      final balance = userSnapshot.data()?['balance'] as int? ?? 0;
      // ignore: avoid_print
      print('[BETTING_REPO] User balance: $balance, bet amount: $amount');

      if (balance < amount) {
        // ignore: avoid_print
        print('[BETTING_REPO] FAIL: Insufficient balance');
        throw Exception('Không đủ số dư để đặt cược!');
      }

      // ignore: avoid_print
      print('[BETTING_REPO] All checks passed - writing bet to Firestore...');
      transaction.update(userRef, {'balance': FieldValue.increment(-amount)});

      transaction.set(betRef, {
        'bet_id': '${raceId}_$uid',
        'race_id': raceId,
        'uid': uid,
        'duck_index': duckIndex,
        'amount': amount,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });

      // ignore: avoid_print
      print('[BETTING_REPO] Bet written successfully');
    });
  }
}
