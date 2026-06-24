import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../utils/constants.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final int instructionsVersion;
  final VoidCallback onUpdated;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.instructionsVersion,
    required this.onUpdated,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  bool _isLoading = false;
  String _chatInstructions = '';
  final List<Uint8List> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId) {
      _loadMessages();
    } else if (widget.instructionsVersion != oldWidget.instructionsVersion) {
      _loadMessages();
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final id = widget.conversationId;
    if (id == null) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _chatInstructions = '';
        });
      }
      return;
    }
    final conversations = await _storage.loadConversations();
    try {
      final conv = conversations.firstWhere((c) => c.id == id);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(conv.messages);
        _chatInstructions = conv.instructions;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.clear();
          _chatInstructions = '';
        });
      }
    }
  }

  String get _systemPrompt {
    final base = r'Usa formato markdown para dar formato al texto '
        '(**negritas**, ## títulos, --- líneas, tablas). '
        'Para TODA notación matemática usa exclusivamente Unicode en línea con el texto. '
        'PROHIBIDO usar cualquier comando LaTeX incluyendo: '
        r'\text{}, \tfrac{}, \frac{}, \boxed{}, \begin{}, \displaystyle, \left, \right. '
        r'PROHIBIDO usar corchetes [...] o paréntesis \(...\) para ecuaciones. '
        r'PROHIBIDO usar \$, \$\$, \{, \} para fórmulas. '
        'NO uses backslash NUNCA en las fórmulas. '
        'Usa SOLO caracteres Unicode directos, sin escapes ni comandos. '
        'Dispones de: '
        'θ, ω, α, β, π, ∞, √, Δ, Σ, ∫, ∈, ≈, ≠, ≤, ≥, →, ⇒, ↔, ·, ×, ÷, ±, ½, ², ³, ⁴, ⁵, ⁶, ⁷, ⁸, ⁹, ⁰, '
        '₁, ₂, ₃, ₄, ₅, ₆, ₇, ₈, ₉, ₀, '
        '∂, ∇, ∏, ∪, ∩, ⊆, ⊂, ∈, ∉, ∀, ∃, ¬, ∧, ∨, ⊕, ⊗, ∞. '
        'Ejemplos correctos: F = G·m₁·m₂ / r², E = ½·m·v², θ = θ₀ + ω₀·t + ½·α·t², '
        'K_rot = ½·I·ω², I_nuevo = I_CM + M·d². '
        'NO cortes las respuestas. Termina siempre cada sección, lista y explicación completa.';
    final trimmed = _chatInstructions.trim();
    if (trimmed.isEmpty) return base;
    if (trimmed == Constants.defaultInstructions) return '$base\n\n$trimmed';
    return '$base\n\n$trimmed';
  }

  Future<void> _ensureConversationExists() async {
    final id = widget.conversationId;
    if (id == null) return;
    final conversations = await _storage.loadConversations();
    final exists = conversations.any((c) => c.id == id);
    if (!exists) {
      final conv = Conversation(
        id: id,
        title: 'Nueva conversación',
        createdAt: DateTime.now(),
        messages: [],
      );
      await _storage.addConversation(conv);
      await _storage.saveActiveConversationId(id);
    }
  }

  Future<void> _persistMessages() async {
    final id = widget.conversationId;
    if (id == null) return;
    await _ensureConversationExists();
    await _storage.saveMessages(id, _messages);
  }



  Future<void> _pickMultipleImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result != null && result.files.isNotEmpty) {
      List<Uint8List> newImages = [];
      for (var file in result.files) {
        if (file.bytes != null) {
          newImages.add(file.bytes!);
        } else if (file.path != null) {
          final fileBytes = await File(file.path!).readAsBytes();
          newImages.add(fileBytes);
        }
      }
      if (newImages.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(newImages);
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty && _selectedImages.isEmpty) return;

    String displayText = text;
    if (_selectedImages.isNotEmpty) {
      displayText += ' [${_selectedImages.length} imagen(es) adjunta(s)]';
    }
    final isFirstUserMessage = _messages.where((m) => m.isUser).isEmpty;
    setState(() {
      _messages.add(Message(text: displayText, isUser: true));
      _inputController.clear();
      _isLoading = true;
    });

    await _persistMessages();

    ApiResult result;
    if (_selectedImages.isNotEmpty) {
      result = await _apiService.sendMessageWithImages(
        text,
        _systemPrompt,
        _selectedImages,
      );
    } else {
      result = await _apiService.sendMessage(text, _systemPrompt);
    }

    if (!mounted) return;

    String fullResponse = result.content;
    setState(() {
      _messages.add(Message(text: fullResponse, isUser: false));
    });

    int retries = 0;
    while (result.finishReason == 'length' && retries < 3) {
      result = await _apiService.sendContinuation(
        _systemPrompt,
        fullResponse,
        'Continúa exactamente desde donde te quedaste. No repitas nada de lo ya dicho. Sigue escribiendo la respuesta exactamente desde el punto donde se interrumpió.',
      );

      if (!mounted) return;
      fullResponse += result.content;
      setState(() {
        _messages.last = Message(text: fullResponse, isUser: false);
      });
      retries++;
    }

    setState(() {
      _isLoading = false;
      _selectedImages.clear();
    });

    if (text.isNotEmpty && isFirstUserMessage) {
      final id = widget.conversationId;
      if (id != null) {
        final title = text.length > 40 ? '${text.substring(0, 40)}...' : text;
        await _storage.updateTitle(id, title);
        widget.onUpdated();
      }
    }

    await _persistMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            reverse: true,
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[_messages.length - 1 - index];
              final isUser = msg.isUser;
              final cs = Theme.of(context).colorScheme;
              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? cs.primaryContainer : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SelectionArea(
                    child: MarkdownBody(
                      data: msg.text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: cs.onSurface),
                        strong: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                        em: TextStyle(fontStyle: FontStyle.italic, color: cs.onSurface),
                        h1: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
                        h2: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface),
                        h3: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface),
                        code: TextStyle(
                          backgroundColor: cs.surfaceContainerHighest,
                          color: cs.primary,
                          fontSize: 13,
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        blockquoteDecoration: BoxDecoration(
                          border: Border(left: BorderSide(color: cs.primary, width: 3)),
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                        ),
                        tableBorder: TableBorder.all(color: cs.outlineVariant, width: 1),
                        tableHead: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface),
                        tableBody: TextStyle(color: cs.onSurface),
                        horizontalRuleDecoration: BoxDecoration(
                          border: Border(top: BorderSide(color: cs.outlineVariant)),
                        ),
                        listBullet: TextStyle(color: cs.onSurface),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_selectedImages.isNotEmpty)
          Container(
            height: 100,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Image.memory(
                        _selectedImages[index],
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          color: Colors.black54,
                          child: const Icon(Icons.close, size: 20, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                onPressed: _isLoading ? null : _pickMultipleImages,
                icon: const Icon(Icons.image),
                tooltip: 'Adjuntar imágenes (múltiples)',
              ),
              Expanded(
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter) {
                      if (HardwareKeyboard.instance.isShiftPressed) {
                        return KeyEventResult.ignored;
                      }
                      _sendMessage();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _inputController,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu pregunta o describe las imágenes...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading ? null : _sendMessage,
                icon: const Icon(Icons.send),
                tooltip: 'Enviar',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
