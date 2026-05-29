import 'package:equatable/equatable.dart';

abstract class BettingState extends Equatable {
  const BettingState();

  @override
  List<Object?> get props => [];
}

class BettingInitial extends BettingState {
  final int? selectedDuck;
  final int? betAmount;

  const BettingInitial({this.selectedDuck, this.betAmount});

  @override
  List<Object?> get props => [selectedDuck, betAmount];
}

class BettingLoading extends BettingState {
  final int? selectedDuck;
  final int? betAmount;

  const BettingLoading({this.selectedDuck, this.betAmount});

  @override
  List<Object?> get props => [selectedDuck, betAmount];
}

class BettingSuccess extends BettingState {
  const BettingSuccess();
}

class BettingFailure extends BettingState {
  final String error;
  final int? selectedDuck;
  final int? betAmount;

  const BettingFailure(this.error, {this.selectedDuck, this.betAmount});

  @override
  List<Object?> get props => [error, selectedDuck, betAmount];
}
