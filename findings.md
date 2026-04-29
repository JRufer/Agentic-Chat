# Findings: Agentic Chat Application

## Project Overview
The project is an on-device AI agent built with Flutter. It focuses on privacy, sovereignty, and real-time interaction.

## Technical Architecture
- **Framework:** Flutter (Android focus).
- **LLM:** Gemma 4 (E2B or E4B variants).
- **Inference Engine:** LiteRT-LM / Edge-Veda (managed runtime).
- **Vector DB:** ObjectBox (HNSW indexing).
- **Embeddings:** ONNX (all-MiniLM-L6-v2).
- **STT:** Sherpa-ONNX (Whisper/Zipformer/Paraformer).
- **TTS:** Piper TTS.
- **Audio Management:** `audio_session`.

## Requirements Summary
- [ ] Agent Name and Attitude (Editable).
- [ ] Moods: Professional, Excited, Angry, Horny, Sad.
- [ ] Autonomous Mood Switching (Function Calling).
- [ ] Persistent Memory (RAG with past chats and explicit notes).
- [ ] Memory Pruning (Summarization).
- [ ] Voice Input/Output (Streaming).

## Environment Constraints
- **Hardware:** Android device with UMA (Unified Memory Architecture).
- **Thermal Management:** Inference causes heat; need thermal guards.
- **Memory:** Android Low Memory Killer (LMK) risk; need supervised runtime.
- **Filesystem:** Read-only issues detected in previous sessions (need writable cache/config).

## Discovery Log
- Found existing Flutter SDK at `/home/jrufer/Development/Translate This/.flutter_sdk`.
- Detected "Read-only file system" error when trying to run the SDK.
