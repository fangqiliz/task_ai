import 'package:flutter_test/flutter_test.dart';

import 'package:task_ai/models/task.dart';
import 'package:task_ai/services/task_text_parser.dart';

void main() {
  group('TaskTextParser', () {
    test('limpia frases de relleno y capitaliza el título', () {
      final parsed = TaskTextParser.parse('recordarme comprar pan');
      expect(parsed.title, 'Comprar pan');
    });

    test('detecta categoría estudio, fecha de mañana y hora', () {
      final parsed = TaskTextParser.parse('estudiar cálculo mañana a las 8');
      expect(parsed.category, TaskCategory.estudio);
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(parsed.dueDate.day, tomorrow.day);
      expect(parsed.dueDate.hour, 8);
    });

    test('detecta hora de la tarde en formato 12 horas', () {
      final parsed =
          TaskTextParser.parse('reunión con el cliente a las 4 de la tarde');
      expect(parsed.category, TaskCategory.trabajo);
      expect(parsed.dueDate.hour, 16);
    });

    test('"urgente" implica prioridad alta y categoría urgente', () {
      final parsed = TaskTextParser.parse('llamar al médico urgente');
      expect(parsed.priority, TaskPriority.alta);
      expect(parsed.category, TaskCategory.urgente);
    });

    test('sin pistas usa personal y prioridad media', () {
      final parsed = TaskTextParser.parse('comprar pan');
      expect(parsed.category, TaskCategory.personal);
      expect(parsed.priority, TaskPriority.media);
    });
  });
}
