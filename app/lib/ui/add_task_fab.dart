import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/api_client.dart';
import '../platform/microphone.dart';
import '../providers.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import '../utils/speech_text.dart';
import '../utils/voice_input_messages.dart';
import 'flowdo_page_route.dart';
import 'focus_dock.dart';

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

  /// 正式发布的只有网页端；本地调试跑桌面时，Windows / Linux 的识别插件
  /// 会把整个进程带崩，这些平台只留打字。
  static bool get voiceSupported {
    if (kIsWeb) {
      return true;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

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

  /// 语音没起来、已经切成打字了：这次松手不要把输入框关掉。
  bool _fellBackToTyping = false;

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
    _speech.cancel().catchError((_) {});
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
      _fellBackToTyping = false;
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

  /// 账号层面有没有开语音；还没拿到账号信息时按开着算。
  bool get _voiceEnabled => ref.read(voiceInputEnabledProvider);

  void _hintNoVoice() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(content: Text('这个平台还不能语音输入，松开手打字吧')),
      );
  }

  void _hintVoiceOff() {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('语音输入在设置里关着，松开手打字吧'),
          action: SnackBarAction(label: '去设置', onPressed: _openSettings),
        ),
      );
  }

  void _openSettings() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      FlowDoPageRoute(
        swipeFromLeftEdgeOnly: false,
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  /// 麦克风被拦、没网这类"说了也白说"的错误：提示怎么解决，同时把输入框切成打字。
  void _voiceFailed(String message, {bool offerSettings = false}) {
    if (!mounted) {
      return;
    }
    _speechSession++;
    _pulse.stop();
    _pulse.reset();
    setState(() {
      _isListening = false;
      _voiceSession = false;
      _holdingVoice = false;
      _fellBackToTyping = _composerOpen;
    });
    if (_composerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
        }
      });
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          action: offerSettings
              ? SnackBarAction(label: '去设置', onPressed: _openSettings)
              : null,
        ),
      );
  }

  void _onSpeechError(String rawError) {
    final message = voiceErrorMessage(
      rawError,
      secureContext: MicrophoneAccess.isSecureContext,
      origin: MicrophoneAccess.pageOrigin,
    );
    if (message == null) {
      // 松手时的 aborted 之类，不用打扰。
      if (mounted) {
        setState(() => _isListening = false);
      }
      return;
    }
    _voiceFailed(message, offerSettings: kIsWeb);
  }

  /// 网页端在真正开麦之前先看一眼权限；已经知道不行的就别让浏览器再报一次 not-allowed。
  bool _blockedByKnownMicState() {
    if (!kIsWeb) {
      return false;
    }
    final state = ref.read(micPermissionProvider);
    switch (state) {
      case MicPermissionState.denied:
      case MicPermissionState.insecureContext:
      case MicPermissionState.unsupported:
      case MicPermissionState.noDevice:
        _voiceFailed(
          micStateMessage(state!, origin: MicrophoneAccess.pageOrigin),
          offerSettings: true,
        );
        return true;
      case MicPermissionState.granted:
      case MicPermissionState.prompt:
      case MicPermissionState.unknown:
      case null:
        return false;
    }
  }

  Future<void> _startVoiceInput() async {
    if (!AddTaskFab.voiceSupported) {
      _hintNoVoice();
      await _closeComposer();
      return;
    }
    if (!_voiceEnabled) {
      _hintVoiceOff();
      await _closeComposer();
      return;
    }
    if (_blockedByKnownMicState()) {
      return;
    }

    final bool available;
    try {
      available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _isListening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          _onSpeechError(error.errorMsg);
        },
      );
    } catch (_) {
      _voiceFailed('语音输入没启动起来，先打字吧');
      return;
    }
    if (!available) {
      _voiceFailed(
        voiceErrorMessage(
              'not supported',
              secureContext: MicrophoneAccess.isSecureContext,
            ) ??
            '当前设备暂不支持语音输入',
      );
      return;
    }
    if (!_holdingVoice && !_voiceSession) {
      return;
    }

    final session = ++_speechSession;
    _speechPrefix = _controller.text.trim();
    String? chineseLocale;
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('zh')) {
          chineseLocale = locale.localeId;
          break;
        }
      }
    } catch (_) {
      // 拿不到语言列表就交给系统默认的那一个。
    }
    try {
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          localeId: chineseLocale,
          pauseFor: const Duration(seconds: 30),
        ),
        onResult: (result) {
          if (session != _speechSession) {
            return;
          }
          final spoken =
              stripTrailingPunctuation(result.recognizedWords.trim());
          final text =
              [_speechPrefix, spoken].where((part) => part.isNotEmpty).join(' ');
          _controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          setState(() {});
        },
      );
    } catch (_) {
      _voiceFailed('语音输入没启动起来，先打字吧');
    }
  }

  Future<void> _endVoiceInput() async {
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {
      // 停不下来也别挡着提交。
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

    if (_fellBackToTyping) {
      // 语音没起来，已经切成打字了，这次松手留着输入框让人接着打。
      _fellBackToTyping = false;
      return;
    }

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
    const navHeight = FocusDock.height + 4;
    final fabTopLeft = _liveFabTopLeft(screen, padding, navHeight);
    final scheme = Theme.of(context).colorScheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final animateFab = !_moved && !reduce;
    final voiceOn = AddTaskFab.voiceSupported && ref.watch(voiceInputEnabledProvider);

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
                  if (!AddTaskFab.voiceSupported) {
                    _hintNoVoice();
                    return;
                  }
                  if (!_voiceEnabled) {
                    _hintVoiceOff();
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
                message: _composerOpen
                    ? '关掉'
                    : voiceOn
                        ? '点按输入，长按说话，拖动贴边'
                        : '点按输入，拖动贴边',
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
