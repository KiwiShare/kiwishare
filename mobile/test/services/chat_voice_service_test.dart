import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kiwishare/services/chat_voice_service.dart';
import 'package:kiwishare/services/r2_upload_service.dart';

void main() {
  test('keeps the measured duration without relabelling it', () {
    expect(validatedChatVoiceDurationMs(12500), 12500);
    expect(validatedChatVoiceDurationMs(0), 1);
  });

  test('rejects a recording measured beyond 60 seconds', () {
    expect(
      () => validatedChatVoiceDurationMs(60001),
      throwsA(
        isA<ChatVoiceException>().having(
          (error) => error.message,
          'message',
          'Voice messages cannot be longer than 60 seconds.',
        ),
      ),
    );
  });

  test('copies and deletes a completed temporary recording', () async {
    final directory = await Directory.systemTemp.createTemp('kiwishare-voice-');
    final file = File('${directory.path}/voice.m4a');
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() => directory.delete(recursive: true));

    final recording = await recordingFromTemporaryFile(file.path, 2500);

    expect(recording.bytes, Uint8List.fromList([1, 2, 3]));
    expect(recording.durationMs, 2500);
    expect(await file.exists(), isFalse);
  });

  test('deletes an over-limit temporary recording after rejection', () async {
    final directory = await Directory.systemTemp.createTemp('kiwishare-voice-');
    final file = File('${directory.path}/voice.m4a');
    await file.writeAsBytes([1, 2, 3]);
    addTearDown(() => directory.delete(recursive: true));

    await expectLater(
      recordingFromTemporaryFile(file.path, 60001),
      throwsA(isA<ChatVoiceException>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('uploads voice bytes through the controlled audio folder', () async {
    final requests = <http.Request>[];
    final uploader = R2ChatVoiceUploader(
      uploader: R2UploadService(
        uploadFolder: 'audio/chat',
        client: MockClient((request) async {
          requests.add(request);
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'uploadUrl': 'https://upload.example.com/signed',
                'publicUrl':
                    'https://assets.kiwishare.online/audio/chat/voice.m4a',
              }),
              200,
            );
          }
          return http.Response('', 200);
        }),
      ),
    );

    final url = await uploader.uploadVoice(
      bytes: Uint8List.fromList([1, 2, 3]),
      fileName: 'voice.m4a',
      contentType: 'audio/mp4',
      authToken: 'valid-token',
    );

    expect(url, 'https://assets.kiwishare.online/audio/chat/voice.m4a');
    expect(jsonDecode(requests.first.body), {
      'fileName': 'voice.m4a',
      'contentType': 'audio/mp4',
      'folder': 'audio/chat',
    });
    expect(requests.last.method, 'PUT');
    expect(requests.last.headers['Content-Type'], 'audio/mp4');
    expect(requests.last.bodyBytes, [1, 2, 3]);
  });

  test('returns a voice-specific error when upload cannot start', () async {
    final uploader = R2ChatVoiceUploader(
      uploader: R2UploadService(
        uploadFolder: 'audio/chat',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'status': 'error'}), 500),
        ),
      ),
    );

    expect(
      () => uploader.uploadVoice(
        bytes: Uint8List.fromList([1]),
        fileName: 'voice.m4a',
        contentType: 'audio/mp4',
        authToken: 'valid-token',
      ),
      throwsA(
        isA<ChatVoiceException>().having(
          (error) => error.message,
          'message',
          'A voice upload could not be started. Please try again.',
        ),
      ),
    );
  });
}
