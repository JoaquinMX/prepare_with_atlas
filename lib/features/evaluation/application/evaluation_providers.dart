import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_controller.dart';
import 'package:prepare_with_atlas/features/evaluation/application/evaluation_state.dart';

export 'package:prepare_with_atlas/features/evaluation/application/evaluation_dependency_providers.dart';

/// Manages the state of the ongoing evaluation request.
final evaluationControllerProvider =
    NotifierProvider<EvaluationController, EvaluationState>(
  EvaluationController.new,
);
