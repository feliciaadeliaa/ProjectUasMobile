import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/add_task_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/projects_screen.dart'; // Updated import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi SharedPreferences dan AsyncAuthStore
  final prefs = await SharedPreferences.getInstance();
  final store = AsyncAuthStore(
    save: (String data) async => prefs.setString('pb_auth', data),
    initial: prefs.getString('pb_auth'),
  );

  // Inisialisasi PocketBase - gunakan URL yang konsisten
  final pb = PocketBase('http://127.0.0.1:8090', authStore: store);

  // Tentukan rute awal berdasarkan status autentikasi
  final initialRoute = pb.authStore.isValid ? '/' : '/login';

  runApp(TaskFlowApp(pb: pb, initialRoute: initialRoute));
}

class TaskFlowApp extends StatelessWidget {
  final PocketBase pb;
  final String initialRoute;

  const TaskFlowApp({super.key, required this.pb, required this.initialRoute});

  static final lightTheme = ThemeData(
    primaryColor: const Color(0xFFF8E1E1),
    scaffoldBackgroundColor: const Color(0xFFF5F7FB),
    fontFamily: 'Roboto',
    brightness: Brightness.light,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
      bodyMedium: TextStyle(fontSize: 16, color: Colors.black54),
      bodySmall: TextStyle(fontSize: 14, color: Colors.black54),
    ),
    cardColor: Colors.white,
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF8E1E1),
        foregroundColor: Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.black87,
      ),
    ),
    iconTheme: const IconThemeData(
      color: Colors.black54,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Colors.black54),
      hintStyle: const TextStyle(color: Colors.black54),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.black87,
      unselectedItemColor: Colors.black54,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static final darkTheme = ThemeData(
    primaryColor: const Color(0xFFF8E1E1),
    scaffoldBackgroundColor: const Color(0xFF1A1A1A),
    fontFamily: 'Roboto',
    brightness: Brightness.dark,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
          fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 16, color: Colors.white60),
      bodySmall: TextStyle(fontSize: 14, color: Colors.white60),
    ),
    cardColor: const Color(0xFF2A2A2A),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: const Color(0xFF2A2A2A),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFF8E1E1),
        foregroundColor: Colors.black87,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white70,
      ),
    ),
    iconTheme: const IconThemeData(
      color: Colors.white60,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      labelStyle: const TextStyle(color: Colors.white60),
      hintStyle: const TextStyle(color: Colors.white60),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF2A2A2A),
      selectedItemColor: Colors.white70,
      unselectedItemColor: Colors.white60,
      elevation: 8,
      type: BottomNavigationBarType.fixed,
    ),
  );

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier(ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'TaskFlow',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          initialRoute: initialRoute,
          routes: {
            '/login': (context) => LoginScreen(pb: pb),
            '/register': (context) => RegisterScreen(pb: pb),
            '/': (context) => HomeScreen(pb: pb),
            '/home': (context) => HomeScreen(pb: pb), // Add alias for safety
            '/add_task': (context) => AddTaskScreen(pb: pb),
            '/profile': (context) => ProfileScreen(pb: pb),
            '/projects': (context) => ProjectsScreen(pb: pb),
          },
        );
      },
    );
  }
}
