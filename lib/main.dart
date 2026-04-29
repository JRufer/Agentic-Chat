import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/models/mood.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/chat/screens/setup_screen.dart';
import 'features/chat/providers/chat_provider.dart';
import 'core/ai/managed_runtime.dart';
import 'shared/widgets/audio_visualizer.dart';

import 'features/chat/screens/chat_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const AgenticChatApp(),
    ),
  );
}

class AgenticChatApp extends StatelessWidget {
  const AgenticChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agentic Chat',
      theme: AppTheme.dark,
      home: const SetupScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

