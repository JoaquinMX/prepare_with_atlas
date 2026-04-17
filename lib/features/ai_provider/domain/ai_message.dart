import 'package:freezed_annotation/freezed_annotation.dart';

part 'ai_message.freezed.dart';
part 'ai_message.g.dart';

/// A text (optionally multimodal) message to/from an AI provider.
@freezed
abstract class AiMessage with _$AiMessage {
  /// Creates an [AiMessage] with the given [role] and [content].
  const factory AiMessage({
    /// The role of the message sender: 'system', 'user', or 'assistant'.
    required String role,

    /// The text content of the message.
    required String content,

    /// Optional PNG bytes for multimodal image input.
    @Default(null) List<int>? imageBytes,

    /// MIME type of the image: 'image/png' or 'image/jpeg'.
    @Default(null) String? imageMimeType,
  }) = _AiMessage;

  /// Deserializes an [AiMessage] from [json].
  factory AiMessage.fromJson(Map<String, dynamic> json) =>
      _$AiMessageFromJson(json);
}
