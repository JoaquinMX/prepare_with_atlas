import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prepare_with_atlas/data/local/app_database.dart';

/// Single shared [AppDatabase] instance for the entire app.
///
/// All feature repositories must watch this provider instead of creating
/// their own [AppDatabase] instances to avoid Drift's "multiple database"
/// warning and potential SQLite race conditions.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
