import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/betting_repository.dart';
import 'betting_event.dart';
import 'betting_state.dart';

class BettingBloc extends Bloc<BettingEvent, BettingState> {
  final BettingRepository repository;

  BettingBloc({required this.repository}) : super(const BettingInitial()) {
    on<SubmitBetEvent>(_onSubmitBet);
    on<ResetBettingState>(_onReset);
  }

  Future<void> _onSubmitBet(
    SubmitBetEvent event,
    Emitter<BettingState> emit,
  ) async {
    emit(BettingLoading());
    try {
      await repository.placeBet(
        uid: event.uid,
        raceId: event.raceId,
        duckIndex: event.duckIndex,
        amount: event.amount,
      );
      emit(BettingSuccess());
    } catch (e) {
      emit(BettingFailure(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onReset(ResetBettingState event, Emitter<BettingState> emit) {
    emit(BettingInitial());
  }
}
