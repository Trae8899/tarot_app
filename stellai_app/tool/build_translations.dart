import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

void main() {
  final projectRoot = Directory.current;
  final cardsDir = Directory(p.join(projectRoot.path, 'assets', 'cards'));
  final outputFile = File(p.join(projectRoot.path, 'assets', 'translations', 'cards.json'));

  if (!cardsDir.existsSync()) {
    stderr.writeln('cards directory not found at ${cardsDir.path}');
    exitCode = 1;
    return;
  }

  final cardEntries = <Map<String, dynamic>>[];

  for (final entity in cardsDir.listSync(recursive: true)) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
      continue;
    }

    try {
      final raw = entity.readAsStringSync(encoding: utf8);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      cardEntries.add(_convertCard(entity, data, projectRoot.path));
    } on FormatException catch (error) {
      stderr.writeln('Failed to decode JSON: ${entity.path}\n  $error');
    } on Exception catch (error) {
      stderr.writeln('Failed to process ${entity.path}\n  $error');
    }
  }

  cardEntries.sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));

  final encoder = const JsonEncoder.withIndent('  ');
  final jsonString = encoder.convert({'cards': cardEntries});

  outputFile
    ..createSync(recursive: true)
    ..writeAsStringSync(jsonString, encoding: utf8);

  final relative = p.relative(outputFile.path, from: projectRoot.path);
  stdout.writeln('Wrote ${cardEntries.length} cards to $relative');
}

Map<String, dynamic> _convertCard(File file, Map<String, dynamic> data, String projectPath) {
  final relativeDir = p.relative(file.parent.path, from: p.join(projectPath, 'assets'));
  final structure = (data['structure'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final meta = (data['meta'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final titles = (meta['titles'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final content = (data['content'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final story = (content['story'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final coreMessage = (content['core_message'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final prompts = (data['prompts'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
  final promptItems = (prompts['items'] as List?)?.whereType<Map>().toList() ?? const [];

  final normalizedId = _normalizedId(structure, meta, file);
  final imagePath = _resolveImagePath(file, relativeDir, normalizedId, data);

  final translations = <String, Map<String, dynamic>>{
    'ko': {
      'name': _string(titles['native'] ?? titles['bottom_main'] ?? titles['original_tarot'] ?? titles['en']),
      'upright': _string(coreMessage['upright']),
      'reversed': _string(coreMessage['reversed']),
      'story': _string(story['korean']),
      'keywords': _stringList(content['keywords']),
      'questions': promptItems.map((item) => _string(item['text'])).where((value) => value.isNotEmpty).toList(),
      'quote': _string(structure['cat_quote']),
      'summary': _stringList(structure['symbol_summary_keywords']),
    },
    'en': {
      'name': _string(titles['en'] ?? titles['original_tarot']),
      'upright': '',
      'reversed': '',
      'story': _string(story['english']),
      'keywords': const <String>[],
      'questions': const <String>[],
      'quote': '',
      'summary': const <String>[],
    },
  };

  return {
    'id': normalizedId,
    'originalId': _string(meta['card_id']),
    'image': imagePath,
    'translations': translations,
    'status': {
      'ko': 'approved',
      'en': 'pending',
      'es': 'pending',
      'ja': 'pending',
    },
    'source': _string(meta['deck_id']).isNotEmpty ? meta['deck_id'] : 'stellai_cards_v1',
    'metadata': {
      'arcana': _string(structure['arcana']),
      'suit': _string(structure['suit']),
      'number': structure['number'],
      'title': titles,
      'colorTheme': _stringList(structure['color_theme_keywords']),
      'props': _string(structure['prop_description']),
      'background': _string(structure['background_scene']),
      'symbolSummary': _stringList(structure['symbol_summary_keywords']),
    },
  };
}

String _normalizedId(Map<String, dynamic> structure, Map<String, dynamic> meta, File file) {
  final arcana = structure['arcana']?.toString().toLowerCase();
  final number = structure['number'];
  final suit = structure['suit']?.toString().toLowerCase();

  int? parsedNumber;
  if (number is int) {
    parsedNumber = number;
  } else if (number is String) {
    parsedNumber = int.tryParse(number);
  }

  if (arcana == 'major' && parsedNumber != null) {
    return 'major_$parsedNumber';
  }

  if (suit != null && suit.isNotEmpty && parsedNumber != null) {
    final suitSlug = suit.replaceAll(RegExp(r'\s+'), '_');
    return '${suitSlug}_$parsedNumber';
  }

  final metaId = meta['card_id']?.toString();
  if (metaId != null && metaId.isNotEmpty) {
    return metaId.toLowerCase();
  }

  return p.basenameWithoutExtension(file.path).toLowerCase();
}

String _resolveImagePath(File jsonFile, String relativeDir, String normalizedId, Map<String, dynamic> data) {
  final parentDir = jsonFile.parent;
  final baseName = p.basenameWithoutExtension(jsonFile.path);
  final expected = File(p.join(parentDir.path, '$baseName.png'));

  if (expected.existsSync()) {
    return p.join(relativeDir, p.basename(expected.path)).replaceAll('\\', '/');
  }

  final slots = (data['assets_slots'] as Map?)?.cast<String, dynamic>();
  final illustration = slots?['illustration']?.toString() ?? '';
  if (illustration.isNotEmpty) {
    final candidate = File(p.join(parentDir.path, illustration));
    if (candidate.existsSync()) {
      return p.join(relativeDir, illustration).replaceAll('\\', '/');
    }
  }

  final siblings = parentDir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.toLowerCase().endsWith('.png'))
      .toList();

  if (siblings.length == 1) {
    final only = siblings.first;
    return p.join(relativeDir, p.basename(only.path)).replaceAll('\\', '/');
  }

  for (final candidate in siblings) {
    final name = p.basenameWithoutExtension(candidate.path).toLowerCase();
    if (name.contains(normalizedId.toLowerCase())) {
      return p.join(relativeDir, p.basename(candidate.path)).replaceAll('\\', '/');
    }
  }

  final metaId = data['meta'] is Map ? data['meta']['card_id']?.toString() ?? '' : '';
  if (metaId.isNotEmpty) {
    final maybe = File(p.join(parentDir.path, '$metaId.png'));
    if (maybe.existsSync()) {
      return p.join(relativeDir, p.basename(maybe.path)).replaceAll('\\', '/');
    }
  }

  return '';
}

String _string(dynamic value) => value?.toString().trim() ?? '';

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value.map((element) => element?.toString() ?? '').where((element) => element.isNotEmpty).toList();
  }
  return const [];
}
