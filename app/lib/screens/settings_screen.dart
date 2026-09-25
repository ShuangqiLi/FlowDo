import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

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

  Widget _sectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionTitle(context, '账号'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '连接'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '聚焦'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    await ref.read(apiProvider).updateMe(focusLimit: limit);
                    ref.invalidate(meProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('聚焦上限已更新')),
                      );
                    }
                  },
                  child: const Text('保存聚焦上限'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _sectionTitle(context, '归档'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  onChanged: (v) async {
                    await ref
                        .read(apiProvider)
                        .updateMe(showArchiveTab: v);
                    ref.invalidate(meProvider);
                  },
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
                    final deleteDays =
                        int.tryParse(_deleteDays.text.trim()) ?? 30;
                    await ref.read(apiProvider).updateMe(
                          archiveAfterDays: days,
                          deleteArchivedAfterDays: deleteDays,
                        );
                    ref.invalidate(meProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('归档习惯已记下')),
                      );
                    }
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
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => ref.read(authStateProvider.notifier).logout(),
          child: const Text('退出登录'),
        ),
      ],
    );
  }
}
