import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../utils/constants.dart';

class ApiResult {
  final String content;
  final String finishReason;
  const ApiResult(this.content, this.finishReason);
}

class ApiService {
  static const int maxWidth = 800;
  static const int quality = 70;

  String _stripThinking(String response) {
    final cleaned = response.replaceAll(RegExp(r'<(thinking|think)>.*?</\1>', dotAll: true), '').trim();
    return cleaned.isEmpty ? response : cleaned;
  }

  Future<Uint8List?> _compressImage(Uint8List bytes) {
    try {
      final image = img.decodeImage(bytes);
      if (image == null) return Future.value(bytes);
      final resized = img.copyResize(image, width: maxWidth);
      return Future.value(Uint8List.fromList(img.encodeJpg(resized, quality: quality)));
    } catch (e) {
      return Future.value(bytes);
    }
  }

  Future<ApiResult> _post(List<Map<String, dynamic>> messages, {int maxTokens = 4000}) async {
    final url = Uri.parse(Constants.groqUrl);
    final Map<String, dynamic> requestBody = {
      "model": "openai/gpt-oss-120b",
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": maxTokens,
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
        final content = _stripThinking(data['choices'][0]['message']['content']);
        final finishReason = data['choices'][0]['finish_reason'] as String? ?? 'stop';
        return ApiResult(content, finishReason);
      } else {
        return ApiResult("Error ${response.statusCode}: ${response.body}", 'error');
      }
    } catch (e) {
      return ApiResult("Error de conexión: $e", 'error');
    }
  }

  Future<ApiResult> sendMessage(
    String userMessage,
    String systemInstructions,
  ) async {
    return _post([
      {"role": "system", "content": systemInstructions},
      {"role": "user", "content": userMessage},
    ]);
  }

  Future<ApiResult> sendMessageWithImages(
    String userMessage,
    String systemInstructions,
    List<Uint8List> imageBytesList,
  ) async {
    List<Map<String, dynamic>> content = [];

    if (userMessage.isNotEmpty) {
      content.add({"type": "text", "text": userMessage});
    }

    for (var i = 0; i < imageBytesList.length; i++) {
      final compressed = await _compressImage(imageBytesList[i]);
      if (compressed != null) {
        String base64Image = base64Encode(compressed);
        content.add({
          "type": "image_url",
          "image_url": {
            "url": "data:image/jpeg;base64,$base64Image"
          }
        });
      }
    }

    final url = Uri.parse(Constants.groqUrl);
    final Map<String, dynamic> requestBody = {
      "model": Constants.visionModel,
      "messages": [
        {"role": "system", "content": systemInstructions},
        {"role": "user", "content": content}
      ],
      "temperature": 0.7,
      "max_tokens": 4000,
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
        final assistantResponse = _stripThinking(data['choices'][0]['message']['content']);
        final finishReason = data['choices'][0]['finish_reason'] as String? ?? 'stop';
        return ApiResult(assistantResponse, finishReason);
      } else {
        return ApiResult("Error ${response.statusCode}: ${response.body}", 'error');
      }
    } catch (e) {
      return ApiResult("Error de conexión: $e", 'error');
    }
  }

  Future<ApiResult> sendContinuation(
    String systemInstructions,
    String lastAssistantResponse,
    String continuationPrompt,
  ) async {
    return _post([
      {"role": "system", "content": systemInstructions},
      {"role": "user", "content": "$lastAssistantResponse\n\n$continuationPrompt"},
    ], maxTokens: 3000);
  }
}
