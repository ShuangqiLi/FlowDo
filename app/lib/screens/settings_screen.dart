import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../platform/microphone.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/add_task_fab.dart';
import '../ui/flowdo_card.dart';
import '../utils/voice_input_messages.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _days = TextEditingController();
  final _focusLimit = TextEditingController();
  final _deleteDays = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (kIsWeb && AddTaskFab.voiceSupported) {
      // 进设置页刷一下麦克风状态，那行提示才是现在的情况。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(micPermissionProvider.notifier).refresh();
        }
      });
    }
  }

  @override
  void dispose() {
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
    bool? voiceInputEnabled,
    String? successMessage,
  }) async {
    try {
      await ref.read(apiProvider).updateMe(
            archiveAfterDays: archiveAfterDays,
            focusLimit: focusLimit,
            deleteArchivedAfterDays: deleteArchivedAfterDays,
            showArchiveTab: showArchiveTab,
            themeKey: themeKey,
            voiceInputEnabled: voiceInputEnabled,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ResponsiveContent(
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
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('外观', caption: '选一套顺眼的样子'),
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
          const SectionHeader('语音输入', caption: '长按加号直接说，松手就记下'),
          FlowDoCard(
            child: _VoiceInputSettings(
              enabled: me.value?.voiceInputEnabled ?? true,
              onChanged: (v) async {
                final ok = await _saveMe(voiceInputEnabled: v);
                if (ok && v && kIsWeb && AddTaskFab.voiceSupported) {
                  // 刚打开就顺手把权限要下来，别等到长按的时候再弹窗。
                  await ref.read(micPermissionProvider.notifier).request();
                }
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader('归档'),
          FlowDoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '归档后只看不改，想清掉就删。到期也会自动打扫干净。清理天数填 0，归档就永久留着。',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('在首页显示归档入口'),
                  subtitle: const Text('开着时左上角设置旁会出现归档；关掉后仍可自动归档'),
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
                    helperText: '填 0 表示永久保留',
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
      ),
    );
  }
}

/// 语音输入开关 + 浏览器麦克风现状。开关跟账号走，权限是浏览器对这个地址记的。
class _VoiceInputSettings extends ConsumerWidget {
  const _VoiceInputSettings({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final captionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
    final micState = ref.watch(micPermissionProvider);
    final showMic = kIsWeb && AddTaskFab.voiceSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('voice-input-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('长按加号说话'),
          subtitle: Text(
            enabled
                ? '开着时进入首页会先申请一次麦克风，之后长按加号就能直接说'
                : '关掉后不会申请麦克风，长按加号也只能打字',
          ),
          value: enabled,
          onChanged: onChanged,
        ),
        if (!AddTaskFab.voiceSupported) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('这个平台还不能语音输入，只在网页端可用。', style: captionStyle),
        ],
        if (showMic && enabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _micIcon(micState),
                size: 18,
                color: _micColor(micState, scheme),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  micState == null
                      ? '正在看浏览器给不给麦克风…'
                      : micStateMessage(
                          micState,
                          origin: MicrophoneAccess.pageOrigin,
                        ),
                  key: const ValueKey('mic-state-text'),
                  style: captionStyle,
                ),
              ),
            ],
          ),
          if (micState != null && micRequestUseful(micState)) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('request-mic'),
              onPressed: () =>
                  ref.read(micPermissionProvider.notifier).request(),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('现在申请麦克风权限'),
            ),
          ],
        ],
      ],
    );
  }

  IconData _micIcon(MicPermissionState? state) {
    return switch (state) {
      MicPermissionState.granted => Icons.mic_rounded,
      MicPermissionState.denied ||
      MicPermissionState.insecureContext ||
      MicPermissionState.unsupported ||
      MicPermissionState.noDevice =>
        Icons.mic_off_rounded,
      _ => Icons.mic_none_rounded,
    };
  }

  Color _micColor(MicPermissionState? state, ColorScheme scheme) {
    return switch (state) {
      MicPermissionState.granted => scheme.primary,
      MicPermissionState.denied ||
      MicPermissionState.insecureContext ||
      MicPermissionState.unsupported ||
      MicPermissionState.noDevice =>
        scheme.error,
      _ => scheme.onSurfaceVariant,
    };
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
