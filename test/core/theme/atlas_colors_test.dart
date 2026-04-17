import 'package:flutter_test/flutter_test.dart';
import 'package:prepare_with_atlas/core/theme/atlas_colors.dart';

void main() {
  group('AtlasColors', () {
    test('background has correct hex value', () {
      expect(AtlasColors.background.toARGB32(), 0xFF0B0D10);
    });
    test('accent is indigo', () {
      expect(AtlasColors.accent.toARGB32(), 0xFF4F46E5);
    });
    test('surface is correct', () {
      expect(AtlasColors.surface.toARGB32(), 0xFF12151A);
    });
    test('success is green', () {
      expect(AtlasColors.success.toARGB32(), 0xFF10B981);
    });
    test('warning is amber', () {
      expect(AtlasColors.warning.toARGB32(), 0xFFF59E0B);
    });
    test('danger is red', () {
      expect(AtlasColors.danger.toARGB32(), 0xFFEF4444);
    });
  });
}
