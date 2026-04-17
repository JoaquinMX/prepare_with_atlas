import 'dart:convert';

import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';

/// Parses the raw AI response string into an [EvaluationResult].
///
/// Uses a three-stage strategy:
/// 1. Direct JSON parse (possibly extracting from markdown fences).
/// 2. Regex fallback to extract dimensional scores from natural language.
/// 3. Throws [EvaluationParseException] if both strategies fail.
class ResponseParser {
  /// Parses [raw] into an [EvaluationResult].
  ///
  /// Throws [EvaluationParseException] if the response cannot be parsed.
  EvaluationResult parse({
    required String raw,
    required String sessionId,
    required String providerUsed,
    required String modelUsed,
  }) {
    final result =
        _tryJsonParse(
          raw,
          sessionId: sessionId,
          providerUsed: providerUsed,
          modelUsed: modelUsed,
        ) ??
        _tryRegexFallback(
          raw,
          sessionId: sessionId,
          providerUsed: providerUsed,
          modelUsed: modelUsed,
        );

    if (result == null) {
      final snippet = raw.substring(0, raw.length.clamp(0, 200));
      throw EvaluationParseException(
        'Could not parse AI evaluation response. Raw: $snippet',
      );
    }

    return result;
  }

  EvaluationResult? _tryJsonParse(
    String raw, {
    required String sessionId,
    required String providerUsed,
    required String modelUsed,
  }) {
    // Try to extract JSON from markdown code fences first.
    var candidate = raw.trim();
    final fenceMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(candidate);
    if (fenceMatch != null) {
      candidate = fenceMatch.group(1) ?? candidate;
    }

    // Try to find a JSON object in the string.
    final jsonStart = candidate.indexOf('{');
    final jsonEnd = candidate.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      candidate = candidate.substring(jsonStart, jsonEnd + 1);
    }

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is! Map<String, dynamic>) return null;

      final rawScorecard = decoded['scorecard'];
      if (rawScorecard is! Map) return null;

      final scorecard = _buildScorecard(rawScorecard);
      final overallScore = _clampScore(scorecard['overall'] ?? 5);

      final strengths = _toStringList(decoded['strengths']);
      final improvements = _toStringList(decoded['improvements']);
      final narrative =
          decoded['narrative']?.toString() ?? 'No narrative provided.';
      final refComparison = decoded['referenceComparison']?.toString();

      return EvaluationResult(
        id: _generateId(),
        sessionId: sessionId,
        scorecard: scorecard,
        overallScore: overallScore,
        strengths: strengths,
        improvements: improvements,
        narrative: narrative,
        referenceComparison: refComparison,
        providerUsed: providerUsed,
        modelUsed: modelUsed,
        rawResponse: raw,
        createdAt: DateTime.now(),
      );
    } on FormatException {
      return null;
    }
  }

  EvaluationResult? _tryRegexFallback(
    String raw, {
    required String sessionId,
    required String providerUsed,
    required String modelUsed,
  }) {
    final scorecard = <String, int>{};

    // Pattern 1: exact key like "requirementsGathering: 7"
    for (final dim in scorecardDimensions) {
      final pattern = RegExp('$dim\\s*:\\s*(\\d+)', caseSensitive: false);
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final score = int.tryParse(match.group(1) ?? '');
        if (score != null) {
          scorecard[dim] = _clampScore(score);
        }
      }
    }

    // Pattern 2: natural language like "Requirements Gathering: 8/10"
    const naturalPatterns = <String, String>{
      'requirementsGathering': r'requirements?\s+gathering',
      'estimationQuality': r'estimation\s+quality',
      'highLevelDesign': r'high.level\s+design',
      'deepDiveQuality': r'deep.dive\s+quality',
      'scalingAwareness': r'scaling\s+awareness',
      'communicationClarity': r'communication\s+clarity',
      'overall': 'overall',
    };

    for (final entry in naturalPatterns.entries) {
      if (scorecard.containsKey(entry.key)) continue;
      final pattern = RegExp(
        '${entry.value}\\s*:?\\s*(\\d+)(?:\\s*/\\s*10)?',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final score = int.tryParse(match.group(1) ?? '');
        if (score != null) {
          scorecard[entry.key] = _clampScore(score);
        }
      }
    }

    // Need at least one score to proceed.
    if (scorecard.isEmpty ||
        (scorecard.length == 1 && !scorecard.containsKey('overall'))) {
      return null;
    }

    // Fill missing dimensions with default.
    final fullScorecard = _fillMissingDimensions(scorecard);
    final overallScore = fullScorecard['overall'] ?? 5;

    return EvaluationResult(
      id: _generateId(),
      sessionId: sessionId,
      scorecard: fullScorecard,
      overallScore: overallScore,
      strengths: const ['See narrative for details.'],
      improvements: const ['See narrative for details.'],
      narrative: '## Evaluation\n\n$raw',
      providerUsed: providerUsed,
      modelUsed: modelUsed,
      rawResponse: raw,
      createdAt: DateTime.now(),
    );
  }

  Map<String, int> _buildScorecard(Map<dynamic, dynamic> raw) {
    final scorecard = <String, int>{};
    for (final dim in scorecardDimensions) {
      final rawValue = raw[dim];
      // If the AI omitted a dimension (null or absent), leave it out of the
      // map — the ScoreCardWidget renders absent entries as "N/A".
      if (rawValue == null) continue;
      final score = rawValue is int
          ? rawValue
          : int.tryParse(rawValue.toString()) ?? 5;
      scorecard[dim] = _clampScore(score);
    }
    return scorecard;
  }

  Map<String, int> _fillMissingDimensions(Map<String, int> partial) {
    final result = <String, int>{};
    for (final dim in scorecardDimensions) {
      result[dim] = partial[dim] ?? 5;
    }
    return result;
  }

  int _clampScore(int score) => score.clamp(0, 10);

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  String _generateId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(16);
}

/// Exception thrown when the AI response cannot be parsed into
/// an [EvaluationResult].
class EvaluationParseException implements Exception {
  /// Creates an [EvaluationParseException] with [message].
  const EvaluationParseException(this.message);

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => 'EvaluationParseException: $message';
}
