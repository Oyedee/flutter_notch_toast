import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'controller.dart';
import 'icons.dart';
import 'motion.dart';
import 'shape.dart';

/// Narrowest body for an island that wraps a top camera cutout; a dynamic
/// island is about 126pt wide.
const double _cutoutMinWidth = 180;

/// Colours and typography for the island.
///
/// Unset colours follow shadcn/ui's neutral palette, inverted like the web
/// original: the island is filled with the `foreground` token and draws text
/// in `background`, so it is near-black in light themes and near-white in
/// dark themes. The ambient [Theme]'s brightness picks the variant.
@immutable
class NotchToastStyle {
  const NotchToastStyle({
    this.backgroundColor,
    this.foregroundColor,
    this.shadowColor,
    this.textStyle,
    this.notchRadius = 16,
  });

  /// The island fill. Defaults to shadcn `foreground`: `#0A0A0A` in light
  /// themes, `#FAFAFA` in dark ones.
  final Color? backgroundColor;

  /// Text, icon badge and button colour. Defaults to shadcn `background`:
  /// `#FFFFFF` in light themes, `#0A0A0A` in dark ones.
  final Color? foregroundColor;

  /// Defaults to shadcn `muted-foreground` at 16% opacity.
  final Color? shadowColor;

  /// Merged over the app's `bodyMedium` text style, after the 14px semibold
  /// defaults.
  final TextStyle? textStyle;

  /// Radius of the body corners and the concave ears in attached mode.
  final double notchRadius;

  /// Fills unset colours from the shadcn neutral palette for the ambient
  /// [Theme]'s brightness.
  NotchToastStyle resolve(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return NotchToastStyle(
      backgroundColor:
          backgroundColor ??
          (dark ? const Color(0xFFFAFAFA) : const Color(0xFF0A0A0A)),
      foregroundColor:
          foregroundColor ??
          (dark ? const Color(0xFF0A0A0A) : const Color(0xFFFFFFFF)),
      shadowColor:
          shadowColor ??
          (dark ? const Color(0x29A3A3A3) : const Color(0x29737373)),
      textStyle: textStyle,
      notchRadius: notchRadius,
    );
  }
}

/// Renders the toasts of a [NotchToastController] above [child]. Mount it once,
/// typically from `MaterialApp.builder`:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => NotchToaster(child: child!),
/// )
/// ```
///
/// An attached toaster joins the island to the top or bottom screen edge and
/// extends it into the device's safe-area inset, so it wraps around a physical
/// notch or dynamic island. While such a top island is visible the status bar
/// is hidden, since the clock and battery would sit underneath it; see
/// [hideStatusBar].
class NotchToaster extends StatefulWidget {
  const NotchToaster({
    super.key,
    required this.child,
    this.controller,
    this.position = NotchPosition.topCenter,
    this.mode = NotchMode.attached,
    this.animation = NotchAnimationPreset.fluid,
    this.style = const NotchToastStyle(),
    this.hideStatusBar = true,
  });

  final Widget child;

  /// Defaults to the global [toast] controller.
  final NotchToastController? controller;
  final NotchPosition position;
  final NotchMode mode;
  final NotchAnimationPreset animation;
  final NotchToastStyle style;

  /// Whether an attached top island hides the status bar while it is shown
  /// on a device with a top inset. The status bar returns, in
  /// [SystemUiMode.edgeToEdge], when the toast is dismissed.
  final bool hideStatusBar;

  @override
  State<NotchToaster> createState() => _NotchToasterState();
}

class _NotchToasterState extends State<NotchToaster> {
  NotchToastRecord? _record;

  /// Bumped each time a toast appears from nothing, so a toast shown while
  /// the previous island is still exiting gets its own shell.
  int _session = 0;

  /// Whether this toaster currently has the status bar hidden.
  bool _statusBarHidden = false;

  NotchToastController get _controller => widget.controller ?? toast;

