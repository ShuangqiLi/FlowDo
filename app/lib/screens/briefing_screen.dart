import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../widgets/priority_selector.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(briefingProvider);
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: briefing.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                data.date,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                '可以先做这些',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.suggestedFocus.isEmpty)
                Text(
                  '暂时没什么特别推荐，去任务池随便挑一件吧。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                ...data.suggestedFocus.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: PriorityBadge(priority: t.priority),
                      title: Text(t.title),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                '正在聚焦',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.focusedTasks.isEmpty)
                Text(
                  '手头还空着，挑一件放进来吧。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                ...data.focusedTasks.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: PriorityBadge(priority: t.priority),
                      title: Text(t.title),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Text(
                '本周搞定了',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (data.completedThisWeek.isEmpty)
                Text(
                  '本周还没打卡，没关系，慢慢来。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                )
              else
                ...data.completedThisWeek.map(
                  (t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(t.title),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      _stat(context, '任务池', data.todoCount),
                      _stat(context, '聚焦', data.focusCount),
                      _stat(context, '完成', data.doneCount),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '今天搞定 ${data.completedToday.length} · 昨天搞定 ${data.completedYesterday.length}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
