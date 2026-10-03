import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_logo.dart';
import '../ui/password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;
  bool _checking = true;
  bool _setup = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    try {
      final setup = await ref.read(apiProvider).needsPasswordSetup();
      if (!mounted) {
        return;
      }
      setState(() {
        _setup = setup;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _checking = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_setup && _password.text != _again.text) {
      setState(() => _error = '两次密码不一样');
      return;
    }
    if (_setup && _password.text.isEmpty) {
      setState(() => _error = '密码还没填呢');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_setup) {
        await ref.read(authStateProvider.notifier).setup(_password.text);
      } else {
        await ref.read(authStateProvider.notifier).login(_password.text);
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: FlowDoCard(
                      padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.center,
                            child: FlowDoLogo(size: 72),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '随随办办',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'FlowDo',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '无压力任务管理',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '随随办办，总会办完。',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Go with the flow, get it done.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_checking)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else ...[
                            PasswordField(
                              controller: _password,
                              label: _setup ? '设一个密码' : '密码',
                              anchorUsername: !_setup,
                              autofillHint: _setup
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                              onSubmitted: _setup ? null : (_) => _submit(),
                            ),
                            if (_setup) ...[
                              const SizedBox(height: 12),
                              PasswordField(
                                controller: _again,
                                label: '再输一次',
                                autofillHint: AutofillHints.newPassword,
                                onSubmitted: (_) => _submit(),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _error!,
                                style: TextStyle(color: scheme.error),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _busy ? null : _submit,
                              icon: _busy
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(_setup ? Icons.check : Icons.login),
                              label: Text(_setup ? '设好，进去' : '登录'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
