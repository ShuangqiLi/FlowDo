import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/api_client.dart';
import '../providers.dart';
import '../theme.dart';
import '../utils/speech_text.dart';

/// 可拖动的加号：贴边吸附，位置按账号记在本地；点按文字，长按语音。
class AddTaskFab extends ConsumerStatefulWidget {
  const AddTaskFab({
    super.key,
    this.visible = true,
  });

  final bool visible;

  static const double size = 56;
  static const double margin = 16;
  static const String prefsPrefix = 'fabPos:';

  @override
  ConsumerState<AddTaskFab> createState() => _AddTaskFabState();
}

class _AddTaskFabState extends ConsumerState<AddTaskFab>
    with TickerProviderStateMixin {
  static const _dragSlop = 10.0;
  static const _holdForVoice = Duration(milliseconds: 320);

  /// 贴左边还是右边。
  bool _onLeft = false;

  /// 竖直位置：0 贴顶可用区，1 贴底可用区。
  double _y = 0.82;

  Offset? _finger;
  Offset? _origin;
  bool _moved = false;
  bool _holdingVoice = false;
  bool _composerOpen = false;
  bool _voiceSession = false;
  bool _isListening = false;
  bool _submitting = false;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _speech = SpeechToText();
  String _speechPrefix = '';
  int _speechSession = 0;
  String? _loadedForUser;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _pulse.dispose();
    _speech.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _prefsKey(String userId) => '${AddTaskFab.prefsPrefix}$userId';

  void _loadPosition(String userId) {
    if (_loadedForUser == userId) {
      return;
    }
    _loadedForUser = userId;
    final raw = ref.read(prefsProvider).getString(_prefsKey(userId));
    if (raw == null || raw.isEmpty) {
      return;
    }
    final parts = raw.split(':');
    if (parts.length != 2) {
      return;
    }
    final y = double.tryParse(parts[1]);
    if (y == null) {
      return;
    }
    setState(() {
      _onLeft = parts[0] == 'left';
      _y = y.clamp(0.0, 1.0);
    });
  }

  Future<void> _savePosition(String userId) async {
    await ref.read(prefsProvider).setString(
          _prefsKey(userId),
          '${_onLeft ? 'left' : 'right'}:${_y.toStringAsFixed(4)}',
        );
  }

  Rect _fabBounds(Size screen, EdgeInsets padding, double navHeight) {
    final top = padding.top + kToolbarHeight + AddTaskFab.margin;
    final bottom =
        screen.height - padding.bottom - navHeight - AddTaskFab.margin;
    final minTop = top;
    final maxTop = mathMax(minTop, bottom - AddTaskFab.size);
    final left = _onLeft
        ? padding.left + AddTaskFab.margin
        : screen.width - padding.right - AddTaskFab.margin - AddTaskFab.size;
    final topPos = minTop + (maxTop - minTop) * _y;
    return Rect.fromLTWH(left, topPos, AddTaskFab.size, AddTaskFab.size);
  }

  double mathMax(double a, double b) => a > b ? a : b;

  Offset _liveFabTopLeft(Size screen, EdgeInsets padding, double navHeight) {
    if (_finger != null && _origin != null && _moved) {
      final dx = (_finger!.dx - _origin!.dx);
      final dy = (_finger!.dy - _origin!.dy);
      final base = _fabBounds(screen, padding, navHeight).topLeft;
      final raw = base.translate(dx, dy);
      return Offset(
        raw.dx.clamp(
          padding.left + 4,
          screen.width - padding.right - AddTaskFab.size - 4,
        ),
        raw.dy.clamp(
          padding.top + 4,
          screen.height - padding.bottom - navHeight - AddTaskFab.size - 4,
        ),
      );
    }
    return _fabBounds(screen, padding, navHeight).topLeft;
  }

  void _snapFrom(Offset topLeft, Size screen, EdgeInsets padding, double navHeight) {
    final centerX = topLeft.dx + AddTaskFab.size / 2;
    final onLeft = centerX < screen.width / 2;
    final top = padding.top + kToolbarHeight + AddTaskFab.margin;
    final bottom =
        screen.height - padding.bottom - navHeight - AddTaskFab.margin;
    final minTop = top;
    final maxTop = mathMax(minTop, bottom - AddTaskFab.size);
    final y = maxTop <= minTop
        ? 1.0
        : ((topLeft.dy - minTop) / (maxTop - minTop)).clamp(0.0, 1.0);
    setState(() {
      _onLeft = onLeft;
      _y = y;
      _finger = null;
      _origin = null;
      _moved = false;
    });
    final userId = ref.read(meProvider).value?.id;
    if (userId != null) {
      _savePosition(userId);
    }
  }

  void _openComposer({required bool voice}) {
    setState(() {
      _composerOpen = true;
      _voiceSession = voice;
    });
    if (voice) {
      _pulse.repeat(reverse: true);
      _startVoiceInput();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
        }
      });
    }
  }

  Future<void> _closeComposer() async {
    await _endVoiceInput();
    _pulse.stop();
    _pulse.reset();
    _speechSession++;
    if (!mounted) {
      return;
    }
    setState(() {
      _composerOpen = false;
      _voiceSession = false;
      _isListening = false;
      _holdingVoice = false;
      _controller.clear();
    });
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _submitting) {
      return;
    }
    _submitting = true;
    await _endVoiceInput();
    _speechSession++;
    _speechPrefix = '';
    try {
      await ref.read(apiProvider).createTask(
            title: title,
            priority: 'MEDIUM',
          );
      ref.invalidate(tasksProvider('TODO'));
      ref.invalidate(briefingProvider);
      ref.read(homeTabProvider.notifier).setIndex(0);
      _submitting = false;
      await _closeComposer();
    } on ApiException catch (e) {
      _submitting = false;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _startVoiceInput() async {
    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        setState(() => _isListening = status == 'listening');
      },
      onError: (error) {
        if (!mounted) return;
        setState(() => _isListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('语音输入没听清：${error.errorMsg}')),
        );
      },
    );
    if (!available) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备暂不支持语音输入')),
      );
      await _closeComposer();
      return;
    }
    if (!_holdingVoice && !_voiceSession) {
      return;
    }

    final session = ++_speechSession;
    _speechPrefix = _controller.text.trim();
    final locales = await _speech.locales();
    String? chineseLocale;
    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith('zh')) {
        chineseLocale = locale.localeId;
        break;
      }
    }
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: chineseLocale,
        pauseFor: const Duration(seconds: 30),
      ),
      onResult: (result) {
        if (session != _speechSession) {
          return;
        }
        final spoken = stripTrailingPunctuation(result.recognizedWords.trim());
        final text =
            [_speechPrefix, spoken].where((part) => part.isNotEmpty).join(' ');
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        setState(() {});
      },
    );
  }

  Future<void> _endVoiceInput() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _onPointerUp(
    Offset position,
    Size screen,
    EdgeInsets padding,
    double navHeight,
  ) async {
    final wasMoved = _moved;
    final wasHoldingVoice = _holdingVoice;
    final topLeft = _liveFabTopLeft(screen, padding, navHeight);

    if (wasMoved) {
      _snapFrom(topLeft, screen, padding, navHeight);
      return;
    }

    setState(() {
      _finger = null;
      _origin = null;
      _moved = false;
      _holdingVoice = false;
    });

    if (wasHoldingVoice) {
      await _endVoiceInput();
      _pulse.stop();
      _pulse.reset();
      if (_controller.text.trim().isNotEmpty) {
        await _submit();
      } else {
        await _closeComposer();
      }
      return;
    }

    // 短按 → 文字输入
    if (!_composerOpen) {
      _openComposer(voice: false);
    } else if (!_voiceSession) {
      await _closeComposer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    final userId = ref.watch(meProvider).value?.id;
    if (userId != null && _loadedForUser != userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadPosition(userId);
        }
      });
    }

    final media = MediaQuery.of(context);
    final screen = media.size;
    final padding = media.padding;
    const navHeight = 122.0;
    final fabTopLeft = _liveFabTopLeft(screen, padding, navHeight);
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final animateFab = !_moved && !reduce;

    return SizedBox.expand(
      child: Stack(
        children: [
          if (_composerOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeComposer,
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
          if (_composerOpen)
            _ComposerBubble(
              fabTopLeft: fabTopLeft,
              onLeft: _onLeft ||
                  (_moved &&
                      fabTopLeft.dx + AddTaskFab.size / 2 < screen.width / 2),
              screen: screen,
              padding: padding,
              listening: _isListening || _voiceSession,
              pulse: _pulse,
              reduceMotion: reduce,
              child: _ComposerField(
                controller: _controller,
                focusNode: _focus,
                listening: _isListening || _voiceSession,
                onSubmit: _submit,
              ),
            ),
          AnimatedPositioned(
            duration: animateFab ? AppMotion.standard : Duration.zero,
            curve: AppMotion.curve,
            left: fabTopLeft.dx,
            top: fabTopLeft.dy,
            child: Listener(
              onPointerDown: (e) {
                _origin = e.position;
                _finger = e.position;
                _moved = false;
                Future<void>.delayed(_holdForVoice, () {
                  if (!mounted || _moved || _origin == null) {
                    return;
                  }
                  _holdingVoice = true;
                  _openComposer(voice: true);
                });
              },
              onPointerMove: (e) {
                if (_origin == null) {
                  return;
                }
                _finger = e.position;
                final delta = e.position - _origin!;
                if (!_moved && delta.distance > _dragSlop) {
                  setState(() => _moved = true);
                  if (_holdingVoice || _voiceSession) {
                    _holdingVoice = false;
                    _closeComposer();
                  }
                } else if (_moved) {
                  setState(() {});
                }
              },
              onPointerUp: (e) => _onPointerUp(
                e.position,
                screen,
                padding,
                navHeight,
              ),
              onPointerCancel: (_) {
                if (_moved && _origin != null && _finger != null) {
                  _snapFrom(
                    _liveFabTopLeft(screen, padding, navHeight),
                    screen,
                    padding,
                    navHeight,
                  );
                } else {
                  setState(() {
                    _finger = null;
                    _origin = null;
                    _moved = false;
                    _holdingVoice = false;
                  });
                  if (_voiceSession) {
                    _closeComposer();
                  }
                }
              },
              child: Tooltip(
                message: _composerOpen ? '关掉' : '点按输入，长按说话，拖动贴边',
                child: Material(
                  key: const ValueKey('add-task-fab'),
                  elevation: _moved ? 10 : 6,
                  shadowColor: scheme.shadow.withValues(alpha: 0.28),
                  color: scheme.primaryContainer,
                  shape: const CircleBorder(),
                  child: SizedBox(
                    width: AddTaskFab.size,
                    height: AddTaskFab.size,
                    child: Icon(
                      _isListening || _voiceSession
                          ? Icons.mic_rounded
                          : Icons.add_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerBubble extends StatelessWidget {
  const _ComposerBubble({
    required this.fabTopLeft,
    required this.onLeft,
    required this.screen,
    required this.padding,
    required this.listening,
    required this.pulse,
    required this.reduceMotion,
    required this.child,
  });

  final Offset fabTopLeft;
  final bool onLeft;
  final Size screen;
  final EdgeInsets padding;
  final bool listening;
  final AnimationController pulse;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const gap = 12.0;
    const maxWidth = 320.0;
    final width = (screen.width - padding.horizontal - AddTaskFab.size - gap * 2)
        .clamp(200.0, maxWidth);

    double left;
    if (onLeft) {
      left = fabTopLeft.dx + AddTaskFab.size + gap;
      if (left + width > screen.width - padding.right - 8) {
        left = screen.width - padding.right - 8 - width;
      }
    } else {
      left = fabTopLeft.dx - gap - width;
      if (left < padding.left + 8) {
        left = padding.left + 8;
      }
    }

    // 优先贴在 FAB 垂直中线；不够就夹进安全区。
    var top = fabTopLeft.dy + (AddTaskFab.size - 56) / 2;
    top = top.clamp(
      padding.top + kToolbarHeight + 8,
      screen.height - padding.bottom - 100,
    );

    final glow = listening && !reduceMotion
        ? Tween<double>(begin: 0.55, end: 1.0).animate(
            CurvedAnimation(parent: pulse, curve: Curves.easeInOut),
          )
        : const AlwaysStoppedAnimation(1.0);

    return AnimatedPositioned(
      duration: reduceMotion ? Duration.zero : AppMotion.standard,
      curve: AppMotion.curve,
      left: left,
      top: top,
      width: width,
      child: AnimatedBuilder(
        animation: glow,
        builder: (context, _) {
          final scale = listening && !reduceMotion
              ? 0.98 + 0.04 * glow.value
              : 1.0;
          return Transform.scale(
            scale: scale,
            alignment: onLeft ? Alignment.centerLeft : Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.large),
                  border: Border.all(
                    color: listening
                        ? scheme.primary
                            .withValues(alpha: 0.45 * glow.value)
                        : scheme.outlineVariant,
                    width: listening ? 1.6 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComposerField extends StatelessWidget {
  const _ComposerField({
    required this.controller,
    required this.focusNode,
    required this.listening,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool listening;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        if (listening) ...[
          Icon(Icons.mic_rounded, color: scheme.primary),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: !listening,
            readOnly: listening,
            textInputAction: TextInputAction.done,
            style: Theme.of(context).textTheme.bodyLarge,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintText: listening ? '正在听，松开就好' : '想到什么？先放进任务池',
              hintStyle: TextStyle(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              contentPadding: EdgeInsets.zero,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
        ),
        if (!listening)
          IconButton.filledTonal(
            tooltip: '添加',
            onPressed: onSubmit,
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
      ],
    );
  }
}
