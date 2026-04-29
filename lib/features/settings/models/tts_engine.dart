enum TtsEngine {
  system,
  sherpaVits,
  cosyVoice2;

  String get label {
    switch (this) {
      case TtsEngine.system:
        return 'System TTS';
      case TtsEngine.sherpaVits:
        return 'Neural TTS (VITS-LJS)';
      case TtsEngine.cosyVoice2:
        return 'CosyVoice 2';
    }
  }

  String get subtitle {
    switch (this) {
      case TtsEngine.system:
        return 'Native Android/iOS voices — no download required';
      case TtsEngine.sherpaVits:
        return 'High-fidelity on-device synthesis (included in setup)';
      case TtsEngine.cosyVoice2:
        return 'State-of-the-art voice cloning — download required (~500 MB)';
    }
  }
}
