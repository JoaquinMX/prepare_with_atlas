import 'dart:typed_data';

import 'package:prepare_with_atlas/features/evaluation/domain/evaluation_result.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';
import 'package:prepare_with_atlas/features/problem_bank/domain/problem.dart';

/// Builds system and user prompts for AI-powered session evaluation.
class PromptBuilder {
  /// Maps each interview stage to the scoring dimensions that should be
  /// evaluated when that stage is practiced as a single-stage drill.
  ///
  /// Each stage maps to its primary dimension plus the cross-cutting
  /// `communicationClarity` and the aggregate `overall` score.
  static const Map<InterviewStage, List<String>> _stageDimensions = {
    InterviewStage.requirementGathering: [
      'requirementsGathering',
      'communicationClarity',
      'overall',
    ],
    InterviewStage.backOfEnvelopeEstimation: [
      'estimationQuality',
      'communicationClarity',
      'overall',
    ],
    InterviewStage.highLevelDesign: [
      'highLevelDesign',
      'communicationClarity',
      'overall',
    ],
    InterviewStage.deepDive: [
      'deepDiveQuality',
      'communicationClarity',
      'overall',
    ],
    InterviewStage.scalingAndBottlenecks: [
      'scalingAwareness',
      'communicationClarity',
      'overall',
    ],
  };

  /// Returns the scoring dimensions that apply to [stage] in a single-stage
  /// drill. Falls back to all dimensions for unknown stages.
  List<String> dimensionsForStage(InterviewStage stage) =>
      _stageDimensions[stage] ?? scorecardDimensions;

  /// Builds the system prompt that instructs the AI how to evaluate.
  ///
  /// Includes role instruction, JSON output format, 7 scoring dimensions,
  /// and a scoring rubric.
  String buildSystemPrompt() => r'''

You are an expert system design interviewer and evaluator with deep experience in distributed systems, scalability, and software architecture. Your task is to evaluate a candidate's system design interview performance and return a structured JSON assessment.

## Scoring Rubric

Score each dimension from 0 to 10:
- **0-3 (Poor)**: Candidate showed little understanding or made major errors.
- **4-6 (Adequate)**: Candidate covered the basics with some gaps.
- **7-10 (Strong)**: Candidate demonstrated solid understanding.

## Scoring Dimensions

You must score the following 7 dimensions (use these exact JSON keys):

1. `requirementsGathering` — Did the candidate clarify requirements?
2. `estimationQuality` — Were back-of-the-envelope estimates reasonable?
3. `highLevelDesign` — Did the candidate sketch clear components and data flow?
4. `deepDiveQuality` — Was the deep-dive thorough and technically sound?
5. `scalingAwareness` — Did the candidate identify bottlenecks and strategies?
6. `communicationClarity` — Was the candidate clear and structured?
7. `overall` — A holistic score for the entire interview.

## Single-Stage Drill Sessions

When the user prompt indicates this was a **single-stage drill**, score ONLY the
dimensions that are explicitly listed for that stage in the table below. For all
other dimensions, **omit them from the scorecard JSON entirely** — do not invent a
score for something the candidate never attempted. Omitted dimensions will be
shown as "N/A" in the UI.

| Stage | Dimensions to score |
|-------|---------------------|
| Requirements | requirementsGathering, communicationClarity, overall |
| Estimation | estimationQuality, communicationClarity, overall |
| High-Level Design | highLevelDesign, communicationClarity, overall |
| Deep Dive | deepDiveQuality, communicationClarity, overall |
| Scaling | scalingAwareness, communicationClarity, overall |

## Required JSON Output Format

Respond with ONLY valid JSON in exactly this structure. Do not include markdown
code fences or any text outside the JSON object:

{
  "scorecard": {
    "requirementsGathering": 7,
    "estimationQuality": 6,
    "highLevelDesign": 8,
    "deepDiveQuality": 7,
    "scalingAwareness": 6,
    "communicationClarity": 8,
    "overall": 7
  },
  "strengths": ["Specific strength 1", "Specific strength 2"],
  "improvements": ["Specific improvement 1", "Specific improvement 2"],
  "narrative": "## Overall Assessment\n\nDetailed markdown narrative...",
  "referenceComparison": null
}

All scores must be integers in the range 0-10. The strengths and improvements
arrays must each contain at least one item. The narrative must be a markdown
string with at least two sections.
''';

