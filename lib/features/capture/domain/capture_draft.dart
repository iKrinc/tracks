import 'package:tracks/data/tables.dart';
import 'package:tracks/features/capture/domain/quick_add_parser.dart';
import 'package:tracks/features/capture/domain/screenshot_parser.dart';
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
    this.accountId,
    this.toAccountId,
    this.categoryId,
    this.linkedRecurringId,
    this.person,
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

  /// Known ids (e.g. paying a recurring bill) win over hints and guesses.
  final int? accountId;
  final int? toAccountId;
  final int? categoryId;

  /// Saving marks this recurring item paid.
  final int? linkedRecurringId;

  /// Someone money was lent to or borrowed from ("lent 2000 to ravi").
  final String? person;
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

/// OCR text of a shared payment screenshot (GPay / PhonePe / Paytm / bank
/// app). Falls back to the SMS parser for screenshots of SMS.
CaptureOutcome captureFromScreenshotText(String text) {
  final raw = text.trim();
  final shot = parsePaymentScreenshot(raw);
  if (shot != null) {
    final who = shot.merchant ?? shot.vpa;
    return CaptureReady(
      CaptureDraft(
        type: shot.kind == SmsKind.credit ? TxnType.income : TxnType.expense,
        source: TxnSource.screenshot,
        amountPaise: shot.amountPaise,
        note: who ?? '',
        merchant: shot.vpa ?? shot.merchant,
        date: shot.date,
        accountLast4: shot.accountLast4,
        bankHint: shot.bankHint,
        categoryText: '${shot.merchant ?? ''} ${shot.vpa ?? ''}'.trim(),
        refNo: shot.refNo,
        rawText: raw,
      ),
    );
  }
  final sms = parseBankSms(raw);
  if (sms.kind != SmsKind.ignore) {
    final d = _fromSms(sms, raw);
    return CaptureReady(
      CaptureDraft(
        type: d.type,
        source: TxnSource.screenshot,
        amountPaise: d.amountPaise,
        note: d.note,
        merchant: d.merchant,
        date: d.date,
        accountLast4: d.accountLast4,
        bankHint: d.bankHint,
        toAccountHint: d.toAccountHint,
        toAccountLast4: d.toAccountLast4,
        tags: d.tags,
        categoryText: d.categoryText,
        refNo: d.refNo,
        rawText: raw,
      ),
    );
  }
  return const CaptureIgnored(
    "Couldn't find a payment in that screenshot. Try the receipt screen.",
  );
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
    person: r.kind == QuickAddKind.lent || r.kind == QuickAddKind.borrowed
        ? person
        : null,
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
