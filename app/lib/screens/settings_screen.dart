import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _url = TextEditingController();
  final _days = TextEditingController();
  final _focusLimit = TextEditingController();
  final _deleteDays = TextEditingController();

  @override
  void initState() {
    super.initState();
    _url.text = ref.read(apiProvider).baseUrl;
  }

  @override
  void dispose() {
    _url.dispose();
    _days.dispose();
    _focusLimit.dispose();
    _deleteDays.dispose();
    super.dispose();
  }

  Future<bool> _saveMe({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    String? themeKey,
    String? successMessage,
  }) async {
    try {
      await ref.read(apiProvider).updateMe(
            archiveAfterDays: archiveAfterDays,
            focusLimit: focusLimit,
            deleteArchivedAfterDays: deleteArchivedAfterDays,
            showArchiveTab: showArchiveTab,
            themeKey: themeKey,
          );
      ref.invalidate(meProvider);
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
      return true;
    } on ApiException catch (e) {
      _showSaveError(e.message);
      return false;
    } catch (_) {
      _showSaveError('没记下，等会儿再试一次。');
      return false;
    }
  }

  void _showSaveError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final scheme = Theme.of(context).colorScheme;

    return ResponsiveContent(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const SectionHeader('账号'),
          FlowDoCard(
            child: me.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (user) {
                if (_days.text.isEmpty) {
                  _days.text = '${user.archiveAfterDays}';
                }
                if (_focusLimit.text.isEmpty) {
                  _focusLimit.text = '${user.focusLimit}';
                }
                if (_deleteDays.text.isEmpty) {
                  _deleteDays.text = '${user.deleteArchivedAfterDays}';
                }
                return Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        Icons.person_outline,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        user.email,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('外观', caption: '选一种舒服的颜色，跟着账号一起走。'),
          FlowDoCard(
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final theme in AppThemeKey.values)
                  _ThemeChoice(
                    theme: theme,
                    selected: me.value?.themeKey == theme.key,
                    onTap:
                        me.value?.themeKey == theme.key ? null : () => _saveMe(themeKey: theme.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('连接'),
          FlowDoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _url,
                  decoration: const InputDecoration(
                    labelText: 'API 地址',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    await ref.read(apiProvider).setBaseUrl(_url.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('地址已记住')),
                      );
                    }
                  },
                  child: const Text('保存地址'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('聚焦'),
          FlowDoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '一次抓太多容易手忙脚乱。到上限后，先搞定或先放回任务池再继续。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _focusLimit,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '同时最多盯几件',
                    prefixIcon: Icon(Icons.center_focus_strong_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    final limit = int.tryParse(_focusLimit.text.trim()) ?? 3;
                    await _saveMe(
                      focusLimit: limit,
                      successMessage: '聚焦上限已更新',
                    );
                  },
                  child: const Text('保存聚焦上限'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('归档'),
          FlowDoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '归档后只看不改，想清掉就删。到期也会自动打扫干净。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在导航里显示归档'),
                  subtitle: const Text('关掉后底部就只留任务池、聚焦、完成和设置'),
                  value: me.value?.showArchiveTab ?? true,
                  onChanged: (v) => _saveMe(showArchiveTab: v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '完成后几天收进归档',
                    prefixIcon: Icon(Icons.schedule),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deleteDays,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '归档后几天自动清掉',
                    prefixIcon: Icon(Icons.delete_sweep_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    final days = int.tryParse(_days.text.trim()) ?? 7;
                    final deleteDays = int.tryParse(_deleteDays.text.trim()) ?? 30;
                    await _saveMe(
                      archiveAfterDays: days,
                      deleteArchivedAfterDays: deleteDays,
                      successMessage: '归档习惯已记下',
                    );
                  },
                  child: const Text('保存归档设置'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () async {
                    final result = await ref.read(apiProvider).runArchive();
                    ref.invalidate(tasksProvider('DONE'));
                    ref.invalidate(tasksProvider('ARCHIVED'));
                    ref.invalidate(briefingProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '收进归档 ${result.archived} 条，清掉过期 ${result.deleted} 条',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('现在就收拾一下'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => ref.read(authStateProvider.notifier).logout(),
            child: const Text('退出登录'),
          ),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final AppThemeKey theme;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      label: '${theme.label}主题',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: AppMotion.standard,
          width: 132,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.7)
                : context.flowColors.softFill,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.preview,
                  borderRadius: BorderRadius.circular(AppRadii.small),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  theme.label,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              if (selected) Icon(Icons.check_rounded, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
