import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'onboarding_screen.dart';
import 'home_page.dart';
import 'settings_page.dart';
import 'auth_pages.dart';
import 'chat_page.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ThemeProvider themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: themeProvider,
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'The Crew App',
            theme: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue,
                secondary: Colors.blueAccent,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            initialRoute: '/',
            routes: {
              '/': (context) => _handleAuth(),
              '/login': (context) => LoginPage(),
              '/home': (context) => HomePage(),
              '/settings': (context) => SettingsPage(),
              '/chat': (context) => ChatPage(
                chatId: 'defaultChatId',
                chatName: 'Default Chat',
                chatAvatar: 'https://example.com/default_avatar.png',
              ),
            },
          );
        },
      ),
    );
  }

  Widget _handleAuth() {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          User? user = snapshot.data;
          if (user == null) {
            return OnboardingScreen();
          }
          return HomePage();
        }
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}