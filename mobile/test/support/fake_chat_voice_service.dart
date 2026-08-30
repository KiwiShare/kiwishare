import 'dart:async';
import 'dart:typed_data';

import 'package:kiwishare/services/chat_voice_service.dart';

class FakeChatVoiceUploader implements ChatVoiceUploader {
  FakeChatVoiceUploader({
    this.url = 'https://assets.kiwishare.online/audio/chat/voice.m4a',
    this.error,
  });

  final String url;
  final ChatVoiceException? error;
  int uploadCalls = 0;
  Uint8List? uploadedBytes;
  String? uploadedFileName;
  String? uploadedContentType;

  @override
  Future<String> uploadVoice({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    required String authToken,
  }) async {
    uploadCalls += 1;
    uploadedBytes = bytes;
    uploadedFileName = fileName;
    uploadedContentType = contentType;
    if (error != null) throw error!;
    return url;
  }
}

class FakeChatVoiceRecorder implements ChatVoiceRecorder {
  FakeChatVoiceRecorder({
    ChatVoiceRecording? recording,
    this.startError,
    this.startGate,
    this.stopGate,
    this.cancelGate,
  }) : recording =
           recording ??
           ChatVoiceRecording(
             bytes: Uint8List.fromList([7, 8, 9]),
             fileName: 'voice.m4a',
             contentType: 'audio/mp4',
             durationMs: 3200,
           );

  final ChatVoiceRecording recording;
  final ChatVoiceException? startError;
  final Completer<void>? startGate;
  final Completer<void>? stopGate;
  final Completer<void>? cancelGate;
  int startCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int disposeCalls = 0;
  final List<String> callOrder = [];

  @override
  Future<void> start() async {
    startCalls += 1;
    callOrder.add('start');
    await startGate?.future;
    if (startError != null) throw startError!;
  }

  @override
  Future<ChatVoiceRecording?> stop() async {
    stopCalls += 1;
    callOrder.add('stop');
    await stopGate?.future;
    return recording;
  }

  @override
  Future<void> cancel() async {
    cancelCalls += 1;
    callOrder.add('cancel');
    await cancelGate?.future;
  }

  @override
  Future<void> dispose() async {
    disposeCalls += 1;
    callOrder.add('dispose');
  }
}
