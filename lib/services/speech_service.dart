import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Estados posibles de la captura por voz, para dar feedback al usuario.
enum SpeechStatus { idle, listening, unavailable, permissionDenied, error }

/// Envuelve speech_to_text: inicialización, permisos del micrófono y
/// transcripción en vivo. El reconocimiento ocurre on-device.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  /// Inicializa el motor de voz. Devuelve false si el dispositivo no tiene
  /// reconocimiento disponible o el usuario negó el permiso de micrófono.
  Future<bool> init({
    required void Function(SpeechStatus status) onStatus,
  }) async {
    if (_initialized) return true;
    try {
      _initialized = await _speech.initialize(
        onError: (SpeechRecognitionError error) {
          onStatus(error.permanent
              ? SpeechStatus.unavailable
              : SpeechStatus.error);
        },
        onStatus: (String status) {
          if (status == 'notListening' || status == 'done') {
            onStatus(SpeechStatus.idle);
          }
        },
      );
    } catch (_) {
      _initialized = false;
    }
    if (!_initialized) {
      final hasMicPermission = await _speech.hasPermission;
      onStatus(hasMicPermission
          ? SpeechStatus.unavailable
          : SpeechStatus.permissionDenied);
    }
    return _initialized;
  }

  /// Escucha y entrega la transcripción parcial y final en español.
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function(double level) onSoundLevel,
  }) async {
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      onSoundLevelChange: onSoundLevel,
      listenOptions: SpeechListenOptions(
        localeId: 'es',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}
