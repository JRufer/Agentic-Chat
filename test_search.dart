import 'package:dio/dio.dart';

void main() async {
  final dio = Dio();
  final response = await dio.post(
    'https://lite.duckduckgo.com/lite/',
    data: {'q': 'what is the capital of france'},
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
  
  for (var m in matches.take(3)) {
    print(m.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim());
  }
}
