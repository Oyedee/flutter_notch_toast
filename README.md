# flutter_notch_toast

Notch-style toast notifications for Flutter. It renders one polished dynamic
island at a time, morphs updates in place, and supports attached or floating
top and bottom placements.

A Flutter port of the [`notch-toast`](https://notch.devsethi.me/) React
package, keeping its shadcn/ui look. It has no dependencies beyond Flutter.

## Installation

```bash
flutter pub add flutter_notch_toast
```

## Setup

Mount one toaster near your application root. `MaterialApp.builder` places it
above every route:

```dart
import 'package:flutter_notch_toast/flutter_notch_toast.dart';

MaterialApp(
  builder: (context, child) => NotchToaster(child: child!),
  home: const HomePage(),
);
```

## Usage

```dart
import 'package:flutter_notch_toast/flutter_notch_toast.dart';

toast.success('Changes saved');

toast.error(
  'Unable to save changes',
  action: NotchToastAction(label: 'Retry', onPressed: retrySave),
);
```

Use `toast()`, `toast.success()`, `toast.error()`, `toast.warning()`,
`toast.info()`, `toast.loading()`, and `toast.promise()`. A new toast replaces
the active toast; reusing an id with `toast.update()` morphs the active island
in place.

```dart
final id = toast.loading('Uploading');
// later…
toast.update(id, title: 'Uploaded', type: NotchToastType.success);

final settings = await toast.promise(
  saveSettings(),
  loading: 'Saving changes',
  successTitle: (value) => 'Saved ${value.name}',
  error: 'Unable to save',
);
```

Success, info, and default toasts close after 3.6 seconds; error, warning, and
loading toasts stay until dismissed and show a close button. Override either
with `duration:` (`Duration.zero` means persistent) and `dismissible:`.

### Placement and motion

```dart
NotchToaster(
  position: NotchPosition.bottomCenter,
  mode: NotchMode.attached,
  animation: NotchAnimationPreset.fluid,
  child: child!,
)
```

`position` is `topCenter` or `bottomCenter`; `mode` is `attached` or
`floating`; animation presets are `fluid`, `gooey`, `smooth`, `subtle`, and
`snappy`.

An attached island joins the screen edge with concave notch corners and
extends into the safe-area inset, so on phones it wraps around the camera
notch or dynamic island. The island stays as wide as its content (at least
180pt around a cutout), and because the clock and battery would sit under it,
the status bar is hidden while a top island is visible and restored when it
closes. Pass `hideStatusBar: false` to leave the status bar alone.

### Styling

The island uses shadcn/ui's neutral palette, inverted like the web original:
it is filled with the `foreground` token and draws text in `background`. In a
light theme that is a `#0A0A0A` island with white text; in a dark theme, a
`#FAFAFA` island with `#0A0A0A` text. The shadow is `muted-foreground` at 16%.
The ambient `Theme`'s brightness picks the variant, and text inherits your
app's font. Override any of it:

```dart
NotchToaster(
  style: const NotchToastStyle(
    backgroundColor: Color(0xFF0A0A0A),
    foregroundColor: Colors.white,
    textStyle: TextStyle(fontFamily: 'Inter'),
    notchRadius: 18,
  ),
  child: child!,
)
```

### Multiple toasters and tests

`toast` is a global `NotchToastController`. Create your own controller and
pass it to `NotchToaster(controller: …)` for an isolated toaster, such as in
widget tests.

## Accessibility

Toasts are live regions, so screen readers announce changes without moving
focus. Dismissible toasts close with their button or Escape (ignored while a
text field has focus), and when the platform asks to reduce motion the island
keeps a brief opacity fade but drops all movement.

## Example

See [`example/`](example/lib/main.dart) for a playground covering every toast
type, the promise and update-in-place flows, both positions and modes, and all
animation presets.

## License

[MIT](LICENSE). Based on
[notch-toast](https://github.com/Devsethi3/notch-toast) by the notch-toast
contributors, also MIT-licensed.
