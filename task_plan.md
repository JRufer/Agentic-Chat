# Task Plan: Agentic Chat Application Implementation

## Goal
Implement a Flutter-based Android chat application with on-device LLM (Gemma 4), persistent localized memory (RAG), and real-time voice interaction as described in `Docs/Idea.md`.

## Current Phase
Phase 1: Requirements & Discovery

## Phases

### Phase 1: Requirements & Discovery
- [x] Read and understand `Docs/Idea.md`
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Environment Setup & Foundation
- [x] Verify Flutter environment and fix "Read-only file system" issues (via SDK copy and HOME redirection)
- [x] Initialize project structure and `pubspec.yaml`
- [ ] Configure `AndroidManifest.xml` with required permissions
- [ ] Implement Hardware Profiling Routine
- **Status:** in_progress

### Phase 3: Core UI & State Management
- [x] Build primary chat interface (basic layout)
- [ ] Build settings screen (Agent Name, Attitude, Moods, Toggles)
- [x] Implement state management (Riverpod) for settings
- **Status:** in_progress

### Phase 4: Local LLM & Context Engine
- [x] Integrate `flutter_litert_lm` (Isolate-based wrapper)
- [x] Implement managed runtime with memory/thermal guards
- [x] Implement dynamic prompt assembly (Name, Attitude, Mood)
- **Status:** in_progress

### Phase 5: Persistent Memory (RAG)
- [x] Integrate `flutter_embedder` (service abstraction)
- [x] Setup `ObjectBox` with HNSW vector indexing (entity definition)
- [x] Implement Write-Manage-Read RAG pipeline (MemoryService)
- [ ] Implement Memory Pruning/Consolidation daemon
- **Status:** in_progress

### Phase 6: Acoustic Pipeline (STT/TTS)
- [ ] Initialize `audio_session` for hardware arbitration
- [ ] Integrate `sherpa_onnx` for streaming STT with VAD
- [ ] Integrate `piper_tts` for chunked streaming synthesis
- [ ] Implement Acoustic Echo Cancellation (AEC)
- **Status:** pending

### Phase 7: Autonomous Agentic Behavior
- [ ] Define JSON schema for `switch_mood` tool
- [ ] Implement tool-calling context injection
- [ ] Implement output parsing and state mutation for moods
- **Status:** pending

### Phase 8: Testing & Refinement
- [ ] Verify all requirements met
- [ ] Document test results in progress.md
- [ ] Fix any issues found
- **Status:** pending

## Key Questions
1. How to resolve the "Read-only file system" issue with the existing Flutter SDK?
2. Which state management solution is preferred (Riverpod or Bloc)? (Assuming Riverpod based on blueprint mention)
3. Where to download the Gemma 4 and ONNX models from securely?

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Follow `Docs/Idea.md` | Comprehensive architectural blueprint provided by user |

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
| `flutter: command not found` | 1 | Found Flutter SDK in `/home/jrufer/Development/Translate This/.flutter_sdk` |
| `Read-only file system` for Flutter SDK | 1 | Investigating (likely need to set `PUB_CACHE` and `FLUTTER_STORAGE_BASE_URL` or copy SDK to writable location) |

## Notes
- Planning files are stored in the project root `/home/jrufer/Development/Chat`.
