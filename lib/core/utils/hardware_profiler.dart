import 'dart:io';
import 'package:flutter/services.dart';

enum GemmaVariant { e2b, e4b }

class HardwareInfo {
  final int ramGB;
  final int cpuCores;
  final GemmaVariant recommendedVariant;
  final bool hasNpu;

  HardwareInfo({
    required this.ramGB,
    required this.cpuCores,
    required this.recommendedVariant,
    this.hasNpu = false,
  });
}

class HardwareProfiler {
  static const MethodChannel _channel = MethodChannel('com.example.agentic_chat/hardware_info');

  static Future<HardwareInfo> profile() async {
    int ramGB = 4;
    int cpuCores = Platform.numberOfProcessors;
    bool hasNpu = false;

    try {
      final Map<dynamic, dynamic>? info = await _channel.invokeMethod('getHardwareInfo');
      if (info != null) {
        ramGB = info['ramGB'] as int? ?? 4;
        cpuCores = info['cpuCores'] as int? ?? cpuCores;
      }
    } catch (e) {
      // Fallback for non-Android or unimplemented channel
      print("Hardware profiling fallback: $e");
    }

    // Logic for recommendation
    // E4B requires ~3GB, E2B requires ~1.5GB
    // We recommend E4B if device has >6GB total RAM to leave room for OS and other apps
    GemmaVariant recommended = ramGB >= 6 ? GemmaVariant.e4b : GemmaVariant.e2b;

    return HardwareInfo(
      ramGB: ramGB,
      cpuCores: cpuCores,
      recommendedVariant: recommended,
      hasNpu: hasNpu,
    );
  }
}
