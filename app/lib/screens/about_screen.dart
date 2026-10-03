import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/about.dart';
import '../platform/open_url.dart';
import '../providers.dart';
import '../theme.dart';

/// 设置里的关于：当前版本，以及检查新版并更新。
class AboutUpdatePanel extends ConsumerStatefulWidget {
  const AboutUpdatePanel({super.key});

  @override
  ConsumerState<AboutUpdatePanel> createState() => _AboutUpdatePanelState();
}

class _AboutUpdatePanelState extends ConsumerState<AboutUpdatePanel> {
  AboutInfo? _info;
  String? _error;
  bool _updating = false;
  bool _checking = false;
  String? _target;
  Timer? _poll;
  DateTime? _pollStarted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final info = await ref.read(apiProvider).about();
      if (!mounted) {
        return;
      }
      final arrived = _target != null && info.version == _target;
      final failed = info.phase == 'failed';
      setState(() {
        _info = info;
        _error = null;
        if (arrived || failed) {
          _updating = false;
          _poll?.cancel();
        }
      });
    } on ApiException catch (error) {
      if (!mounted || _updating) {
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || _updating) {
        return;
      }
      setState(() => _error = '连不上服务，稍后再看');
    }
  }

  Future<void> _checkAndUpdate() async {
    if (_updating) {
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final info = await ref.read(apiProvider).about();
      if (!mounted) {
        return;
      }
      setState(() {
        _info = info;
        _checking = false;
      });
      if (info.updateAvailable && info.canUpdate) {
        await _update();
        return;
      }
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _checking = false;
        _error = '没能检查更新，稍后再试';
      });
    }
  }

  Future<void> _update() async {
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final target = await ref.read(apiProvider).startUpdate();
      if (!mounted) {
        return;
      }
      setState(() => _target = target);
      _pollStarted = DateTime.now();
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 2), (_) async {
        if (_pollStarted != null &&
            DateTime.now().difference(_pollStarted!) >
                const Duration(minutes: 3)) {
          _poll?.cancel();
          if (mounted) {
            setState(() {
              _updating = false;
              _error = '更新太久了。刷新看看版本，或在部署目录执行 docker compose ps';
            });
          }
          return;
        }
        await _load();
      });
      await _load();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _updating = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _updating = false;
        _error = '没能开始更新，稍后再试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final info = _info;
    final busy = _updating || _checking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          info == null ? '当前版本' : '当前版本 ${info.version}',
          key: const ValueKey('about-version'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            _status(info),
            key: const ValueKey('about-status'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
                ),
          ),
        ),
        if (_updating) ...[
          const SizedBox(height: AppSpacing.md),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton.tonalIcon(
          key: const ValueKey('about-update'),
          onPressed: busy ? null : _checkAndUpdate,
          icon: const Icon(Icons.system_update_alt_rounded),
          label: Text(
            _updating
                ? '正在更新'
                : _checking
                    ? '正在检查…'
                    : '检查新版并更新',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton.icon(
          key: const ValueKey('about-release-notes'),
          onPressed: () {
            final tag = info?.latest ?? info?.version;
            final url = tag == null
                ? 'https://github.com/ShuangqiLi/FlowDo/releases'
                : 'https://github.com/ShuangqiLi/FlowDo/releases/tag/v$tag';
            openExternalUrl(url);
          },
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('发行说明'),
        ),
      ],
    );
  }

  String _status(AboutInfo? info) {
    if (_error != null) {
      return _error!;
    }
    if (info == null) {
      return '正在看有没有新版本…';
    }
    if (_target != null && info.version == _target) {
      return '已经换上 $_target。';
    }
    if (_updating || info.phase == 'downloading' || info.phase == 'applying') {
      return info.message ?? '正在更新，网页会短时间打不开。';
    }
    if (info.phase == 'failed' && info.message != null) {
      return info.message!;
    }
    if (!info.reachable) {
      return '现在连不上 GitHub，查不了有没有新版本。当前是 ${info.version}。';
    }
    if (info.updateAvailable) {
      if (!info.canUpdate) {
        return '有新版本 ${info.latest}。这台部署没把 Docker 交给服务端，请在部署目录重新运行启动脚本。';
      }
      return '有新版本 ${info.latest}，点下面即可换上。数据库不会动。';
    }
    return '已经是最新的。';
  }
}
