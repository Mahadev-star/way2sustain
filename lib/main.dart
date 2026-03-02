import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'auth/auth_service.dart';
import 'auth/login_page.dart';
import 'home/home_page.dart';
import 'providers/auth_provider.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print("🔧 Initializing Way2Sustain...");
  }

  await AuthService.testConnection();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(), lazy: false),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Way2Sustain',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF151717),
          primaryColor: const Color(0xFF43A047),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF43A047),
            brightness: Brightness.dark,
          ),
        ),

        initialRoute: '/splash',

        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}
