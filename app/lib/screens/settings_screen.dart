import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../platform/microphone.dart';
import '../providers.dart';
import '../theme.dart';
import '../ui/add_task_fab.dart';
import '../ui/flowdo_card.dart';
import '../ui/flowdo_page_route.dart';
import '../utils/voice_input_messages.dart';
import 'about_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// 嵌在首页底栏页时不自带 AppBar。
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _days = TextEditingController();
  final _focusLimit = TextEditingController();
  final _deleteDays = TextEditingController();
  final _focusLimitFocus = FocusNode();
  final _daysFocus = FocusNode();
  final _deleteDaysFocus = FocusNode();

  var _filled = false;
  var _saving = false;
  var _showSaved = false;
  Timer? _savedHide;
  Timer? _focusDebounce;
  Timer? _archiveDebounce;

  @override
  void initState() {
    super.initState();
    if (kIsWeb && AddTaskFab.voiceSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(micPermissionProvider.notifier).refresh();
        }
      });
    }
    _focusLimit.addListener(_scheduleFocusSave);
    _days.addListener(_scheduleArchiveSave);
    _deleteDays.addListener(_scheduleArchiveSave);
    _focusLimitFocus.addListener(() {
      if (!_focusLimitFocus.hasFocus) {
        _flushFocusSave();
      }
    });
    _daysFocus.addListener(() {
      if (!_daysFocus.hasFocus) {
        _flushArchiveSave();
      }
    });
    _deleteDaysFocus.addListener(() {
      if (!_deleteDaysFocus.hasFocus) {
        _flushArchiveSave();
      }
    });
  }

  void _fillFromMe() {
    final user = ref.read(meProvider).value;
    if (user == null) {
      return;
    }
    if (!_filled) {
      _filled = true;
      _days.text = '${user.archiveAfterDays}';
      _focusLimit.text = '${user.focusLimit}';
      _deleteDays.text = '${user.deleteArchivedAfterDays}';
      return;
    }
    if (!_focusLimitFocus.hasFocus) {
      final next = '${user.focusLimit}';
      if (_focusLimit.text != next) {
        _focusLimit.text = next;
      }
    }
    if (!_daysFocus.hasFocus) {
      final next = '${user.archiveAfterDays}';
      if (_days.text != next) {
        _days.text = next;
      }
    }
    if (!_deleteDaysFocus.hasFocus) {
      final next = '${user.deleteArchivedAfterDays}';
      if (_deleteDays.text != next) {
        _deleteDays.text = next;
      }
    }
  }

  @override
  void dispose() {
    _savedHide?.cancel();
    _focusDebounce?.cancel();
    _archiveDebounce?.cancel();
    _focusLimit.removeListener(_scheduleFocusSave);
    _days.removeListener(_scheduleArchiveSave);
    _deleteDays.removeListener(_scheduleArchiveSave);
    _days.dispose();
    _focusLimit.dispose();
    _deleteDays.dispose();
    _focusLimitFocus.dispose();
    _daysFocus.dispose();
    _deleteDaysFocus.dispose();
    super.dispose();
  }

  void _scheduleFocusSave() {
    if (!_filled) {
      return;
    }
    _focusDebounce?.cancel();
    _focusDebounce = Timer(const Duration(milliseconds: 450), _flushFocusSave);
  }

  void _scheduleArchiveSave() {
    if (!_filled) {
      return;
    }
    _archiveDebounce?.cancel();
    _archiveDebounce =
        Timer(const Duration(milliseconds: 450), _flushArchiveSave);
  }

  Future<void> _flushFocusSave() async {
    _focusDebounce?.cancel();
    final me = ref.read(meProvider).value;
    final limit = int.tryParse(_focusLimit.text.trim());
    if (me == null || limit == null || limit < 1 || limit > 99) {
      return;
    }
    if (limit == me.focusLimit) {
      return;
    }
    await _saveMe(focusLimit: limit);
  }

  Future<void> _flushArchiveSave() async {
    _archiveDebounce?.cancel();
    final me = ref.read(meProvider).value;
    final days = int.tryParse(_days.text.trim());
    final deleteDays = int.tryParse(_deleteDays.text.trim());
    if (me == null || days == null || deleteDays == null) {
      return;
    }
    if (days < 0 || deleteDays < 0 || days > 3650 || deleteDays > 3650) {
      return;
    }
    if (days == me.archiveAfterDays &&
        deleteDays == me.deleteArchivedAfterDays) {
      return;
    }
    await _saveMe(
      archiveAfterDays: days,
      deleteArchivedAfterDays: deleteDays,
    );
  }

  Future<bool> _saveMe({
    int? archiveAfterDays,
    int? focusLimit,
    int? deleteArchivedAfterDays,
    bool? showArchiveTab,
    bool? showRecurringReminders,
    String? themeKey,
    bool? voiceInputEnabled,
  }) async {
    if (_saving) {
      // 串行一点，避免连点开关撞车；数值防抖后通常不会叠。
    }
    setState(() {
      _saving = true;
      _showSaved = false;
    });
    try {
      await ref.read(meProvider.notifier).save(
            archiveAfterDays: archiveAfterDays,
            focusLimit: focusLimit,
            deleteArchivedAfterDays: deleteArchivedAfterDays,
            showArchiveTab: showArchiveTab,
            showRecurringReminders: showRecurringReminders,
            themeKey: themeKey,
            voiceInputEnabled: voiceInputEnabled,
          );
      if (!mounted) {
        return true;
      }
      setState(() {
        _saving = false;
        _showSaved = true;
      });
      _savedHide?.cancel();
      _savedHide = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() => _showSaved = false);
        }
      });
      return true;
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showSaveError(e.message);
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
      }
      _showSaveError('没记下，等会儿再试一次。');
      return false;
    }
  }

  void _showSaveError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    final scheme = Theme.of(context).colorScheme;
    ref.listen(meProvider, (prev, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fillFromMe();
        }
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fillFromMe();
      }
    });

    final body = ResponsiveContent(
      child: RefreshIndicator(
        onRefresh: () => ref.read(lazySyncProvider.notifier).pull(),
        child: ListView(
          physics: refreshScrollPhysics,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            _SaveStatusBar(saving: _saving, showSaved: _showSaved),
            const SectionHeader('外观', caption: '只影响现在这个任务空间'),
            FlowDoCard(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: _ThemeMenu(
                selected: AppThemeKey.fromKey(me.value?.themeKey),
                onSelected: (theme) => _saveMe(themeKey: theme.key),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('聚焦', caption: '当前任务空间 · 改完自动保存'),
            FlowDoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '一次抓太多容易手忙脚乱。到上限后，先完成或先放回任务池再继续。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _focusLimit,
                    focusNode: _focusLimitFocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _flushFocusSave,
                    decoration: const InputDecoration(
                      labelText: '同时最多盯几件',
                      prefixIcon: Icon(Icons.center_focus_strong_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('提醒', caption: '当前任务空间 · 改完自动保存'),
            FlowDoCard(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                title: const Text('在任务池显示循环提醒'),
                subtitle: const Text('关掉后仍会到点提醒，只是不列在任务池里'),
                value: me.value?.showRecurringReminders ?? true,
                onChanged: (v) => _saveMe(showRecurringReminders: v),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('归档', caption: '当前任务空间 · 改完自动保存'),
            FlowDoCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.xs,
                    ),
                    title: const Text('在底栏显示归档'),
                    subtitle: const Text('关掉后仍会按天数自动归档'),
                    value: me.value?.showArchiveTab ?? false,
                    onChanged: (v) => _saveMe(showArchiveTab: v),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '归档后只看不改。清理天数填 0，归档就永久留着。',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _days,
                          focusNode: _daysFocus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          textInputAction: TextInputAction.next,
                          onEditingComplete: () {
                            _flushArchiveSave();
                            _deleteDaysFocus.requestFocus();
                          },
                          decoration: const InputDecoration(
                            labelText: '完成后几天收进归档',
                            prefixIcon: Icon(Icons.schedule_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          controller: _deleteDays,
                          focusNode: _deleteDaysFocus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          textInputAction: TextInputAction.done,
                          onEditingComplete: _flushArchiveSave,
                          decoration: const InputDecoration(
                            labelText: '归档后几天自动清掉',
                            helperText: '填 0 表示永久保留',
                            prefixIcon: Icon(Icons.delete_sweep_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('语音输入', caption: '全局 · 长按加号直接说，松手就记下'),
            FlowDoCard(
              child: _VoiceInputSettings(
                enabled: me.value?.voiceInputEnabled ?? true,
                onChanged: (v) async {
                  final ok = await _saveMe(voiceInputEnabled: v);
                  if (ok && v && kIsWeb && AddTaskFab.voiceSupported) {
                    await ref.read(micPermissionProvider.notifier).request();
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('关于', caption: '全局'),
            const FlowDoCard(child: AboutUpdatePanel()),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    FlowDoPageRoute(
                      builder: (_) =>
                          const ChangePasswordScreen(fromSettings: true),
                    ),
                  );
                },
                child: const Text('修改密码'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  disabledBackgroundColor:
                      scheme.error.withValues(alpha: 0.38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.control),
                  ),
                ),
                onPressed: () => ref.read(authStateProvider.notifier).logout(),
                child: const Text('退出登录'),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.embedded) {
      return ColoredBox(
        color: context.flowColors.canvas,
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: body,
    );
  }
}

class _SaveStatusBar extends StatelessWidget {
  const _SaveStatusBar({
    required this.saving,
    required this.showSaved,
  });

  final bool saving;
  final bool showSaved;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = saving
        ? '正在保存…'
        : showSaved
            ? '已保存'
            : null;
    return AnimatedSize(
      duration: AppMotion.quick,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: label == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    saving ? Icons.sync_rounded : Icons.check_circle_rounded,
                    size: 16,
                    color: saving ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: saving
                              ? scheme.onSurfaceVariant
                              : scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// 语音输入开关 + 浏览器麦克风现状。开关存在服务端设置里，权限是浏览器对这个地址记的。
class _VoiceInputSettings extends ConsumerWidget {
  const _VoiceInputSettings({
    required this.enabled,
    required this.onChanged,
  });

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final captionStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        );
    final micState = ref.watch(micPermissionProvider);
    final showMic = kIsWeb && AddTaskFab.voiceSupported;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('voice-input-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('长按加号说话'),
          subtitle: Text(
            enabled
                ? '开着时进入首页会先申请一次麦克风，之后长按加号就能直接说'
                : '关掉后不会申请麦克风，长按加号也只能打字',
          ),
          value: enabled,
          onChanged: onChanged,
        ),
        if (!AddTaskFab.voiceSupported) ...[
          const SizedBox(height: AppSpacing.xs),
          Text('这个平台还不能语音输入，只在网页端可用。', style: captionStyle),
        ],
        if (showMic && enabled) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _micIcon(micState),
                size: 18,
                color: _micColor(micState, scheme),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  micState == null
                      ? '正在看浏览器给不给麦克风…'
                      : micStateMessage(
                          micState,
                          origin: MicrophoneAccess.pageOrigin,
                        ),
                  key: const ValueKey('mic-state-text'),
                  style: captionStyle,
                ),
              ),
            ],
          ),
          if (micState != null && micRequestUseful(micState)) ...[
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              key: const ValueKey('request-mic'),
              onPressed: () =>
                  ref.read(micPermissionProvider.notifier).request(),
              icon: const Icon(Icons.mic_rounded),
              label: const Text('现在申请麦克风权限'),
            ),
          ],
        ],
      ],
    );
  }

  IconData _micIcon(MicPermissionState? state) {
    return switch (state) {
      MicPermissionState.granted => Icons.mic_rounded,
      MicPermissionState.denied ||
      MicPermissionState.insecureContext ||
      MicPermissionState.unsupported ||
      MicPermissionState.noDevice =>
        Icons.mic_off_rounded,
      _ => Icons.mic_none_rounded,
    };
  }

  Color _micColor(MicPermissionState? state, ColorScheme scheme) {
    return switch (state) {
      MicPermissionState.granted => scheme.primary,
      MicPermissionState.denied ||
      MicPermissionState.insecureContext ||
      MicPermissionState.unsupported ||
      MicPermissionState.noDevice =>
        scheme.error,
      _ => scheme.onSurfaceVariant,
    };
  }
}

class _ThemeMenu extends StatelessWidget {
  const _ThemeMenu({
    required this.selected,
    required this.onSelected,
  });

  final AppThemeKey selected;
  final ValueChanged<AppThemeKey> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
        ),
      ),
      menuChildren: [
        for (final theme in AppThemeKey.values)
          MenuItemButton(
            onPressed: () {
              if (theme != selected) {
                onSelected(theme);
              }
            },
            style: const ButtonStyle(
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 4),
              ),
            ),
            child: _ThemeSwatch(theme: theme, selected: theme == selected),
          ),
      ],
      builder: (context, controller, child) {
        return _ThemeSwatch(
          theme: selected,
          showsChevron: true,
          open: controller.isOpen,
          onTap: () {
            if (controller.isOpen) {
              controller.close();
            } else {
              controller.open();
            }
          },
        );
      },
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({
    required this.theme,
    this.selected = false,
    this.showsChevron = false,
    this.open = false,
    this.onTap,
  });

  final AppThemeKey theme;
  final bool selected;
  final bool showsChevron;
  final bool open;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = _themeSwatchFill(theme.preview);
    final ink = _themeSwatchInk(theme.preview);
    final radius = BorderRadius.circular(AppRadii.control);
    return Semantics(
      button: onTap != null,
      selected: selected || (showsChevron && !open),
      label: '${theme.label}主题',
      child: Material(
        color: fill,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      theme.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  if (selected && !showsChevron)
                    Icon(Icons.check_rounded, color: ink),
                  if (showsChevron)
                    Icon(
                      open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ink,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 色块直接用主题本色，字用同色系的浅色，不用黑白。
Color _themeSwatchFill(Color preview) => preview;

Color _themeSwatchInk(Color preview) {
  final hsl = HSLColor.fromColor(preview);
  return hsl
      .withLightness(0.86)
      .withSaturation((hsl.saturation * 0.45).clamp(0.18, 0.42))
      .toColor();
}
