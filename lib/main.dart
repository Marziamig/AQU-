import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'login_page.dart';
import 'register_page.dart';
import 'home_page.dart';
import 'chat_page.dart';
import 'announcements_page.dart';
import 'screens/profile_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/create_ad_screen.dart';
import 'screens/create_request_screen.dart';
import 'screens/create_transport_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/map_list_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/terms_screen.dart';
import 'screens/notifications_page.dart'; // 🔥 AGGIUNTO
import 'splash_screen.dart';

const String supabaseUrl = 'https://dawwywntowafqsmacvsg.supabase.co';
const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.'
    'eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRhd3d5d250b3dhZnFzbWFjdnNnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3NjEyODgsImV4cCI6MjA4MTMzNzI4OH0.'
    't4uR9SFk5sdv3OBNuxvr19Bnxk8zZiepMPDhMjVWo8A';

const String stripePublishableKey =
    'pk_test_51Szw56HfQYIo3wUltO8tYfT4dJ8RvbCUcHE7dQ0ZRv9aGB1eWFFfdEqOOf7H0I91bPRzXgYetJMRKXYI3YJaMhDI0043sH1GNV';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Stripe.publishableKey = stripePublishableKey;
  await Stripe.instance.applySettings();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aqui',
      theme: ThemeData(
        useMaterial3: false,
        iconTheme: const IconThemeData(
          color: Colors.black,
          size: 40,
        ),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home': (_) => const HomePage(),
        '/announcements': (_) => const AnnouncementsPage(),
        '/profile': (_) => const ProfileScreen(),
        '/messages': (_) => const MessagesScreen(),
        '/notifications': (_) => const NotificationsPage(), // 🔥 AGGIUNTO
        '/create-ad': (_) => const CreateAdScreen(),
        '/create-transport': (_) => const CreateTransportScreen(),
        '/create-request': (_) => const CreateRequestScreen(),
        '/map-list': (_) => const MapListScreen(),
        '/faq': (_) => const FaqScreen(),
        '/privacy': (_) => const PrivacyScreen(),
        '/terms': (_) => const TermsScreen(),
        '/reviews': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;

          return ReviewsScreen(
            reviewedUserId: args['reviewedUserId'],
            adId: args['adId'],
          );
        },
        '/chat': (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;

          return ChatPage(
            conversationId: args['conversationId'],
            receiverId: args['receiverId'],
          );
        },
      },
    );
  }
}
