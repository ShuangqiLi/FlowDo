import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_logo.dart';
import '../ui/password_field.dart';

/// 改密码。首次登录强制改，或从设置里主动改。
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

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
      if (widget.fromSettings) {
        ref.invalidate(meProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('密码改好了')),
          );
          Navigator.of(context).pop();
        }
      } else {
        ref.invalidate(meProvider);
      }
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
                      widget.fromSettings ? '改密码' : '先换个密码',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.fromSettings
                          ? '改完用新密码登录。'
                          : '这台 FlowDo 还在用初始密码。换成你自己的，之后就不再问了。',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    PasswordField(
                      controller: _current,
                      label: widget.fromSettings ? '现在的密码' : '初始密码',
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: _next,
                      label: '新密码',
                      autofillHint: AutofillHints.newPassword,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: _again,
                      label: '再输一次',
                      autofillHint: AutofillHints.newPassword,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy
                            ? '正在改…'
                            : widget.fromSettings
                                ? '改好'
                                : '改好，进去',
                      ),
                    ),
                    if (widget.fromSettings)
                      TextButton(
                        onPressed: _busy ? null : () => Navigator.of(context).pop(),
                        child: const Text('先不改'),
                      )
                    else
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
