import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _apiUrl = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiUrl.text = ref.read(apiProvider).baseUrl;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _apiUrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _register = !_register;
      _error = null;
      _confirmPassword.clear();
    });
  }

  Future<void> _submit() async {
    if (_register) {
      if (_password.text.length < 8) {
        setState(() => _error = '密码再长一点吧，至少 8 位');
        return;
      }
      if (_password.text != _confirmPassword.text) {
        setState(() => _error = '两次密码好像不太一样');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).setBaseUrl(_apiUrl.text);
      if (_register) {
        await ref.read(authStateProvider.notifier).register(
              _email.text.trim(),
              _password.text,
            );
      } else {
        await ref.read(authStateProvider.notifier).login(
              _email.text.trim(),
              _password.text,
            );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '连不上服务器，看看 API 地址对不对');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final obscuredStyle = AppText.obscuredStyle(
      Theme.of(context).textTheme.bodyLarge,
    );

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
                          TextField(
                            controller: _apiUrl,
                            decoration: const InputDecoration(
                              labelText: 'API 地址',
                              hintText: 'http://127.0.0.1:3000',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: '邮箱',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _password,
                            obscureText: true,
                            style: obscuredStyle,
                            decoration: InputDecoration(
                              labelText: _register ? '密码（至少 8 位）' : '密码',
                              prefixIcon: const Icon(Icons.lock_outline),
                            ),
                            onSubmitted: (_) {
                              if (!_register) {
                                _submit();
                              }
                            },
                          ),
                          AnimatedSwitcher(
                            duration: AppMotion.standard,
                            child: _register
                                ? Padding(
                                    key: const ValueKey('confirm-password'),
                                    padding: const EdgeInsets.only(top: 12),
                                    child: TextField(
                                      controller: _confirmPassword,
                                      obscureText: true,
                                      style: obscuredStyle,
                                      decoration: const InputDecoration(
                                        labelText: '确认密码',
                                        prefixIcon: Icon(Icons.lock_person_rounded),
                                      ),
                                      onSubmitted: (_) => _submit(),
                                    ),
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('no-confirm-password'),
                                  ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                          ],
                          const SizedBox(height: 20),
                          if (_register)
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _submit,
                              icon: _busy
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1),
                              label: const Text('注册'),
                            )
                          else
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
                                  : const Icon(Icons.login),
                              label: const Text('登录'),
                            ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _busy ? null : _toggleMode,
                            child: Text(
                              _register ? '已经有账号啦？去登录' : '还没有账号？来注册',
                            ),
                          ),
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
