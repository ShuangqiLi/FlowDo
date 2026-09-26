import 'package:flutter_test/flutter_test.dart';
import 'package:flowdo/platform/microphone.dart';
import 'package:flowdo/utils/voice_input_messages.dart';

void main() {
  group('voiceErrorMessage', () {
    test('not-allowed on an http origin explains the insecure-origin rule', () {
      final message = voiceErrorMessage(
        'not-allowed',
        secureContext: false,
        origin: 'http://192.168.1.8:8080',
      );
      expect(message, isNotNull);
      expect(message, isNot(contains('not-allowed')));
      expect(message, contains('http'));
      expect(message, contains('192.168.1.8:8080'));
      expect(message, contains(insecureOriginFlag));
    });

    test('not-allowed on a secure origin points at the site permission', () {
      final message = voiceErrorMessage('not-allowed', secureContext: true);
      expect(message, contains('麦克风'));
      expect(message, contains('网站设置'));
      expect(message, isNot(contains(insecureOriginFlag)));
    });

    test('service-not-allowed is treated like not-allowed', () {
      expect(
        voiceErrorMessage('service-not-allowed', secureContext: true),
        voiceErrorMessage('not-allowed', secureContext: true),
      );
    });

    test('network failures mention the recognition service', () {
      final message = voiceErrorMessage('network', secureContext: true);
      expect(message, contains('网络'));
      expect(message, contains('Edge'));
    });

    test('aborted is silent', () {
      expect(voiceErrorMessage('aborted', secureContext: true), isNull);
    });

    test('unknown codes still include the raw code for debugging', () {
      expect(
        voiceErrorMessage('weird-thing', secureContext: true),
        contains('weird-thing'),
      );
    });
  });

  group('micStateMessage', () {
    test('every state has a sentence', () {
      for (final state in MicPermissionState.values) {
        expect(micStateMessage(state), isNotEmpty, reason: '$state');
      }
    });

    test('insecure context names the page origin', () {
      expect(
        micStateMessage(
          MicPermissionState.insecureContext,
          origin: 'http://nas:8088',
        ),
        contains('http://nas:8088'),
      );
    });

    test('asking again only makes sense before a decision', () {
      expect(micRequestUseful(MicPermissionState.prompt), isTrue);
      expect(micRequestUseful(MicPermissionState.unknown), isTrue);
      expect(micRequestUseful(MicPermissionState.granted), isFalse);
      expect(micRequestUseful(MicPermissionState.denied), isFalse);
      expect(micRequestUseful(MicPermissionState.insecureContext), isFalse);
    });
  });
}
