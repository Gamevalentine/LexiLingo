import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, debugPrint;
import 'package:easy_localization/easy_localization.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:lexilingo_app/firebase_options.dart';
import 'package:lexilingo_app/core/services/deep_link_service.dart';
import 'package:lexilingo_app/core/services/purchases_service.dart';
import 'package:lexilingo_app/core/services/firebase_messaging_service.dart';
import 'package:lexilingo_app/core/services/app_navigation_service.dart';
import 'package:lexilingo_app/core/services/notification_service.dart';
import 'package:lexilingo_app/core/theme/app_theme.dart';
import 'package:lexilingo_app/core/theme/app_tactile_theme.dart';
import 'package:lexilingo_app/core/navigation/learner_route.dart';
import 'package:lexilingo_app/core/di/injection_container.dart' as di;
import 'package:lexilingo_app/core/network/api_config.dart';
import 'package:lexilingo_app/core/utils/app_logger.dart';
// import 'package:lexilingo_app/core/services/course_import_service.dart'; // Already disabled
import 'package:lexilingo_app/core/services/health_check_service.dart';
import 'package:lexilingo_app/core/startup/startup_coordinator.dart';
import 'package:lexilingo_app/core/startup/startup_task.dart';
import 'package:lexilingo_app/core/startup/local_state_migration_service.dart';
import 'package:lexilingo_app/core/services/sync_queue_lifecycle_runner.dart';
import 'package:lexilingo_app/core/network/api_client.dart';
import 'package:lexilingo_app/features/achievements/presentation/screens/achievements_screen.dart';
import 'package:lexilingo_app/features/achievements/presentation/providers/achievement_provider.dart';
import 'package:lexilingo_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:lexilingo_app/features/auth/presentation/pages/reset_password_page.dart';
import 'package:lexilingo_app/features/auth/presentation/widgets/auth_wrapper.dart';
import 'package:lexilingo_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:lexilingo_app/features/chat/presentation/providers/story_provider.dart';
import 'package:lexilingo_app/features/course/presentation/providers/course_provider.dart';
import 'package:lexilingo_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:lexilingo_app/features/learning/presentation/providers/learning_provider.dart';
import 'package:lexilingo_app/features/level/presentation/pages/placement_test_page.dart';
import 'package:lexilingo_app/features/level/presentation/providers/level_provider.dart';
import 'package:lexilingo_app/features/level/presentation/providers/placement_test_provider.dart';
import 'package:lexilingo_app/features/level/presentation/providers/proficiency_provider.dart';
import 'package:lexilingo_app/features/notifications/presentation/providers/notification_provider.dart';
import 'package:lexilingo_app/features/profile/presentation/providers/profile_provider.dart';
import 'package:lexilingo_app/features/progress/presentation/providers/progress_provider.dart';
import 'package:lexilingo_app/features/social/presentation/providers/social_provider.dart';
import 'package:lexilingo_app/features/vocabulary/presentation/providers/vocab_provider.dart';
import 'package:lexilingo_app/features/vocabulary/presentation/providers/flashcard_provider.dart';
import 'package:lexilingo_app/features/vocabulary/presentation/screens/flashcard_review_screen.dart';
import 'package:lexilingo_app/features/vocabulary/presentation/screens/word_of_day_screen.dart';
import 'package:lexilingo_app/features/vocabulary/vocabulary_di.dart'
    as vocab_di;
