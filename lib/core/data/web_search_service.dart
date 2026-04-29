import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class WebSearchService {
  final Dio _dio = Dio();

  Future<String> search(String query) async {
    try {
      final response = await _dio.post(
        'https://lite.duckduckgo.com/lite/',
        data: {'q': query},
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      final html = response.data.toString();
      
      final snippetRegex = RegExp(r"<td class='result-snippet'[^>]*>(.*?)</td>", dotAll: true);
      final matches = snippetRegex.allMatches(html);
      
      if (matches.isEmpty) return "No results found on the web.";
      
      final results = matches.take(3).map((m) {
        return m.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      }).join('\n\n');
      
      return results;
    } catch (e) {
      return "Search failed: $e";
    }
  }
  Future<String?> searchImage(String query) async {
    try {
      final response = await _dio.get(
        'https://www.bing.com/images/search?q=$query',
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
        ),
      );

      final html = response.data.toString();
      final regex1 = RegExp(r'murl&quot;:&quot;(.*?)&quot;');
      final match1 = regex1.firstMatch(html);
      
      if (match1 != null) {
        return match1.group(1);
      }
      
      final regex2 = RegExp(r'murl":"(.*?)"');
      final match2 = regex2.firstMatch(html);
      
      if (match2 != null) {
        return match2.group(1);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

final webSearchServiceProvider = Provider((ref) => WebSearchService());
