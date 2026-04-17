import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/key_encryption_service.dart';

import 'key_encryption_service_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  late MockFlutterSecureStorage mockStorage;
  late KeyEncryptionService sut;
  String? storedKey;

  setUp(() {
    storedKey = null;
    mockStorage = MockFlutterSecureStorage();

    // Simulate read returning null first time (no key), then the stored key
    when(mockStorage.read(key: anyNamed('key'))).thenAnswer(
      (_) async => storedKey,
    );
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((invocation) async {
      storedKey =
          invocation.namedArguments[const Symbol('value')] as String?;
    });

    sut = KeyEncryptionService(storage: mockStorage);
  });

  group('KeyEncryptionService', () {
    test('encrypt then decrypt returns original plaintext', () async {
      const plaintext = 'my-secret-api-key-12345';

      final ciphertext = await sut.encrypt(plaintext);
      final decrypted = await sut.decrypt(ciphertext);

      expect(decrypted, plaintext);
    });

    test('different plaintexts produce different ciphertexts', () async {
      final ct1 = await sut.encrypt('hello');
      final ct2 = await sut.encrypt('world');

      expect(ct1, isNot(equals(ct2)));
    });

    test(
        'same plaintext encrypted twice produces different ciphertexts '
        '(random IV)', () async {
      const plaintext = 'same-input';

      final ct1 = await sut.encrypt(plaintext);

      // Reset cached key to force re-read from storage (still same key)
      final sut2 = KeyEncryptionService(storage: mockStorage);
      final ct2 = await sut2.encrypt(plaintext);

      expect(ct1, isNot(equals(ct2)));
    });

    test('decrypt throws FormatException for invalid ciphertext', () async {
      // Seed the key so decrypt can initialise
      await sut.encrypt('seed');

      expect(
        () => sut.decrypt('not-valid-format'),
        throwsA(isA<FormatException>()),
      );
    });

    test('ciphertext contains colon separator', () async {
      final ct = await sut.encrypt('test');
      expect(ct.contains(':'), isTrue);
    });
  });
}
