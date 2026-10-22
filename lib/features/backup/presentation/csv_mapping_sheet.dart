import 'package:flutter/material.dart';
import 'package:tracks/features/backup/domain/csv_transactions.dart';

const _fieldLabels = {
  CsvField.date: 'Date',
  CsvField.amount: 'Amount',
  CsvField.type: 'Type (income/expense)',
  CsvField.account: 'Account',
  CsvField.toAccount: 'To account',
  CsvField.category: 'Category',
  CsvField.note: 'Note',
  CsvField.merchant: 'Merchant',
  CsvField.tags: 'Tags',
  CsvField.ref: 'Ref no.',
};

/// Lets the user confirm which CSV column holds which field.
class CsvMappingSheet extends StatefulWidget {
  const CsvMappingSheet({super.key, required this.table});

  final List<List<String>> table;

  @override
  State<CsvMappingSheet> createState() => _CsvMappingSheetState();
}

class _CsvMappingSheetState extends State<CsvMappingSheet> {
  late final CsvMapping _mapping = guessMapping(widget.table.first);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headers = widget.table.first;
    final parsed = parseCsvRows(widget.table, _mapping);
    final ready =
        _mapping.containsKey(CsvField.date) &&
        _mapping.containsKey(CsvField.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Match columns', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${widget.table.length - 1} rows. Date and Amount are required; '
            'without a Type column, negative amounts are expenses.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final field in CsvField.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(_fieldLabels[field]!)),
                        Expanded(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _mapping[field],
                            hint: const Text('—'),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('—'),
                              ),
                              for (var i = 0; i < headers.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    headers[i].isEmpty
                                        ? 'Column ${i + 1}'
                                        : headers[i],
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              if (v == null) {
                                _mapping.remove(field);
                              } else {
                                _mapping[field] = v;
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ready
                ? '${parsed.rows.length} ready'
                      '${parsed.errors.isEmpty ? '' : ', ${parsed.errors.length} will be skipped'}'
                : 'Pick the Date and Amount columns',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: ready && parsed.rows.isNotEmpty
                ? () => Navigator.pop(context, _mapping)
                : null,
            icon: const Icon(Icons.check),
            label: Text('Import ${parsed.rows.length}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }
}
