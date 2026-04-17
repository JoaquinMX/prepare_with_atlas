import 'package:prepare_with_atlas/features/interview_session/domain/interview_session.dart';

/// Summary of a session for display in the history list.
class SessionSummary {
  /// Creates a [SessionSummary].
  const SessionSummary({
    required this.session,
    required this.problemTitle,
    this.overallScore,
  });

  /// The underlying interview session.
  final InterviewSession session;

  /// Title of the problem that was practised.
  final String problemTitle;

  /// Optional overall score (0–10) from the AI evaluation.
  final int? overallScore;
}
