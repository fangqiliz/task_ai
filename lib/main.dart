import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'models/task.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'repositories/task_repository.dart';
import 'screens/ai_assistant_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/register_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/task_form_screen.dart';
import 'services/auth_service.dart';
import 'services/hive_service.dart';
import 'services/supabase_service.dart';
import 'services/sync_service.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // Inicializar Hive
  final hiveService = HiveService();
  await hiveService.init();

  final authService = AuthService();
  final supabaseService = SupabaseService();
  final syncService = SyncService(
    hiveService: hiveService,
    supabaseService: supabaseService,
  );
  final taskRepository = TaskRepository(
    hiveService: hiveService,
    syncService: syncService,
  );

  runApp(
    MultiProvider(
      providers: [
        Provider<HiveService>.value(value: hiveService),
        Provider<AuthService>.value(value: authService),
        Provider<SupabaseService>.value(value: supabaseService),
        Provider<SyncService>.value(value: syncService),
        Provider<TaskRepository>.value(value: taskRepository),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) => AuthProvider(authService: authService),
        ),
        ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
          create: (context) => TaskProvider(
            repository: taskRepository,
            syncService: syncService,
          ),
          update: (context, authProvider, taskProvider) {
            taskProvider!.updateUser(authProvider.currentUser?.id);
            return taskProvider;
          },
        ),
      ],
      child: const TaskAIApp(),
    ),
  );
}

class TaskAIApp extends StatefulWidget {
  const TaskAIApp({super.key});

  @override
  State<TaskAIApp> createState() => _TaskAIAppState();
}

class _TaskAIAppState extends State<TaskAIApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final loggedIn = authProvider.isAuthenticated;
        final isLoggingIn = state.matchedLocation == '/login';
        final isRegistering = state.matchedLocation == '/register';

        if (!loggedIn && !isLoggingIn && !isRegistering) {
          return '/login';
        }
        if (loggedIn && (isLoggingIn || isRegistering)) {
          return '/';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/form',
          builder: (context, state) {
            final task = state.extra as Task?;
            return TaskFormScreen(task: task);
          },
        ),
        GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/ai', builder: (context, state) => const AiAssistantScreen()),
        GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
        GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TaskAI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'SF Pro Display',
      ),
      routerConfig: _router,
    );
  }
}