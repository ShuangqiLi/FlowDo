import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// 还挂在页面上的密码表单。离开登录/改密页后必须拆掉，
/// 否则密码插件会把后面的任务请求当成「更新密码」。
final List<web.HTMLFormElement> _passwordForms = <web.HTMLFormElement>[];

/// 拆掉已经不该继续留在页面上的密码框。
///
/// 登录和改密页上的表单标着 `data-flowdo-mounted=1`，不会动。
void retireStrayPasswordFields() {
  for (final form in List<web.HTMLFormElement>.of(_passwordForms)) {
    if (form.getAttribute('data-flowdo-mounted') == '1') {
      continue;
    }
    _neuterPasswordForm(form);
    _passwordForms.remove(form);
  }
  final nodes = web.document.querySelectorAll('[data-flowdo-pw]');
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes.item(i);
    if (node == null || !node.isA<web.HTMLElement>()) {
      continue;
    }
    final el = node as web.HTMLElement;
    if (el.getAttribute('data-flowdo-mounted') == '1') {
      continue;
    }
    _neuterPasswordForm(el);
  }
}

void _neuterPasswordForm(web.HTMLElement form) {
  final inputs = form.querySelectorAll('input');
  for (var i = 0; i < inputs.length; i++) {
    final node = inputs.item(i);
    if (node == null || !node.isA<web.HTMLInputElement>()) {
      continue;
    }
    final input = node as web.HTMLInputElement;
    input.setAttribute('data-retired', '1');
    input.removeAttribute('name');
    input.autocomplete = 'off';
    input.type = 'text';
  }
  form.remove();
}

/// 网页上的密码框。
///
/// Flutter 把界面画在画布上，密码插件只能看见真正的 `<input type="password">`。
/// 这里嵌一个真实表单，插件才能填进来，填入的值再同步回 [controller]。
class PasswordField extends StatefulWidget {
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

  /// 登录页多放一个用户名输入，方便插件把「用户名 + 密码」一起填上。
  /// 不占界面，登录也不使用它。
  final bool anchorUsername;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  late final String _viewType = 'flowdo-pw-${identityHashCode(this)}';
  web.HTMLFormElement? _form;
  web.HTMLInputElement? _input;
  web.HTMLStyleElement? _styleEl;
  var _registered = false;
  var _disposed = false;
  var _syncing = false;

