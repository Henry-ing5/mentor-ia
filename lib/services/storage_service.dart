import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class StorageService {
  static const _themeKey = 'theme_mode';
  static const _activeKey = 'active_conversation_id';
  static const _conversationsKey = 'conversations';

  // Tema
  Future<String> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey) ?? 'light';
  }

  Future<void> saveThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  // Conversación activa
  Future<String?> loadActiveConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  Future<void> saveActiveConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  // Conversaciones
  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_conversationsKey);
    if (data == null) return [];
    final list = jsonDecode(data) as List;
    return list.map((e) => Conversation.fromJson(e)).toList();
  }

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(conversations.map((c) => c.toJson()).toList());
    await prefs.setString(_conversationsKey, data);
  }

  // Conveniencia: obtener conversación activa
  Future<Conversation?> getActiveConversation() async {
    final id = await loadActiveConversationId();
    if (id == null) return null;
    final conversations = await loadConversations();
    try {
      return conversations.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // Conveniencia: guardar mensajes de una conversación
  Future<void> saveMessages(String conversationId, List<Message> messages) async {
    final conversations = await loadConversations();
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    conversations[index].messages.clear();
    conversations[index].messages.addAll(messages);
    await saveConversations(conversations);
  }

  // Conveniencia: actualizar título
  Future<void> updateTitle(String conversationId, String title) async {
    final conversations = await loadConversations();
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    conversations[index].title = title;
    await saveConversations(conversations);
  }

  // Conveniencia: agregar conversación
  Future<void> addConversation(Conversation conversation) async {
    final conversations = await loadConversations();
    conversations.insert(0, conversation);
    await saveConversations(conversations);
  }

  // Conveniencia: actualizar instrucciones
  Future<void> updateInstructions(String conversationId, String instructions) async {
    final conversations = await loadConversations();
    final index = conversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) return;
    conversations[index].instructions = instructions;
    await saveConversations(conversations);
  }
}
