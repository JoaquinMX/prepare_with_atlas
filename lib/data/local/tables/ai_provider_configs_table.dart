import 'package:drift/drift.dart';

/// Drift table for persisted AI provider configurations.
@DataClassName('AiProviderConfigRow')
class AiProviderConfigs extends Table {
  /// Auto-incremented primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Provider name: 'openai' | 'anthropic' | 'gemini' |
  /// 'openrouter' | 'ollama'.
  TextColumn get providerName => text()();

  /// Config type: 'api_key' | 'oauth' | 'ollama'.
  TextColumn get configType => text()();

  /// AES-encrypted JSON payload containing the provider credentials.
  TextColumn get encryptedData => text()();

  /// Whether this is the currently active provider.
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(false))();

  /// When this record was created.
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When this record was last updated.
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
