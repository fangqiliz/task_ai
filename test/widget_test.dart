import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:task_ai/main.dart';
import 'package:task_ai/providers/task_provider.dart';

void main() {
  testWidgets('La app arranca y muestra el dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TaskProvider(),
        child: const TaskAIApp(),
      ),
    );
    expect(find.text('Tareas Prioritarias'), findsOneWidget);
    expect(find.text('Progreso Hoy'), findsOneWidget);
  });
}
