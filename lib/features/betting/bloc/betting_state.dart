import 'package:equatable/equatable.dart';

abstract class BettingState extends Equatable {
  const BettingState();

  @override
  List<Object?> get props => [];
}

class BettingInitial extends BettingState {
  const BettingInitial();
}

class BettingLoading extends BettingState {
  const BettingLoading();
}

class BettingSuccess extends BettingState {}

class BettingFailure extends BettingState {
  final String error;

  const BettingFailure(this.error);

  @override
  List<Object?> get props => [error];
}
