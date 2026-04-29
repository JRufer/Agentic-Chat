# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Agentic Chat** (`agentic_chat`) is a fully on-device Flutter/Android chat application running Gemma 4 (via LiteRT-LM) with zero cloud dependencies. The AI is "agentic" because it autonomously executes tools (memory saving, web search, reminders, image search) by emitting bracket-tagged commands in its token stream that `chat_screen.dart` intercepts and acts on before the user ever sees them.

## Common Commands

```bash
# Run on connected Android device
flutter run

# Build release APK
flutter build apk --release

# Run code generation (Riverpod + ObjectBox)
dart run build_runner build --delete-conflicting-outputs

# Watch mode for codegen during development
dart run build_runner watch --delete-conflicting-outputs

# Analyze code
flutter analyze

# Run tests
flutter test
```

## Architecture

### The Agentic Loop (critical to understand)

The heart of the app is in `lib/features/chat/screens/chat_screen.dart:_handleUserInput()`. When the user sends a message:

1. **Prompt assembly** — `chat_screen.dart` injects: system template (from `prompts_config.dart`), current datetime, flat-list memories (from `shared_preferences`), and the user message.
2. **Streaming** — `ManagedRuntime.generate()` returns a `Stream<String>` of tokens from `flutter_litert_lm`.
3. **Tool interception** — The stream listener watches for bracket tags. On completion, regex matches strip the tags from the display text and execute side effects:
   - `[SAVE_MEMORY: fact]` → writes to `memoryProvider` (SharedPreferences)
   - `[REMIND_ME: title | YYYY-MM-DD HH:MM:00]` → schedules a local notification via `ReminderService`
   - `[SEARCH_WEB: query]` → calls `WebSearchService` (DuckDuckGo Lite scrape), then **recursively calls `_handleUserInput`** with the results injected as context
   - `[SEARCH_IMAGE: query]` → fetches an image URL and attaches it to the chat bubble
   - `[MOOD: <type>]` — if autonomous mood switching is enabled, this prefix is parsed mid-stream to update `settingsProvider`

### Key Layers

| Layer | Location | Purpose |
|---|---|---|
| LLM engine | `lib/core/ai/inference_engine.dart` | Wraps `flutter_litert_lm`; GPU→CPU fallback on init |
| Managed runtime | `lib/core/ai/managed_runtime.dart` | Lifecycle management; thermal/memory polling via `MethodChannel` |
| Voice | `lib/core/audio/voice_service.dart` | STT via `sherpa_onnx`; TTS via `sherpa_onnx` (high-fidelity) or `flutter_tts` (fallback) |
| Memory | `lib/core/data/memory_provider.dart` | Flat `List<String>` of facts in SharedPreferences |
| Settings | `lib/features/settings/providers/settings_provider.dart` | All user-configurable state; persisted to SharedPreferences |
| Chat history | `lib/features/chat/providers/chat_provider.dart` | In-memory `List<Message>` for the current session |

### Model File

The Gemma model must be placed at:
```
<app documents dir>/models/gemma_v4_final.litertlm
```
The `SetupScreen` (`lib/features/chat/screens/setup_screen.dart`) handles downloading it on first launch. The engine attempts GPU init first and falls back to CPU.

### Mood System

`MoodType` enum (defined in `lib/features/settings/models/mood.dart`) has 6 values: `professional`, `excited`, `angry`, `romantic`, `sad`, `sarcastic`. Each maps to:
- A color (drives the entire UI gradient and accent theming)
- A default prompt injected into the system template at `{mood}`

Mood prompts are user-editable per-mood in Settings and stored in SharedPreferences as `prompt_<moodName>`.

### System Prompt Template

Defined in `lib/core/config/prompts_config.dart`. The template uses `{name}`, `{attitude}`, `{mood}`, `{autonomous_directive}`, `{search_directive}`, and `{image_directive}` placeholders. The `settingsProvider` always returns the hardcoded template constant — user-editable template customization is wired in settings UI but `settings_provider.dart:build()` currently ignores any saved override.

### State Management

All state is Riverpod. `sharedPreferencesProvider` is injected at the root `ProviderScope` in `main.dart` and consumed by `settingsProvider` and `memoryProvider` via `ref.watch`. There is no `objectbox` usage in the current implementation despite it being in `pubspec.yaml` — the architecture doc describes it as a future RAG layer.

### Audio Session

`audio_session` is configured in `voice_service.dart` with `playAndRecord` + `defaultToSpeaker` to allow simultaneous mic + speaker without OS lockout. The VAD in Sherpa-ONNX handles endpoint detection; the `[DONE]` sentinel from the STT stream signals end-of-speech to `chat_screen.dart`.
