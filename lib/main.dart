import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'models/task.dart';
import 'providers/task_provider.dart';
import 'theme/app_colors.dart';
import 'screens/home_screen.dart';
import 'screens/task_form_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/ai_assistant_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const TaskAIApp(),
    ),
  );
}

final _router = GoRouter(
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
    GoRoute(
        path: '/profile', builder: (context, state) => const ProfileScreen()),
    GoRoute(
        path: '/ai', builder: (context, state) => const AiAssistantScreen()),
  ],
);

class TaskAIApp extends StatelessWidget {
  const TaskAIApp({super.key});

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