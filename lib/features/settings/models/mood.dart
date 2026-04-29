import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/prompts_config.dart';

enum MoodType {
  professional,
  excited,
  angry,
  romantic,
  sad,
  sarcastic;

  String get label {
    switch (this) {
      case MoodType.professional: return 'Professional';
      case MoodType.excited: return 'Excited';
      case MoodType.angry: return 'Angry';
      case MoodType.romantic: return 'Romantic';
      case MoodType.sad: return 'Sad';
      case MoodType.sarcastic: return 'Sarcastic';
    }
  }

  Color get color {
    switch (this) {
      case MoodType.professional: return AppColors.professional;
      case MoodType.excited: return AppColors.excited;
      case MoodType.angry: return AppColors.angry;
      case MoodType.romantic: return AppColors.romantic;
      case MoodType.sad: return AppColors.sad;
      case MoodType.sarcastic: return AppColors.sarcastic;
    }
  }
}

class Mood {
  final MoodType type;
  final String prompt;

  Mood({
    required this.type,
    required this.prompt,
  });

  factory Mood.defaultFor(MoodType type) {
    return Mood(
      type: type,
      prompt: PromptsConfig.getDefaultMoodPrompt(type),
    );
  }
}
