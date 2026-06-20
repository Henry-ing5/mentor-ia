import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

class ApiService {
  Future<String> sendMessage(
    String userMessage,
    String systemInstructions,
  ) async {
    final url = Uri.parse(Constants.groqUrl);

    final Map<String, dynamic> requestBody = {
      "model":
          "llama-3.3-70b-versatile", // Puedes cambiarlo a "mixtral-8x7b-32768" si prefieres
      "messages": [
        {"role": "system", "content": systemInstructions},
        {"role": "user", "content": userMessage},
      ],
      "temperature": 0.7,
      "max_tokens": 800,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Constants.groqApiKey}',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final assistantResponse = data['choices'][0]['message']['content'];
        return assistantResponse;
      } else {
        return "Error ${response.statusCode}: ${response.body}";
      }
    } catch (e) {
      return "Error de conexión: $e";
    }
  }
}
