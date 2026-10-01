import 'package:flutter/material.dart';

import '../theme.dart';

/// 测试和非网页端用的密码框。网页端会换成真正的 HTML 输入框。
class PasswordField extends StatelessWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.autofillHint = AutofillHints.password,
    this.onSubmitted,
    this.anchorUsername = false,
  });

  final TextEditingController controller;
  final String label;
  final String autofillHint;
  final ValueChanged<String>? onSubmitted;

  /// 登录页为密码管理器留一个用户名锚点。这里不显示。
  final bool anchorUsername;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: true,
      autofillHints: [autofillHint],
      style: AppText.obscuredStyle(Theme.of(context).textTheme.bodyLarge),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
