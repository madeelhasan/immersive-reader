import 'package:flutter_test/flutter_test.dart';
import 'package:immersive_reader/progress/sm2_scheduler.dart';

void main() {
  test('Case A: single neutral exposure from default new-word state', () {
    final scheduler = Sm2Scheduler();
    final input = WordProgress();
    final result = scheduler.recordExposure(input, ExposureOutcome.neutral);
    expect(result.exposures, 1);
    expect(result.easeFactor, closeTo(2.5, 1e-9));
    expect(result.intervalDays, closeTo(2.5, 1e-9));
    expect(result.timesToggledBack, 0);
    expect(result.timesToggledForward, 0);
    expect(result.status, 'introduced');
  });

  test('Case B: toggledBack from default new-word state', () {
    final scheduler = Sm2Scheduler();
    final input = WordProgress();
    final result = scheduler.recordExposure(input, ExposureOutcome.toggledBack);
    expect(result.exposures, 1);
    expect(result.easeFactor, closeTo(2.3, 1e-9));
    expect(result.intervalDays, closeTo(1, 1e-9));
    expect(result.timesToggledBack, 1);
    expect(result.timesToggledForward, 0);
    expect(result.status, 'introduced');
  });

  test('Case C: toggledForward from default new-word state', () {
    final scheduler = Sm2Scheduler();
    final input = WordProgress();
    final result = scheduler.recordExposure(input, ExposureOutcome.toggledForward);
    expect(result.exposures, 1);
    expect(result.easeFactor, closeTo(2.65, 1e-9));
    expect(result.intervalDays, closeTo(2.65, 1e-9));
    expect(result.timesToggledBack, 0);
    expect(result.timesToggledForward, 1);
    expect(result.status, 'introduced');
  });

  test('Case D: three consecutive neutral exposures reach reinforced', () {
    final scheduler = Sm2Scheduler();
    var current = WordProgress();
    current = scheduler.recordExposure(current, ExposureOutcome.neutral);
    current = scheduler.recordExposure(current, ExposureOutcome.neutral);
    current = scheduler.recordExposure(current, ExposureOutcome.neutral);
    expect(current.exposures, 3);
    expect(current.easeFactor, closeTo(2.5, 1e-9));
    expect(current.intervalDays, closeTo(15.625, 1e-9));
    expect(current.status, 'reinforced');
  });

  test('Case E: six consecutive neutral exposures reach learned', () {
    final scheduler = Sm2Scheduler();
    var current = WordProgress();
    for (int i = 0; i < 6; i++) {
      current = scheduler.recordExposure(current, ExposureOutcome.neutral);
    }
    expect(current.exposures, 6);
    expect(current.easeFactor, closeTo(2.5, 1e-9));
    expect(current.intervalDays, closeTo(244.140625, 1e-9));
    expect(current.status, 'learned');
  });

  test('Case F: toggle-back can demote status from learned to reinforced', () {
    final scheduler = Sm2Scheduler();
    final input = WordProgress(
      exposures: 6,
      easeFactor: 2.5,
      intervalDays: 244.140625,
      status: 'learned',
    );
    final result = scheduler.recordExposure(input, ExposureOutcome.toggledBack);
    expect(result.exposures, 7);
    expect(result.easeFactor, closeTo(2.3, 1e-9));
    expect(result.intervalDays, closeTo(1, 1e-9));
    expect(result.timesToggledBack, 1);
    expect(result.timesToggledForward, 0);
    expect(result.status, 'reinforced');
  });

  test('Case G: easeFactor cannot drop below 1.3 floor', () {
    final scheduler = Sm2Scheduler();
    var current = WordProgress(easeFactor: 1.4);
    current = scheduler.recordExposure(current, ExposureOutcome.toggledBack);
    expect(current.easeFactor, closeTo(1.3, 1e-9));
    current = scheduler.recordExposure(current, ExposureOutcome.toggledBack);
    expect(current.easeFactor, closeTo(1.3, 1e-9));
  });

  test('Case H: easeFactor cannot rise above 2.8 ceiling', () {
    final scheduler = Sm2Scheduler();
    final input = WordProgress(easeFactor: 2.75);
    final result = scheduler.recordExposure(input, ExposureOutcome.toggledForward);
    expect(result.easeFactor, closeTo(2.8, 1e-9));
  });
}
