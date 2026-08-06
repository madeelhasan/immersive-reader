class WordProgress {
  final int exposures;
  final int timesToggledBack;
  final int timesToggledForward;
  final double easeFactor;
  final double intervalDays;
  final String status;

  const WordProgress({
    this.exposures = 0,
    this.timesToggledBack = 0,
    this.timesToggledForward = 0,
    this.easeFactor = 2.5,
    this.intervalDays = 1,
    this.status = 'new',
  });
}

enum ExposureOutcome { neutral, toggledBack, toggledForward }

class Sm2Scheduler {
  static const double minEaseFactor = 1.3;
  static const double maxEaseFactor = 2.8;

  WordProgress recordExposure(WordProgress current, ExposureOutcome outcome) {
    final int newExposures = current.exposures + 1;
    int newTimesToggledBack = current.timesToggledBack;
    int newTimesToggledForward = current.timesToggledForward;
    double newEaseFactor;
    double newIntervalDays;

    switch (outcome) {
      case ExposureOutcome.neutral:
        newEaseFactor = current.easeFactor;
        newIntervalDays = current.intervalDays * current.easeFactor;
        break;
      case ExposureOutcome.toggledBack:
        newEaseFactor = current.easeFactor - 0.2;
        if (newEaseFactor < minEaseFactor) {
          newEaseFactor = minEaseFactor;
        }
        newIntervalDays = 1;
        newTimesToggledBack += 1;
        break;
      case ExposureOutcome.toggledForward:
        newEaseFactor = current.easeFactor + 0.15;
        if (newEaseFactor > maxEaseFactor) {
          newEaseFactor = maxEaseFactor;
        }
        newIntervalDays = current.intervalDays * newEaseFactor;
        newTimesToggledForward += 1;
        break;
    }

    String newStatus;
    if (newExposures >= 6 && newEaseFactor >= 2.5) {
      newStatus = 'learned';
    } else if (newExposures >= 3 && newEaseFactor >= 2.0) {
      newStatus = 'reinforced';
    } else if (newExposures >= 1) {
      newStatus = 'introduced';
    } else {
      newStatus = 'new';
    }

    return WordProgress(
      exposures: newExposures,
      timesToggledBack: newTimesToggledBack,
      timesToggledForward: newTimesToggledForward,
      easeFactor: newEaseFactor,
      intervalDays: newIntervalDays,
      status: newStatus,
    );
  }
}
