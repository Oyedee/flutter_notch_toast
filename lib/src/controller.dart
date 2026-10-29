import 'dart:async';

import 'package:flutter/foundation.dart';

/// The visual intent of a toast; controls its icon and default behaviour.
enum NotchToastType { normal, success, error, warning, info, loading }

/// Which screen edge the toaster is anchored to.
enum NotchPosition { topCenter, bottomCenter }

/// [attached] joins the island to the screen edge with concave notch corners;
/// [floating] renders a detached pill inset from the edge.
enum NotchMode { attached, floating }

/// Motion presets for the shell and content transitions.
enum NotchAnimationPreset { fluid, gooey, smooth, subtle, snappy }

/// A trailing text button rendered inside the toast.
@immutable
class NotchToastAction {
  const NotchToastAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;
}

/// The toast currently shown by a [NotchToastController].
///
/// [revision] changes on every show or update so the toaster can morph the
/// island even when the [id] stays the same.
@immutable
class NotchToastRecord {
  const NotchToastRecord({
    required this.id,
    required this.title,
    required this.type,
    required this.duration,
    required this.dismissible,
    required this.revision,
    this.action,
  });

  final String id;
  final String title;
  final NotchToastType type;

  /// How long the toast stays visible. [Duration.zero] keeps it until it is
  /// dismissed or replaced.
  final Duration duration;
  final bool dismissible;
  final NotchToastAction? action;
  final int revision;
}

const _defaultDuration = Duration(milliseconds: 3600);

Duration _defaultDurationFor(NotchToastType type) => switch (type) {
  NotchToastType.normal ||
  NotchToastType.success ||
  NotchToastType.info => _defaultDuration,
  NotchToastType.warning ||
  NotchToastType.error ||
  NotchToastType.loading => Duration.zero,
};

bool _defaultDismissibleFor(NotchToastType type) =>
    type == NotchToastType.error ||
    type == NotchToastType.warning ||
    type == NotchToastType.loading;

/// A latest-toast-wins store. Showing a toast replaces the active one; showing
/// or updating with the same id morphs the active island in place.
///
/// Most apps use the global [toast] instance. Call the controller directly to
/// show a default toast: `toast('Copied')`.
class NotchToastController {
  NotchToastController();

  final ValueNotifier<NotchToastRecord?> _active = ValueNotifier(null);
  Timer? _timer;
  int _idSeed = 0;
  int _revisionSeed = 0;

  /// The active toast, or null when nothing is shown.
  ValueListenable<NotchToastRecord?> get active => _active;

  String call(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  String success(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    type: NotchToastType.success,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  String error(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    type: NotchToastType.error,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  String warning(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    type: NotchToastType.warning,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  String info(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    type: NotchToastType.info,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  String loading(
    String title, {
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) => show(
    title,
    type: NotchToastType.loading,
    id: id,
    duration: duration,
    dismissible: dismissible,
    action: action,
  );

  /// Shows a toast of any [type] and returns its id.
  String show(
    String title, {
    NotchToastType type = NotchToastType.normal,
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) {
    _set(
      NotchToastRecord(
        id: id ?? 'notch-${DateTime.now().microsecondsSinceEpoch}-${_idSeed++}',
        title: title,
        type: type,
        duration: duration ?? _defaultDurationFor(type),
        dismissible: dismissible ?? _defaultDismissibleFor(type),
        action: action,
        revision: _revisionSeed++,
      ),
    );
    return _active.value!.id;
  }

  /// Shows a loading toast while [future] runs, then morphs it into a success
  /// or error toast. The result is ignored if another toast replaced it.
  ///
  /// [successTitle] and [errorTitle] build the title from the outcome and take
  /// precedence over [success] and [error].
  Future<T> promise<T>(
    Future<T> future, {
    required String loading,
    String? success,
    String Function(T value)? successTitle,
    String? error,
    String Function(Object error)? errorTitle,
    String? id,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
  }) async {
    assert(success != null || successTitle != null);
    assert(error != null || errorTitle != null);
    final toastId = show(
      loading,
      type: NotchToastType.loading,
      id: id,
      duration: Duration.zero,
      dismissible: false,
      action: action,
    );
    final loadingRevision = _active.value!.revision;
    bool isCurrent() =>
        _active.value?.id == toastId &&
        _active.value?.revision == loadingRevision;

    try {
      final value = await future;
      if (isCurrent()) {
        show(
          successTitle?.call(value) ?? success!,
          type: NotchToastType.success,
          id: toastId,
          duration: duration,
          dismissible: dismissible,
          action: action,
        );
      }
      return value;
    } catch (reason) {
      if (isCurrent()) {
        show(
          errorTitle?.call(reason) ?? error!,
          type: NotchToastType.error,
          id: toastId,
          duration: duration,
          dismissible: dismissible,
          action: action,
        );
      }
      rethrow;
    }
  }

  /// Patches the active toast if its id matches. Pass [clearAction] to remove
  /// an existing action.
  void update(
    String id, {
    String? title,
    NotchToastType? type,
    Duration? duration,
    bool? dismissible,
    NotchToastAction? action,
    bool clearAction = false,
  }) {
    final current = _active.value;
    if (current == null || current.id != id) return;
    _set(
      NotchToastRecord(
        id: id,
        title: title ?? current.title,
        type: type ?? current.type,
        duration: duration ?? current.duration,
        dismissible: dismissible ?? current.dismissible,
        action: clearAction ? null : action ?? current.action,
        revision: _revisionSeed++,
      ),
    );
  }

  /// Dismisses the active toast, or only the toast with [id] when given.
  void dismiss([String? id]) {
    final current = _active.value;
    if (current == null || (id != null && current.id != id)) return;
    _set(null);
  }

  void _set(NotchToastRecord? record) {
    _timer?.cancel();
    _timer = null;
    _active.value = record;
    if (record != null && record.duration > Duration.zero) {
      _timer = Timer(record.duration, () => dismiss(record.id));
    }
  }
}

/// The app-wide toast store rendered by [NotchToaster] by default.
final NotchToastController toast = NotchToastController();
