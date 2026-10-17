import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/play_context.dart';
import '../models/word_pack.dart';

/// Optional features that ship inside the app but are switched on from the store.
enum FeaturePlugin {
  scores(
    id: 'skore',
    name: 'Skóre a žebříček',
    emoji: '🏆',
    description: 'Body za každé kolo a žebříček hráčů. Pro ty, kdo chtějí soutěžit.',
  ),
  voting(
    id: 'hlasovani',
    name: 'Tajné hlasování',
    emoji: '🗳️',
    description: 'Telefon koluje a každý tajně hlasuje. Aplikace vyhodnotí, kdo vyhrál.',
  ),
  ai(
    id: 'ai-temata',
    name: 'AI témata',
    emoji: '✨',
    description: 'Napiš libovolné téma a AI k němu vymyslí slova. Potřebuje internet.',
  );

  const FeaturePlugin({required this.id, required this.name, required this.emoji, required this.description});

  final String id;
  final String name;
  final String emoji;
  final String description;

  static FeaturePlugin? byId(String id) {
    for (final f in values) {
      if (f.id == id) return f;
    }
    return null;
  }
}

enum PluginType { feature, pack }

/// One entry of store/catalog.json.
class StoreItem {
  const StoreItem({
    required this.id,
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    this.audience = Audience.family,
    this.path,
    this.words = 0,
  });

  final String id;
  final PluginType type;
  final String name;
  final String emoji;
  final String description;
  final Audience audience;

  /// Repo-relative path of a pack JSON.
  final String? path;
  final int words;

  FeaturePlugin? get feature => type == PluginType.feature ? FeaturePlugin.byId(id) : null;

  static StoreItem? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final type = json['type'] == 'feature' ? PluginType.feature : PluginType.pack;
    if (type == PluginType.feature && FeaturePlugin.byId(id) == null) return null; // unknown to this app version
    if (type == PluginType.pack && json['path'] is! String) return null;
    return StoreItem(
      id: id,
      type: type,
      name: name,
      emoji: json['emoji'] as String? ?? '🧩',
      description: json['description'] as String? ?? '',
      audience: Audience.parse(json['audience']),
      path: json['path'] as String?,
      words: (json['words'] as num?)?.toInt() ?? 0,
    );
  }

  factory StoreItem.fromFeature(FeaturePlugin f) =>
      StoreItem(id: f.id, type: PluginType.feature, name: f.name, emoji: f.emoji, description: f.description);
}

class StoreException implements Exception {
  const StoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads the plugin catalog and packs from the public GitHub repo. This is the
/// only part of the app (besides AI) that goes online.
class StoreClient {
  StoreClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? const String.fromEnvironment(
          'STORE_URL',
          defaultValue: 'https://raw.githubusercontent.com/radys-s/impostor/main/',
        );

  final http.Client _client;
  final String _baseUrl;

  Future<List<StoreItem>> catalog() async {
    final json = await _get('store/catalog.json');
    final plugins = json['plugins'];
    final List<StoreItem> items;
    try {
      items = <StoreItem>[
        if (plugins is List)
          for (final p in plugins)
            if (p is Map<String, dynamic>) ?StoreItem.fromJson(p),
      ];
    } catch (_) {
      throw const StoreException('Obchod vrátil neplatná data.');
    }
    // Every feature this app knows is always offered, even if the catalog lags behind.
    for (final f in FeaturePlugin.values) {
      if (!items.any((i) => i.id == f.id)) items.insert(0, StoreItem.fromFeature(f));
    }
    return items;
  }

  Future<WordPack> pack(StoreItem item) async {
    final json = await _get(item.path!);
    final WordPack pack;
    try {
      pack = WordPack.fromJson(json, fromStore: true).copyWith(id: item.id, audience: item.audience);
    } catch (_) {
      throw const StoreException('Balíček je poškozený. Zkus to později.');
    }
    if (pack.words.length < 3) throw const StoreException('Balíček je poškozený. Zkus to později.');
    return pack;
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse('$_baseUrl$path')).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const StoreException('Obchod neodpovídá. Zkus to za chvíli.');
    } on Exception {
      // ClientException, SocketException on IO and anything else from the transport.
      throw const StoreException('Obchod potřebuje internet. Hra sama funguje i offline.');
    }
    if (response.statusCode != 200) {
      throw StoreException('Obchod teď není dostupný (chyba ${response.statusCode}).');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const StoreException('Obchod vrátil neplatná data.');
    }
  }
}
