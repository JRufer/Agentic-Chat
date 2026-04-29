# Agentic Chat - Architecture & Implementation Guide

## Overview
**Agentic Chat** is a fully on-device, highly autonomous conversational AI application built with Flutter. Unlike standard wrapper apps that rely on cloud APIs, this application runs a state-of-the-art Large Language Model (Gemma) and high-fidelity Neural Text-to-Speech (VITS/Kokoro) entirely locally on the user's hardware. 

The architecture is designed to give the AI "agency" by allowing it to execute local skills (Memory, Web Search, Reminders) autonomously via background token parsing, creating a seamless and magical user experience.

---

## Core Technologies
*   **Framework:** Flutter (Dart)
*   **State Management:** Riverpod (`flutter_riverpod`, `riverpod_annotation`)
*   **On-Device LLM Inference:** `flutter_litert_lm` (LiteRT / TFLite engine running Gemma 4 or similar)
*   **Offline Neural Speech Synthesis:** `sherpa_onnx` (VITS & Kokoro models for high-fidelity offline voice generation)
*   **System Audio & Voice Capture:** `record`, `just_audio`, `audio_session`, `flutter_tts` (for system fallback)
*   **Local Storage:** `shared_preferences` (for settings, AI memories, and prompt persistence), `objectbox` (for complex entities)
*   **Networking (Web Search):** `dio`
*   **Background Tasks (Reminders):** `flutter_local_notifications`, `timezone`

---

## Directory Structure & File Roles

### `lib/main.dart`
The entry point of the application. Responsible for initializing the Riverpod ProviderScope, loading native libraries, initializing `SharedPreferences`, and booting up the initial Flutter widget tree.

### `lib/core/`
Contains the foundational services and configurations that power the backend engine of the app.

*   **`ai/managed_runtime.dart`**
    *   Wraps the `flutter_litert_lm` engine. Manages the lifecycle of the on-device LLM, handles prompt injection, and exposes a real-time `Stream` of generated tokens to the UI.
*   **`audio/voice_service.dart`**
    *   The central audio controller. Manages Speech-to-Text (STT) capture using the `record` package and handles audio playback. It routes Text-to-Speech (TTS) either to the high-fidelity `sherpa_onnx` models or falls back to native `flutter_tts` based on user settings.
*   **`config/prompts_config.dart`**
    *   The "Brain" of the AI's persona. Contains the master system templates, critical personality directives, and instructions that teach the AI how to use its tools (e.g., `[SAVE_MEMORY]`, `[SEARCH_WEB]`, `[REMIND_ME]`).
*   **`data/memory_provider.dart`**
    *   Manages the AI's long-term memory. Reads and writes extracted facts to local storage so the AI remembers details across app restarts.
*   **`data/web_search_service.dart`**
    *   A custom tool that uses `dio` to perform live, API-key-free web scraping via DuckDuckGo Lite.
*   **`data/reminder_service.dart`**
    *   Wraps `flutter_local_notifications`. Schedules exact, timezone-aware alarms on the user's OS and handles callbacks when the user taps a notification to reopen the app.
*   **`theme/app_theme.dart`**
    *   Defines the core design system, text themes, and the specific `AppColors` mapped to different AI moods.

### `lib/features/chat/`
Contains the primary user interface and logic for the conversational experience.

*   **`providers/chat_provider.dart`**
    *   Manages the `ChatHistory` state. Controls adding, updating, and replacing messages as the LLM streams tokens.
*   **`screens/chat_screen.dart`**
    *   **The most complex file in the app.** 
    *   **UI:** Renders the dynamic, animated interface (AnimatedContainers) that fluidly shifts color based on the AI's mood. Handles the Voice Overlay and text input.
    *   **Logic:** Intercepts the raw token stream from `ManagedRuntime`. It acts as the "Tool Executor" by parsing tags (like `[SAVE_MEMORY: fact]`), stripping them out so the user doesn't see them or hear them spoken, gracefully rendering UI indicators (like the Brain or Bell icons), and executing the underlying native code (scheduling alarms, executing web searches, recursively injecting search results back into the LLM).
*   **`screens/setup_screen.dart`**
    *   Handles the initial onboarding, permissions, and downloading of the heavy local models (Gemma/Kokoro) required for offline inference.

### `lib/features/settings/`
Allows the user to customize the AI's behavior and constraints.

*   **`models/mood.dart`**
    *   Defines the `MoodType` enum, mapping moods (Professional, Excited, Angry, Romantic, Sad, Sarcastic) to specific labels and colors.
*   **`providers/settings_provider.dart`**
    *   Manages the active `SettingsState`. Handles the toggle states for Web Search, System TTS, and Autonomous Mood Switching. Critically, it prioritizes hardcoded System Prompts over cached versions to ensure the AI's instructions are always up-to-date.
*   **`screens/settings_screen.dart`**
    *   The UI for modifying the agent's name, attitude, system templates, and enabling/disabling skills.

### `lib/shared/`
*   **`widgets/audio_visualizer.dart`**
    *   A reactive UI component that provides visual feedback to the user while the app is actively listening to their voice.

---

## The "Agentic" Loop Architecture

What makes this app "Agentic" rather than a simple chatbot is the recursive interception loop in `chat_screen.dart`:

1.  **Context Injection:** When the user sends a message, `chat_screen.dart` builds an `augmentedPrompt` containing the master system instructions, the current exact local time, all saved long-term memories, and the user's input.
2.  **Streaming & Tool Use:** The LLM streams tokens back. Because it was taught how to use tools in `prompts_config.dart`, it might decide to output a command like `[SEARCH_WEB: London Weather]`.
3.  **Interception:** The `ChatScreen`'s stream listener detects the bracket `[`. It immediately pauses the TTS engine so the command isn't spoken aloud.
4.  **Execution & Recursion:** Once the tag is fully streamed, the UI strips the tag, updates the chat bubble to read *"Searching the web..."*, and calls `WebSearchService`. Once the results are fetched, it seamlessly re-injects the results into the background context and tells the LLM to generate a new response based on the data. The user only ever sees the final, intelligent output.
