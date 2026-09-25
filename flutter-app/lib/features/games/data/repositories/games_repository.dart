import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/network/api_client.dart';
import '../../../../core/services/local_cache_service.dart';
import '../../domain/entities/game_entities.dart';

/// Repository for the Games feature — word games, XP system, and leaderboard.
///
/// Uses [ApiClient] for authenticated requests. The client handles JWT bearer
/// tokens, logging, and network error mapping automatically.
///
/// Two styles of methods are provided:
///   • Session methods  — return game container objects (WordScrambleGame,
///     MatchingGame, etc.) which include timer/XP config from the backend.
///   • Word-list methods — return plain lists of entity objects
///     (List{ScrambleWord}, MatchingGameData, etc.) for use when only the
///     word data is needed.
///
/// XP methods always bypass the cache (mutate server state).
class GamesRepository {
  final ApiClient _apiClient;
  final LocalCacheService _cache;

  GamesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(),
      _cache = LocalCacheService.instance;

  // ── Word Scramble ─────────────────────────────────────────────────────────

  /// Full session — includes timer config and XP settings.
  Future<WordScrambleGame> getWordScramble({
    String level = 'A2',
    int count = 10,
  }) async {
    if (kIsWeb) return _guestWordScramble(level, count);
    final data = await _apiClient.get(
      '/games/word-scramble?level=$level&count=$count',
    );
    return WordScrambleGame.fromJson(data);
  }

