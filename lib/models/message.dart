class Message {
  final String text;
  final bool isUser; // true = usuario, false = asistente

  Message({required this.text, required this.isUser});
}
