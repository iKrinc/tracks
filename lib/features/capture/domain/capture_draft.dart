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
    this.time,
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

  /// Time of day from the SMS/receipt; null means "now".
  final ClockTime? time;
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

/// Several transactions found at once (e.g. a screenshot of an SMS thread).
class CaptureMany extends CaptureOutcome {
  const CaptureMany(this.drafts);
  final List<CaptureDraft> drafts;
}

class CaptureIgnored extends CaptureOutcome {
  const CaptureIgnored(this.message);

  /// User-facing reason, shown in a SnackBar.
  final String message;
}

/// Runs [parse]; if it throws (a format nobody foresaw), falls back to a
/// blank draft that keeps the raw text so nothing is lost and nothing
/// crashes. The user fills it in by hand.
CaptureOutcome _safely(
  String raw,
  TxnSource source,
  CaptureOutcome Function() parse,
) {
  try {
    return parse();
  } catch (_) {
    return CaptureReady(
      CaptureDraft(
        type: TxnType.expense,
        source: source,
        note: '',
        rawText: raw,
      ),
    );
  }
}

/// A line typed into the quick-add bar.
CaptureOutcome captureFromQuickAdd(
  String text, {
  required DateTime now,
  required Set<String> accountKeywords,
}) => _safely(
  text,
  TxnSource.quickText,
  () => _quickAdd(text, now: now, accountKeywords: accountKeywords),
);

CaptureOutcome _quickAdd(
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
}) => _safely(
  text,
  TxnSource.sms,
  () => _sharedText(text, now: now, accountKeywords: accountKeywords),
);

CaptureOutcome _sharedText(
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
CaptureOutcome captureFromScreenshotText(String text) =>
    _safely(text, TxnSource.screenshot, () => _screenshotText(text));

/// OCR'd screenshot as ML Kit blocks (one per bubble/paragraph). A payment
/// receipt gives one draft; a screenshot of an SMS thread gives one per
/// message, in order, with repeats (same ref no.) dropped.
CaptureOutcome captureFromScreenshotBlocks(List<String> blocks) {
  final full = blocks.join('\n');
  return _safely(full, TxnSource.screenshot, () {
    if (blocks.isEmpty) {
      return const CaptureIgnored("Couldn't find any text in that image");
    }
    final receipt = parsePaymentScreenshot(full);
    if (receipt != null) return _screenshotText(full);
    final drafts = <CaptureDraft>[];
    final seen = <String>{};
    // OCR wraps bubble lines; the SMS parser wants one flowing sentence.
    // A line ending in - or / is a date OCR wrapped ("22-10-" / "26").
    String flat(String b) => b
        .replaceAll(RegExp(r'(?<=\d[-/])\s*\n\s*(?=\d)'), '')
        .replaceAll(RegExp(r'\s*\n\s*'), ' ')
        .trim();
    for (var i = 0; i < blocks.length; i++) {
      var text = flat(blocks[i]);
      var sms = parseBankSms(text);
      // OCR sometimes splits one bubble into two blocks. Join it with the
      // next block when that one means nothing alone and joining reads
      // more (an amount at all, or the date / ref no. the first half lacks).
      int filled(SmsParseResult r) => r.kind == SmsKind.ignore
          ? 0
          : 1 + (r.date == null ? 0 : 1) + (r.refNo == null ? 0 : 1);
      var joined = text;
      var used = 0;
      for (var j = 1; j <= 3 && i + j < blocks.length && filled(sms) < 3; j++) {
        final next = flat(blocks[i + j]);
        if (parseBankSms(next).kind != SmsKind.ignore) break;
        joined = '$joined $next';
        final again = parseBankSms(joined);
        if (filled(again) > filled(sms)) {
          text = joined;
          sms = again;
          used = j;
        }
      }
      i += used;
      if (sms.kind == SmsKind.ignore) continue;
      final key = sms.refNo ?? '${sms.amountPaise}|${sms.date}|${sms.merchant}';
      if (!seen.add(key)) continue;
      drafts.add(_asScreenshot(_fromSms(sms, text)));
    }
    if (drafts.isEmpty) return _screenshotText(full);
    return drafts.length == 1
        ? CaptureReady(drafts.single)
        : CaptureMany(drafts);
  });
}

CaptureDraft _asScreenshot(CaptureDraft d) => CaptureDraft(
  type: d.type,
  source: TxnSource.screenshot,
  amountPaise: d.amountPaise,
  note: d.note,
  merchant: d.merchant,
  date: d.date,
  time: d.time,
  accountLast4: d.accountLast4,
  bankHint: d.bankHint,
  toAccountHint: d.toAccountHint,
  toAccountLast4: d.toAccountLast4,
  tags: d.tags,
  categoryText: d.categoryText,
  refNo: d.refNo,
  rawText: d.rawText,
);

CaptureOutcome _screenshotText(String text) {
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
        time: shot.time,
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
    return CaptureReady(_asScreenshot(_fromSms(sms, raw)));
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
    time: r.time,
    // A card bill payment moves money from the bank account (when the SMS
    // names it) *into* the card.
    accountLast4: cardPayment ? r.counterAccountLast4 : r.accountLast4,
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

/// Combines the captures of several shared screenshots into one review,
/// dropping repeats (same ref no., or same amount/date/payee).
CaptureOutcome mergeCaptures(List<CaptureOutcome> outcomes) {
  if (outcomes.length == 1) return outcomes.single;
  final drafts = <CaptureDraft>[];
  final seen = <String>{};
  for (final o in outcomes) {
    final found = switch (o) {
      CaptureReady(:final draft) => [draft],
      CaptureMany(:final drafts) => drafts,
      CaptureIgnored() => const <CaptureDraft>[],
    };
    for (final d in found) {
      final key = d.refNo ?? '${d.amountPaise}|${d.date}|${d.merchant}';
      if (seen.add(key)) drafts.add(d);
    }
  }
  if (drafts.isEmpty) {
    return outcomes.whereType<CaptureIgnored>().firstOrNull ??
        const CaptureIgnored('No payments found in those images');
  }
  return drafts.length == 1 ? CaptureReady(drafts.single) : CaptureMany(drafts);
}