  /// Word list only — lightweight alternative to [getWordScramble].
  ///
  /// GET /games/scramble?level=A1&count=10
  Future<List<ScrambleWord>> getScrambleWords({
    String level = 'A1',
    int count = 10,
  }) async {
    final data = await _apiClient.get(
      '/games/scramble?level=$level&count=$count',
    );
    return (data['words'] as List<dynamic>? ?? [])
        .map((w) => ScrambleWord.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  // ── Fill in the Blank ─────────────────────────────────────────────────────

  /// Full session — includes timer config and total XP.
  Future<FillBlankGame> getFillBlank({
    String level = 'B1',
    int count = 8,
  }) async {
    if (kIsWeb) return _guestFillBlank(level, count);
    final data = await _apiClient.get(
      '/games/fill-blank?level=$level&count=$count',
    );
    return FillBlankGame.fromJson(data);
  }

  /// Question list only — lightweight alternative to [getFillBlank].
  ///
  /// GET /games/fill-blank?level=A1&count=8
  Future<List<FillBlankQuestion>> getFillBlankQuestions({
    String level = 'A1',
    int count = 8,
  }) async {
    final data = await _apiClient.get(
      '/games/fill-blank?level=$level&count=$count',
    );
    return (data['questions'] as List<dynamic>? ?? [])
        .map((q) => FillBlankQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  // ── Matching Game ─────────────────────────────────────────────────────────

  /// Full session — includes timer config and XP settings.
  Future<MatchingGame> getMatchingGame({
    String level = 'B1',
    String variant = 'definition',
  }) async {
    if (kIsWeb) return _guestMatching(level, variant);
    final data = await _apiClient.get(
      '/games/matching?level=$level&variant=$variant',
    );
    return MatchingGame.fromJson(data);
  }

  /// Two-column data only — lightweight alternative to [getMatchingGame].
  ///
  /// GET /games/matching?level=A1&count=6&variant=definition
  Future<MatchingGameData> getMatchingPairs({
    String level = 'A1',
    int count = 6,
    String variant = 'definition',
  }) async {
    final data = await _apiClient.get(
      '/games/matching?level=$level&count=$count&variant=$variant',
    );
    return MatchingGameData.fromJson(data);
  }

  // ── Spelling Bee ──────────────────────────────────────────────────────────

  /// Full session — includes timer config.
  Future<SpellingBeeGame> getSpellingBee({
    String level = 'B1',
    int count = 8,
  }) async {
    if (kIsWeb) return _guestSpellingBee(level, count);
    final data = await _apiClient.get(
      '/games/spelling-bee?level=$level&count=$count',
    );
    return SpellingBeeGame.fromJson(data);
  }

  /// Word list only — lightweight alternative to [getSpellingBee].
  ///
  /// GET /games/spelling-bee?level=A1&count=8
  Future<List<SpellingBeeWord>> getSpellingBeeWords({
    String level = 'A1',
    int count = 8,
  }) async {
    final data = await _apiClient.get(
      '/games/spelling-bee?level=$level&count=$count',
    );
    return (data['words'] as List<dynamic>? ?? [])
        .map((w) => SpellingBeeWord.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  // ── Grammar Quiz ──────────────────────────────────────────────────────────

  /// Full session — includes timer config and topic info.
  Future<GrammarQuizGame> getGrammarQuiz({
    String level = 'B1',
    String? topic,
    int count = 10,
  }) async {
    if (kIsWeb) return _guestGrammarQuiz(level, topic, count);
    final query = StringBuffer('/games/grammar-quiz?level=$level&count=$count');
    if (topic != null) query.write('&topic=$topic');
    final data = await _apiClient.get(query.toString());
    return GrammarQuizGame.fromJson(data);
  }

  /// Question list only (API-aligned) — lightweight alternative to
  /// [getGrammarQuiz].
  ///
  /// GET /games/grammar-quiz?level=A1[&topic=tenses]&count=10
  Future<List<GrammarQuizQuestion>> getGrammarQuizQuestions({
    String level = 'A1',
    String? topic,
    int count = 10,
  }) async {
    final query = StringBuffer('/games/grammar-quiz?level=$level&count=$count');
    if (topic != null) query.write('&topic=$topic');
    final data = await _apiClient.get(query.toString());
    return (data['questions'] as List<dynamic>? ?? [])
        .map((q) => GrammarQuizQuestion.fromJson(q as Map<String, dynamic>))
        .toList();
  }

  // ── Hangman ───────────────────────────────────────────────────────────────

  /// Full session — includes tiered hints and max-lives config.
  Future<HangmanGame> getHangmanGame({
    String level = 'A2',
    String? category,
  }) async {
    if (kIsWeb) return _guestHangman(level, category);
    final query = StringBuffer('/games/hangman?level=$level');
    if (category != null) query.write('&category=$category');
    final data = await _apiClient.get(query.toString());
    return HangmanGame.fromJson(data);
  }

  /// Single word only (flat entity) — lightweight alternative to
  /// [getHangmanGame].
  ///
  /// GET /games/hangman?level=A1[&category=animals]
  Future<HangmanWord> getHangmanWord({
    String level = 'A1',
    String? category,
  }) async {
    final query = StringBuffer('/games/hangman?level=$level');
    if (category != null) query.write('&category=$category');
    final data = await _apiClient.get(query.toString());
    // Backend may wrap the word under a 'word' key or return it at root.
    final wordData = data['word'] as Map<String, dynamic>? ?? data;
    return HangmanWord.fromJson(wordData);
  }

  Future<XPAwardResult> completeGameSession({
    required String sessionId,
    required List<Map<String, String>> answers,
    int? clientDurationSeconds,
    int hintsUsed = 0,
  }) async {
    if (kIsWeb) return _guestAward(answers);
    final data = await _apiClient.post(
      '/games/sessions/$sessionId/complete',
      body: {
        'answers': answers,
        if (clientDurationSeconds != null)
          'client_duration_seconds': clientDurationSeconds,
        'hints_used': hintsUsed,
      },
    );
    final xpData = data['xp_result'] as Map<String, dynamic>? ?? data;
    await _cache.invalidate('xp:profile:v1');
    await _cache.invalidate('xp:leaderboard:limit:20');
    return XPAwardResult.fromJson(xpData);
  }

  // ── XP System ─────────────────────────────────────────────────────────────

  /// Award XP to the current user after completing a game.
  ///
  /// POST /xp/award — always hits the network (mutates server state).
  ///
  /// [source] should match GameType.apiKey, e.g. 'word_scramble'.
  Future<XPAwardResult> awardXP({
    required String source,
    required int baseXp,
    String? sourceId,
    String? sourceDetail,
    int? durationSeconds,
    int? score,
    int? totalQuestions,
  }) async {
    if (kIsWeb) {
      return XPAwardResult(
        xpAwarded: baseXp,
        baseXp: baseXp,
        newTotalXp: baseXp,
        oldLevel: 1,
        newLevel: 1,
        currentXpInLevel: baseXp,
        levelProgressPercent: (baseXp / 100).clamp(0.0, 1.0).toDouble(),
        message: 'Guest XP',
      );
    }
    final body = <String, dynamic>{
      'source': source,
      'base_xp': baseXp,
      if (sourceId != null) 'source_id': sourceId,
      if (sourceDetail != null) 'source_detail': sourceDetail,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (score != null) 'score': score,
      if (totalQuestions != null) 'total_questions': totalQuestions,
    };
    final data = await _apiClient.post('/xp/award', body: body);
    await _cache.invalidate('xp:profile:v1');
    await _cache.invalidate('xp:leaderboard:limit:20');
    return XPAwardResult.fromJson(data);
  }

  /// Fetch the current user's XP profile.
  ///
  /// GET /xp/profile — local-first with short TTL to reduce repeated load.
  Future<XPProfile> getXPProfile() async {
    if (kIsWeb) {
      return const XPProfile(
        userId: 'guest',
        totalXp: 0,
        numericLevel: 1,
      );
    }
    final cached = await _cache.getOrFetch(
      key: 'xp:profile:v1',
      type: 'game',
      fetchFn: () => _apiClient.get('/xp/profile'),
    );
    final data = cached ?? await _apiClient.get('/xp/profile');
    // Backend may wrap the profile under a 'profile' key or return it at root.
    final profileData = data['profile'] as Map<String, dynamic>? ?? data;
    return XPProfile.fromJson(profileData);
  }

  /// Fetch the XP leaderboard.
  ///
  /// GET /xp/leaderboard?limit=20
  ///
  /// Returns the raw JSON map. Parse entries with [LeaderboardEntry.fromJson]
  /// (new, includes isCurrentUser) or [LeaderboardUser.fromJson] (legacy).
  Future<Map<String, dynamic>> getLeaderboard({int limit = 20}) async {
    if (kIsWeb) {
      return <String, dynamic>{'entries': <dynamic>[], 'current_user': null};
    }
    final cacheKey = 'xp:leaderboard:limit:$limit';
    final cached = await _cache.getOrFetch(
      key: cacheKey,
      type: 'game',
      fetchFn: () => _apiClient.get('/xp/leaderboard?limit=$limit'),
    );
    return cached ?? await _apiClient.get('/xp/leaderboard?limit=$limit');
  }
}

  WordScrambleGame _guestWordScramble(String level, int count) {
    final bank = <Map<String, String>>[
      {'word': 'travel', 'hint': 'Đi từ nơi này đến nơi khác', 'definition': 'to go from one place to another', 'vi': 'du lịch'},
      {'word': 'garden', 'hint': 'Nơi trồng cây và hoa', 'definition': 'an area where plants and flowers grow', 'vi': 'khu vườn'},
      {'word': 'family', 'hint': 'Parents, children and relatives', 'definition': 'a group of related people', 'vi': 'gia đình'},
      {'word': 'weather', 'hint': 'Rain, sun, wind or snow', 'definition': 'the condition of the air outside', 'vi': 'thời tiết'},
      {'word': 'healthy', 'hint': 'Opposite of sick', 'definition': 'in good physical condition', 'vi': 'khỏe mạnh'},
      {'word': 'library', 'hint': 'Borrow books here', 'definition': 'a place where books are kept', 'vi': 'thư viện'},
    ];
    final selected = bank.take(count.clamp(1, bank.length).toInt()).toList();
    return WordScrambleGame.fromJson({
      'session_id': 'guest-word-scramble',
      'cefr_level': level,
      'timer_seconds': 90,
      'base_xp_per_word': 10,
      'streak_bonus_threshold': 3,
      'words': [
        for (var i = 0; i < selected.length; i++)
          {
            'word_id': 'guest-ws-$i',
            'word': selected[i]['word'],
            'shuffled_letters':
                selected[i]['word']!.toUpperCase().split('').reversed.toList(),
            'correct_order': selected[i]['word']!.toUpperCase().split(''),
            'hint': selected[i]['hint'],
            'definition': selected[i]['definition'],
            'xp_value': 10,
            'letter_count': selected[i]['word']!.length,
            'cefr_level': level,
            'vietnamese_translation': selected[i]['vi'],
          },
      ],
    });
  }

  FillBlankGame _guestFillBlank(String level, int count) {
    final bank = <Map<String, dynamic>>[
      {
        'id': 'guest-fb-1',
        'sentence': 'She ___ to school every day.',
        'options': ['goes', 'go', 'going', 'went'],
        'correct_answer': 'goes',
        'grammar_tip': 'He/She/It + verb-s in the present simple.',
        'explanation': 'Use “goes” with the third-person singular subject “she”.',
      },
      {
        'id': 'guest-fb-2',
        'sentence': 'I have lived here ___ 2022.',
        'options': ['since', 'for', 'from', 'during'],
        'correct_answer': 'since',
        'grammar_tip': 'Use “since” with a starting point.',
        'explanation': '2022 is a point in time, so “since” is correct.',
      },
      {
        'id': 'guest-fb-3',
        'sentence': 'If I had more time, I ___ study more.',
        'options': ['would', 'will', 'am', 'did'],
        'correct_answer': 'would',
        'grammar_tip': 'Second conditional: If + past, would + base verb.',
        'explanation': 'This is an unreal present situation.',
      },
      {
        'id': 'guest-fb-4',
        'sentence': 'They ___ dinner when I called.',
        'options': ['were having', 'have', 'had', 'are having'],
        'correct_answer': 'were having',
        'grammar_tip': 'Past continuous describes an action in progress.',
        'explanation': 'The dinner was in progress when the call happened.',
      },
      {
        'id': 'guest-fb-5',
        'sentence': 'You ___ wear a seat belt in a car.',
        'options': ['must', 'might', 'would', 'could'],
        'correct_answer': 'must',
        'grammar_tip': '“Must” expresses strong obligation.',
        'explanation': 'Wearing a seat belt is an obligation.',
      },
    ];
    final questions = bank.take(count.clamp(1, bank.length).toInt()).map((q) => {
      ...q,
      'cefr_level': level,
    }).toList();
    return FillBlankGame.fromJson({
      'session_id': 'guest-fill-blank',
      'cefr_level': level,
      'timer_seconds_per_question': 25,
      'total_xp': questions.length * 10,
      'questions': questions,
    });
  }

  MatchingGame _guestMatching(String level, String variant) {
    final pairs = <Map<String, String>>[
      {'word_id': 'guest-m-1', 'word': 'journey', 'match_text': 'a trip from one place to another'},
      {'word_id': 'guest-m-2', 'word': 'improve', 'match_text': 'to become better'},
      {'word_id': 'guest-m-3', 'word': 'confident', 'match_text': 'feeling sure about your ability'},
      {'word_id': 'guest-m-4', 'word': 'environment', 'match_text': 'the natural world around us'},
      {'word_id': 'guest-m-5', 'word': 'necessary', 'match_text': 'needed or required'},
      {'word_id': 'guest-m-6', 'word': 'opportunity', 'match_text': 'a good chance to do something'},
    ];
    return MatchingGame.fromJson({
      'session_id': 'guest-matching',
      'cefr_level': level,
      'variant': variant,
      'timer_seconds': 75,
      'time_bonus_threshold': 0.5,
      'base_xp': 20,
      'pairs': [
        for (final p in pairs) {...p, 'variant': variant},
      ],
      'words_column': [for (final p in pairs) p['word']],
      'definitions_column': [for (final p in pairs.reversed) p['match_text']],
    });
  }

  SpellingBeeGame _guestSpellingBee(String level, int count) {
    final bank = <Map<String, dynamic>>[
      {'word_id': 'guest-sp-1', 'word': 'travel', 'ipa_pronunciation': '/ˈtrævəl/', 'definition': 'to go from one place to another', 'vietnamese_translation': 'du lịch'},
      {'word_id': 'guest-sp-2', 'word': 'weather', 'ipa_pronunciation': '/ˈweðər/', 'definition': 'the condition of the air outside', 'vietnamese_translation': 'thời tiết'},
      {'word_id': 'guest-sp-3', 'word': 'library', 'ipa_pronunciation': '/ˈlaɪbreri/', 'definition': 'a place where books are kept', 'vietnamese_translation': 'thư viện'},
      {'word_id': 'guest-sp-4', 'word': 'healthy', 'ipa_pronunciation': '/ˈhelθi/', 'definition': 'in good physical condition', 'vietnamese_translation': 'khỏe mạnh'},
      {'word_id': 'guest-sp-5', 'word': 'knowledge', 'ipa_pronunciation': '/ˈnɒlɪdʒ/', 'definition': 'information and skills gained by learning', 'vietnamese_translation': 'kiến thức'},
    ];
    return SpellingBeeGame.fromJson({
      'session_id': 'guest-spelling',
      'cefr_level': level,
      'timer_seconds': 45,
      'words': [
        for (final w in bank.take(count.clamp(1, bank.length).toInt()))
          {...w, 'xp_value': 10, 'max_replays': 3},
      ],
    });
  }

  GrammarQuizGame _guestGrammarQuiz(String level, String? topic, int count) {
    final bank = <Map<String, dynamic>>[
      {
        'id': 'guest-gq-1',
        'question': 'I ___ him since last Monday.',
        'options': ["haven't seen", "didn't see", "don't see", "wasn't seeing"],
        'correct_answer': "haven't seen",
        'explanation': '“Since” commonly goes with the present perfect here.',
        'topic': 'present_perfect',
      },
      {
        'id': 'guest-gq-2',
        'question': 'If I ___ more time, I would study harder.',
        'options': ['had', 'have', 'will have', 'having'],
        'correct_answer': 'had',
        'explanation': 'Second conditional: If + past simple, would + base verb.',
        'topic': 'conditionals',
      },
      {
        'id': 'guest-gq-3',
        'question': 'You ___ smoke here — it is not allowed.',
        'options': ["mustn't", 'must', 'should', "needn't"],
        'correct_answer': "mustn't",
        'explanation': '“Mustn’t” expresses prohibition.',
        'topic': 'modals',
      },
      {
        'id': 'guest-gq-4',
        'question': 'The report ___ by the manager yesterday.',
        'options': ['was written', 'wrote', 'has written', 'is written'],
        'correct_answer': 'was written',
        'explanation': 'Past passive: was/were + past participle.',
        'topic': 'passive',
      },
      {
        'id': 'guest-gq-5',
        'question': 'Have you ever ___ sushi?',
        'options': ['eaten', 'eat', 'ate', 'eating'],
        'correct_answer': 'eaten',
        'explanation': 'Present perfect uses have/has + past participle.',
        'topic': 'present_perfect',
      },
    ];
    final questions = bank.take(count.clamp(1, bank.length).toInt()).map((q) => {
      ...q,
      'cefr_level': level,
    }).toList();
    return GrammarQuizGame.fromJson({
      'session_id': 'guest-grammar',
      'cefr_level': level,
      'topic': topic ?? 'mixed',
      'timer_seconds_per_question': 25,
      'total_xp': questions.length * 10,
      'questions': questions,
    });
  }

  HangmanGame _guestHangman(String level, String? category) {
    return HangmanGame.fromJson({
      'session_id': 'guest-hangman',
      'word_id': 'guest-h-1',
      'word': 'journey',
      'letter_count': 7,
      'category': category ?? 'travel',
      'cefr_level': level,
      'hints': {
        'hint1_free': 'A trip from one place to another',
        'hint2_xp_cost': 5,
        'hint2_definition': 'an act of travelling from one place to another',
        'hint3_xp_cost': 5,
      },
      'max_lives': 6,
      'base_xp': 15,
      'available_categories': ['travel', 'education', 'daily life'],
      'vietnamese_translation': 'hành trình',
    });
  }

  XPAwardResult _guestAward(List<Map<String, String>> answers) {
    final answered = answers.where((a) => (a['answer'] ?? '').trim().isNotEmpty).length;
    final xp = answered * 10;
    return XPAwardResult(
      xpAwarded: xp,
      baseXp: xp,
      newTotalXp: xp,
      dailyXpToday: xp,
      dailyCapRemaining: 500,
      oldLevel: 1,
      newLevel: 1,
      currentXpInLevel: xp,
      levelProgressPercent: (xp / 100).clamp(0.0, 1.0).toDouble(),
      message: 'Guest session completed',
    );
  }

