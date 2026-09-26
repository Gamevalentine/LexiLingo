import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lexilingo_app/core/theme/app_theme.dart';

/// Assistant-first home entry.
///
/// Keeps the original learning features intact while making the AI tutor the
/// clearest place to start. Guided actions can prefill the tutor input so the
/// learner immediately understands what the assistant can do.
class AssistantStartCard extends StatelessWidget {
  const AssistantStartCard({super.key});

  void _openAssistant(BuildContext context, {String? starterPrompt}) {
    Navigator.pushNamed(
      context,
      '/lexi',
      arguments: starterPrompt == null
          ? null
          : <String, dynamic>{'starterPrompt': starterPrompt},
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColorRoles.primary(isDark);
    final surface = Theme.of(context).colorScheme.surface;
    final secondaryText = AppColorRoles.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primary.withValues(alpha: isDark ? 0.48 : 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.06),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: isDark ? 0.16 : 0.10),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'home.assistantBadge'.tr(),
                          style: TextStyle(
                            color: primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'home.assistantHubTitle'.tr(),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        'home.assistantHubSubtitle'.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: secondaryText,
                              height: 1.45,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openAssistant(context),
                icon: const Icon(Icons.smart_toy_rounded),
                label: Text('home.assistantAskAi'.tr()),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'home.assistantChooseTask'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 560 ? 4 : 2;
                const gap = 10.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    _AssistantTask(
                      width: width,
                      icon: Icons.school_rounded,
                      label: 'home.assistantGrammar'.tr(),
                      onTap: () => _openAssistant(
                        context,
                        starterPrompt: 'home.assistantGrammarPrompt'.tr(),
                      ),
                    ),
                    _AssistantTask(
                      width: width,
                      icon: Icons.fact_check_rounded,
                      label: 'home.assistantCorrectSentence'.tr(),
                      onTap: () => _openAssistant(
                        context,
                        starterPrompt: 'home.assistantCorrectSentencePrompt'.tr(),
                      ),
                    ),
                    _AssistantTask(
                      width: width,
                      icon: Icons.forum_rounded,
                      label: 'home.assistantConversation'.tr(),
                      onTap: () => _openAssistant(
                        context,
                        starterPrompt: 'home.assistantConversationPrompt'.tr(),
                      ),
                    ),
                    _AssistantTask(
                      width: width,
                      icon: Icons.mic_rounded,
                      label: 'home.assistantPronunciation'.tr(),
                      onTap: () =>
                          Navigator.pushNamed(context, '/voice-practice'),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _AssistantLink(
                  icon: Icons.style_rounded,
                  label: 'home.assistantReviewVocab'.tr(),
                  onTap: () =>
                      Navigator.pushNamed(context, '/vocabulary/review'),
                ),
                _AssistantLink(
                  icon: Icons.menu_book_rounded,
                  label: 'home.assistantContinueCourse'.tr(),
                  onTap: () => Navigator.pushNamed(context, '/courses'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantTask extends StatelessWidget {
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AssistantTask({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppColorRoles.primary(isDark);

    return SizedBox(
      width: width,
      child: Material(
        color: primary.withValues(alpha: isDark ? 0.09 : 0.055),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
            child: Column(
              children: [
                Icon(icon, color: primary, size: 23),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AssistantLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
