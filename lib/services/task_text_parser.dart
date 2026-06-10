import '../models/task.dart';

/// Resultado del análisis de un texto libre (voz u OCR).
class ParsedTask {
  final String title;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime dueDate;

  const ParsedTask({
    required this.title,
    required this.category,
    required this.priority,
    required this.dueDate,
  });
}

/// Analiza texto en lenguaje natural (es) y deduce título, categoría,
/// prioridad y fecha de la tarea. Todo el procesamiento es on-device.
class TaskTextParser {
  static const _fillerPhrases = [
    'recordarme',
    'recuérdame',
    'recuerdame',
    'crear tarea',
    'crear una tarea',
    'nueva tarea',
    'agregar tarea',
    'añadir tarea',
    'tengo que',
    'debo',
  ];

  static const _workKeywords = [
    'trabajo',
    'reunión',
    'reunion',
    'oficina',
    'jefe',
    'cliente',
    'informe',
    'entrevista',
  ];

  static const _studyKeywords = [
    'estudiar',
    'estudio',
    'examen',
    'clase',
    'universidad',
    'ensayo',
    'exposición',
    'exposicion',
    'presentación',
    'presentacion',
    'proyecto',
    'asignación',
    'asignacion',
  ];

  static const _urgentKeywords = ['urgente', 'ya mismo', 'inmediato'];

  static const _highPriorityKeywords = [
    'urgente',
    'importante',
    'prioridad alta',
    'cuanto antes',
  ];

  static const _lowPriorityKeywords = [
    'prioridad baja',
    'sin prisa',
    'algún día',
    'algun dia',
    'cuando pueda',
  ];

  static ParsedTask parse(String rawText) {
    final text = rawText.trim();
    final lower = text.toLowerCase();

    return ParsedTask(
      title: _cleanTitle(text),
      category: _detectCategory(lower),
      priority: _detectPriority(lower),
      dueDate: _detectDate(lower),
    );
  }

  static String _cleanTitle(String text) {
    var title = text.trim();
    final lower = title.toLowerCase();
    for (final filler in _fillerPhrases) {
      if (lower.startsWith(filler)) {
        title = title.substring(filler.length).trim();
        break;
      }
    }
    if (title.isEmpty) title = text.trim();
    if (title.isEmpty) return title;
    // Primera letra en mayúscula
    return title[0].toUpperCase() + title.substring(1);
  }

  static TaskCategory _detectCategory(String lower) {
    if (_urgentKeywords.any(lower.contains)) return TaskCategory.urgente;
    if (_workKeywords.any(lower.contains)) return TaskCategory.trabajo;
    if (_studyKeywords.any(lower.contains)) return TaskCategory.estudio;
    return TaskCategory.personal;
  }

  static TaskPriority _detectPriority(String lower) {
    if (_highPriorityKeywords.any(lower.contains)) return TaskPriority.alta;
    if (_lowPriorityKeywords.any(lower.contains)) return TaskPriority.baja;
    return TaskPriority.media;
  }

  static DateTime _detectDate(String lower) {
    final now = DateTime.now();
    var date = now;

    if (lower.contains('pasado mañana') || lower.contains('pasado manana')) {
      date = now.add(const Duration(days: 2));
    } else if (lower.contains('mañana') || lower.contains('manana')) {
      date = now.add(const Duration(days: 1));
    } else if (lower.contains('próxima semana') ||
        lower.contains('proxima semana')) {
      date = now.add(const Duration(days: 7));
    }

    // "a las 8", "a las 14:30", "a la 1"
    final timeMatch =
        RegExp(r'a las? (\d{1,2})(?::(\d{2}))?').firstMatch(lower);
    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2) ?? '0');
      if (hour <= 12 &&
          (lower.contains('tarde') || lower.contains('noche'))) {
        hour += 12;
      }
      if (hour < 24 && minute < 60) {
        date = DateTime(date.year, date.month, date.day, hour, minute);
      }
    }

    return date;
  }
}
