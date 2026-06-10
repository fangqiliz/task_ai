import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/task.dart';
import '../providers/task_provider.dart';
import '../services/ocr_service.dart';
import '../services/speech_service.dart';
import '../services/task_text_parser.dart';
import '../theme/app_colors.dart';

/// Pantalla "Asistente IA" (mockup 03): captura por voz (speech_to_text)
/// y escaneo OCR (google_mlkit_text_recognition), todo on-device.
class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen>
    with TickerProviderStateMixin {
  final SpeechService _speechService = SpeechService();
  final OcrService _ocrService = OcrService();

  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  bool _isListening = false;
  bool _isProcessingImage = false;
  bool _voiceTaskCreated = false;
  String _transcript = '';
  double _soundLevel = 0;
  String _suggestion =
      'Dicta una tarea con tu voz o escanea un documento: yo detecto el '
      'título, la categoría y la prioridad por ti.';

  static const List<double> _waveBaseHeights = [
    10, 18, 22, 14, 24, 8, 16, 20, 12, 18, 22, 14,
  ];
  static const _waveColors = [
    AppColors.primary,
    AppColors.violetLight,
    AppColors.cyan,
    AppColors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _speechService.cancel();
    _ocrService.dispose();
    super.dispose();
  }

  // ===================== Opción A · Captura por voz =====================

  Future<void> _toggleListening() async {
    if (_speechService.isListening) {
      await _speechService.stop();
      return;
    }

    final available = await _speechService.init(onStatus: _onSpeechStatus);
    if (!available || !mounted) return;

    setState(() {
      _isListening = true;
      _transcript = '';
      _voiceTaskCreated = false;
    });

    await _speechService.listen(
      onResult: (text, isFinal) {
        if (!mounted) return;
        setState(() => _transcript = text);
        if (isFinal) _createTaskFromVoice();
      },
      onSoundLevel: (level) {
        if (mounted) setState(() => _soundLevel = level);
      },
    );
  }

  void _onSpeechStatus(SpeechStatus status) {
    if (!mounted) return;
    switch (status) {
      case SpeechStatus.idle:
        setState(() => _isListening = false);
        _createTaskFromVoice();
      case SpeechStatus.permissionDenied:
        setState(() {
          _isListening = false;
          _suggestion = 'Necesito acceso al micrófono para dictar tareas. '
              'Activa el permiso en los ajustes del sistema.';
        });
        _showSnack('Permiso de micrófono denegado');
      case SpeechStatus.unavailable:
        setState(() {
          _isListening = false;
          _suggestion =
              'El reconocimiento de voz no está disponible en este dispositivo.';
        });
        _showSnack('Reconocimiento de voz no disponible');
      case SpeechStatus.error:
        setState(() => _isListening = false);
        _showSnack('No te escuché bien, intenta de nuevo');
      case SpeechStatus.listening:
        break;
    }
  }

  void _createTaskFromVoice() {
    if (_voiceTaskCreated) return;
    final text = _transcript.trim();
    if (text.isEmpty) return;
    _voiceTaskCreated = true;

    final parsed = TaskTextParser.parse(text);
    context.read<TaskProvider>().addTask(Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: parsed.title,
          description: 'Creada por voz con TaskAI',
          category: parsed.category,
          priority: parsed.priority,
          dueDate: parsed.dueDate,
        ));

    setState(() {
      _isListening = false;
      _suggestion = 'Tarea creada por voz: "${parsed.title}" · '
          '${_categoryLabel(parsed.category)} · '
          'prioridad ${_priorityLabel(parsed.priority)}';
    });
    _showSnack('✨ Tarea creada: ${parsed.title}');
  }

  // ===================== Opción B · Escaneo OCR =====================

  Future<void> _scanText({required bool fromCamera}) async {
    if (_isProcessingImage) return;
    setState(() => _isProcessingImage = true);
    try {
      final result = await _ocrService.scan(fromCamera: fromCamera);
      if (!mounted || result.cancelled) return;
      if (result.isEmpty) {
        _showSnack('No detecté texto en la imagen, intenta con más luz');
        return;
      }
      _showOcrResultsSheet(result.lines);
    } catch (_) {
      if (mounted) {
        _showSnack('No pude procesar la imagen. Revisa el permiso de cámara');
      }
    } finally {
      if (mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _showOcrResultsSheet(List<String> lines) {
    final selected = List<bool>.filled(lines.length, true);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.aiDarkMid,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final count = selected.where((s) => s).length;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '📷 Texto detectado',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Selecciona las líneas que quieres convertir en tareas',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lines.length,
                    itemBuilder: (_, i) => CheckboxListTile(
                      value: selected[i],
                      onChanged: (v) =>
                          setSheetState(() => selected[i] = v ?? false),
                      title: Text(
                        lines[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      activeColor: AppColors.primary,
                      checkColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: count == 0
                      ? null
                      : () {
                          final chosen = [
                            for (var i = 0; i < lines.length; i++)
                              if (selected[i]) lines[i],
                          ];
                          Navigator.pop(sheetContext);
                          _createTasksFromOcr(chosen);
                        },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppColors.purpleGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count == 0
                          ? 'Selecciona al menos una línea'
                          : 'Crear $count ${count == 1 ? 'tarea' : 'tareas'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _createTasksFromOcr(List<String> lines) {
    final provider = context.read<TaskProvider>();
    final baseId = DateTime.now().millisecondsSinceEpoch;
    final titles = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final parsed = TaskTextParser.parse(lines[i]);
      titles.add(parsed.title);
      provider.addTask(Task(
        id: '${baseId}_$i',
        title: parsed.title,
        description: 'Creada con escaneo OCR de TaskAI',
        category: parsed.category,
        priority: parsed.priority,
        dueDate: parsed.dueDate,
      ));
    }

    final preview = titles.take(3).map((t) => '"$t"').join(', ');
    setState(() {
      _suggestion = 'Detecté ${titles.length} '
          '${titles.length == 1 ? 'tarea' : 'tareas'} en tu foto: $preview'
          '${titles.length > 3 ? '…' : ''}';
    });
    _showSnack('✨ ${titles.length} ${titles.length == 1 ? 'tarea creada' : 'tareas creadas'} desde la imagen');
  }

  // ===================== Helpers =====================

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primaryDark,
      ));
  }

  String _categoryLabel(TaskCategory c) => switch (c) {
        TaskCategory.trabajo => '💼 Trabajo',
        TaskCategory.personal => '🙂 Personal',
        TaskCategory.estudio => '🎓 Estudio',
        TaskCategory.urgente => '⚡ Urgente',
      };

  String _priorityLabel(TaskPriority p) => switch (p) {
        TaskPriority.alta => 'alta',
        TaskPriority.media => 'media',
        TaskPriority.baja => 'baja',
      };

  // ===================== UI =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.aiBackgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              _buildBlob(top: 40, right: -40, color: AppColors.pink),
              _buildBlob(bottom: 140, left: -30, color: AppColors.cyan),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 8),
                  _buildVoiceButton(),
                  const SizedBox(height: 14),
                  _buildVoiceHint(),
                  const SizedBox(height: 10),
                  _buildVoiceWave(),
                  _buildCaptureSection(),
                  const Spacer(),
                  _buildSuggestionCard(),
                  const SizedBox(height: 12),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: IgnorePointer(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.3), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        children: [
          Text(
            'Hola, soy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.aiTitleGradient.createShader(bounds),
            child: const Text(
              'TaskAI Assistant',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¿Cómo puedo organizarte hoy?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Center(
      child: GestureDetector(
        onTap: _toggleListening,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final t = _pulseController.value;
            final pulseScale = 1 + (_isListening ? 0.35 : 0.15) * t;
            return SizedBox(
              width: 130,
              height: 130,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Halo pulsante
                  Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary
                            .withValues(alpha: 0.35 * (1 - t)),
                      ),
                    ),
                  ),
                  // Anillo fijo
                  Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                  ),
                  child!,
                ],
              ),
            );
          },
          child: Container(
            width: 86,
            height: 86,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.voiceGradient,
              boxShadow: [
                BoxShadow(
                  color: Color(0x997C5CFF),
                  blurRadius: 30,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 38,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHint() {
    final text = _isListening
        ? (_transcript.isEmpty ? 'Escuchando…' : '"$_transcript"')
        : 'Toca para hablar · "Recordarme estudiar mañana a las 8"';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: _isListening ? 0.95 : 0.7),
          fontSize: _isListening ? 13 : 11,
          fontWeight: _isListening ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildVoiceWave() {
    return SizedBox(
      height: 28,
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          // Nivel de sonido del micrófono normalizado (rango típico -2..10)
          final level = ((_soundLevel + 2) / 12).clamp(0.0, 1.0);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_waveBaseHeights.length, (i) {
              double height = _waveBaseHeights[i];
              if (_isListening) {
                final phase =
                    _waveController.value * 2 * math.pi + i * 0.7;
                height = height *
                    (0.45 + 0.55 * (0.5 + 0.5 * math.sin(phase))) *
                    (0.7 + 0.6 * level);
              }
              return Container(
                width: 3,
                height: height.clamp(4.0, 28.0),
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                decoration: BoxDecoration(
                  color: _waveColors[i % _waveColors.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildCaptureSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'CAPTURA INTELIGENTE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const Spacer(),
              if (_isProcessingImage)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.cyan,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CaptureCard(
                  emoji: '📷',
                  title: 'OCR Escáner',
                  subtitle: 'Escanea documentos',
                  onTap: () => _scanText(fromCamera: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CaptureCard(
                  emoji: '📸',
                  title: 'Foto',
                  subtitle: 'Extrae tareas',
                  onTap: () => _scanText(fromCamera: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.25),
            AppColors.cyan.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✨', style: TextStyle(fontSize: 12)),
              SizedBox(width: 6),
              Text(
                'SUGERENCIA IA',
                style: TextStyle(
                  color: Color(0xFFC4B5FD),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _suggestion,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.aiDarkTop.withValues(alpha: 0.95),
        border: const Border(
          top: BorderSide(color: Colors.white12),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _DarkNavItem(
                icon: Icons.home_rounded,
                label: 'Inicio',
                active: false,
                onTap: () => context.go('/'),
              ),
              _DarkNavItem(
                icon: Icons.auto_awesome,
                label: 'IA',
                active: true,
                onTap: () {},
              ),
              _DarkNavItem(
                icon: Icons.calendar_month_outlined,
                label: 'Calendario',
                active: false,
                onTap: () => _showSnack('Disponible próximamente'),
              ),
              _DarkNavItem(
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                active: false,
                onTap: () => context.push('/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaptureCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CaptureCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DarkNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? const Color(0xFFC4B5FD) : Colors.white.withValues(alpha: 0.6);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
