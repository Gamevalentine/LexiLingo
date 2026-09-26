import 'package:flutter_test/flutter_test.dart';
import 'package:lexilingo_app/features/voice/domain/services/pronunciation_transcript_scorer.dart';

void main() {
  group('PronunciationTranscriptScorer', () {
    test('gives a perfect score for an exact transcript', () {
      final score = PronunciationTranscriptScorer.score(
        transcript: 'Hello how are you today',
        targetText: 'Hello, how are you today?',
        recognitionConfidence: 1,
      );

      expect(score.overallScore, 100);
      expect(score.accuracyScore, 100);
      expect(score.completenessScore, 100);
      expect(score.wordScores.every((word) => !word.hasIssue), isTrue);
    });

    test('marks an omitted target word without shifting every later word', () {
      final score = PronunciationTranscriptScorer.score(
        transcript: 'I love languages',
        targetText: 'I love learning languages',
      );

      expect(score.completenessScore, 75);
      expect(
        score.wordScores.any(
          (word) => word.word == 'learning' && word.issue == 'omission',
        ),
        isTrue,
      );
      expect(
        score.wordScores.any(
          (word) => word.word == 'languages' && !word.hasIssue,
        ),
        isTrue,
      );
    });

    test('penalizes inserted words', () {
      final score = PronunciationTranscriptScorer.score(
        transcript: 'nice very to meet you',
        targetText: 'nice to meet you',
      );

      expect(score.accuracyScore, lessThan(100));
      expect(
        score.wordScores.any((word) => word.issue == 'insertion'),
        isTrue,
      );
    });

    test('keeps close word substitutions as partial credit', () {
      final score = PronunciationTranscriptScorer.score(
        transcript: 'weather is beautifol today',
        targetText: 'weather is beautiful today',
      );

      final beautiful = score.wordScores.firstWhere(
        (word) => word.word == 'beautiful',
      );
      expect(beautiful.score, greaterThanOrEqualTo(70));
      expect(beautiful.issue, 'mispronunciation');
    });
  });
}
