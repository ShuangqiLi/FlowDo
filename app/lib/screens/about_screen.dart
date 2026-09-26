import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/about.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_logo.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  AboutInfo? _info;
  String? _error;
  bool _updating = false;
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
            DateTime.now().difference(_pollStarted!) > const Duration(minutes: 3)) {
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
    final status = _status(info);

    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ResponsiveContent(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            const SizedBox(height: AppSpacing.lg),
            const Center(child: FlowDoLogo(size: 72)),
            const SizedBox(height: AppSpacing.md),
            Text(
              '随随办办',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            Text(
              'FlowDo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FlowDoCard(
              child: Column(
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
                      status,
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
                  if (info != null && info.updateAvailable && info.canUpdate) ...[
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      key: const ValueKey('about-update'),
                      onPressed: _updating ? null : _update,
                      icon: const Icon(Icons.system_update_alt_rounded),
                      label: Text(_updating ? '正在更新' : '更新到 ${info.latest}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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
      return '有新版本 ${info.latest}，可以在这里换上。数据库不会动。';
    }
    return '已经是最新的。';
  }
}
