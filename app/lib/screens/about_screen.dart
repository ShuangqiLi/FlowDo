import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/about.dart';
import '../platform/open_url.dart';
import '../providers.dart';
import '../theme.dart';

/// 设置里的关于：当前版本和这一版的发行说明；点按钮才检查新版。
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
  bool _checked = false;
  String? _offer;
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
          if (arrived) {
            _offer = null;
            _checked = false;
          }
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

  bool get _readyToUpdate {
    final info = _info;
    return _offer != null && info != null && info.version != _offer;
  }

  Future<void> _check() async {
    if (_updating) {
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final info = await ref.read(apiProvider).about(check: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _info = info;
        _checking = false;
        _checked = true;
        _offer = info.updateAvailable ? info.latest : null;
      });
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
        if (_status(info).isNotEmpty)
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
          onPressed: busy ? null : (_readyToUpdate ? _update : _check),
          icon: Icon(
            _readyToUpdate
                ? Icons.download_rounded
                : Icons.system_update_alt_rounded,
          ),
          label: Text(
            _updating
                ? '正在更新'
                : _checking
                    ? '正在检查…'
                    : _readyToUpdate
                        ? '更新'
                        : '检查新版',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Semantics(
          key: const ValueKey('about-release-notes'),
          link: true,
          label: '发行说明',
          value: _notesUrl(info),
          button: true,
          child: ExcludeSemantics(
            child: TextButton.icon(
              onPressed: () => openExternalUrl(_notesUrl(info)),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('发行说明'),
            ),
          ),
        ),
      ],
    );
  }

  String _notesUrl(AboutInfo? info) {
    final tag = _offer ?? info?.version;
    if (tag == null) {
      return 'https://github.com/ShuangqiLi/FlowDo/releases';
    }
    return 'https://github.com/ShuangqiLi/FlowDo/releases/tag/v$tag';
  }

  String _status(AboutInfo? info) {
    if (_error != null) {
      return _error!;
    }
    if (info == null) {
      return '正在读取当前版本…';
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
    if (!_checked) {
      return '';
    }
    if (!info.reachable) {
      return '现在连不上 GitHub，查不了有没有新版本。当前是 ${info.version}。';
    }
    if (_offer != null) {
      if (!info.canUpdate) {
        return '有新版本 $_offer。这台部署没把 Docker 交给服务端，请在部署目录重新运行启动脚本。';
      }
      return '有新版本 $_offer。';
    }
    return '已经是最新的。';
  }
}
