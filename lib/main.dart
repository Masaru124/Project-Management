import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/projects/create_project_screen.dart';
import 'screens/projects/project_detail_screen.dart';
import 'services/auth_service.dart';
import 'services/project_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load environment variables
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found. Please create a .env file with your Supabase configuration.');
    debugPrint('Using fallback values. Update these with your actual Supabase credentials.');
  }

  // Validate required environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? 'your_supabase_url_here';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 'your_supabase_anon_key_here';

  if (supabaseUrl == 'your_supabase_url_here' || supabaseAnonKey == 'your_supabase_anon_key_here') {
    debugPrint('ERROR: Please update your .env file with actual Supabase credentials');
  }

  // Initialize Supabase
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Error initializing Supabase: $e');
    rethrow;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ProjectService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/create-project',
          builder: (context, state) => const CreateProjectScreen(),
        ),
        GoRoute(
          path: '/project/:id',
          builder: (context, state) {
            final projectId = state.pathParameters['id']!;
            return ProjectDetailScreen(projectId: projectId);
          },
        ),
      ],
      redirect: (context, state) {
        final authService = Provider.of<AuthService>(context, listen: false);

        final isLoggedIn = authService.currentUser != null;
        final isAuthRoute =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register';

        if (!isLoggedIn && !isAuthRoute) {
          return '/login';
        }

        if (isLoggedIn && isAuthRoute) {
          return '/home';
        }

        return null;
      },
    );

    return MaterialApp.router(
      title: 'Group Project Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
