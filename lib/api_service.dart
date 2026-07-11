import 'dart:convert';
import 'package:http/http.dart' as http;

/// Calls the 3ayn AWS backend (Java Lambdas behind API Gateway).
/// With [mock] true it returns sample answers so the app is fully usable on
/// the tablet before the backend exists.
class ApiService {
  ApiService({required this.baseUrl, required this.mock});

  final String baseUrl;
  final bool mock;

  /// POST /ask — scene description (Bedrock Nova Lite)
  Future<String> describeScene(String img, String lang) => _call(
        'ask',
        img,
        lang,
        mockText: lang == 'ar'
            ? 'شخصان يجلسان على طاولة أمامك، وباب مفتوح على اليمين.'
            : 'Two people are seated at a table ahead of you, with an open door to the right.',
      );

  /// POST /who — identify an enrolled person (Rekognition Faces)
  Future<String> whoIsThis(String img, String lang) => _call(
        'who',
        img,
        lang,
        mockText: lang == 'ar' ? 'هذه سارة أمامك.' : 'Sara is in front of you.',
      );

  /// POST /read — read printed text aloud (Textract)
  Future<String> readText(String img, String lang) => _call(
        'read',
        img,
        lang,
        mockText: lang == 'ar'
            ? 'مكتوب: قهوة، شاي، عصير طازج.'
            : 'It reads: Coffee, Tea, Fresh Juice.',
      );

  /// POST /find — locate an object and give a direction (Rekognition labels)
  Future<String> find(String img, String lang, String label) => _call(
        'find',
        img,
        lang,
        extra: {'label': label},
        mockText: lang == 'ar'
            ? 'وجدته على يسارك.'
            : 'Found it — on your left.',
      );

  /// POST /enroll — register a known person's face (caregiver flow)
  Future<String> enroll(String img, String lang, String personName) => _call(
        'enroll',
        img,
        lang,
        extra: {'name': personName},
        mockText: lang == 'ar'
            ? 'تم تسجيل $personName.'
            : '$personName has been enrolled.',
      );

  Future<String> _call(
    String path,
    String img,
    String lang, {
    Map<String, dynamic> extra = const {},
    required String mockText,
  }) async {
    if (mock) {
      await Future.delayed(const Duration(milliseconds: 700));
      return mockText;
    }

    final resp = await http.post(
      Uri.parse('$baseUrl/$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': img, 'lang': lang, ...extra}),
    );

    if (resp.statusCode != 200) {
      throw Exception('Server error ${resp.statusCode}: ${resp.body}');
    }

    // Backend returns { "text": "..." } on success (see ApiResponse.java).
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['text'] ?? data['message'] ?? '').toString();
  }
}
