import 'package:flutter/material.dart';

import '../theme.dart';

class QuickAddField extends StatelessWidget {
  const QuickAddField({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onVoiceStart,
    required this.onVoiceEnd,
    this.isListening = false,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onVoiceStart;
  final VoidCallback onVoiceEnd;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        hintText: isListening ? '正在听，松开就好' : '想到什么？先放进任务池',
        prefixIcon: const Icon(Icons.add_task_rounded),
        suffixIconConstraints: const BoxConstraints(minWidth: 96),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _HoldToTalkButton(
              isListening: isListening,
              onStart: onVoiceStart,
              onEnd: onVoiceEnd,
            ),
            IconButton.filledTonal(
              tooltip: '添加',
              onPressed: onSubmit,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
      onSubmitted: (_) => onSubmit(),
    );
  }
}

class _HoldToTalkButton extends StatelessWidget {
  const _HoldToTalkButton({
    required this.isListening,
    required this.onStart,
    required this.onEnd,
  });

  final bool isListening;
  final VoidCallback onStart;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: isListening ? '松开结束说话' : '按住说话',
      child: Tooltip(
        message: isListening ? '松开结束' : '按住说话',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => onStart(),
          onLongPressEnd: (_) => onEnd(),
          onLongPressCancel: onEnd,
          child: AnimatedContainer(
            duration: AppMotion.quick,
            curve: AppMotion.curve,
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? scheme.errorContainer : Colors.transparent,
            ),
            child: Icon(
              isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
              color: isListening
                  ? scheme.onErrorContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
