import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:prepare_with_atlas/features/ai_provider/data/openai_oauth_service.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';

import 'openai_oauth_service_test.mocks.dart';

@GenerateMocks([Dio])
void main() {
  late OpenAiOAuthService sut;
  late MockDio mockDio;

  RequestOptions opts() => RequestOptions();

  Map<String, dynamic> tokenResponse({
    String accessToken = 'at-test',
    String refreshToken = 'rt-test',
    int expiresIn = 3600,
  }) =>
      {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_in': expiresIn,
      };

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mockDio = MockDio();
    sut = OpenAiOAuthService(
      dio: mockDio,
      launchUri: (_) async => true,
    );
  });

  group('OpenAiOAuthService', () {
    group('generateCodeVerifier', () {
      test('returns string of 43-128 chars', () {
        final verifier = sut.generateCodeVerifier();
        expect(verifier.length, greaterThanOrEqualTo(43));
        expect(verifier.length, lessThanOrEqualTo(128));
      });

      test('only contains valid base64url chars', () {
        final verifier = sut.generateCodeVerifier();
        final validChars = RegExp(r'^[A-Za-z0-9\-_]+$');
        expect(validChars.hasMatch(verifier), isTrue);
      });

      test('produces different values each call', () {
        final v1 = sut.generateCodeVerifier();
        final v2 = sut.generateCodeVerifier();
        expect(v1, isNot(equals(v2)));
      });
    });

    group('generateCodeChallenge', () {
      test('is deterministic for same input', () {
        const verifier = 'test-verifier-12345';
        final c1 = sut.generateCodeChallenge(verifier);
        final c2 = sut.generateCodeChallenge(verifier);
        expect(c1, equals(c2));
      });

      test('produces different output for different inputs', () {
        final c1 = sut.generateCodeChallenge('verifier-one');
        final c2 = sut.generateCodeChallenge('verifier-two');
        expect(c1, isNot(equals(c2)));
      });

      test('result only contains base64url characters', () {
        final challenge =
            sut.generateCodeChallenge('any-verifier-value');
        final validChars = RegExp(r'^[A-Za-z0-9\-_]+$');
        expect(validChars.hasMatch(challenge), isTrue);
      });
    });

    group('buildAuthorizationUrl', () {
      test('includes code_challenge in query params', () {
        final url = sut.buildAuthorizationUrl(
          codeChallenge: 'my-challenge',
        );
        expect(
          url.queryParameters['code_challenge'],
          'my-challenge',
        );
      });

      test('includes code_challenge_method=S256', () {
        final url = sut.buildAuthorizationUrl(
          codeChallenge: 'my-challenge',
        );
        expect(
          url.queryParameters['code_challenge_method'],
          'S256',
        );
      });

      test('includes response_type=code', () {
        final url = sut.buildAuthorizationUrl(
          codeChallenge: 'my-challenge',
        );
        expect(url.queryParameters['response_type'], 'code');
      });

      test('points to auth.openai.com', () {
        final url = sut.buildAuthorizationUrl(
          codeChallenge: 'challenge',
        );
        expect(url.host, 'auth.openai.com');
      });
    });

    group('exchangeCodeForTokens', () {
      test('returns OAuthConfig with tokens on success', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final result = await sut.exchangeCodeForTokens(
          code: 'auth-code',
          codeVerifier: 'verifier',
        );

        expect(result, isA<OAuthConfig>());
        expect(result.accessToken, 'at-test');
        expect(result.refreshToken, 'rt-test');
        expect(result.providerName, 'openai');
      });

      test('expiresAt is in the future', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final result = await sut.exchangeCodeForTokens(
          code: 'code',
          codeVerifier: 'verifier',
        );

        expect(result.expiresAt.isAfter(DateTime.now()), isTrue);
      });

      test('sends correct grant_type and code_verifier', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        await sut.exchangeCodeForTokens(
          code: 'test-code',
          codeVerifier: 'test-verifier',
        );

        final captured = verify(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: captureAnyNamed('data'),
          ),
        ).captured;
        final body = captured.first as Map<String, dynamic>;
        expect(body['grant_type'], 'authorization_code');
        expect(body['code'], 'test-code');
        expect(body['code_verifier'], 'test-verifier');
      });

      test('400 response throws AiProviderException with statusCode 400',
          () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: opts(),
            response: Response(
              statusCode: 400,
              data: <String, dynamic>{},
              requestOptions: opts(),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(
          () => sut.exchangeCodeForTokens(
            code: 'bad-code',
            codeVerifier: 'verifier',
          ),
          throwsA(
            isA<AiProviderException>()
                .having((e) => e.statusCode, 'statusCode', 400),
          ),
        );
      });
    });

    group('refreshTokens', () {
      late OAuthConfig existingConfig;

      setUp(() {
        existingConfig = OAuthConfig(
          providerName: 'openai',
          accessToken: 'old-at',
          refreshToken: 'old-rt',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
        );
      });

      test('returns OAuthConfig with new access token', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(
              accessToken: 'new-at',
              refreshToken: 'new-rt',
            ),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final result = await sut.refreshTokens(existingConfig);

        expect(result.accessToken, 'new-at');
        expect(result.refreshToken, 'new-rt');
        expect(result.providerName, 'openai');
      });

      test('preserves modelOverride from original config', () async {
        final configWithModel = OAuthConfig(
          providerName: 'openai',
          accessToken: 'old-at',
          refreshToken: 'old-rt',
          expiresAt: DateTime.now().add(const Duration(minutes: 5)),
          modelOverride: 'gpt-4-turbo',
        );

        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final result = await sut.refreshTokens(configWithModel);
        expect(result.modelOverride, 'gpt-4-turbo');
      });

      test('sends correct grant_type and refresh_token', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        await sut.refreshTokens(existingConfig);

        final captured = verify(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: captureAnyNamed('data'),
          ),
        ).captured;
        final body = captured.first as Map<String, dynamic>;
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'old-rt');
      });

      test('401 response throws AiProviderException with statusCode 401',
          () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenThrow(
          DioException(
            requestOptions: opts(),
            response: Response(
              statusCode: 401,
              data: <String, dynamic>{},
              requestOptions: opts(),
            ),
            type: DioExceptionType.badResponse,
          ),
        );

        expect(
          () => sut.refreshTokens(existingConfig),
          throwsA(
            isA<AiProviderException>()
                .having((e) => e.statusCode, 'statusCode', 401),
          ),
        );
      });
    });

    group('authenticate', () {
      const channelName = 'test-oauth-channel';
      const codec = StandardMethodCodec();

      OpenAiOAuthService makeService({
        bool launchSucceeds = true,
      }) {
        return OpenAiOAuthService(
          dio: mockDio,
          channel: const MethodChannel(channelName),
          launchUri: (_) async => launchSucceeds,
        );
      }

      test('throws AiProviderException when browser cannot be launched',
          () async {
        final service = makeService(launchSucceeds: false);

        await expectLater(
          service.authenticate(),
          throwsA(
            isA<AiProviderException>().having(
              (e) => e.message,
              'message',
              contains('Could not open browser'),
            ),
          ),
        );
      });

      test(
          'completes with OAuthConfig after receiving callback '
          'with authorization code', () async {
        when(
          mockDio.post<Map<String, dynamic>>(
            any,
            data: anyNamed('data'),
          ),
        ).thenAnswer(
          (_) async => Response(
            data: tokenResponse(),
            statusCode: 200,
            requestOptions: opts(),
          ),
        );

        final service = makeService();
        final authFuture = service.authenticate();

        // Simulate AppDelegate forwarding the callback URL.
        await TestDefaultBinaryMessengerBinding
            .instance.defaultBinaryMessenger
            .handlePlatformMessage(
          channelName,
          codec.encodeMethodCall(
            const MethodCall(
              'onCallback',
              'com.joaquinmx.preparewithatlas://oauth/callback?code=test-code',
            ),
          ),
          (_) {},
        );

        final result = await authFuture;
        expect(result, isA<OAuthConfig>());
        expect(result.accessToken, 'at-test');
      });

      test('throws AiProviderException on timeout', () async {
        final service = makeService();

        await expectLater(
          service.authenticate(
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(
            isA<AiProviderException>().having(
              (e) => e.message,
              'message',
              contains('timed out'),
            ),
          ),
        );
      });
    });
  });
}