  /// Builds the user prompt containing the problem statement, stage notes,
  /// and optional reference answer.
  ///
  /// Long note content (over 20,000 characters combined) is middle-truncated
  /// to keep the prompt within model context limits.
  ///
  /// When [isSingleStage] is true, a "Session Type" section is added so the
  /// AI knows to omit unevaluated dimensions from the scorecard JSON.
  String buildUserPrompt({
    required Problem problem,
    required List<StageNote> notes,

    /// Optional PNG screenshot bytes for multimodal vision input.
    Uint8List? whiteboardScreenshot,

    /// Optional reference solution for curated problems.
    String? referenceAnswer,

    /// Whether this was a single-stage drill (not a full interview).
    bool isSingleStage = false,

    /// The stage practiced in a single-stage drill; null for full sessions.
    InterviewStage? focusStage,
  }) {
    final buffer = StringBuffer()
      ..writeln('# System Design Interview Evaluation')
      ..writeln();

    if (isSingleStage && focusStage != null) {
      final dims = dimensionsForStage(focusStage);
      buffer
        ..writeln('## Session Type')
        ..writeln()
        ..writeln(
          'This was a **single-stage drill** focused on: '
          '**${focusStage.displayName}**.',
        )
        ..writeln()
        ..writeln(
          'The candidate practiced only this one stage, not the full '
          'interview. Score ONLY these dimensions: **${dims.join(', ')}**. '
          'Omit all other dimensions from the scorecard JSON entirely.',
        )
        ..writeln();
    }

    buffer
      ..writeln('## Problem Statement')
      ..writeln()
      ..writeln('**Title:** ${problem.title}')
      ..writeln()
      ..writeln(problem.description)
      ..writeln()
      ..writeln('## Candidate Notes by Stage')
      ..writeln();

    for (final note in notes) {
      final stageName = note.stage.displayName;
      final minutes = note.timeSpentSeconds ~/ 60;
      final seconds = note.timeSpentSeconds % 60;
      final timeStr = seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';

      buffer
        ..writeln('### Stage: $stageName')
        ..writeln('**Time spent:** $timeStr')
        ..writeln();

      final truncated = _maybeTruncate(note.notes);
      buffer
        ..writeln(truncated.isEmpty ? '_(No notes recorded)_' : truncated)
        ..writeln();
    }

    if (whiteboardScreenshot != null) {
      buffer
        ..writeln('## Whiteboard')
        ..writeln()
        ..writeln('_(A whiteboard screenshot is attached as an image above.)_')
        ..writeln();
    }

    if (referenceAnswer != null) {
      buffer
        ..writeln('## Reference Solution')
        ..writeln()
        ..writeln(
          'The following is the curated reference answer for this problem. '
          "Use it to compare the candidate's approach:",
        )
        ..writeln()
        ..writeln(referenceAnswer)
        ..writeln();
    }

    buffer
      ..writeln('---')
      ..writeln()
      ..writeln(
        "Please evaluate the candidate's performance based on the notes above "
        'and return a JSON evaluation following the format specified in the '
        'system prompt. Be specific and constructive in your feedback.',
      );

    return buffer.toString();
  }

  /// Middle-truncates [text] if it exceeds [limit] characters.
  ///
  /// Keeps approximately the first half and last half, separated by a
  /// truncation marker.
  String _maybeTruncate(String text, {int limit = 20000}) {
    if (text.length <= limit) return text;

    final half = limit ~/ 2;
    final start = text.substring(0, half);
    final end = text.substring(text.length - half);
    return '$start\n\n[...content truncated for length...]\n\n$end';
  }
}
