import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'r2_upload_service.dart';

const maxChatVoiceDurationMs = 60000;

int validatedChatVoiceDurationMs(int elapsedMs) {
  if (elapsedMs > maxChatVoiceDurationMs) {
    throw const ChatVoiceException(
      'Voice messages cannot be longer than 60 seconds.',
    );
  }
  return elapsedMs < 1 ? 1 : elapsedMs;
}

class ChatVoiceRecording {
  const ChatVoiceRecording({
    required this.bytes,
    required this.fileName,
    required this.contentType,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;
  final int durationMs;
}

class ChatVoiceException implements Exception {
  const ChatVoiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class ChatVoiceRecorder {
  Future<void> start();
  Future<ChatVoiceRecording?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceChatVoiceRecorder implements ChatVoiceRecorder {
  DeviceChatVoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw const ChatVoiceException(
        'Microphone access is required to record a voice message.',
      );
    }
    final directory = await getTemporaryDirectory();
    final fileName = 'chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
      ),
      path: '${directory.path}/$fileName',
    );
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  Future<ChatVoiceRecording?> stop() async {
    // Capture the user-visible recording duration before awaiting native AAC
    // finalization, which can add encoder shutdown latency after the limit.
    _stopwatch.stop();
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;
    final durationMs = validatedChatVoiceDurationMs(elapsedMs);
    final file = XFile(path, mimeType: 'audio/mp4');
    final bytes = await file.readAsBytes();
    return ChatVoiceRecording(
      bytes: bytes,
      fileName: file.name.isEmpty
          ? 'chat_voice_${DateTime.now().millisecondsSinceEpoch}.m4a'
          : file.name,
      contentType: 'audio/mp4',
      durationMs: durationMs,
    );
  }

  @override
  Future<void> cancel() async {
    _stopwatch
      ..stop()
      ..reset();
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}

abstract interface class ChatVoiceUploader {
  Future<String> uploadVoice({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  });
}

class R2ChatVoiceUploader implements ChatVoiceUploader {
  R2ChatVoiceUploader({R2UploadService? uploader})
    : _uploader = uploader ?? R2UploadService(uploadFolder: 'audio/chat');

  final R2UploadService _uploader;

  @override
  Future<String> uploadVoice({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  }) async {
    try {
      return await _uploader.uploadFile(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
        authToken: authToken,
        startFailureMessage:
            'A voice upload could not be started. Please try again.',
        uploadFailureMessage:
            'The voice message could not be uploaded. Please try again.',
      );
    } on ListingPhotoUploadException catch (error) {
      throw ChatVoiceException(error.message);
    }
  }
}
