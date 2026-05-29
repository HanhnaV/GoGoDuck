import 'package:cloud_firestore/cloud_firestore.dart';

class BettingRepository {
  Future<void> placeBet({
    required String uid,
    required String raceId,
    required int duckIndex,
    required int amount,
  }) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final userRef = FirebaseFirestore.instance.doc('users/$uid');
      final betRef = FirebaseFirestore.instance.doc('bets/${raceId}_$uid');

      final userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw Exception('Tài khoản không tồn tại!');
      }

      final balance = userSnapshot.data()?['balance'] as int? ?? 0;
      if (balance < amount) {
        throw Exception('Không đủ số dư để đặt cược!');
      }

      final betSnapshot = await transaction.get(betRef);
      if (betSnapshot.exists) {
        throw Exception('Bạn đã đặt cược cho trận này rồi!');
      }

      transaction.update(userRef, {'balance': balance - amount});

      transaction.set(betRef, {
        'bet_id': '${raceId}_$uid',
        'race_id': raceId,
        'uid': uid,
        'duck_index': duckIndex,
        'amount': amount,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
    });
  }
}