  @override
  void initState() {
    super.initState();
    _record = _controller.active.value;
    _controller.active.addListener(_onChanged);
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didUpdateWidget(NotchToaster oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldController = oldWidget.controller ?? toast;
    if (oldController != _controller) {
      oldController.active.removeListener(_onChanged);
      _controller.active.addListener(_onChanged);
      _onChanged();
    }
  }

  @override
  void dispose() {
    _controller.active.removeListener(_onChanged);
    HardwareKeyboard.instance.removeHandler(_onKey);
    if (_statusBarHidden) _setStatusBarHidden(false);
    super.dispose();
  }

  void _onChanged() {
    final next = _controller.active.value;
    setState(() {
      if (_record == null && next != null) _session++;
      _record = next;
    });
  }

  void _setStatusBarHidden(bool hidden) {
    _statusBarHidden = hidden;
    SystemChrome.setEnabledSystemUIMode(
      hidden ? SystemUiMode.manual : SystemUiMode.edgeToEdge,
      overlays: hidden ? const [SystemUiOverlay.bottom] : null,
    );
  }

  bool _onKey(KeyEvent event) {
    final record = _record;
    if (record == null ||
        !record.dismissible ||
        event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape ||
        _isEditing()) {
      return false;
    }
    _controller.dismiss(record.id);
    return true;
  }

  static bool _isEditing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final motion = reduceMotion
        ? reducedMotionFade
        : notchPresets[widget.animation]!;
    final isBottom = widget.position == NotchPosition.bottomCenter;
    final viewPadding =
        MediaQuery.maybeViewPaddingOf(context) ?? EdgeInsets.zero;
    final edgeInset = isBottom ? viewPadding.bottom : viewPadding.top;
    final attached = widget.mode == NotchMode.attached;
    final edgeAlignment = isBottom
        ? Alignment.bottomCenter
        : Alignment.topCenter;
    final record = _record;

    // Once hidden, keep going by the inset we saw before hiding so a platform
    // that shrinks the inset without a status bar cannot make this flip-flop.
    final hideStatusBar =
        widget.hideStatusBar &&
        record != null &&
        attached &&
        !isBottom &&
        (viewPadding.top > 0 || _statusBarHidden);
    if (hideStatusBar != _statusBarHidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && hideStatusBar != _statusBarHidden) {
          _setStatusBarHidden(hideStatusBar);
        }
      });
    }

    final shellSwitcher = AnimatedSwitcher(
      duration: motion.duration,
      switchInCurve: motion.curve,
      switchOutCurve: motion.curve.flipped,
      layoutBuilder: (current, previous) => _PopLayout(
        alignment: edgeAlignment,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => _ShellTransition(
        animation: animation,
        isBottom: isBottom,
        origin: attached ? edgeAlignment : Alignment.center,
        reduceMotion: reduceMotion,
        child: child,
      ),
      child: record == null
          ? const SizedBox.shrink(key: ValueKey('empty'))
          : _NotchShell(
              key: ValueKey(_session),
              record: record,
              controller: _controller,
              position: widget.position,
              mode: widget.mode,
              motion: motion,
              reduceMotion: reduceMotion,
              style: widget.style.resolve(context),
              edgeInset: attached ? edgeInset : 0,
            ),
    );

    final offset = attached ? 0.0 : edgeInset + 16;
    return Stack(
      fit: StackFit.expand,
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        Positioned(
          left: 16,
          right: 16,
          top: isBottom ? null : offset,
          bottom: isBottom ? offset : null,
          child: Align(alignment: edgeAlignment, child: shellSwitcher),
        ),
      ],
    );
  }
}

class _ShellTransition extends StatelessWidget {
  const _ShellTransition({
    required this.animation,
    required this.isBottom,
    required this.origin,
    required this.reduceMotion,
    required this.child,
  });

