import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/key_encryption_service.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config_repository.dart';

/// Drift-backed implementation of [AiProviderConfigRepository].
///
/// Credentials are stored as AES-256-GCM encrypted JSON in the
/// `ai_provider_configs` Drift table.
class DriftAiProviderConfigRepository implements AiProviderConfigRepository {
  /// Creates a [DriftAiProviderConfigRepository].
  DriftAiProviderConfigRepository({
    required AppDatabase database,
    required KeyEncryptionService encryptionService,
  })  : _db = database,
        _enc = encryptionService;

  final AppDatabase _db;
  final KeyEncryptionService _enc;

  @override
  Future<void> save(AiProviderConfig config) async {
    final name = _providerNameOf(config);
    final type = _configTypeOf(config);
    final encrypted = await _enc.encrypt(jsonEncode(config.toJson()));

    await (_db.aiProviderConfigs.delete()
          ..where((t) => t.providerName.equals(name)))
        .go();

    await _db.aiProviderConfigs.insertOne(
      AiProviderConfigsCompanion.insert(
        providerName: name,
        configType: type,
        encryptedData: encrypted,
        isActive: const Value(false),
      ),
    );
  }

  @override
  Future<AiProviderConfig?> getActive() async {
    final row = await (_db.aiProviderConfigs.select()
          ..where((t) => t.isActive.equals(true)))
        .getSingleOrNull();
    if (row == null) return null;
    return _decryptRow(row);
  }

  @override
  Future<List<AiProviderConfig>> getAll() async {
    final rows = await _db.aiProviderConfigs.select().get();
    final results = <AiProviderConfig>[];
    for (final row in rows) {
      results.add(await _decryptRow(row));
    }
    return results;
  }

  @override
  Future<void> setActive(String providerName) async {
    await _db.aiProviderConfigs.update().write(
          const AiProviderConfigsCompanion(isActive: Value(false)),
        );
    await (_db.aiProviderConfigs.update()
          ..where((t) => t.providerName.equals(providerName)))
        .write(const AiProviderConfigsCompanion(isActive: Value(true)));
  }

  @override
  Future<void> delete(String providerName) async {
    await (_db.aiProviderConfigs.delete()
          ..where((t) => t.providerName.equals(providerName)))
        .go();
  }

  Future<AiProviderConfig> _decryptRow(AiProviderConfigRow row) async {
    final json = jsonDecode(await _enc.decrypt(row.encryptedData))
        as Map<String, dynamic>;
    return AiProviderConfig.fromJson(json);
  }

  String _providerNameOf(AiProviderConfig config) => switch (config) {
        ApiKeyConfig(:final providerName) => providerName,
        OAuthConfig(:final providerName) => providerName,
        OllamaConfig() => 'ollama',
      };

  String _configTypeOf(AiProviderConfig config) => switch (config) {
        ApiKeyConfig() => 'api_key',
        OAuthConfig() => 'oauth',
        OllamaConfig() => 'ollama',
      };
}
