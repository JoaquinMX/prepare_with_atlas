import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/interview_stage.dart';
import 'package:prepare_with_atlas/features/interview_session/domain/stage_note.dart';

void main() {
  final updatedAt = DateTime(2026, 4, 9);

  final note = StageNote(
    id: 1,
    sessionId: 10,
    stage: InterviewStage.highLevelDesign,
    timerDurationSeconds: 720,
    updatedAt: updatedAt,
  );

  group('StageNote', () {
    test('creates with required fields', () {
      expect(note.id, 1);
      expect(note.sessionId, 10);
      expect(note.stage, InterviewStage.highLevelDesign);
      expect(note.notes, '');
      expect(note.timeSpentSeconds, 0);
    });

    test('copyWith updates notes', () {
      final updated = note.copyWith(notes: 'My design notes');
      expect(updated.notes, 'My design notes');
      expect(updated.id, 1);
    });

    test('JSON round-trip preserves all fields', () {
      final noteWithNotes = note.copyWith(
        notes: 'Some notes',
        timeSpentSeconds: 300,
      );
      final json = noteWithNotes.toJson();
      final restored = StageNote.fromJson(json);
      expect(restored.id, noteWithNotes.id);
      expect(restored.sessionId, noteWithNotes.sessionId);
      expect(restored.stage, noteWithNotes.stage);
      expect(restored.notes, noteWithNotes.notes);
      expect(restored.timeSpentSeconds, noteWithNotes.timeSpentSeconds);
    });
  });
}
