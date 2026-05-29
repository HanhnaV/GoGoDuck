import 'package:equatable/equatable.dart';

abstract class BettingEvent extends Equatable {
  const BettingEvent();

  @override
  List<Object?> get props => [];
}

class SubmitBetEvent extends BettingEvent {
  final String uid;
  final String raceId;
  final int duckIndex;
  final int amount;

  const SubmitBetEvent({
    required this.uid,
    required this.raceId,
    required this.duckIndex,
    required this.amount,
  });

  @override
  List<Object?> get props => [uid, raceId, duckIndex, amount];
}

class ResetBettingState extends BettingEvent {}
