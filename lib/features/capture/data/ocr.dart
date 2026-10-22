import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Reads the text in an image with ML Kit's on-device Latin model, one
/// string per block (a receipt section, an SMS bubble). The image never
/// leaves the phone.
Future<List<String>> readTextBlocksFromImage(String path) async {
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(path));
    return [
      for (final block in result.blocks)
        [for (final line in block.lines) line.text].join('\n'),
    ];
  } finally {
    await recognizer.close();
  }
}
