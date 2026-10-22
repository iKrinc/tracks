import 'dart:math' as math;

/// Monthly EMI for a reducing-balance loan. [rateBp] is the yearly rate in
/// basis points (9.5% = 950). The rate factor needs pow(), so it's computed
/// in double and the result is rounded straight back to whole paise.
int emiPaise({
  required int principalPaise,
  required int rateBp,
  required int months,
}) {
  if (months <= 0) return principalPaise;
  if (rateBp == 0) return (principalPaise / months).ceil();
  final r = rateBp / 10000 / 12;
  final f = math.pow(1 + r, months);
  return (principalPaise * r * f / (f - 1)).round();
}

typedef LoanProgress = ({int paidPaise, int percentPaid, int? monthsLeft});

/// How far along a loan or IOU is. Months left is estimated from the EMI and
/// rate (standard amortisation), when both are known.
LoanProgress loanProgress({
  required int principalPaise,
  required int outstandingPaise,
  int? emiPaise,
  int? rateBp,
}) {
  final owed = outstandingPaise.clamp(0, principalPaise);
  final paid = principalPaise - owed;
  final percent = principalPaise == 0 ? 100 : paid * 100 ~/ principalPaise;
  int? months;
  final emi = emiPaise;
  if (emi != null && emi > 0 && owed > 0) {
    if (rateBp == null || rateBp == 0) {
      months = (owed / emi).ceil();
    } else {
      final r = rateBp / 10000 / 12;
      final x = 1 - r * owed / emi;
      // EMI below the monthly interest never pays off.
      months = x <= 0 ? null : (-math.log(x) / math.log(1 + r)).ceil();
    }
  } else if (owed == 0) {
    months = emi == null ? null : 0;
  }
  return (paidPaise: paid, percentPaid: percent, monthsLeft: months);
}
