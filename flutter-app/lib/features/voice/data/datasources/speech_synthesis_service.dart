/// Platform-aware speech synthesis service.
library;

export 'web_speech_synthesis_stub.dart'
    if (dart.library.html) 'web_speech_synthesis.dart';
