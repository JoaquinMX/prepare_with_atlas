import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider.dart';
import 'package:prepare_with_atlas/features/ai_provider/domain/ai_provider_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles OpenAI OAuth 2.1/PKCE authentication flow.
///
/// Responsible for PKCE helpers, opening the system browser, waiting for
/// the redirect callback via the macOS custom URI scheme, exchanging the
/// authorization code for tokens, and refreshing expired tokens.
class OpenAiOAuthService {
  /// Creates an [OpenAiOAuthService].
  ///
  /// All constructor parameters may be overridden for testing.
  OpenAiOAuthService({
    Dio? dio,
    MethodChannel? channel,
    Future<bool> Function(Uri)? launchUri,
  })  : _dio = dio ?? _buildDio(),
        _channel = channel ??
            const MethodChannel(
              'com.joaquinmx.preparewithatlas/oauth',
            ),
        _launchUri = launchUri ?? launchUrl;

  static const _clientId = 'preparewithatlas';
  static const _redirectUri =
      'com.joaquinmx.preparewithatlas://oauth/callback';
  static const _authEndpoint = 'https://auth.openai.com/authorize';
  static const _tokenEndpoint = 'https://auth.openai.com/oauth/token';
  static const _scope = 'openid profile email';

  final Dio _dio;
  final MethodChannel _channel;
  final Future<bool> Function(Uri) _launchUri;
  Completer<String>? _callbackCompleter;

  static Dio _buildDio() => Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  /// Generates a cryptographically random PKCE code verifier (43–128 chars).
  ///
  /// Uses only the URL-safe base64url character set: `[A-Za-z0-9\-_]`.
  String generateCodeVerifier() {
    final random = Random.secure();
    final bytes =
        List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Derives the PKCE code challenge from [verifier] using
  /// SHA-256 → base64url.
  ///
  /// Deterministic: the same [verifier] always produces the same result.
  String generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  /// Builds the OAuth authorization URL including PKCE parameters.
  Uri buildAuthorizationUrl({required String codeChallenge}) {
    return Uri.parse(_authEndpoint).replace(
      queryParameters: {
        'client_id': _clientId,
        'redirect_uri': _redirectUri,
        'response_type': 'code',
        'scope': _scope,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      },
    );
  }

  /// Exchanges an authorization [code] for an [OAuthConfig] with tokens.
  ///
  /// The [codeVerifier] must match the challenge sent in the original auth URL.
  /// Throws [AiProviderException] on HTTP or parse errors.
  Future<OAuthConfig> exchangeCodeForTokens({
    required String code,
    required String codeVerifier,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUri,
          'code_verifier': codeVerifier,
        },
      );
      return _parseTokenResponse(response.data!);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Refreshes tokens using [config]'s refresh token.
  ///
  /// Returns a new [OAuthConfig] with updated access token and expiry.
  /// Throws [AiProviderException] if the refresh token is invalid or expired.
  Future<OAuthConfig> refreshTokens(OAuthConfig config) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _tokenEndpoint,
        data: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': config.refreshToken,
        },
      );
      return _parseTokenResponse(
        response.data!,
        modelOverride: config.modelOverride,
      );
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  /// Initiates the full OAuth browser flow.
  ///
  /// 1. Generates a PKCE verifier/challenge pair.
  /// 2. Opens the system browser at the OpenAI authorization URL.
  /// 3. Waits (up to [timeout]) for the redirect callback via the macOS
  ///    custom URI scheme handled in AppDelegate.
  /// 4. Extracts the authorization code from the callback URL.
  /// 5. Exchanges the code for tokens via [exchangeCodeForTokens].
  ///
  /// Throws [AiProviderException] if the browser cannot be opened, the
  /// flow times out, or the callback is missing the authorization code.
  Future<OAuthConfig> authenticate({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final verifier = generateCodeVerifier();
    final challenge = generateCodeChallenge(verifier);
    final url = buildAuthorizationUrl(codeChallenge: challenge);

    _callbackCompleter = Completer<String>();
    _channel.setMethodCallHandler(_handleMethodCall);

    try {
      final launched = await _launchUri(url);
      if (!launched) {
        throw const AiProviderException(
          'Could not open browser for authentication.',
        );
      }

      final String callbackUrl;
      try {
        callbackUrl =
            await _callbackCompleter!.future.timeout(timeout);
      } on TimeoutException {
        throw const AiProviderException(
          'OAuth authentication timed out. Please try again.',
        );
      }

      final code =
          Uri.parse(callbackUrl).queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw const AiProviderException(
          'OAuth callback missing authorization code.',
        );
      }

      return exchangeCodeForTokens(
        code: code,
        codeVerifier: verifier,
      );
    } finally {
      _callbackCompleter = null;
      _channel.setMethodCallHandler(null);
    }
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onCallback') {
      final url = call.arguments as String;
      if (!(_callbackCompleter?.isCompleted ?? true)) {
        _callbackCompleter?.complete(url);
      }
    }
  }

  OAuthConfig _parseTokenResponse(
    Map<String, dynamic> data, {
    String modelOverride = '',
  }) {
    return OAuthConfig(
      providerName: 'openai',
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiresAt: DateTime.now().add(
        Duration(seconds: data['expires_in'] as int),
      ),
      modelOverride: modelOverride,
    );
  }

  AiProviderException _mapError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 400) {
      return const AiProviderException(
        'Invalid authorization code or client configuration.',
        statusCode: 400,
      );
    }
    if (code == 401) {
      return const AiProviderException(
        'Invalid or expired refresh token. Please sign in again.',
        statusCode: 401,
      );
    }
    return AiProviderException(
      e.message ?? 'OAuth token request failed.',
      statusCode: code,
    );
  }
}