import 'package:lexilingo_app/features/user/presentation/providers/user_provider.dart';
import 'package:lexilingo_app/features/user/presentation/providers/settings_provider.dart';
import 'package:lexilingo_app/features/home/presentation/providers/home_provider.dart';
import 'package:lexilingo_app/features/home/presentation/pages/today_plan_page.dart';
import 'package:lexilingo_app/features/voice/presentation/providers/voice_provider.dart';
import 'package:lexilingo_app/features/voice/presentation/providers/tts_settings_provider.dart';
import 'package:lexilingo_app/features/voice/presentation/providers/speech_recognition_provider.dart';
import 'package:lexilingo_app/features/progress/presentation/providers/streak_provider.dart';
import 'package:lexilingo_app/features/progress/presentation/providers/daily_challenges_provider.dart';
import 'package:lexilingo_app/features/social/presentation/screens/social_screen.dart';
import 'package:lexilingo_app/features/youtube/presentation/providers/youtube_provider.dart';
import 'package:lexilingo_app/features/youtube/presentation/screens/youtube_explore_screen.dart';
import 'package:lexilingo_app/features/youtube/presentation/screens/youtube_player_screen.dart';
import 'package:lexilingo_app/features/youtube/domain/entities/youtube_entities.dart';
import 'package:lexilingo_app/features/news/presentation/providers/news_provider.dart';
import 'package:lexilingo_app/features/news/presentation/screens/news_list_screen.dart';
import 'package:lexilingo_app/features/news/presentation/screens/news_detail_screen.dart';
import 'package:lexilingo_app/features/news/presentation/screens/news_quiz_screen.dart';
import 'package:lexilingo_app/features/news/domain/entities/news_entities.dart';
import 'package:lexilingo_app/features/games/presentation/providers/games_provider.dart';
import 'package:lexilingo_app/features/games/presentation/screens/games_hub_screen.dart';
import 'package:lexilingo_app/features/podcast/presentation/providers/podcast_provider.dart';
import 'package:lexilingo_app/features/podcast/presentation/screens/podcast_explore_screen.dart';
import 'package:lexilingo_app/features/podcast/presentation/screens/podcast_detail_screen.dart';
import 'package:lexilingo_app/features/podcast/presentation/screens/podcast_player_screen.dart';
import 'package:lexilingo_app/features/podcast/domain/entities/podcast_entities.dart';
import 'package:lexilingo_app/features/books/presentation/providers/book_provider.dart';
import 'package:lexilingo_app/features/books/presentation/screens/book_library_screen.dart';
import 'package:lexilingo_app/features/mistakes/presentation/pages/mistake_notebook_page.dart';
import 'package:lexilingo_app/features/offline/presentation/pages/offline_sync_center_page.dart';
import 'package:lexilingo_app/features/practice/presentation/pages/practice_lab_page.dart';
import 'package:lexilingo_app/features/premium/presentation/screens/paywall_screen.dart';
import 'package:lexilingo_app/features/lexi_chat/presentation/providers/lexi_chat_provider.dart';
import 'package:lexilingo_app/features/lexi_chat/presentation/pages/lexi_chat_page.dart';
import 'package:lexilingo_app/features/home/presentation/pages/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  if (kIsWeb) {
    // Avoid sqflite web worker boot failures when sqflite_sw.js is not deployed.
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  }

  // Add error handler for Flutter and Dart errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
  };

  try {
    // Load only public client config. Raw .env files may contain server
    // secrets and must never be bundled into Flutter web assets.
    final envFile = kReleaseMode
        ? 'assets/env/prod_config'
        : 'assets/env/dev_config';
    await dotenv.load(fileName: envFile);
  } catch (e) {
    debugPrint('Warning: Could not load public config: $e');
  }

  debugPrint('Backend API base URL: ${ApiConfig.baseUrl}');
  debugPrint('AI service base URL: ${ApiConfig.aiServiceUrl}');

  // The public web build is guest-only and does not use auth/push.
  // Skip Firebase startup there to reduce first-load work.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');

      FlutterError.onError = kReleaseMode
          ? FirebaseCrashlytics.instance.recordFlutterFatalError
          : FlutterError.presentError;

      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('Warning: Firebase initialization failed: $e');
    }
  }

  // Initialize Dependency Injection (skip database on web)
  await LocalStateMigrationService().runIfNeeded();
  await di.initializeDependencies(skipDatabase: kIsWeb);

  // Native builds use scheduled/local notifications. Guest web does not.
  if (!kIsWeb) {
    await di.sl<NotificationService>().ensureInitialized();
  }

  // Run startup tasks (health check, seeding). Keep non-blocking for first frame.
  if (!kIsWeb) {
    final coordinator = StartupCoordinator(
      tasks: [
        StartupTask(
          id: 'health_check',
          label: 'Ping backend /health',
          action: () async {
            final ok = await di.sl<HealthCheckService>().ping();
            if (!ok) throw Exception('Backend health check failed');
          },
        ),
      ],
    );

    unawaited(
      coordinator.run(
        onProgress: (result) => logDebug(
          'Startup',
          '${result.id}: ${result.status.name} ${result.message ?? ''}',
        ),
      ),
    );
  }

  // Wrap runApp in runZonedGuarded so uncaught async errors are forwarded to
  // Crashlytics. In release mode only — dev keeps the default red-screen behavior.
  if (!kIsWeb && kReleaseMode) {
    runZonedGuarded(
      () => runApp(
        EasyLocalization(
          supportedLocales: const [
            Locale('vi'),
            Locale('en'),
            Locale('ja'),
            Locale('ko'),
            Locale('zh'),
            Locale('fr'),
            Locale('es'),
          ],
          path: 'assets/i18n',
          fallbackLocale: const Locale('vi'),
          startLocale: const Locale('vi'),
          useOnlyLangCode: true,
          child: const LexiLingoApp(),
        ),
      ),
      (error, stack) =>
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
    );
  } else {
    runApp(
      EasyLocalization(
        supportedLocales: const [
          Locale('vi'),
          Locale('en'),
          Locale('ja'),
          Locale('ko'),
          Locale('zh'),
          Locale('fr'),
          Locale('es'),
        ],
        path: 'assets/i18n',
        fallbackLocale: const Locale('vi'),
        startLocale: const Locale('vi'),
        useOnlyLangCode: true,
        child: const LexiLingoApp(),
      ),
    );
  }

  // Initialize Firebase Messaging and Deep Links after UI starts rendering
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    if (!kIsWeb) {
      try {
        await FirebaseMessagingService.instance.initialize();
        debugPrint('Firebase Messaging initialized successfully');
      } catch (e) {
        debugPrint('Warning: Firebase Messaging initialization failed: $e');
      }
    }
    try {
      await DeepLinkService.instance.init();
      debugPrint('Deep link service initialized');
    } catch (e) {
      debugPrint('Warning: Deep link service initialization failed: $e');
    }
    if (!kIsWeb) {
      try {
        await PurchasesService.instance.init(
          iosApiKey: dotenv.maybeGet('REVENUECAT_API_KEY_IOS'),
          androidApiKey: dotenv.maybeGet('REVENUECAT_API_KEY_ANDROID'),
        );
      } catch (e) {
        debugPrint('Warning: RevenueCat initialization failed: $e');
      }
    }
  });
}

