// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, uri_does_not_exist

import 'dart:js' as js;
import 'dart:js_util' as js_util;

class WebSpeechSynthesis {
  static bool get isSupported =>
      js.context.hasProperty('speechSynthesis') &&
      js.context.hasProperty('SpeechSynthesisUtterance');

  void speak(
    String text, {
    String language = 'en-US',
    double rate = 1.0,
  }) {
    final trimmed = text.trim();
    if (!isSupported || trimmed.isEmpty) return;

    try {
      final synthesis = js.context['speechSynthesis'];
      final ctor = js.context['SpeechSynthesisUtterance'] as js.JsFunction;
      final utterance = js.JsObject(ctor, [trimmed]);
      utterance['lang'] = language;
      utterance['rate'] = rate;
      utterance['pitch'] = 1.0;
      utterance['volume'] = 1.0;

      js_util.callMethod<void>(synthesis, 'cancel', const []);
      js_util.callMethod<void>(synthesis, 'speak', [utterance]);
    } catch (_) {
      // Browser TTS is a progressive enhancement; never break chat.
    }
  }

  void stop() {
    if (!isSupported) return;
    try {
      js_util.callMethod<void>(
        js.context['speechSynthesis'],
        'cancel',
        const [],
      );
    } catch (_) {}
  }
}
