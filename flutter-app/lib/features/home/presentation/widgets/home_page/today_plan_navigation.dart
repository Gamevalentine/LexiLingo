import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lexilingo_app/core/navigation/learner_route.dart';
import 'package:lexilingo_app/features/course/presentation/screens/course_list_screen.dart';
import 'package:lexilingo_app/features/home/presentation/widgets/home_page/today_plan_models.dart';
import 'package:lexilingo_app/features/voice/presentation/screens/voice_practice_screen.dart';

void openTodayPlanTask(BuildContext context, TodayPlanTask task) {
  if (kIsWeb) {
    switch (task.destination) {
      case TodayPlanDestination.vocabularyReview:
        Navigator.of(context).pushNamed('/vocabulary/review');
        return;
      case TodayPlanDestination.courseList:
        Navigator.of(context).pushNamed('/courses');
        return;
      case TodayPlanDestination.games:
        Navigator.of(context).pushNamed('/games');
        return;
      case TodayPlanDestination.lexi:
        Navigator.of(context).pushNamed('/lexi');
        return;
      case TodayPlanDestination.voice:
        Navigator.of(context).pushNamed(
          '/lexi',
          arguments: <String, dynamic>{
            'starterPrompt':
                'Hãy giúp mình luyện phát âm và nói tiếng Anh. Bắt đầu bằng 5 câu ngắn trình độ B1, sửa lỗi phát âm/cách diễn đạt bằng hướng dẫn dễ hiểu.',
          },
        );
        return;
      case TodayPlanDestination.news:
        Navigator.of(context).pushNamed(
          '/lexi',
          arguments: <String, dynamic>{
            'starterPrompt':
                'Hãy cho mình một đoạn tin tiếng Anh ngắn trình độ B1 để luyện đọc, sau đó hỏi 3 câu kiểm tra hiểu bài.',
          },
        );
        return;
      case TodayPlanDestination.podcast:
        Navigator.of(context).pushNamed(
          '/lexi',
          arguments: <String, dynamic>{
            'starterPrompt':
                'Hãy tạo một bài luyện nghe tiếng Anh ngắn trình độ B1 dưới dạng hội thoại, sau đó hỏi mình 3 câu.',
          },
        );
        return;
    }
  }

  switch (task.destination) {
    case TodayPlanDestination.vocabularyReview:
      Navigator.of(context).pushNamed('/vocabulary/review');
      return;
    case TodayPlanDestination.courseList:
      LearnerRoute.push(context, (_) => const CourseListScreen());
      return;
    case TodayPlanDestination.games:
      Navigator.of(context).pushNamed('/games');
      return;
    case TodayPlanDestination.lexi:
      Navigator.of(context).pushNamed('/lexi');
      return;
    case TodayPlanDestination.voice:
      LearnerRoute.push(context, (_) => const VoicePracticeScreen());
      return;
    case TodayPlanDestination.news:
      Navigator.of(context).pushNamed('/news');
      return;
    case TodayPlanDestination.podcast:
      Navigator.of(context).pushNamed('/podcast');
      return;
  }
}
