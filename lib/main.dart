import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/chat_screen.dart';
import 'screens/instructions_screen.dart';
import 'services/storage_service.dart';
import 'models/conversation.dart';

void main() async {
  await dotenv.load(fileName: "assets/.env");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await StorageService().loadThemeMode();
    if (!mounted) return;
    setState(() {
      _themeMode = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleTheme() {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    setState(() => _themeMode = newMode);
    StorageService().saveThemeMode(newMode == ThemeMode.dark ? 'dark' : 'light');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mentor IA',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: HomeScreen(onThemeToggle: _toggleTheme, isDark: _themeMode == ThemeMode.dark),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDark;

  const HomeScreen({super.key, required this.onThemeToggle, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storage = StorageService();
  List<Conversation> _conversations = [];
  String? _activeId;
  String _activeTitle = 'Nueva conversación';
  int _instructionsVersion = 0;
  bool _isEditingTitle = false;
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final conversations = await _storage.loadConversations();
    if (!mounted) return;
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _conversations = conversations;
      _activeId = newId;
      _activeTitle = 'Nueva conversación';
    });
  }

  void _updateActiveTitle() {
    if (_activeId == null) {
      _activeTitle = 'Chat';
      return;
    }
    try {
      final conv = _conversations.firstWhere((c) => c.id == _activeId);
      _activeTitle = conv.title;
    } catch (_) {
      _activeTitle = 'Chat';
    }
  }

  Future<void> _newConversation() async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _activeTitle = 'Nueva conversación';
    });
    Navigator.of(context).pop();
  }

  Future<void> _selectConversation(String id) async {
    await _storage.saveActiveConversationId(id);
    if (!mounted) return;
    setState(() {
      _activeId = id;
      _updateActiveTitle();
    });
    Navigator.of(context).pop();
  }

  Future<void> _onChatUpdated() async {
    final conversations = await _storage.loadConversations();
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      _updateActiveTitle();
      _instructionsVersion++;
    });
  }

  void _saveTitle(String newTitle) {
    if (newTitle.trim().isEmpty) return;
    setState(() {
      _activeTitle = newTitle.trim();
      _isEditingTitle = false;
    });
    if (_activeId != null) {
      _storage.updateTitle(_activeId!, newTitle.trim());
      _onChatUpdated();
    }
  }

  Future<void> _showRenameDialog(Conversation conv) async {
    final controller = TextEditingController(text: conv.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renombrar conversación'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre de la conversación',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newTitle != null && newTitle.isNotEmpty) {
      await _storage.updateTitle(conv.id, newTitle);
      await _onChatUpdated();
    }
  }

  Future<void> _showDeleteConfirmation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conversación'),
        content: const Text('¿Seguro que quieres eliminar esta conversación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteConversation(id);
    }
  }

  Future<void> _deleteConversation(String id) async {
    final conversations = await _storage.loadConversations();
    conversations.removeWhere((c) => c.id == id);
    await _storage.saveConversations(conversations);
    if (_activeId == id) {
      final newId = conversations.isNotEmpty ? conversations.first.id : null;
      await _storage.saveActiveConversationId(newId ?? '');
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _activeId = newId;
        _updateActiveTitle();
      });
    } else {
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(border: InputBorder.none),
                style: Theme.of(context).textTheme.titleMedium,
                onSubmitted: _saveTitle,
              )
            : GestureDetector(
                onTap: () {
                  _titleController.text = _activeTitle;
                  setState(() => _isEditingTitle = true);
                },
                child: Text(_activeTitle),
              ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: 'Chat'),
            Tab(icon: Icon(Icons.settings), text: 'Instrucciones'),
          ],
        ),
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: cs.primaryContainer,
                child: Text(
                  'Conversaciones',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _conversations.length,
                  itemBuilder: (context, index) {
                    final conv = _conversations[index];
                    final isActive = conv.id == _activeId;
                    return ListTile(
                      selected: isActive,
                      selectedTileColor: cs.primaryContainer.withValues(alpha: 0.5),
                      leading: const Icon(Icons.chat_outlined),
                      title: Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${conv.messages.length} mensajes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onTap: () => _selectConversation(conv.id),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showRenameDialog(conv),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => _showDeleteConfirmation(conv.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ElevatedButton.icon(
                  onPressed: _newConversation,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva conversación'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Configuración',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Modo oscuro'),
                secondary: Icon(widget.isDark ? Icons.dark_mode : Icons.light_mode),
                value: widget.isDark,
                onChanged: (_) => widget.onThemeToggle(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _tabController.index,
        children: [
          ChatScreen(
            key: ValueKey(_activeId),
            conversationId: _activeId,
            instructionsVersion: _instructionsVersion,
            onUpdated: _onChatUpdated,
          ),
          InstructionsScreen(
            key: ValueKey('${_activeId}_instructions'),
            conversationId: _activeId,
            instructionsVersion: _instructionsVersion,
            onUpdated: _onChatUpdated,
          ),
        ],
      ),
    );
  }
}
