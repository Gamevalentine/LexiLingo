import 'package:lexilingo_app/features/voice/domain/entities/pronunciation_score.dart';

/// Produces an honest pronunciation estimate from recognized text.
///
/// This scorer deliberately stays at transcript/word level. Browser speech
/// recognition does not expose the acoustic alignment needed for trustworthy
/// phoneme-level grading.
class PronunciationTranscriptScorer {
  const PronunciationTranscriptScorer._();

  static PronunciationScore score({
    required String transcript,
    required String targetText,
    double? recognitionConfidence,
  }) {
    final spokenWords = _words(transcript);
    final targetWords = _words(targetText);

    if (targetWords.isEmpty) {
      return PronunciationScore(
        overallScore: 0,
        accuracyScore: 0,
        fluencyScore: 0,
        completenessScore: 0,
        userTranscript: transcript,
        targetText: targetText,
        feedback: 'Choose a phrase before recording.',
      );
    }

    final alignment = _align(targetWords, spokenWords);
    final wordScores = <WordScore>[];
    var targetScoreTotal = 0;
    var spokenTargetWords = 0;
    var insertions = 0;

    for (final pair in alignment) {
      if (pair.target == null) {
        insertions += 1;
        wordScores.add(
          WordScore(
            word: pair.spoken ?? '',
            score: 0,
            issue: 'insertion',
          ),
        );
        continue;
      }

      if (pair.spoken == null) {
        wordScores.add(
          WordScore(word: pair.target!, score: 0, issue: 'omission'),
        );
        continue;
      }

      spokenTargetWords += 1;
      final similarity = _wordSimilarity(pair.target!, pair.spoken!);
      final score = pair.target == pair.spoken
          ? 100
          : similarity >= 0.80
          ? 85
          : similarity >= 0.60
          ? 70
          : similarity >= 0.45
          ? 50
          : 25;

      targetScoreTotal += score;
      wordScores.add(
        WordScore(
          word: pair.target!,
          score: score,
          issue: score == 100 ? null : 'mispronunciation',
        ),
      );
    }

    final accuracyDenominator = targetWords.length + insertions;
    final accuracy = accuracyDenominator == 0
        ? 0
        : (targetScoreTotal / accuracyDenominator).round();
    final completeness =
        ((spokenTargetWords / targetWords.length) * 100).round();

    final confidence = recognitionConfidence;
    final fluency = confidence != null && confidence > 0 && confidence <= 1
        ? (confidence * 100).round()
        : ((accuracy + completeness) / 2).round();

    final overall =
        (accuracy * 0.55 + completeness * 0.30 + fluency * 0.15).round();

    return PronunciationScore(
      overallScore: _clampScore(overall),
      accuracyScore: _clampScore(accuracy),
      fluencyScore: _clampScore(fluency),
      completenessScore: _clampScore(completeness),
      userTranscript: transcript.trim(),
      targetText: targetText.trim(),
      wordScores: wordScores,
      feedback: _feedback(overall),
    );
  }

  static List<String> _words(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (normalized.isEmpty) return const [];
    return normalized.split(' ');
  }

  static List<_AlignedWord> _align(
    List<String> target,
    List<String> spoken,
  ) {
    final n = target.length;
    final m = spoken.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));

    for (var i = 0; i <= n; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= m; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final substitutionCost = target[i - 1] == spoken[j - 1] ? 0 : 1;
        final deletion = dp[i - 1][j] + 1;
        final insertion = dp[i][j - 1] + 1;
        final substitution = dp[i - 1][j - 1] + substitutionCost;
        dp[i][j] = _min3(deletion, insertion, substitution);
      }
    }

    final reversed = <_AlignedWord>[];
    var i = n;
    var j = m;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0) {
        final substitutionCost = target[i - 1] == spoken[j - 1] ? 0 : 1;
        if (dp[i][j] == dp[i - 1][j - 1] + substitutionCost) {
          reversed.add(
            _AlignedWord(target: target[i - 1], spoken: spoken[j - 1]),
          );
          i -= 1;
          j -= 1;
          continue;
        }
      }

      if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        reversed.add(_AlignedWord(target: target[i - 1], spoken: null));
        i -= 1;
        continue;
      }

      if (j > 0) {
        reversed.add(_AlignedWord(target: null, spoken: spoken[j - 1]));
        j -= 1;
      }
    }

    return reversed.reversed.toList(growable: false);
  }

  static double _wordSimilarity(String a, String b) {
    if (a == b) return 1;
    final longest = a.length > b.length ? a.length : b.length;
    if (longest == 0) return 1;
    return 1 - (_levenshteinDistance(a, b) / longest);
  }

  static int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (index) => index);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        current[j + 1] = _min3(
          current[j] + 1,
          previous[j + 1] + 1,
          previous[j] + cost,
        );
      }
      final temp = previous;
      previous = current;
      current = temp;
    }

    return previous[b.length];
  }

  static int _min3(int a, int b, int c) {
    var min = a < b ? a : b;
    if (c < min) min = c;
    return min;
  }

  static int _clampScore(num value) => value.clamp(0, 100).toInt();

  static String _feedback(int score) {
    if (score >= 90) {
      return 'Excellent pronunciation. Keep the same pace and clarity.';
    }
    if (score >= 75) {
      return 'Good job. Repeat the highlighted words once more.';
    }
    if (score >= 55) {
      return 'Nice effort. Slow down and focus on the words marked for review.';
    }
    return 'Try again slowly after listening to the example once more.';
  }
}

class _AlignedWord {
  final String? target;
  final String? spoken;

  const _AlignedWord({required this.target, required this.spoken});
}
