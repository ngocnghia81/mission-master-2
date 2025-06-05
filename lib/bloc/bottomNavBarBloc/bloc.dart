import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/events.dart';
import 'package:mission_master/bloc/bottomNavBarBloc/states.dart';

class NavBarBloc extends Bloc<NavBarEvents, NavBarStates> {
  NavBarBloc() : super(pageNavigate(index: 0)) {
    on<currentPage>((event, emit) {
      emit(pageNavigate(index: event.index));
    });
  }
}
