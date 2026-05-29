import 'package:flutter_bloc/flutter_bloc.dart';

import '../repository/betting_repository.dart';
import 'betting_event.dart';
import 'betting_state.dart';

class BettingBloc extends Bloc<BettingEvent, BettingState> {
  final BettingRepository repository;

  BettingBloc({required this.repository}) : super(const BettingInitial()) {
    on<SubmitBetEvent>(_onSubmitBet);
    on<SelectDuckEvent>(_onSelectDuck);
    on<UpdateAmountEvent>(_onUpdateAmount);
    on<ResetBettingState>(_onReset);
  }

  Future<void> _onSubmitBet(
    SubmitBetEvent event,
    Emitter<BettingState> emit,
  ) async {
    // ignore: avoid_print
    print('[BETTING_BLOC] SubmitBetEvent received - uid: ${event.uid}, raceId: ${event.raceId}, duck: ${event.duckIndex}, amount: ${event.amount}');
    emit(BettingLoading(selectedDuck: event.duckIndex, betAmount: event.amount));
    // ignore: avoid_print
    print('[BETTING_BLOC] Emitted BettingLoading');
    try {
      // ignore: avoid_print
      print('[BETTING_BLOC] Calling repository.placeBet...');
      await repository.placeBet(
        uid: event.uid,
        raceId: event.raceId,
        duckIndex: event.duckIndex,
        amount: event.amount,
      );
      // ignore: avoid_print
      print('[BETTING_BLOC] placeBet succeeded - emitting BettingSuccess');
      emit(const BettingSuccess());
    } catch (e) {
      // ignore: avoid_print
      print('[BETTING_BLOC] placeBet FAILED: $e');
      emit(BettingFailure(
        e.toString().replaceFirst('Exception: ', ''),
        selectedDuck: event.duckIndex,
        betAmount: event.amount,
      ));
    }
  }

  void _onSelectDuck(SelectDuckEvent event, Emitter<BettingState> emit) {
    // ignore: avoid_print
    print('[BETTING_BLOC] SelectDuckEvent: duck ${event.duckIndex}');
    final current = state;
    emit(BettingInitial(
      selectedDuck: event.duckIndex,
      betAmount: current is BettingInitial ? current.betAmount : null,
    ));
  }

  void _onUpdateAmount(UpdateAmountEvent event, Emitter<BettingState> emit) {
    // ignore: avoid_print
    print('[BETTING_BLOC] UpdateAmountEvent: ${event.amount}');
    final current = state;
    emit(BettingInitial(
      selectedDuck: current is BettingInitial ? current.selectedDuck : null,
      betAmount: event.amount,
    ));
  }

  void _onReset(ResetBettingState event, Emitter<BettingState> emit) {
    // ignore: avoid_print
    print('[BETTING_BLOC] ResetBettingState received - emitting BettingInitial');
    emit(const BettingInitial());
  }
}
