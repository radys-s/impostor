import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/word_pack.dart';

class AiException implements Exception {
  const AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Calls the impostor-ai Cloudflare Worker. The URL is baked in at build time:
/// `flutter build ios --dart-define=AI_URL=https://...`.
class AiClient {
  AiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? _configuredUrl;

  static const _configuredUrl = String.fromEnvironment('AI_URL');
  static bool get configured => _configuredUrl.isNotEmpty;

  final http.Client _client;
  final String _baseUrl;

  Future<List<WordEntry>> generate({required String topic, required int count, required String installId}) async {
    if (_baseUrl.isEmpty) {
      throw const AiException('AI v této verzi aplikace není nastavená. Vestavěná témata fungují dál.');
    }
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/words'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'topic': topic, 'count': count, 'installId': installId}),
          )
          .timeout(const Duration(seconds: 45));
    } on TimeoutException {
      throw const AiException('AI neodpověděla včas. Zkus to prosím znovu.');
    } on http.ClientException {
      throw const AiException('Nepodařilo se spojit s AI. Jsi připojený k internetu? Vestavěná témata fungují i offline.');
    }

    Map<String, dynamic>? body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      body = null;
    }

    if (response.statusCode != 200) {
      final error = body?['error'];
      final code = error is Map ? error['code'] as String? : null;
      final message = error is Map ? error['message'] as String? : null;
      throw AiException(switch (code) {
        'quota_install' => 'Dnešní limit AI pro tento telefon je vyčerpaný. Zítra zase.',
        'quota_global' => 'AI má pro dnešek vyčerpaný bezplatný limit. Zítra zase.',
        _ => message ?? 'AI teď nefunguje (chyba ${response.statusCode}). Zkus to později.',
      });
    }

    final words = body?['words'];
    if (words is! List) throw const AiException('AI vrátila neplatnou odpověď. Zkus to znovu.');
    final entries = dedupeWords([
      for (final w in words)
        if (w is Map<String, dynamic>) WordEntry.fromJson(w),
    ]);
    if (entries.isEmpty) throw const AiException('AI k tomuto tématu nic nenašla. Zkus ho popsat jinak.');
    return entries;
  }
}