  Color _fill = const Color(0xFFFFFFFF);
  Color _border = const Color(0xFFC3D4C8);
  Color _focus = const Color(0xFF5F9B82);
  Color _text = const Color(0xFF3A4A40);
  Color _hint = const Color(0xFF6B7C72);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_pushToDom);
  }

  @override
  void didUpdateWidget(PasswordField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_pushToDom);
      widget.controller.addListener(_pushToDom);
      _pushToDom();
    }
    final input = _input;
    if (input == null) {
      return;
    }
    if (oldWidget.label != widget.label) {
      input.placeholder = widget.label;
      input.setAttribute('aria-label', widget.label);
    }
    if (oldWidget.autofillHint != widget.autofillHint) {
      input.autocomplete = _autocompleteToken;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.controller.removeListener(_pushToDom);
    _retire();
    super.dispose();
  }

  /// 页面还在时插件需要这个表单；离开后立刻拆掉。
  /// Flutter 的 platform view 有时会在组件销毁之后才把表单插进文档，
  /// 所以这里先作废，插进来的也只是普通输入框。
  void _retire() {
    final form = _form;
    _form = null;
    _input = null;
    if (form == null) {
      return;
    }
    form.setAttribute('data-flowdo-mounted', '0');
    _neuterPasswordForm(form);
    _passwordForms.remove(form);
  }

  void _pushToDom() {
    final input = _input;
    if (input == null || _syncing) return;
    if (input.value != widget.controller.text) {
      input.setAttribute('data-silent', '1');
      input.value = widget.controller.text;
      input.removeAttribute('data-silent');
    }
  }

  void _fromDom() {
    final input = _input;
    if (input == null || !mounted) return;
    final text = input.value;
    if (text == widget.controller.text) return;
    _syncing = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _syncing = false;
  }

  void _ensureRegistered() {
    if (_registered) return;
    _registered = true;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      if (_disposed || !mounted) {
        return web.HTMLDivElement();
      }
      return _createForm();
    });
  }

  /// 浏览器只认 current-password / new-password，不认 Flutter 的 `password`。
  String get _autocompleteToken {
    if (widget.autofillHint == AutofillHints.newPassword) return 'new-password';
    return 'current-password';
  }

  web.HTMLFormElement _createForm() {
    final form = web.HTMLFormElement();
    form.setAttribute('data-flowdo-pw', '1');
    form.setAttribute('data-flowdo-mounted', '1');
    form.setAttribute('autocomplete', 'on');
    _form = form;
    _passwordForms.add(form);
    form.style
      ..margin = '0'
      ..height = '100%'
      ..width = '100%'
      ..position = 'relative';

    if (widget.anchorUsername) {
      final username = web.HTMLInputElement()
        ..type = 'text'
        ..name = 'username'
        ..autocomplete = 'username'
        ..tabIndex = -1;
      username.setAttribute('aria-hidden', 'true');
      username.style
        ..position = 'absolute'
        ..width = '1px'
        ..height = '1px'
        ..padding = '0'
        ..margin = '0'
        ..border = '0'
        ..opacity = '0';
      form.appendChild(username);
    }

    final style = web.HTMLStyleElement();
    _styleEl = style;
    style.textContent = _css();
    form.appendChild(style);

    final box = web.HTMLLabelElement();
    box.className = 'box';
    final icon = web.HTMLSpanElement();
    icon.innerHTML = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 2a5 5 0 0 0-5 5v3H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8a2 2 0 0 0-2-2h-1V7a5 5 0 0 0-5-5zm-3 8V7a3 3 0 0 1 6 0v3H9z"/></svg>'.toJS;
    final input = web.HTMLInputElement()
      ..className = 'pw'
      ..type = 'password'
      ..name = 'password'
      ..autocomplete = _autocompleteToken
      ..placeholder = widget.label
      ..value = widget.controller.text;
    input.setAttribute('aria-label', widget.label);
    input.setAttribute('autocapitalize', 'off');
    input.setAttribute('spellcheck', 'false');
    box.appendChild(icon);
    box.appendChild(input);
    form.appendChild(box);
    _input = input;
    _hookValueSetter(input);

    void onEdit(web.Event event) {
      _fromDom();
    }

    input.addEventListener('input', onEdit.toJS);
    input.addEventListener('change', onEdit.toJS);
    input.addEventListener('animationstart', onEdit.toJS);
    form.addEventListener(
      'submit',
      (web.Event event) {
        event.preventDefault();
        _fromDom();
        widget.onSubmitted?.call(input.value);
      }.toJS,
    );
    return form;
  }

  /// 密码插件常常只改 input.value、不发 input 事件。拦住赋值，补一次事件，
  /// Flutter 这边的 controller 才能收到填入的密码。
  void _hookValueSetter(web.HTMLInputElement input) {
    final script = web.HTMLScriptElement();
    script.textContent = '''
(() => {
  const script = document.currentScript;
  const input = script && script.parentElement && script.parentElement.querySelector('input.pw');
  const desc = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value');
  if (!input || !desc || input.dataset.valueHook) return;
  input.dataset.valueHook = '1';
  Object.defineProperty(input, 'value', {
    configurable: true,
    get() { return desc.get.call(this); },
    set(v) {
      if (desc.get.call(this) === v) return;
      desc.set.call(this, v);
      if (input.getAttribute('data-silent') === '1') return;
      if (input.getAttribute('data-retired') === '1') return;
      input.dispatchEvent(new Event('input', { bubbles: true }));
    }
  });
  script.remove();
})();
''';
    input.parentElement?.appendChild(script);
  }

  String _css() {
    String css(Color c) {
      final r = (c.r * 255).round().clamp(0, 255);
      final g = (c.g * 255).round().clamp(0, 255);
      final b = (c.b * 255).round().clamp(0, 255);
      return 'rgba($r,$g,$b,${c.a.toStringAsFixed(3)})';
    }

    return '''
      @keyframes flowdo-autofill { from { opacity: 1 } to { opacity: 1 } }
      .box {
        box-sizing: border-box;
        display: flex;
        align-items: center;
        gap: 12px;
        height: 100%;
        margin: 0;
        padding: 0 16px;
        background: ${css(_fill)};
        border: 1px solid ${css(_border)};
        border-radius: 12px;
        color: ${css(_hint)};
      }
      .box:focus-within { border: 1.7px solid ${css(_focus)}; }
      .box svg { width: 24px; height: 24px; flex: none; }
      .box .pw {
        flex: 1;
        min-width: 0;
        border: 0;
        outline: none;
        background: transparent;
        color: ${css(_text)};
        font: 16px/1.4 ui-sans-serif, system-ui, "Segoe UI", sans-serif;
      }
      /* 掩码点是 U+2022。思源黑体里它是全角，点距会拉开近一倍，所以输入内容不用中文字体。
         占位的「密码」仍走中文字体。 */
      .box .pw::placeholder {
        color: ${css(_hint)};
        font-family: "Noto Sans SC", "PingFang SC", "Microsoft YaHei", sans-serif;
      }
      .box .pw:-webkit-autofill {
        animation: flowdo-autofill 0.01s;
        -webkit-text-fill-color: ${css(_text)};
        caret-color: ${css(_text)};
        box-shadow: 0 0 0 1000px ${css(_fill)} inset;
      }
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    _fill = scheme.surface;
    _border = scheme.outlineVariant;
    _focus = scheme.primary;
    _text = scheme.onSurface;
    _hint = scheme.onSurfaceVariant;
    _styleEl?.textContent = _css();
    _ensureRegistered();
    return SizedBox(
      height: 56,
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
