import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tracks/app/icons.dart';
import 'package:tracks/app/providers.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/app/widgets/hero.dart';
import 'package:tracks/core/dates.dart';
import 'package:tracks/core/money.dart';
import 'package:tracks/data/app_database.dart';
import 'package:tracks/features/insights/domain/reports.dart';
import 'package:tracks/features/transactions/domain/summary.dart';
import 'package:tracks/features/transactions/presentation/search_screen.dart';

/// Two-series chart colours (TracksTokens.seriesA/B): validated categorical
/// slots, not the app's green/pink, which fail CVD separation (ΔE 3.6).
({Color a, Color b}) _seriesColors(ThemeData t) =>
    (a: t.tokens.seriesA, b: t.tokens.seriesB);

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _year = false;
  DateTime _month = monthStart(DateTime.now());
  TxnType _kind = TxnType.expense;

  DateTime get _from => _year ? DateTime(_month.year) : _month;
  DateTime get _to =>
      _year ? DateTime(_month.year + 1) : nextMonthStart(_month);
  DateTime get _prevFrom => _year
      ? DateTime(_month.year - 1)
      : DateTime(_month.year, _month.month - 1);
  String get _label => _year ? '${_month.year}' : monthLabel(_month);
  String get _prevLabel =>
      _year ? '${_month.year - 1}' : monthLabel(_prevFrom).split(' ').first;

  SearchArgs _args({TxnType? type, int? categoryId}) => _year
      ? SearchArgs.year(_month.year, type: type, categoryId: categoryId)
      : SearchArgs.month(_month, type: type, categoryId: categoryId);

  void _shift(int by) => setState(
    () => _month = _year
        ? DateTime(_month.year + by, _month.month)
        : DateTime(_month.year, _month.month + by),
  );

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allDatedTxnsProvider).value ?? const <DatedTxn>[];
    final lookup = {
      for (final kind in CategoryKind.values)
        for (final c
            in ref.watch(categoriesProvider(kind)).value ?? const <Category>[])
          c.id: c,
    };

    bool inRange(DatedTxn t, DateTime from, DateTime to) =>
        !t.occurredAt.isBefore(from) && t.occurredAt.isBefore(to);
    final current = all.where((t) => inRange(t, _from, _to)).toList();
    final previous = all.where((t) => inRange(t, _prevFrom, _from)).toList();
    int sum(List<DatedTxn> l, TxnType k) =>
        l.where((t) => t.type == k).fold(0, (a, t) => a + t.amountPaise);
    final now = sum(current, _kind);
    final before = sum(previous, _kind);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(-1),
            ),
            Flexible(
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(_label)),
            ),
            IconButton(
              tooltip: 'Next',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shift(1),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Month')),
                    ButtonSegment(value: true, label: Text('Year')),
                  ],
                  selected: {_year},
                  onSelectionChanged: (s) => setState(() => _year = s.first),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SegmentedButton<TxnType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: TxnType.expense, label: Text('Spent')),
                    ButtonSegment(value: TxnType.income, label: Text('Income')),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ComparisonHero(
            title: _kind == TxnType.expense
                ? 'Spent in $_label'
                : 'Income in $_label',
            paise: now,
            previousPaise: before,
            previousLabel: _prevLabel,
            lowerIsBetter: _kind == TxnType.expense,
            onTap: () => context.push('/search', extra: _args(type: _kind)),
          ),
          const SizedBox(height: 16),
          if (_year)
            _ChartCard(
              title: 'Month by month',
              legend: const ['Income', 'Spent'],
              child: _YearBars(
                months: totalsByMonth(all, _month.year),
                onTapMonth: (m) =>
                    context.push('/search', extra: SearchArgs.month(m)),
              ),
            )
          else
            _ChartCard(
              title: _kind == TxnType.expense ? 'Spending pace' : 'Income pace',
              legend: [monthLabel(_month).split(' ').first, _prevLabel],
              dashedSecond: true,
              child: _PaceLine(
                current: cumulativeSpend(
                  all,
                  _month,
                  today: DateTime.now(),
                  type: _kind,
                ),
                previous: cumulativeSpend(all, _prevFrom, type: _kind),
              ),
            ),
          const SizedBox(height: 16),
          _CategoryCard(
            slices: categoryBreakdown(
              current,
              _kind,
              parentOf: {for (final c in lookup.values) c.id: c.parentId},
            ),
            categories: lookup,
            onTap: (id) => context.push(
              '/search',
              extra: _args(type: _kind, categoryId: id),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonHero extends StatelessWidget {
  const _ComparisonHero({
    required this.title,
    required this.paise,
    required this.previousPaise,
    required this.previousLabel,
    required this.lowerIsBetter,
    required this.onTap,
  });

  final String title;
  final int paise;
  final int previousPaise;
  final String previousLabel;
  final bool lowerIsBetter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final diff = paise - previousPaise;
    final String compare;
    if (previousPaise == 0) {
      compare = 'Nothing recorded in $previousLabel';
    } else if (diff == 0) {
      compare = 'Same as $previousLabel';
    } else {
      final pct = (diff.abs() * 100 / previousPaise).round();
      compare =
          '${formatPaise(diff.abs(), hideZeroPaise: true)} ($pct%) '
          '${diff > 0 ? 'more' : 'less'} than $previousLabel';
    }
    final good = previousPaise != 0 && diff != 0 && (diff < 0) == lowerIsBetter;
    return HeroCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              color: tokens.heroMuted,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: AnimatedAmount(
              paise,
              semanticsPrefix: '$title ',
              style: theme.textTheme.displaySmall?.copyWith(
                color: tokens.heroInk,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (previousPaise != 0 && diff != 0)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    diff > 0 ? Icons.trending_up : Icons.trending_down,
                    size: 18,
                    color: good ? theme.incomeColor : theme.expenseColor,
                  ),
                ),
              Flexible(
                child: Text(
                  compare,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tokens.heroInk,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.legend,
    required this.child,
    this.dashedSecond = false,
  });

  final String title;
  final List<String> legend;
  final Widget child;
  final bool dashedSecond;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _seriesColors(theme);
    Widget key(String label, Color color, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: dashed ? 2 : 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
    // On `surface`: series B (#EB6834) needs it to stay above 3:1.
    return Card(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(TracksTokens.radiusCard),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              children: [
                key(legend[0], colors.a),
                key(
                  legend[1],
                  dashedSecond ? theme.colorScheme.outline : colors.b,
                  dashed: dashedSecond,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: child),
          ],
        ),
      ),
    );
  }
}

