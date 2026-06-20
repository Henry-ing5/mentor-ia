import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
}
