/// Settings key for the app lock ("on" / "off").
const appLockKey = 'appLock';

/// How long the app may sit in the background before it locks again. Long
/// enough that the biometric prompt itself (which briefly backgrounds the
/// app) and a quick hop to the SMS app don't trigger a relock.
const relockGrace = Duration(seconds: 30);

bool shouldRelock({
  required bool enabled,
  required DateTime? leftAt,
  required DateTime now,
  Duration grace = relockGrace,
}) => enabled && leftAt != null && now.difference(leftAt) > grace;
