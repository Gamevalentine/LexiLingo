class WebSpeechSynthesis {
  static bool get isSupported => false;

  void speak(
    String text, {
    String language = 'en-US',
    double rate = 1.0,
  }) {}

  void stop() {}
}
