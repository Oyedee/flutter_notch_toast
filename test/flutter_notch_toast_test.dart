import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_notch_toast/flutter_notch_toast.dart';

void main() {
  late NotchToastController controller;

  setUp(() => controller = NotchToastController());
  tearDown(() => controller.dismiss());

  Future<void> pumpToaster(
    WidgetTester tester, {
    NotchPosition position = NotchPosition.topCenter,
    NotchMode mode = NotchMode.attached,
    bool reduceMotion = false,
    Widget? home,
  }) {
    return tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: MaterialApp(
          home: home ?? const Scaffold(),
          builder: (context, child) => NotchToaster(
            controller: controller,
            position: position,
            mode: mode,
            child: child!,
          ),
        ),
      ),
    );
  }

  /// Lets enter/exit transitions finish without waiting on the spinner.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('keeps only the newest toast and updates a matching id', (
    tester,
  ) async {
    await pumpToaster(tester);

    expect(controller.success('First toast', id: 'first'), 'first');
    controller.error('Second toast', id: 'second');
    await settle(tester);

    expect(find.text('First toast'), findsNothing);
    expect(find.text('Second toast'), findsOneWidget);

    controller.update(
      'second',
      title: 'Updated toast',
      type: NotchToastType.warning,
    );
    await settle(tester);

    expect(find.text('Second toast'), findsNothing);
    expect(find.text('Updated toast'), findsOneWidget);
    expect(controller.active.value!.type, NotchToastType.warning);
  });

  testWidgets('respects ids, direct dismissal, and timed dismissal', (
    tester,
  ) async {
    await pumpToaster(tester);

    controller.success(
      'Timed toast',
      id: 'timed',
      duration: const Duration(milliseconds: 100),
    );
    controller.dismiss('different-id');
    await tester.pump();
    expect(find.text('Timed toast'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await settle(tester);
    expect(controller.active.value, isNull);
    expect(find.text('Timed toast'), findsNothing);

    controller.error('Persistent toast', id: 'persistent');
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Persistent toast'), findsOneWidget);

    controller.dismiss('persistent');
    await settle(tester);
    expect(find.text('Persistent toast'), findsNothing);
  });

  testWidgets('morphs promise loading into success and error states', (
    tester,
  ) async {
    await pumpToaster(tester);

    final saving = Completer<String>();
    final saved = controller.promise(
      saving.future,
      loading: 'Saving changes',
      successTitle: (value) => 'Saved $value',
      error: 'Unable to save',
    );
    await tester.pump();
    expect(find.text('Saving changes'), findsOneWidget);
    expect(controller.active.value!.type, NotchToastType.loading);

    saving.complete('settings');
    expect(await saved, 'settings');
    await settle(tester);
    expect(find.text('Saved settings'), findsOneWidget);

    final syncing = Completer<void>();
    final synced = controller.promise(
      syncing.future,
      loading: 'Syncing changes',
      success: 'Changes synced',
      error: 'Unable to sync',
    );
    syncing.completeError(StateError('Sync failed'));
    await expectLater(synced, throwsStateError);
    await settle(tester);
    expect(find.text('Unable to sync'), findsOneWidget);
    expect(controller.active.value!.type, NotchToastType.error);
  });

  testWidgets('a stale promise does not overwrite a newer toast', (
    tester,
  ) async {
    await pumpToaster(tester);

    final pending = Completer<void>();
    final result = controller.promise(
      pending.future,
      loading: 'Working',
      success: 'Old success',
      error: 'Old error',
    );
    controller.error('Newest notification', id: 'newest');

    pending.complete();
    await result;
    await settle(tester);

    expect(find.text('Newest notification'), findsOneWidget);
    expect(find.text('Old success'), findsNothing);
  });

  testWidgets('Escape dismisses without stealing focus, except while typing', (
    tester,
  ) async {
    final field = FocusNode();
    addTearDown(field.dispose);
    await pumpToaster(
      tester,
      home: Scaffold(body: TextField(focusNode: field)),
    );

    controller.error('Could not save');
    await settle(tester);
    expect(find.text('Could not save'), findsOneWidget);

    field.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(controller.active.value, isNotNull);
    expect(field.hasFocus, isTrue);

    field.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(controller.active.value, isNull);
    expect(find.text('Could not save'), findsNothing);
  });

  testWidgets('close button dismisses any toast marked dismissible', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpToaster(tester);

    controller.success('Saved');
    await settle(tester);
    expect(find.bySemanticsLabel('Dismiss notification'), findsNothing);

    controller.success('Saved', dismissible: true);
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Dismiss notification'));
    await settle(tester);
    expect(controller.active.value, isNull);
    semantics.dispose();
  });

  testWidgets('action buttons invoke their callback', (tester) async {
    await pumpToaster(tester);
    var retried = 0;

    controller.error(
      'Unable to save',
      action: NotchToastAction(label: 'Retry', onPressed: () => retried++),
    );
    await settle(tester);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);

    controller.update(controller.active.value!.id, clearAction: true);
    await settle(tester);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('renders every position, mode and reduced motion', (
    tester,
  ) async {
    for (final position in NotchPosition.values) {
      for (final mode in NotchMode.values) {
        for (final reduceMotion in [false, true]) {
          await pumpToaster(
            tester,
            position: position,
            mode: mode,
            reduceMotion: reduceMotion,
          );
          for (final type in NotchToastType.values) {
            controller.show('$type', type: type);
            await settle(tester);
            expect(find.text('$type'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
          controller.dismiss();
          await settle(tester);
        }
      }
    }
  });

  testWidgets('places the island at the chosen edge', (tester) async {
    await pumpToaster(tester, position: NotchPosition.bottomCenter);
    controller('Bottom');
    await settle(tester);
    final screen = tester.getSize(find.byType(NotchToaster));
    expect(
      tester.getRect(find.text('Bottom')).bottom,
      greaterThan(screen.height - 40),
    );

    await pumpToaster(tester);
    controller('Top');
    await settle(tester);
    expect(tester.getRect(find.text('Top')).top, lessThan(40));
    controller.dismiss();
  });

  testWidgets('uses the inverted shadcn neutral palette by default', (
    tester,
  ) async {
    const expected = {
      Brightness.light: (Color(0xFF0A0A0A), Color(0xFFFFFFFF)),
      Brightness.dark: (Color(0xFFFAFAFA), Color(0xFF0A0A0A)),
    };
    for (final MapEntry(key: brightness, value: (fill, text))
        in expected.entries) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const SizedBox(),
          builder: (context, child) =>
              NotchToaster(controller: controller, child: child!),
        ),
      );
      controller('Themed');
      await settle(tester);
      expect(tester.widget<Text>(find.text('Themed')).style!.color, text);
      final style = const NotchToastStyle().resolve(
        tester.element(find.text('Themed')),
      );
      expect(style.backgroundColor, fill);
      controller.dismiss();
      await settle(tester);
    }
  });

  testWidgets('hides the status bar while a top notch wraps the cutout', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(top: 180);
    tester.view.viewPadding = const FakeViewPadding(top: 180);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final modes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          modes.add('${call.arguments}');
        } else if (call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
          modes.add('overlays:${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    Future<void> pumpApp(NotchMode mode) => tester.pumpWidget(
      MaterialApp(
        home: const SizedBox(),
        builder: (context, child) =>
            NotchToaster(controller: controller, mode: mode, child: child!),
      ),
    );

    await pumpApp(NotchMode.attached);
    controller('Short');
    await settle(tester);
    expect(modes, hasLength(1));
    expect(tester.getSize(find.byType(AnimatedSize)).width, 180);

    controller.dismiss();
    await settle(tester);
    expect(modes, hasLength(2));
    expect(modes.last, contains('edgeToEdge'));

    await pumpApp(NotchMode.floating);
    controller('Floating');
    await settle(tester);
    expect(modes, hasLength(2));
    controller.dismiss();
    await settle(tester);
  });

  test('applies type defaults', () {
    controller.error('Error');
    expect(controller.active.value!.duration, Duration.zero);
    expect(controller.active.value!.dismissible, isTrue);

    controller.success('Saved');
    expect(
      controller.active.value!.duration,
      const Duration(milliseconds: 3600),
    );
    expect(controller.active.value!.dismissible, isFalse);
  });
}
