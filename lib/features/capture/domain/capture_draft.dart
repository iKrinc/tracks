import 'package:tracks/data/tables.dart';
import 'package:tracks/features/capture/domain/quick_add_parser.dart';
import 'package:tracks/features/capture/domain/sms_parser.dart';

/// Everything the Confirm Card needs to pre-fill, from any capture source.
/// Hints are unresolved: the sheet matches them against the user's accounts.
class CaptureDraft {
  const CaptureDraft({
    required this.type,
    required this.source,
    this.amountPaise,
    this.note = '',
    this.merchant,
    this.date,
    this.accountHint,
    this.accountLast4,
    this.bankHint,
    this.toAccountHint,
    this.toAccountLast4,
    this.tags = '',
    this.categoryText = '',
    this.refNo,
    this.rawText,
  });

  final TxnType type;
  final TxnSource source;
  final int? amountPaise;
  final String note;
  final String? merchant;

  /// Date only; null means "today".
  final DateTime? date;
  final String? accountHint;
  final String? accountLast4;
  final String? bankHint;
  final String? toAccountHint;
  final String? toAccountLast4;

  /// Comma-separated.
  final String tags;

  /// Words to guess a category from (description, merchant, flags).
  final String categoryText;
  final String? refNo;

  /// Original text, stored for audit.
  final String? rawText;
}

sealed class CaptureOutcome {
  const CaptureOutcome();
}

class CaptureReady extends CaptureOutcome {
  const CaptureReady(this.draft);
  final CaptureDraft draft;
}

class CaptureIgnored extends CaptureOutcome {
  const CaptureIgnored(this.message);

  /// User-facing reason, shown in a SnackBar.
  final String message;
}

/// A line typed into the quick-add bar.
CaptureOutcome captureFromQuickAdd(
  String text, {
  required DateTime now,
  required Set<String> accountKeywords,
}) {
  final r = parseQuickAdd(text, now: now, accountKeywords: accountKeywords);
  if (r == null) {
    return const CaptureIgnored('Add an amount, e.g. "chai 20"');
  }
  return CaptureReady(_fromQuickAdd(r, text.trim()));
}

/// Text shared into the app: a bank/UPI SMS, or failing that a quick-add
/// line (e.g. "chai 20" shared from a notes app).
CaptureOutcome captureFromSharedText(
  String text, {
  required DateTime now,
  required Set<String> accountKeywords,
}) {
  final raw = text.trim();
  final sms = parseBankSms(raw);
  switch (sms.kind) {
    case SmsKind.debit || SmsKind.credit:
      return CaptureReady(_fromSms(sms, raw));
    case SmsKind.ignore:
      switch (sms.ignoreReason) {
        case SmsIgnoreReason.otp:
          return const CaptureIgnored("That's an OTP, nothing to add");
        case SmsIgnoreReason.noAmount:
          return CaptureReady(
            CaptureDraft(
              type: TxnType.expense,
              source: TxnSource.sms,
              rawText: raw,
            ),
          );
        case SmsIgnoreReason.noTransaction || null:
          final quick = parseQuickAdd(
            raw,
            now: now,
            accountKeywords: accountKeywords,
          );
          if (quick != null) return CaptureReady(_fromQuickAdd(quick, raw));
          return const CaptureIgnored('No transaction found in that message');
      }
  }
}

CaptureDraft _fromQuickAdd(QuickAddResult r, String raw) {
  final person = r.person;
  final desc = r.description;
  String join(String s) => desc.isEmpty ? s : '$desc · $s';
  final note = switch (r.kind) {
    QuickAddKind.lent when person != null => join('Lent to $person'),
    QuickAddKind.borrowed when person != null => join('Borrowed from $person'),
    _ when person != null => join(person),
    _ => desc,
  };
  return CaptureDraft(
    type: switch (r.kind) {
      QuickAddKind.income || QuickAddKind.borrowed => TxnType.income,
      QuickAddKind.transfer => TxnType.transfer,
      QuickAddKind.expense || QuickAddKind.lent => TxnType.expense,
    },
    source: TxnSource.quickText,
    amountPaise: r.amountPaise,
    note: note,
    date: r.date,
    accountHint: r.accountHint,
    toAccountHint: r.toAccountHint,
    tags: switch (r.kind) {
      QuickAddKind.lent => 'lent',
      QuickAddKind.borrowed => 'borrowed',
      _ => '',
    },
    categoryText: desc,
    rawText: raw,
  );
}

CaptureDraft _fromSms(SmsParseResult r, String raw) {
  final atm = r.channel == SmsChannel.atm && r.kind == SmsKind.debit;
  final cardPayment = r.flags.contains(SmsFlag.cardPayment);
  final type = atm || cardPayment
      ? TxnType.transfer
      : (r.kind == SmsKind.debit ? TxnType.expense : TxnType.income);
  final flagWords = [
    if (r.flags.contains(SmsFlag.refund)) 'refund',
    if (r.flags.contains(SmsFlag.emi)) 'emi',
  ];
  return CaptureDraft(
    type: type,
    source: TxnSource.sms,
    amountPaise: r.amountPaise,
    note: atm ? 'ATM withdrawal' : (r.merchant ?? ''),
    merchant: r.merchant,
    date: r.date,
    // A card bill payment moves money *into* the card; the paying bank
    // account usually isn't in the SMS.
    accountLast4: cardPayment ? null : r.accountLast4,
    bankHint: cardPayment ? null : r.bankHint,
    toAccountHint: atm ? 'cash' : null,
    toAccountLast4: cardPayment ? r.accountLast4 : null,
    tags: [
      if (r.flags.contains(SmsFlag.autopay)) 'autopay',
      if (r.flags.contains(SmsFlag.emi)) 'emi',
    ].join(','),
    categoryText: [r.merchant ?? '', ...flagWords].join(' ').trim(),
    refNo: r.refNo,
    rawText: raw,
  );
}
