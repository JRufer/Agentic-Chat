import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadManager {
  final Dio _dio = Dio();

  Future<String> downloadModel(
    String url, 
    String fileName, 
    Function(double) onProgress, {
    Map<String, String>? headers,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDocDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final savePath = '${modelsDir.path}/$fileName';
    final file = File(savePath);

    if (await file.exists()) {
      return savePath;
    }

    await _dio.download(
      url,
      savePath,
      options: Options(headers: headers),
      onReceiveProgress: (received, total) {
        if (total != -1) {
          onProgress(received / total);
        }
      },
    );

    return savePath;
  }
}
final modelDownloadProvider = Provider((ref) => DownloadManager());
