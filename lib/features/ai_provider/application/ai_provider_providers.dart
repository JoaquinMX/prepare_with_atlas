import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_controller.dart';
import 'package:prepare_with_atlas/features/ai_provider/application/ai_provider_state.dart';

export 'package:prepare_with_atlas/features/ai_provider/data/ai_provider_config_providers.dart'
    show aiProviderConfigRepositoryProvider;

/// Provides the singleton [AiProviderController] and its [AiProviderState].
final aiProviderControllerProvider =
    NotifierProvider<AiProviderController, AiProviderState>(
  AiProviderController.new,
);
