import 'package:flutter/material.dart';

class QuickAddField extends StatelessWidget {
  const QuickAddField({
    super.key,
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: '想到什么？先放进任务池',
        prefixIcon: const Icon(Icons.add_task_rounded),
        suffixIcon: IconButton.filledTonal(
          tooltip: '添加',
          onPressed: onSubmit,
          icon: const Icon(Icons.arrow_upward_rounded),
        ),
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }
}
