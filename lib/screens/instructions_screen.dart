import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/message.dart';
import '../models/conversation.dart';
import '../utils/constants.dart';

class InstructionsScreen extends StatefulWidget {
  final String? conversationId;
  final int instructionsVersion;
  final VoidCallback onUpdated;

  const InstructionsScreen({
    super.key,
    required this.conversationId,
    required this.instructionsVersion,
    required this.onUpdated,
  });

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final TextEditingController _chatController = TextEditingController();
  final StorageService _storage = StorageService();
  String _chatTitle = '';

  @override
  void initState() {
    super.initState();
    _loadChat();
  }

  @override
  void didUpdateWidget(InstructionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.conversationId != oldWidget.conversationId ||
        widget.instructionsVersion != oldWidget.instructionsVersion) {
      _loadChat();
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _loadChat() async {
    final id = widget.conversationId;
    if (id == null) {
      _chatController.text = '';
      _chatTitle = '';
      if (mounted) setState(() {});
      return;
    }
    final conversations = await _storage.loadConversations();
    try {
      final conv = conversations.firstWhere((c) => c.id == id);
      if (!mounted) return;
      _chatTitle = conv.title;
      final stored = conv.instructions;
      final custom = stored.startsWith(Constants.defaultInstructions)
          ? stored.substring(Constants.defaultInstructions.length).trim()
          : stored;
      _chatController.text = custom;
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
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
      widget.onUpdated();
    }
  }

  Future<void> _saveChat() async {
    final id = widget.conversationId;
    if (id == null) return;

    await _ensureConversationExists();

    final conversations = await _storage.loadConversations();
    try {
      final conv = conversations.firstWhere((c) => c.id == id);
      final custom = _chatController.text.trim();
      final hasNoMessages = conv.messages.isEmpty;

      conv.instructions = Constants.defaultInstructions +
          (custom.isNotEmpty ? '\n\n$custom' : '');

      if (hasNoMessages) {
        conv.messages.add(Message(
          text: '¡Hola! Soy Mentor IA, tu tutor personal. ¿Con qué tema te gustaría empezar?',
          isUser: false,
        ));
      }

      await _storage.saveConversations(conversations);
      widget.onUpdated();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Instrucciones de "${conv.title}" guardadas')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar instrucciones')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.conversationId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Selecciona o crea una conversación para personalizar sus instrucciones.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          Text(
            'Instrucciones de este chat: "$_chatTitle"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    Constants.defaultInstructions,
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega instrucciones adicionales para este chat:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _chatController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Ej: Vamos a estudiar cálculo diferencial...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _saveChat,
            icon: const Icon(Icons.save),
            label: const Text('Guardar instrucciones del chat'),
          ),
        ],
      ],
    );
  }
}
