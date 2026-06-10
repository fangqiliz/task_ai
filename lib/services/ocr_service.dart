import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// Resultado de un escaneo OCR.
class OcrResult {
  /// Líneas de texto detectadas, candidatas a convertirse en tareas.
  final List<String> lines;

  /// true si el usuario canceló la captura (no es un error).
  final bool cancelled;

  const OcrResult({this.lines = const [], this.cancelled = false});

  bool get isEmpty => lines.isEmpty;
}

/// Captura una imagen (cámara o galería) y reconoce el texto con
/// Google ML Kit. Todo el procesamiento ocurre on-device.
class OcrService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Escanea texto desde la cámara o la galería y devuelve las líneas
  /// detectadas. Lanza una excepción si ML Kit falla.
  Future<OcrResult> scan({required bool fromCamera}) async {
    final XFile? image = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) return const OcrResult(cancelled: true);

    final inputImage = InputImage.fromFilePath(image.path);
    final RecognizedText recognized =
        await _recognizer.processImage(inputImage);

    final lines = <String>[];
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        // Se descartan líneas muy cortas (ruido del OCR)
        if (text.length >= 3) lines.add(text);
      }
    }
    return OcrResult(lines: lines);
  }

  void dispose() {
    _recognizer.close();
  }
}
