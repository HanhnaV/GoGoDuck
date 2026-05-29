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

class SelectDuckEvent extends BettingEvent {
  final int duckIndex;

  const SelectDuckEvent(this.duckIndex);

  @override
  List<Object?> get props => [duckIndex];
}

class UpdateAmountEvent extends BettingEvent {
  final int amount;

  const UpdateAmountEvent(this.amount);

  @override
  List<Object?> get props => [amount];
}

class ResetBettingState extends BettingEvent {}
