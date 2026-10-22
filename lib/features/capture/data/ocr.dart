import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text in an image with ML Kit's on-device Latin model. The image
/// never leaves the phone.
Future<String> readTextFromImage(String path) async {
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    // Block by block keeps labels ("Paid to") next to their values.
    return [
      for (final block in result.blocks)
        for (final line in block.lines) line.text,
    ].join('\n');
  } finally {
    await recognizer.close();
  }
}
