import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

/// Abstract repository for persisting [AiProviderConfig] records.
abstract class AiProviderConfigRepository {
  /// Saves (upserts) a [config] to storage.
  Future<void> save(AiProviderConfig config);

  /// Returns the currently active [AiProviderConfig], or `null` if none.
  Future<AiProviderConfig?> getActive();

  /// Returns all stored [AiProviderConfig] records.
  Future<List<AiProviderConfig>> getAll();

  /// Sets the config for [providerName] as the active one.
  Future<void> setActive(String providerName);

  /// Deletes the config for [providerName].
  Future<void> delete(String providerName);
}
