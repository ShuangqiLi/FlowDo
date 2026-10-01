import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_logo.dart';

/// 第一次用默认密码登录后，必须先换掉密码才能进首页。
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text.isEmpty) {
      setState(() => _error = '新密码还没填呢');
      return;
    }
    if (_next.text != _again.text) {
      setState(() => _error = '两次新密码不一样');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      ref.invalidate(meProvider);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = '连不上服务，稍后再试一次');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final obscured = AppText.obscuredStyle(Theme.of(context).textTheme.bodyLarge);

    return Scaffold(
      backgroundColor: context.flowColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FlowDoCard(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: Alignment.center,
                      child: FlowDoLogo(size: 64),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      '先换个密码',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '这台 FlowDo 还在用初始密码。换成你自己的，之后就不再问了。',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _current,
                      obscureText: true,
                      style: obscured,
                      autofillHints: const [AutofillHints.password],
                      decoration: const InputDecoration(
                        labelText: '初始密码',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _next,
                      obscureText: true,
                      style: obscured,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: const InputDecoration(
                        labelText: '新密码',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _again,
                      obscureText: true,
                      style: obscured,
                      decoration: const InputDecoration(
                        labelText: '再输一次',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? '正在改…' : '改好，进去'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => ref.read(authStateProvider.notifier).logout(),
                      child: const Text('先退出'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
