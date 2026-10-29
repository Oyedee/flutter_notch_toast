import 'package:flutter/material.dart';
import 'package:flutter_notch_toast/flutter_notch_toast.dart';

void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key});

  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  NotchPosition _position = NotchPosition.topCenter;
  NotchMode _mode = NotchMode.attached;
  NotchAnimationPreset _animation = NotchAnimationPreset.fluid;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'flutter_notch_toast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey),
      builder: (context, child) => NotchToaster(
        position: _position,
        mode: _mode,
        animation: _animation,
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 72, 24, 96),
            children: [
              Text(
                'flutter_notch_toast',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              _Section(
                title: 'Types',
                children: [
                  FilledButton.tonal(
                    onPressed: () => toast('Copied to clipboard'),
                    child: const Text('Default'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => toast.success('Changes saved'),
                    child: const Text('Success'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => toast.error(
                      'Unable to save changes',
                      action: NotchToastAction(
                        label: 'Retry',
                        onPressed: () => toast.success('Saved on retry'),
                      ),
                    ),
                    child: const Text('Error + action'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => toast.warning('Storage almost full'),
                    child: const Text('Warning'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => toast.info('New version available'),
                    child: const Text('Info'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => toast.loading('Uploading'),
                    child: const Text('Loading'),
                  ),
                ],
              ),
              _Section(
                title: 'Flows',
                children: [
                  FilledButton(
                    onPressed: () => toast
                        .promise(
                          Future.delayed(
                            const Duration(seconds: 2),
                            () => 'settings',
                          ),
                          loading: 'Saving changes',
                          successTitle: (value) => 'Saved $value',
                          error: 'Unable to save',
                        )
                        .ignore(),
                    child: const Text('Promise'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final id = toast.loading('Connecting');
                      await Future<void>.delayed(const Duration(seconds: 1));
                      toast.update(id, title: 'Syncing 248 files');
                      await Future<void>.delayed(const Duration(seconds: 1));
                      toast.update(
                        id,
                        title: 'All files synced',
                        type: NotchToastType.success,
                        duration: const Duration(seconds: 3),
                        dismissible: false,
                      );
                    },
                    child: const Text('Update in place'),
                  ),
                  OutlinedButton(
                    onPressed: () => toast.dismiss(),
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
              _Section(
                title: 'Position',
                children: [
                  SegmentedButton(
                    segments: const [
                      ButtonSegment(
                        value: NotchPosition.topCenter,
                        label: Text('Top'),
                      ),
                      ButtonSegment(
                        value: NotchPosition.bottomCenter,
                        label: Text('Bottom'),
                      ),
                    ],
                    selected: {_position},
                    onSelectionChanged: (value) =>
                        setState(() => _position = value.single),
                  ),
                  SegmentedButton(
                    segments: const [
                      ButtonSegment(
                        value: NotchMode.attached,
                        label: Text('Attached'),
                      ),
                      ButtonSegment(
                        value: NotchMode.floating,
                        label: Text('Floating'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (value) =>
                        setState(() => _mode = value.single),
                  ),
                ],
              ),
              _Section(
                title: 'Animation',
                children: [
                  for (final preset in NotchAnimationPreset.values)
                    ChoiceChip(
                      label: Text(preset.name),
                      selected: _animation == preset,
                      onSelected: (_) {
                        setState(() => _animation = preset);
                        toast.success('Animation: ${preset.name}');
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: children),
        ],
      ),
    );
  }
}
