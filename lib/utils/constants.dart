import 'package:flutter_dotenv/flutter_dotenv.dart';

class Constants {
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
  static const String groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String visionModel = 'qwen/qwen3.6-27b';
  static const String defaultInstructions =
      'Eres un tutor de IA. Tu nombre es Mentor IA. Siempre respondes en español.';
}
