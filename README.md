# Agente IA

Asistente de IA con interfaz Flutter usando Google Gemini API.

## Características

- **Chat** con un agente de IA vía Gemini API
- **Instrucciones personalizables** define la personalidad y reglas del asistente (se guardan localmente)
- Interfaz con pestañas (Instrucciones / Chat)
- Persistencia de instrucciones con `shared_preferences`

## Requisitos

- Flutter SDK >=3.12.2
- Una clave de API de Google Gemini

## Configuración

1. Edita `assets/.env` y agrega tu clave de Gemini:

```
GEMINI_API_KEY=tu_clave_aqui
```

2. Instala dependencias:

```bash
flutter pub get
```

## Uso

```bash
flutter run
```

## Compilar

### Android (APK)
```bash
flutter build apk --release
```

### Linux
```bash
flutter build linux --release
```

## Estructura

```
lib/
├── main.dart                   # Punto de entrada con TabBar
├── models/message.dart         # Modelo de mensaje
├── screens/
│   ├── instructions_screen.dart  # Editor de instrucciones
│   └── chat_screen.dart          # Pantalla de chat
├── services/api_service.dart   # Llamada a Gemini API
└── utils/constants.dart        # Constantes y configuración
```
