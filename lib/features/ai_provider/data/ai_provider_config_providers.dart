import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/drift_ai_provider_config_repository.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/key_encryption_service.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config_repository.dart';
import 'package:prepare_with_atlas/features/interview_session/application/session_providers.dart';

/// Provides a [KeyEncryptionService] backed by macOS Keychain.
final keyEncryptionServiceProvider = Provider<KeyEncryptionService>(
  (_) => KeyEncryptionService(),
);

/// Provides the [AiProviderConfigRepository] backed by Drift + AES-256-GCM.
final aiProviderConfigRepositoryProvider =
    Provider<AiProviderConfigRepository>(
  (ref) => DriftAiProviderConfigRepository(
    database: ref.watch(appDatabaseProvider),
    encryptionService: ref.watch(keyEncryptionServiceProvider),
  ),
);