  final Animation<double> animation;
  final bool isBottom;
  final Alignment origin;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final opacity = t.clamp(0.0, 1.0);
        if (reduceMotion) return Opacity(opacity: opacity, child: child);
        final exiting = animation.status == AnimationStatus.reverse;
        final travel = (exiting ? 8 : 12) * (isBottom ? 1 : -1);
        final blur = ((exiting ? 6 : 8) * (1 - t)).clamp(0.0, 8.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, travel * (1 - t)),
            child: Transform.scale(
              scale: 0.96 + 0.04 * t,
              alignment: origin,
              child: _Blur(sigma: blur, child: child!),
            ),
          ),
        );
      },
    );
  }
}

class _ContentTransition extends StatelessWidget {
  const _ContentTransition({
    required this.animation,
    required this.slotOffset,
    required this.origin,
    required this.reduceMotion,
    required this.child,
  });

  final Animation<double> animation;
  final double slotOffset;
  final Alignment origin;
  final bool reduceMotion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        final opacity = t.clamp(0.0, 1.0);
        if (reduceMotion) return Opacity(opacity: opacity, child: child);
        final exiting = animation.status == AnimationStatus.reverse;
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, slotOffset * (1 - t)),
            child: Transform.scale(
              scale: 0.92 + 0.08 * t,
              alignment: origin,
              child: _Blur(
                sigma: exiting ? 0 : (5 * (1 - t)).clamp(0.0, 5.0),
                child: child!,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Blur extends StatelessWidget {
  const _Blur({required this.sigma, required this.child});

  final double sigma;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma < 0.05) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}

class _NotchShell extends StatelessWidget {
  const _NotchShell({
    super.key,
    required this.record,
    required this.controller,
    required this.position,
    required this.mode,
    required this.motion,
    required this.reduceMotion,
    required this.style,
    required this.edgeInset,
  });

  final NotchToastRecord record;
  final NotchToastController controller;
  final NotchPosition position;
  final NotchMode mode;
  final NotchMotion motion;
  final bool reduceMotion;
  final NotchToastStyle style;
  final double edgeInset;

  @override
  Widget build(BuildContext context) {
    final isBottom = position == NotchPosition.bottomCenter;
    final attached = mode == NotchMode.attached;
    final origin = attached
        ? (isBottom ? Alignment.bottomCenter : Alignment.topCenter)
        : Alignment.center;

    Widget content = AnimatedSwitcher(
      duration: motion.duration,
      reverseDuration: reduceMotion
          ? motion.duration
          : const Duration(milliseconds: 100),
      switchInCurve: motion.curve,
      switchOutCurve: notchEase.flipped,
      layoutBuilder: (current, previous) =>
          _PopLayout(alignment: origin, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => _ContentTransition(
        animation: animation,
        slotOffset: isBottom ? 7 : -7,
        origin: origin,
        reduceMotion: reduceMotion,
        child: child,
      ),
      child: _NotchContent(
        key: ValueKey(record.revision),
        record: record,
        controller: controller,
        style: style,
        reduceMotion: reduceMotion,
      ),
    );
    if (!reduceMotion) {
      content = AnimatedSize(
        duration: motion.duration,
        curve: motion.curve,
        alignment: origin,
        child: content,
      );
    }

    // An island pushed into the top inset wraps the device's camera cutout,
    // so keep its body wider than a dynamic island even for short titles.
    if (attached && !isBottom && edgeInset > 0) {
      content = ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _cutoutMinWidth),
        child: content,
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      child: CustomPaint(
        painter: NotchShellPainter(
          color: style.backgroundColor!,
          shadowColor: style.shadowColor!,
          position: position,
          mode: mode,
          radius: style.notchRadius,
        ),
        child: ClipRRect(
          borderRadius: notchBodyRadius(
            position: position,
            mode: mode,
            radius: style.notchRadius,
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: isBottom ? 0 : edgeInset,
              bottom: isBottom ? edgeInset : 0,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _NotchContent extends StatelessWidget {
  const _NotchContent({
    super.key,
    required this.record,
    required this.controller,
    required this.style,
    required this.reduceMotion,
  });

  final NotchToastRecord record;
  final NotchToastController controller;
  final NotchToastStyle style;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final foreground = style.foregroundColor!;
    final textStyle =
        (Theme.of(context).textTheme.bodyMedium ?? const TextStyle())
            .copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.25,
              color: foreground,
              decoration: TextDecoration.none,
            )
            .merge(style.textStyle);
    final action = record.action;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (record.type != NotchToastType.normal)
            NotchStatusIcon(
              type: record.type,
              foreground: foreground,
              background: style.backgroundColor!,
              reduceMotion: reduceMotion,
            ),
          Flexible(
            child: Text(
              record.title,
              style: textStyle,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null)
            _NotchButton(
              onPressed: action.onPressed,
              foreground: foreground,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              builder: (color) => Text(
                action.label,
                style: textStyle.copyWith(fontSize: 12, color: color),
              ),
            ),
          if (record.dismissible)
            _NotchButton(
              onPressed: () => controller.dismiss(record.id),
              foreground: foreground,
              semanticLabel: 'Dismiss notification',
              size: const Size.square(24),
              builder: (color) => CustomPaint(
                size: const Size.square(12),
                painter: _CloseGlyphPainter(color),
              ),
            ),
        ],
      ),
    );
  }
}

/// A minimal text-free button: 76% foreground at rest, full foreground on a
/// 12% wash when hovered or focused, plus a focus ring.
class _NotchButton extends StatefulWidget {
  const _NotchButton({
    required this.onPressed,
    required this.foreground,
    required this.builder,
    this.padding = EdgeInsets.zero,
    this.size,
    this.semanticLabel,
  });

  final VoidCallback onPressed;
  final Color foreground;
  final Widget Function(Color color) builder;
  final EdgeInsets padding;
  final Size? size;
  final String? semanticLabel;

  @override
  State<_NotchButton> createState() => _NotchButtonState();
}

class _NotchButtonState extends State<_NotchButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _hovered || _focused;
    final foreground = widget.foreground;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _hovered = value),
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: true,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: widget.size?.width,
            height: widget.size?.height,
            alignment: widget.size == null ? null : Alignment.center,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: highlighted
                  ? foreground.withValues(alpha: 0.12)
                  : const Color(0x00000000),
              borderRadius: BorderRadius.circular(6),
              border: _focused
                  ? Border.all(
                      color: foreground,
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
            ),
            child: widget.builder(
              highlighted ? foreground : foreground.withValues(alpha: 0.76),
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseGlyphPainter extends CustomPainter {
  _CloseGlyphPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(4, 4), const Offset(12, 12), paint);
    canvas.drawLine(const Offset(12, 4), const Offset(4, 12), paint);
  }

  @override
  bool shouldRepaint(_CloseGlyphPainter old) => old.color != color;
}

/// Stacks switcher children but sizes itself to the last (incoming) child
/// only, so exiting children never affect layout. Children keep their widget
/// type when they move from incoming to outgoing, preserving their state.
class _PopLayout extends MultiChildRenderObjectWidget {
  const _PopLayout({required this.alignment, super.children});

  final Alignment alignment;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPopLayout(alignment);

  @override
  void updateRenderObject(BuildContext context, _RenderPopLayout renderObject) {
    renderObject.alignment = alignment;
  }
}

class _PopLayoutParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderPopLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _PopLayoutParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _PopLayoutParentData> {
  _RenderPopLayout(this._alignment);

  Alignment _alignment;
  set alignment(Alignment value) {
    if (value == _alignment) return;
    _alignment = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PopLayoutParentData) {
      child.parentData = _PopLayoutParentData();
    }
  }

  @override
  void performLayout() {
    final loose = constraints.loosen();
    var child = firstChild;
    while (child != null) {
      child.layout(loose, parentUsesSize: true);
      child = childAfter(child);
    }
    size = constraints.constrain(lastChild?.size ?? Size.zero);
    child = firstChild;
    while (child != null) {
      (child.parentData! as _PopLayoutParentData).offset = _alignment
          .alongOffset((size - child.size) as Offset);
      child = childAfter(child);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    // Only the incoming child is interactive.
    final child = lastChild;
    if (child == null) return false;
    final offset = (child.parentData! as _PopLayoutParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}
