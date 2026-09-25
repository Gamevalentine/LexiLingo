import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:lexilingo_app/core/widgets/cefr_badge.dart';
import 'package:lexilingo_app/core/widgets/lottie_loading_widget.dart';
import 'package:provider/provider.dart';
import 'package:lexilingo_app/core/theme/app_theme.dart';
import '../../domain/entities/story.dart';
import '../providers/story_provider.dart';
import '../utils/topic_icon_resolver.dart';
import 'topic_chat_page.dart';

/// Story Selection Page - Modern Redesign
class StorySelectionPage extends StatefulWidget {
  const StorySelectionPage({super.key});

  @override
  State<StorySelectionPage> createState() => _StorySelectionPageState();
}

class _StorySelectionPageState extends State<StorySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DifficultyLevel? _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<StoryProvider>();
        provider.loadStories();
        provider.loadCategories();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = AppColorRoles.primary(isDark);

    if (kIsWeb) {
      return _buildGuestConversationHub(theme, isDark, accent);
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 86,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Consumer<StoryProvider>(
          builder: (context, provider, _) {
            final total = provider.stories.length;
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.forum_rounded,
                    color: Theme.of(context).colorScheme.surface,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'storySelection.pageTitle'.tr(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColorRoles.textPrimary(isDark),
                      ),
                    ),
                    Text(
                      'storySelection.topicsAvailableCount'.tr(
                        namedArgs: {'total': '$total'},
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.textMuted
                            : AppColors.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        actions: const [],
      ),
      body: Consumer<StoryProvider>(
        builder: (context, provider, child) {
          final filteredStories = provider.stories.where((s) {
            final matchesSearch =
                s.title.en.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                s.category.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesDifficulty =
                _selectedDifficulty == null ||
                s.difficultyLevel == _selectedDifficulty;
            return matchesSearch && matchesDifficulty;
          }).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildSearchBar(theme, isDark),
                  ),

                  // Filter Chips
                  _buildFilterChips(theme, isDark),

                  // Content
                  Expanded(
                    child: provider.isLoading && provider.stories.isEmpty
                        ? const Center(child: LottieLoadingWidget.medium())
                        : _buildStoryList(filteredStories, theme, isDark),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuestConversationHub(
    ThemeData theme,
    bool isDark,
    Color accent,
  ) {
    final topics = <({IconData icon, String title, String subtitle, String prompt})>[
      (
        icon: Icons.coffee_rounded,
        title: 'Gọi đồ ở quán cà phê',
        subtitle: 'Luyện gọi món, hỏi giá và phản hồi tự nhiên.',
        prompt:
            'Hãy đóng vai nhân viên quán cà phê và luyện hội thoại tiếng Anh với mình ở trình độ B1. Chỉ nói tiếng Anh, mỗi lượt ngắn và sửa lỗi sau khi mình trả lời.',
      ),
      (
        icon: Icons.flight_takeoff_rounded,
        title: 'Sân bay & du lịch',
        subtitle: 'Check-in, hỏi đường, hành lý và tình huống du lịch.',
        prompt:
            'Hãy đóng vai nhân viên sân bay và luyện hội thoại tiếng Anh với mình ở trình độ B1. Bắt đầu bằng một tình huống check-in tự nhiên và chỉ nói tiếng Anh.',
      ),
      (
        icon: Icons.work_rounded,
        title: 'Phỏng vấn xin việc',
        subtitle: 'Trả lời câu hỏi phỏng vấn và cải thiện cách diễn đạt.',
        prompt:
            'Hãy làm nhà tuyển dụng và phỏng vấn mình bằng tiếng Anh ở trình độ B1-B2. Hỏi từng câu một, sau mỗi câu trả lời hãy sửa lỗi ngắn gọn rồi hỏi tiếp.',
      ),
      (
        icon: Icons.people_alt_rounded,
        title: 'Giao tiếp hằng ngày',
        subtitle: 'Small talk, sở thích và những chủ đề đời thường.',
        prompt:
            'Hãy trò chuyện với mình bằng tiếng Anh như một người bạn. Chủ đề đời sống hằng ngày, trình độ B1, mỗi lượt một câu hỏi tự nhiên và sửa lỗi khi cần.',
      ),
      (
        icon: Icons.restaurant_rounded,
        title: 'Nhà hàng',
        subtitle: 'Đặt bàn, gọi món và xử lý tình huống tại nhà hàng.',
        prompt:
            'Hãy đóng vai phục vụ nhà hàng và luyện hội thoại tiếng Anh với mình ở trình độ B1. Bắt đầu từ lúc mình bước vào nhà hàng, chỉ nói tiếng Anh.',
      ),
      (
        icon: Icons.hotel_rounded,
        title: 'Khách sạn',
        subtitle: 'Đặt phòng, nhận phòng và yêu cầu hỗ trợ.',
        prompt:
            'Hãy đóng vai lễ tân khách sạn và luyện hội thoại tiếng Anh với mình ở trình độ B1. Bắt đầu bằng thủ tục check-in và chỉ nói tiếng Anh.',
      ),
    ];

    void openTopic(String prompt) {
      Navigator.of(context).pushNamed(
        '/lexi',
        arguments: <String, dynamic>{'starterPrompt': prompt},
      );
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      appBar: AppBar(
        toolbarHeight: 86,
        automaticallyImplyLeading: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.forum_rounded,
                color: theme.colorScheme.surface,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hội thoại',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColorRoles.textPrimary(isDark),
                  ),
                ),
                Text(
                  'Luyện tình huống thực tế với Trợ lý AI',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColorRoles.textSecondary(isDark),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: topics.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 430,
              mainAxisExtent: 190,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemBuilder: (context, index) {
              final topic = topics[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => openTopic(topic.prompt),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDarkMuted : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(topic.icon, color: accent),
                        ),
                        const Spacer(),
                        Text(
                          topic.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          topic.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColorRoles.textSecondary(isDark),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final accent = AppColorRoles.primary(isDark);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDarkMuted : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.backgroundDark.withValues(
              alpha: isDark ? 0.35 : 0.10,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(color: AppColorRoles.textPrimary(isDark)),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'storySelection.searchHint'.tr(),
          hintStyle: TextStyle(color: AppColorRoles.textMuted(isDark)),
          prefixIcon: Icon(
            Icons.search,
            color: isDark ? accent : theme.primaryColor,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(top: 0, bottom: 0, right: 16),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip(
            'storySelection.filterAll'.tr(),
            _selectedDifficulty == null,
            () {
              setState(() => _selectedDifficulty = null);
            },
            theme,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'storySelection.filterBeginner'.tr(),
            _selectedDifficulty == DifficultyLevel.A1 ||
                _selectedDifficulty == DifficultyLevel.A2,
            () {
              setState(() => _selectedDifficulty = DifficultyLevel.A1);
            },
            theme,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'storySelection.filterIntermediate'.tr(),
            _selectedDifficulty == DifficultyLevel.B1 ||
                _selectedDifficulty == DifficultyLevel.B2,
            () {
              setState(() => _selectedDifficulty = DifficultyLevel.B1);
            },
            theme,
            isDark,
          ),
          const SizedBox(width: 8),
          _buildChip(
            'storySelection.filterAdvanced'.tr(),
            _selectedDifficulty == DifficultyLevel.C1 ||
                _selectedDifficulty == DifficultyLevel.C2,
            () {
              setState(() => _selectedDifficulty = DifficultyLevel.C1);
            },
            theme,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    ThemeData theme,
    bool isDark,
  ) {
    final accent = AppColorRoles.primary(isDark);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accent
              : (isDark ? AppColors.surfaceDarkMuted : Colors.white),
          borderRadius: BorderRadius.circular(999),
          border: isSelected
              ? null
              : Border.all(
                  color: (isDark ? accent : theme.primaryColor).withValues(
                    alpha: 0.2,
                  ),
                ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark ? accent : theme.primaryColor).withValues(
                      alpha: 0.3,
                    ),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.slate900
                : AppColorRoles.textSecondary(isDark),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildStoryList(
    List<StoryListItem> stories,
    ThemeData theme,
    bool isDark,
  ) {
    if (stories.isEmpty) {
      return _buildEmptyState(isDark);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: stories.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'storySelection.popularScenariosTitle'.tr(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColorRoles.textPrimary(isDark),
                  ),
                ),
                Text(
                  'storySelection.seeAllLink'.tr(),
                  style: TextStyle(
                    color: isDark
                        ? AppColorRoles.primary(isDark)
                        : theme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        final story = stories[index - 1];
        return _TopicListItem(
          story: story,
          onTap: () => _handleTopicSelection(story),
          theme: theme,
          isDark: isDark,
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'storySelection.noTopicsFound'.tr(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColorRoles.textSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleTopicSelection(StoryListItem story) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TopicChatPage(story: story)),
    );
  }
}

class _TopicListItem extends StatelessWidget {
  final StoryListItem story;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;
  final bool isWarming;

  const _TopicListItem({
    required this.story,
    required this.onTap,
    required this.theme,
    required this.isDark,
    // ignore: unused_element_parameter
    this.isWarming = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDarkMuted : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  (isDark ? AppColorRoles.primary(isDark) : theme.primaryColor)
                      .withValues(alpha: isDark ? 0.20 : 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.backgroundDark.withValues(
                  alpha: isDark ? 0.25 : 0.08,
                ),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color:
                      (isDark
                              ? AppColorRoles.primary(isDark)
                              : theme.primaryColor)
                          .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  TopicIconResolver.forStory(story),
                  color: isDark
                      ? AppColorRoles.primary(isDark)
                      : theme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      story.title.en,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColorRoles.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CefrBadge(level: story.difficultyLevel.shortName),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColorRoles.textMuted(isDark),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${story.estimatedMinutes} mins',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColorRoles.textMuted(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isWarming)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: LottieLoadingWidget.tiny(),
                )
              else
                Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColorRoles.primary(isDark)
                      : theme.primaryColor,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
