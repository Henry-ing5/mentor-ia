import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  final TextEditingController _controller = TextEditingController();
  final String _prefKey = 'agent_instructions';

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null) {
      _controller.text = saved;
    } else {
      _controller.text = "Eres un asistente de IA útil, amigable y que responde en español.";
    }
    setState(() {});
  }

  Future<void> _saveInstructions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _controller.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instrucciones guardadas correctamente')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Instrucciones del Agente')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  hintText: 'Define la personalidad y reglas del asistente...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _saveInstructions,
              icon: const Icon(Icons.save),
              label: const Text('Guardar Instrucciones'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
