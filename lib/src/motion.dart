import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'controller.dart';

/// The CSS `cubic-bezier(0.16, 1, 0.3, 1)` ease used throughout.
const Curve notchEase = Cubic(0.16, 1, 0.3, 1);

/// A curve plus the duration it should run for.
class NotchMotion {
  const NotchMotion(this.curve, this.duration);

  final Curve curve;
  final Duration duration;
}

/// Samples a critically-or-under-damped spring from 0 to 1 so it can drive
/// ordinary implicit animations. Values may overshoot 1.
class SpringCurve extends Curve {
  SpringCurve({
    required double mass,
    required double stiffness,
    required double damping,
  }) : _simulation = SpringSimulation(
         SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
         0,
         1,
         0,
       ) {
    var t = 0.0;
    while (t < 3 && !_simulation.isDone(t)) {
      t += 1 / 240;
    }
    settleTime = Duration(microseconds: (t * 1e6).round());
  }

  final SpringSimulation _simulation;

  /// How long the spring takes to come to rest.
  late final Duration settleTime;

  @override
  double transformInternal(double t) =>
      _simulation.x(t * settleTime.inMicroseconds / 1e6);
}

NotchMotion _spring(double mass, double stiffness, double damping) {
  final curve = SpringCurve(mass: mass, stiffness: stiffness, damping: damping);
  return NotchMotion(curve, curve.settleTime);
}

final Map<NotchAnimationPreset, NotchMotion> notchPresets = {
  NotchAnimationPreset.fluid: _spring(0.62, 400, 32),
  NotchAnimationPreset.gooey: _spring(0.7, 280, 18),
  NotchAnimationPreset.smooth: const NotchMotion(
    notchEase,
    Duration(milliseconds: 380),
  ),
  NotchAnimationPreset.subtle: _spring(0.58, 340, 40),
  NotchAnimationPreset.snappy: _spring(0.48, 520, 34),
};

const NotchMotion contentMotion = NotchMotion(
  notchEase,
  Duration(milliseconds: 420),
);
const NotchMotion reducedMotionFade = NotchMotion(
  notchEase,
  Duration(milliseconds: 180),
);