/// Recessive axes: muted labels, horizontal grid only.
FlTitlesData _titles(
  ThemeData theme, {
  required Widget Function(double, TitleMeta) bottom,
  double? bottomInterval,
}) {
  final style = theme.textTheme.labelSmall?.copyWith(
    color: theme.colorScheme.onSurfaceVariant,
  );
  return FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 40,
        getTitlesWidget: (v, meta) => v == meta.max
            ? const SizedBox.shrink()
            : SideTitleWidget(
                meta: meta,
                child: Text(compactPaise((v * 100).round()), style: style),
              ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 24,
        interval: bottomInterval,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          child: DefaultTextStyle.merge(style: style, child: bottom(v, meta)),
        ),
      ),
    ),
  );
}

FlGridData _grid(ThemeData theme) => FlGridData(
  drawVerticalLine: false,
  getDrawingHorizontalLine: (_) => FlLine(
    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
    strokeWidth: 1,
  ),
);

/// Cumulative spend this month vs last (rupees as double for drawing only).
class _PaceLine extends StatelessWidget {
  const _PaceLine({required this.current, required this.previous});

  final List<int> current;
  final List<int> previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _seriesColors(theme);
    List<FlSpot> spots(List<int> v) => [
      for (var i = 0; i < v.length; i++) FlSpot(i + 1.0, v[i] / 100),
    ];
    if (current.every((v) => v == 0) && previous.every((v) => v == 0)) {
      return const Center(child: Text('Nothing recorded yet'));
    }
    return Semantics(
      label:
          'Running total. This month ${spokenPaise(current.lastOrNull ?? 0)} '
          'so far; last month ${spokenPaise(previous.lastOrNull ?? 0)} in total.',
      excludeSemantics: true,
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: 31,
          minY: 0,
          gridData: _grid(theme),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            theme,
            bottomInterval: 5,
            // Day 1 and every 5th day; the last day's label would collide.
            bottom: (v, _) => Text(v == 1 || v % 5 == 0 ? '${v.toInt()}' : ''),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.barIndex == 0 ? 'This' : 'Last'} · day ${s.x.toInt()}\n'
                    '${formatPaise((s.y * 100).round(), hideZeroPaise: true)}',
                    TextStyle(
                      color: theme.colorScheme.onInverseSurface,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots(current),
              color: colors.a,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colors.a.withValues(alpha: 0.10),
              ),
            ),
            LineChartBarData(
              spots: spots(previous),
              color: theme.colorScheme.outline,
              barWidth: 2,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _YearBars extends StatelessWidget {
  const _YearBars({required this.months, required this.onTapMonth});

  final List<(DateTime, Totals)> months;
  final ValueChanged<DateTime> onTapMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _seriesColors(theme);
    BarChartRodData rod(int paise, Color c) => BarChartRodData(
      toY: paise / 100,
      color: c,
      width: 7,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    );
    final income = months.fold(0, (a, m) => a + m.$2.incomePaise);
    final spent = months.fold(0, (a, m) => a + m.$2.expensePaise);
    return Semantics(
      label:
          'Month by month for ${months.first.$1.year}: income '
          '${spokenPaise(income)}, spent ${spokenPaise(spent)}. '
          'Tap a month to open its transactions.',
      excludeSemantics: true,
      child: BarChart(
        BarChartData(
          gridData: _grid(theme),
          borderData: FlBorderData(show: false),
          titlesData: _titles(
            theme,
            bottom: (v, _) => Text('JFMAMJJASOND'[v.toInt()]),
          ),
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              final i = response?.spot?.touchedBarGroupIndex;
              if (event is FlTapUpEvent && i != null) onTapMonth(months[i].$1);
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => theme.colorScheme.inverseSurface,
              getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                '${monthLabel(months[gi].$1).split(' ').first.substring(0, 3)} '
                '${ri == 0 ? 'income' : 'spent'}\n'
                '${formatPaise((rod.toY * 100).round(), hideZeroPaise: true)}',
                TextStyle(
                  color: theme.colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < months.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 2,
                barRods: [
                  rod(months[i].$2.incomePaise, colors.a),
                  rod(months[i].$2.expensePaise, colors.b),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Part-to-whole as ranked horizontal bars: one hue (identity comes from
/// the label and icon, never colour), direct labels, tap for the rows.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.slices,
    required this.categories,
    required this.onTap,
  });

  final List<CategorySlice> slices;
  final Map<int, Category> categories;
  final ValueChanged<int?> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = slices.isEmpty ? 1 : slices.first.sumPaise;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By category', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (slices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Nothing in this period')),
              ),
            for (final s in slices)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onTap(s.categoryId),
                child: Semantics(
                  label:
                      '${categories[s.categoryId]?.name ?? 'Uncategorised'}, '
                      '${spokenPaise(s.sumPaise)}, ${s.shareBp ~/ 100} percent',
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(
                            categories[s.categoryId]?.color ??
                                Palette.sand.toARGB32(),
                          ),
                          foregroundColor: Colors.black87,
                          child: Icon(
                            iconFor(categories[s.categoryId]?.icon ?? ''),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      categories[s.categoryId]?.name ??
                                          'Uncategorised',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    formatPaise(
                                      s.sumPaise,
                                      hideZeroPaise: true,
                                    ),
                                    style: const TextStyle(
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 48,
                                    child: Text(
                                      '${(s.shareBp / 100).round()}%',
                                      textAlign: TextAlign.end,
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: s.sumPaise / top,
                                  minHeight: 6,
                                  color: scheme.primary,
                                  backgroundColor: scheme.surfaceContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
