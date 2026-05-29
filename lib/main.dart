import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'firebase_options.dart';
import 'features/auth/auth_screen.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/betting/bloc/betting_bloc.dart';
import 'features/betting/repository/betting_repository.dart';
import 'features/home/home_screen.dart';
import 'features/game/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(repository: AuthRepository()),
        ),
        BlocProvider(
          create: (_) => BettingBloc(repository: BettingRepository()),
        ),
      ],
      child: MaterialApp(
        title: 'GoGoDuck',
        theme: ThemeData(primarySwatch: Colors.orange),
        debugShowCheckedModeBanner: false,
        initialRoute: '/auth',
        routes: {
          '/auth': (context) => const AuthScreen(),
          '/home': (context) => const HomeScreen(),
          '/game': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            final raceId = args is String ? args : null;
            return GameScreen(raceId: raceId);
          },
        },
      ),
    );
  }
}
