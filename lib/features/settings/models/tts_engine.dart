enum TtsEngine {
  system,
  sherpaVits,
  kokoro,
  matcha;

  String get label {
    switch (this) {
      case TtsEngine.system:
        return 'System TTS';
      case TtsEngine.sherpaVits:
        return 'Neural TTS (VITS-LJS)';
      case TtsEngine.kokoro:
        return 'Kokoro TTS';
      case TtsEngine.matcha:
        return 'Matcha-TTS';
    }
  }

  String get subtitle {
    switch (this) {
      case TtsEngine.system:
        return 'Native Android/iOS voices — no download required';
      case TtsEngine.sherpaVits:
        return 'High-fidelity on-device synthesis (included in setup)';
      case TtsEngine.kokoro:
        return 'High-quality multi-speaker — download required (~400 MB)';
      case TtsEngine.matcha:
        return 'Fast & expressive LJSpeech voice — download required (~200 MB)';
    }
  }
}
