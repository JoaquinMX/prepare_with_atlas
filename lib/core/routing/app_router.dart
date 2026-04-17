import 'package:go_router/go_router.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/evaluation_loading_screen.dart';
import 'package:prepare_with_atlas/features/evaluation/presentation/evaluation_result_screen.dart';
import 'package:prepare_with_atlas/features/history/domain/session_summary.dart';
import 'package:prepare_with_atlas/features/history/presentation/progress_comparison_screen.dart';
import 'package:prepare_with_atlas/features/history/presentation/session_detail_screen.dart';
import 'package:prepare_with_atlas/features/history/presentation/session_history_screen.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/interview_screen.dart';
import 'package:prepare_with_atlas/features/interview_session/presentation/session_setup_screen.dart'
    as interview_setup;
import 'package:prepare_with_atlas/features/problem_bank/presentation/problem_bank_screen.dart';
import 'package:prepare_with_atlas/features/settings/presentation/ai_settings_screen.dart';
import 'package:prepare_with_atlas/features/settings/presentation/general_settings_screen.dart';
import 'package:prepare_with_atlas/presentation/home/home_screen.dart';
import 'package:prepare_with_atlas/presentation/shell/app_shell.dart';

/// The application router.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Interview screen lives OUTSIDE ShellRoute so the sidebar is hidden.
    GoRoute(path: '/interview', builder: (c, s) => const InterviewScreen()),

    // Evaluation screens live OUTSIDE ShellRoute — no sidebar.
    GoRoute(
      path: '/evaluation/loading',
      builder: (c, s) => const EvaluationLoadingScreen(),
    ),
    GoRoute(
      path: '/evaluation/result',
      builder: (c, s) => const EvaluationResultScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/problems', builder: (c, s) => const ProblemsScreen()),
        GoRoute(
          path: '/history',
          builder: (c, s) => const SessionHistoryScreen(),
        ),
        GoRoute(
          path: '/history/detail/:sessionId',
          builder: (context, state) {
            final summary = state.extra as SessionSummary?;
            if (summary == null) {
              // Fallback — no extra provided (e.g. deep link).
              return const SessionHistoryScreen();
            }
            return SessionDetailScreen(summary: summary);
          },
        ),
        GoRoute(
          path: '/history/compare',
          builder: (context, state) {
            final extra = state.extra as Map<String, String>?;
            final priorId = extra?['priorSessionId'] ?? '';
            final currentId = extra?['currentSessionId'] ?? '';
            return ProgressComparisonScreen(
              priorSessionId: priorId,
              currentSessionId: currentId,
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (c, s) => const GeneralSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/ai',
          builder: (c, s) => const AiSettingsScreen(),
        ),
        GoRoute(
          path: '/session-setup',
          builder: (context, state) {
            final idParam =
                state.uri.queryParameters['problemId'] ?? '0';
            final problemId = int.tryParse(idParam) ?? 0;
            return interview_setup.SessionSetupScreen(problemId: problemId);
          },
        ),
      ],
    ),
  ],
);
