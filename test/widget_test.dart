import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:task_ai/main.dart';
import 'package:task_ai/models/task.dart';
import 'package:task_ai/providers/auth_provider.dart';
import 'package:task_ai/providers/task_provider.dart';
import 'package:task_ai/repositories/task_repository.dart';
import 'package:task_ai/services/auth_service.dart';
import 'package:task_ai/services/hive_service.dart';
import 'package:task_ai/services/supabase_service.dart';
import 'package:task_ai/services/sync_service.dart';

class MockHiveService extends HiveService {
  @override
  Future<void> init() async {}
  @override
  List<Task> getTasks(String userId) => [];
  @override
  List<Task> getUnsyncedTasks(String userId) => [];
}

void main() {
  testWidgets('La app arranca y muestra el login',
      (WidgetTester tester) async {
    // Inicializar Supabase con datos placeholder para el test offline
    await Supabase.initialize(
      url: 'https://yafcbxeparxnrvqcrcqt.supabase.co',
      publishableKey: 'sb_publishable_uWZ7BQfOqviunj1BIqBQ6w_cob87IVR',
    );

    final hiveService = MockHiveService();
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

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<HiveService>.value(value: hiveService),
          Provider<AuthService>.value(value: authService),
          Provider<SupabaseService>.value(value: supabaseService),
          Provider<SyncService>.value(value: syncService),
          Provider<TaskRepository>.value(value: taskRepository),
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => AuthProvider(authService: authService),
          ),
          ChangeNotifierProxyProvider<AuthProvider, TaskProvider>(
            create: (_) => TaskProvider(
              repository: taskRepository,
              syncService: syncService,
            ),
            update: (_, authProvider, taskProvider) {
              taskProvider!.updateUser(authProvider.currentUser?.id);
              return taskProvider;
            },
          ),
        ],
        child: const TaskAIApp(),
      ),
    );

    await tester.pumpAndSettle();
    
    // Verificar que arranca y nos muestra la pantalla de inicio de sesión
    expect(find.text('TaskAI'), findsOneWidget);
    expect(find.text('Inicia sesión para sincronizar tus tareas en tiempo real'), findsOneWidget);
  });
}