class LexiLingoApp extends StatefulWidget {
  const LexiLingoApp({super.key});

  @override
  State<LexiLingoApp> createState() => _LexiLingoAppState();
}

class _LexiLingoAppState extends State<LexiLingoApp>
    with WidgetsBindingObserver {
  SyncQueueLifecycleRunner? _syncQueueRunner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _syncQueueRunner = SyncQueueLifecycleRunner(
        apiClient: di.sl<ApiClient>(),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncQueueRunner?.start();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncQueueRunner?.stop();
    DeepLinkService.instance.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncQueueRunner?.onAppResumed();
    }
  }

  String? _extractResetTokenFromDeepLink() {
    final pending = DeepLinkService.instance.pendingResetToken;
    if (pending != null && pending.isNotEmpty) {
      DeepLinkService.instance.pendingResetToken = null;
      return pending;
    }

    final queryToken = Uri.base.queryParameters['token'];
    if (queryToken != null && queryToken.isNotEmpty) {
      return queryToken;
    }

    final fragment = Uri.base.fragment;
    if (fragment.isNotEmpty) {
      final fragmentUri = Uri.tryParse(fragment);
      final fragmentToken = fragmentUri?.queryParameters['token'];
      if (fragmentToken != null && fragmentToken.isNotEmpty) {
        return fragmentToken;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => di.sl<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<UserProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<HomeProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ProfileProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ChatProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<StoryProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<CourseProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<LearningProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ProgressProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<VocabProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<FlashcardProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<VoiceProvider>()),
        ChangeNotifierProvider(
          create: (_) => di.sl<SpeechRecognitionProvider>(),
        ),
        ChangeNotifierProvider(
          create: (_) => di.sl<TtsSettingsProvider>()..init(),
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = di.sl<StreakProvider>();
            if (!kIsWeb) p.loadStreak();
            return p;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final p = di.sl<DailyChallengesProvider>();
            if (!kIsWeb) p.loadChallenges();
            return p;
          },
        ),
        ChangeNotifierProvider(create: (_) => di.sl<AchievementProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<NotificationProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<LevelProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<ProficiencyProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<SettingsProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<GamificationProvider>()),
        ChangeNotifierProvider(create: (_) => di.sl<SocialProvider>()),
        // Phase 1: YouTube Video Integration
        ChangeNotifierProvider(create: (_) => di.sl<YouTubeProvider>()),
        // Phase 2: News Reading
        ChangeNotifierProvider(create: (_) => di.sl<NewsProvider>()),
        // Phase 3: English Games + XP System
        // On web: defer XP profile load to avoid blocking startup
        ChangeNotifierProvider(
          create: (_) {
            final p = di.sl<GamesProvider>();
            if (!kIsWeb) p.loadXPProfile();
            return p;
          },
        ),
        // Phase 4: Podcast
        // On web: defer curated podcast load (AudioService not available on web)
        ChangeNotifierProvider(
          create: (_) {
            final p = di.sl<PodcastProvider>();
            if (!kIsWeb) p.loadCuratedPodcasts();
            return p;
          },
        ),
        // Phase 5: Book Reading
        ChangeNotifierProvider(create: (_) => di.sl<BookProvider>()),
        // Phase 6: Lexi Chat — Story Adventure
        ChangeNotifierProvider(create: (_) => di.sl<LexiChatProvider>()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return MaterialApp(
            title: 'LexiLingo',
            navigatorKey: AppNavigationService.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            themeAnimationDuration: Duration.zero,
            builder: (context, child) {
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: AppTheme.systemUiOverlayStyle(
                  Theme.of(context).brightness,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            // Localization — easy_localization handles locale state
            locale: context.locale,
            supportedLocales: context.supportedLocales,
            localizationsDelegates: context.localizationDelegates,
            home: kIsWeb
                ? const LearnerTheme(child: MainScreen())
                : const AuthWrapper(),
            routes: {
              '/youtube': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy gợi ý cho mình một bài luyện tiếng Anh kiểu video: chọn một chủ đề B1, cho 8 từ vựng, một đoạn hội thoại ngắn và 3 câu hỏi luyện tập.',
                      )
                    : const YouTubeExploreScreen(),
              ),
              '/youtube/player': LearnerRoute.builder((context) {
                if (kIsWeb) {
                  return const LexiChatPage(
                    initialPrompt:
                        'Hãy tạo cho mình một bài luyện tiếng Anh kiểu video ở trình độ B1, có từ vựng, hội thoại và câu hỏi luyện tập.',
                  );
                }
                final video =
                    ModalRoute.of(context)!.settings.arguments as YouTubeVideo;
                return YouTubePlayerScreen(video: video);
              }),
              '/news': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy cho mình một bản tin tiếng Anh ngắn trình độ B1 về một chủ đề đời sống, kèm từ vựng chính và 3 câu hỏi đọc hiểu.',
                      )
                    : const NewsListScreen(),
              ),
              '/news/detail': LearnerRoute.builder((context) {
                if (kIsWeb) {
                  return const LexiChatPage(
                    initialPrompt:
                        'Hãy cho mình một bài đọc tiếng Anh ngắn trình độ B1, giải thích từ mới và hỏi 3 câu đọc hiểu.',
                  );
                }
                final article =
                    ModalRoute.of(context)!.settings.arguments as NewsArticle;
                return NewsDetailScreen(article: article);
              }),
              '/news/quiz': LearnerRoute.builder((context) {
                if (kIsWeb) {
                  return const LexiChatPage(
                    initialPrompt:
                        'Hãy kiểm tra đọc hiểu tiếng Anh của mình bằng 5 câu hỏi trình độ B1. Hỏi từng câu một và chấm sau mỗi câu.',
                  );
                }
                final article =
                    ModalRoute.of(context)!.settings.arguments as NewsArticle;
                return NewsQuizScreen(article: article);
              }),
              // Phase 3: English Games
              '/games': LearnerRoute.builder(
                (context) => const GamesHubScreen(),
              ),
              '/courses': LearnerRoute.builder(
                (context) => const MainScreen(initialIndex: 1),
              ),
              '/today-plan': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy lập cho mình kế hoạch học tiếng Anh hôm nay trong 15 phút ở trình độ B1, gồm từ vựng, ngữ pháp và hội thoại ngắn.',
                      )
                    : const TodayPlanPage(),
              ),
              '/practice-lab': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy tạo một buổi luyện tiếng Anh 10 phút trình độ B1, gồm ngữ pháp, từ vựng và 5 câu hỏi tương tác. Hỏi từng câu một.',
                      )
                    : const PracticeLabPage(),
              ),
              '/mistake-notebook': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy giúp mình rà lại các lỗi tiếng Anh thường gặp. Cho 5 câu sai ở trình độ B1 để mình sửa từng câu một, rồi giải thích ngắn.',
                      )
                    : const MistakeNotebookPage(),
              ),
              '/profile': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const MainScreen(initialIndex: 0)
                    : const MainScreen(initialIndex: 4),
              ),
              '/achievements': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const MainScreen(initialIndex: 0)
                    : const AchievementsScreen(),
              ),
              '/social': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const MainScreen(initialIndex: 0)
                    : const SocialScreen(),
              ),
              '/premium': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const MainScreen(initialIndex: 0)
                    : const PaywallScreen(),
              ),
              '/offline-sync': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const MainScreen(initialIndex: 0)
                    : const OfflineSyncCenterPage(),
              ),
              '/placement-test': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy kiểm tra nhanh trình độ tiếng Anh của mình bằng 8 câu hỏi tăng dần độ khó. Hỏi từng câu một, chờ mình trả lời rồi mới tiếp tục. Cuối cùng ước lượng CEFR và giải thích ngắn.',
                      )
                    : ChangeNotifierProvider(
                        create: (_) => di.sl<PlacementTestProvider>(),
                        child: const PlacementTestPage(),
                      ),
              ),
              '/vocabulary/review': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy ôn từ vựng tiếng Anh với mình bằng 10 câu hỏi ngắn trình độ B1. Hỏi từng câu một, chờ mình trả lời, sửa sai và giải thích bằng tiếng Việt khi cần.',
                      )
                    : ChangeNotifierProvider(
                        create: (_) => vocab_di.getIt<FlashcardProvider>(),
                        child: const FlashcardReviewScreen(),
                      ),
              ),
              '/vocabulary/word-of-day': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy chọn một từ tiếng Anh hữu ích cho hôm nay ở trình độ B1, giải thích nghĩa, phát âm, collocation và cho 3 câu ví dụ.',
                      )
                    : const WordOfDayScreen(),
              ),
              // Phase 4: Podcast
              '/podcast': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy tạo một bài luyện nghe tiếng Anh kiểu podcast ngắn trình độ B1: đoạn hội thoại khoảng 1 phút, từ vựng chính và 3 câu hỏi.',
                      )
                    : const PodcastExploreScreen(),
              ),
              '/podcast/detail': LearnerRoute.builder((context) {
                if (kIsWeb) {
                  return const LexiChatPage(
                    initialPrompt:
                        'Hãy tạo một bài luyện nghe kiểu podcast ngắn trình độ B1 và hỏi mình 3 câu sau đó.',
                  );
                }
                final podcast =
                    ModalRoute.of(context)!.settings.arguments as Podcast;
                return PodcastDetailScreen(podcast: podcast);
              }),
              '/podcast/player': LearnerRoute.builder((context) {
                if (kIsWeb) {
                  return const LexiChatPage(
                    initialPrompt:
                        'Hãy tạo một đoạn hội thoại tiếng Anh ngắn để mình luyện nghe, rồi kiểm tra mình bằng 3 câu hỏi.',
                  );
                }
                final args =
                    ModalRoute.of(context)!.settings.arguments
                        as Map<String, dynamic>;
                return PodcastPlayerScreen(
                  episode: args['episode'] as PodcastEpisode,
                  artworkUrl: args['artworkUrl'] as String,
                );
              }),
              // Phase 5: Books
              '/books': LearnerRoute.builder(
                (context) => kIsWeb
                    ? const LexiChatPage(
                        initialPrompt:
                            'Hãy cho mình một đoạn đọc tiếng Anh ngắn trình độ B1 như một trang sách, giải thích 6 từ mới và hỏi 3 câu đọc hiểu.',
                      )
                    : const BookLibraryScreen(),
              ),
              // Phase 6: Lexi Chat
              '/lexi': LearnerRoute.builder((context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                String? starterPrompt;
                if (args is Map<String, dynamic>) {
                  starterPrompt = args['starterPrompt'] as String?;
                }
                return LexiChatPage(initialPrompt: starterPrompt);
              }),
              '/reset-password': (context) {
                if (kIsWeb) {
                  return const LearnerTheme(child: MainScreen(initialIndex: 0));
                }
                final args = ModalRoute.of(context)?.settings.arguments;
                String? token;
                if (args is String) {
                  token = args;
                } else if (args is Map<String, dynamic>) {
                  token = args['token'] as String?;
                }
                token ??= _extractResetTokenFromDeepLink();
                return ResetPasswordPage(initialToken: token);
              },
            },
          );
        },
      ),
    );
  }
}
