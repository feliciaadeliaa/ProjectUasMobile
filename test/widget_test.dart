import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taskflow/main.dart';

void main() {
  testWidgets('Login screen displays correctly', (WidgetTester tester) async {
    // Initialize SharedPreferences and AsyncAuthStore for PocketBase
    final prefs = await SharedPreferences.getInstance();
    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );

    // Initialize PocketBase instance
    final pb = PocketBase('http://127.0.0.1:8090', authStore: store);

    // Build our app with required parameters and trigger a frame
    await tester.pumpWidget(TaskFlowApp(
      pb: pb,
      initialRoute: '/login', // Since the initial route in main.dart is dynamic, we set it to '/login' for testing
    ));

    // Wait for the UI to settle (in case of animations or async loading)
    await tester.pumpAndSettle();

    // Verify that the LoginScreen is displayed
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign in to manage your tasks'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Email and Password fields
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Don’t have an account?'), findsOneWidget);
    expect(find.text('Sign Up'), findsOneWidget);
  });
}