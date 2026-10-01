import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lexilingo_app/core/widgets/lottie_loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:lexilingo_app/features/course/presentation/providers/course_provider.dart';
import 'package:lexilingo_app/features/course/domain/entities/course_detail_entity.dart';
import 'package:lexilingo_app/features/learning/presentation/screens/learning_session_screen.dart';
import 'package:lexilingo_app/features/learning/presentation/screens/learning_roadmap_screen.dart';
import 'package:lexilingo_app/core/theme/app_theme.dart';

/// Course Detail Screen
/// Shows course roadmap with units and lessons
class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final String? heroTag;
  final String? initialThumbnailUrl;
  final String? fallbackThumbnailUrl;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    this.heroTag,
    this.initialThumbnailUrl,
    this.fallbackThumbnailUrl,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourseDetail(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingDetail) {
            return const Center(child: LottieLoadingWidget.medium());
          }

          if (provider.detailError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.errorBright,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.detailError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadCourseDetail(widget.courseId),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            );
          }

          final course = provider.courseDetail;
          if (course == null) {
            return Center(child: Text('course.notFound'.tr()));
          }

          return CustomScrollView(
            slivers: [
              // Compact App Bar with smaller title
              SliverAppBar(
                pinned: true,
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                titleSpacing: 0,
                title: Text(
                  course.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.surface,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
              ),

              // Course Info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCourseHeroCard(context, course),
                      const SizedBox(height: 16),

                      // Description
                      if (course.description != null) ...[
                        Text(
                          course.description!,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Course Stats
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _StatChip(
                            icon: Icons.language,
                            label: course.language,
                          ),
                          _StatChip(icon: Icons.bar_chart, label: course.level),
                          _StatChip(
                            icon: Icons.star,
                            label: '${course.totalXp} XP',
                          ),
                          _StatChip(
                            icon: Icons.access_time,
                            label: 'course.durationMin'.tr(
                              namedArgs: {
                                'count': '${course.estimatedDuration}',
                              },
                            ),
                          ),
                          _StatChip(
                            icon: Icons.book,
                            label: 'course.totalLessonsCount'.tr(
                              namedArgs: {'count': '${course.totalLessons}'},
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Progress (if enrolled)
                      if (course.isEnrolled == true) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'course.yourProgress'.tr(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                  value: (course.userProgress ?? 0) / 100,
                                  minHeight: 8,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'course.userProgressPercent'.tr(
                                    namedArgs: {
                                      'percent':
                                          course.userProgress?.toStringAsFixed(
                                            0,
                                          ) ??
                                          '0',
                                    },
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColorRoles.textSecondary(
                                      Theme.of(context).brightness ==
                                          Brightness.dark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // View Full Roadmap Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.account_tree_outlined),
                            label: Text('course.viewFullRoadmap'.tr()),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LearningRoadmapScreen(
                                    courseId: course.id,
                                    courseTitle: course.title,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Enroll Button (if not enrolled)
                      if (course.isEnrolled != true) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: provider.isEnrolling
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: LottieLoadingWidget.tiny(),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(
                              provider.isEnrolling
                                  ? 'course.enrolling'.tr()
                                  : 'course.startLearning'.tr(),
                            ),
                            onPressed: provider.isEnrolling
                                ? null
                                : () => _enrollInCourse(context, provider),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (course.id == 'course-en-zero-69') ...[
                        const SizedBox(height: 8),
                        Text(
                          '4 tài liệu nguồn của khóa học',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Các tài liệu bạn đã gửi được gắn trực tiếp với khóa học này để bạn biết bài nào đang dựa trên nguồn nào.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColorRoles.textSecondary(
                              Theme.of(context).brightness ==
                                  Brightness.dark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const _SourceDocumentCard(
                          title: 'Ngữ pháp Tiếng Anh',
                          subtitle: 'Nguồn chính cho lộ trình ngữ pháp từ cơ bản đến nâng cao.',
                          icon: Icons.menu_book_rounded,
                        ),
                        const SizedBox(height: 10),
                        const _SourceDocumentCard(
                          title: 'Bài tập Tiếng Anh 6 - Tập 1',
                          subtitle: 'Luyện phát âm, từ vựng, ngữ pháp, nói, đọc và viết cho các chủ điểm đầu.',
                          icon: Icons.assignment_rounded,
                        ),
                        const SizedBox(height: 10),
                        const _SourceDocumentCard(
                          title: 'Bài tập Tiếng Anh 6 - Tập 2',
                          subtitle: 'Tiếp tục luyện Unit 7–12 và các chủ điểm mở rộng ở phần sau khóa học.',
                          icon: Icons.assignment_turned_in_rounded,
                        ),
                        const SizedBox(height: 10),
                        const _SourceDocumentCard(
                          title: 'Giải thích ngữ pháp Tiếng Anh - Mai Lan Hương',
                          subtitle: 'Tài liệu tham khảo bổ sung để giải thích sâu hơn khi cần.',
                          icon: Icons.library_books_rounded,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Roadmap Header
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'course.learningRoadmap'.tr(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // Units List
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final unit = course.units[index];
                  return _UnitCard(
                    unit: unit,
                    unitNumber: index + 1,
                    courseId: course.id,
                  );
                }, childCount: course.units.length),
              ),

              // Bottom Padding
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enrollInCourse(
    BuildContext context,
    CourseProvider provider,
  ) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    provider.clearEnrollmentMessages();

    final success = await provider.enrollInCourse(widget.courseId);

    if (!mounted) return;

    if (success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.enrollmentSuccess ?? 'course.enrolledSuccess'.tr(),
          ),
          backgroundColor: AppColors.greenSuccessBright,
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(provider.enrollmentError ?? 'course.enrollFailed'.tr()),
          backgroundColor: AppColors.errorBright,
        ),
      );
    }
  }

  Widget _buildCourseHeroCard(BuildContext context, CourseDetailEntity course) {
    final heroImage = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _buildCourseBackground(context, course),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: widget.heroTag != null
          ? Hero(tag: widget.heroTag!, child: heroImage)
          : heroImage,
    );
  }

  Widget _buildCourseBackground(
    BuildContext context,
    CourseDetailEntity course,
  ) {
    final imageUrls = buildCourseThumbnailCandidates(
      detailThumbnailUrl: course.thumbnailUrl,
      initialThumbnailUrl: widget.initialThumbnailUrl,
      fallbackThumbnailUrl: widget.fallbackThumbnailUrl,
    );

    if (imageUrls.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _CourseHeroNetworkImage(
            imageUrls: imageUrls,
            placeholder: _buildCourseImagePlaceholder(context),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return _buildCourseImagePlaceholder(context);
  }

  Widget _buildCourseImagePlaceholder(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: Icon(
        Icons.school,
        size: 64,
        color: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}

List<String> buildCourseThumbnailCandidates({
  String? detailThumbnailUrl,
  String? initialThumbnailUrl,
  String? fallbackThumbnailUrl,
}) {
  final candidates = <String>[];

  for (final value in [
    detailThumbnailUrl,
    initialThumbnailUrl,
    fallbackThumbnailUrl,
  ]) {
    final url = value?.trim();
    if (url != null && url.isNotEmpty && !candidates.contains(url)) {
      candidates.add(url);
    }
  }

  return candidates;
}

class _CourseHeroNetworkImage extends StatelessWidget {
  final List<String> imageUrls;
  final Widget placeholder;

  const _CourseHeroNetworkImage({
    required this.imageUrls,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return _buildCandidate(0);
  }

  Widget _buildCandidate(int index) {
    if (index >= imageUrls.length) {
      return placeholder;
    }

    return CachedNetworkImage(
      imageUrl: imageUrls[index],
      fit: BoxFit.cover,
      placeholder: (_, __) => placeholder,
      errorWidget: (_, __, ___) => _buildCandidate(index + 1),
    );
  }
}

/// Stat Chip Widget
class _SourceDocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SourceDocumentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColorRoles.primary(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceDarkMuted
            : primary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColorRoles.textSecondary(isDark),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.greenSuccessBright,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Đã tích hợp vào khóa học',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenSuccessBright,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}

/// Unit Card Widget
class _UnitCard extends StatelessWidget {
  final UnitWithLessonsEntity unit;
  final int unitNumber;
  final String courseId;

  const _UnitCard({
    required this.unit,
    required this.unitNumber,
    required this.courseId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _parseColor(unit.backgroundColor, isDark),
          child: Text(
            '$unitNumber',
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          unit.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: unit.description != null
            ? Text(
                unit.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        children: unit.lessons.map((lesson) {
          return _LessonTile(lesson: lesson, courseId: courseId);
        }).toList(),
      ),
    );
  }

  Color _parseColor(String? colorString, bool isDark) {
    if (colorString == null || colorString.isEmpty) {
      return AppColorRoles.primary(isDark);
    }
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return AppColorRoles.primary(isDark);
    }
  }
}

/// Lesson Tile Widget
class _LessonTile extends StatelessWidget {
  final LessonInRoadmapEntity lesson;
  final String courseId;

  const _LessonTile({required this.lesson, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final isLocked = lesson.isLocked ?? false;
    final isCompleted = lesson.isCompleted ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: _getLessonIcon(lesson.lessonType, isLocked, isCompleted, isDark),
      title: Text(
        lesson.title,
        style: TextStyle(
          color: isLocked ? Colors.grey : null,
          decoration: isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // XP Badge
          Chip(
            avatar: const Icon(Icons.star, size: 16),
            label: Text('${lesson.xpReward}'),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          // Status Icon
          if (isCompleted)
            const Icon(Icons.check_circle, color: AppColors.greenSuccessBright)
          else if (isLocked)
            const Icon(Icons.lock, color: Colors.grey)
          else
            Icon(
              Icons.play_circle_outline,
              color: AppColorRoles.primary(isDark),
            ),
        ],
      ),
      onTap: isLocked
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LearningSessionScreen(
                    lessonId: lesson.id,
                    courseId: courseId,
                  ),
                ),
              );
            },
    );
  }

  Widget _getLessonIcon(
    String lessonType,
    bool isLocked,
    bool isCompleted,
    bool isDark,
  ) {
    IconData iconData;
    Color color;

    if (isLocked) {
      iconData = Icons.lock;
      color = Colors.grey;
    } else if (isCompleted) {
      iconData = Icons.check_circle;
      color = AppColors.greenSuccessBright;
    } else {
      switch (lessonType.toLowerCase()) {
        case 'vocabulary':
          iconData = Icons.school;
          color = AppColorRoles.primary(isDark);
          break;
        case 'grammar':
          iconData = Icons.menu_book;
          color = AppColors.orange;
          break;
        case 'listening':
          iconData = Icons.headphones;
          color = AppColors.purple;
          break;
        case 'speaking':
          iconData = Icons.mic;
          color = AppColors.errorBright;
          break;
        case 'reading':
          iconData = Icons.book;
          color = AppColors.teal;
          break;
        case 'writing':
          iconData = Icons.edit;
          color = Colors.indigo;
          break;
        case 'quiz':
          iconData = Icons.quiz;
          color = AppColors.warning;
          break;
        default:
          iconData = Icons.article;
          color = Colors.grey;
      }
    }

    return Icon(iconData, color: color);
  }
}
