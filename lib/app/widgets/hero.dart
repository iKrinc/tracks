import 'package:flutter/material.dart';
import 'package:tracks/app/theme.dart';
import 'package:tracks/core/money.dart';

/// The gradient card that leads a screen. Content uses [TracksTokens.heroInk].
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.child, this.padding, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Makes the whole card tappable, with the splash drawn on the gradient.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TracksTokens.radiusHero),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tokens.heroGradient,
        ),
      ),
      // Transparent Material so InkWells inside (and [onTap]) splash on top
      // of the gradient rather than invisibly underneath it.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TracksTokens.radiusHero),
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: tokens.heroInk),
              child: IconTheme.merge(
                data: IconThemeData(color: tokens.heroInk),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An amount that counts to its new value (350 ms), with tabular digits so
/// it doesn't jitter, and a spoken label.
class AnimatedAmount extends StatelessWidget {
  const AnimatedAmount(
    this.paise, {
    super.key,
    this.style,
    this.prefix = '',
    this.semanticsPrefix = '',
  });

  final int paise;
  final TextStyle? style;
  final String prefix;
  final String semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: '$semanticsPrefix${spokenPaise(paise)}',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: paise.toDouble()),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        // Display only: rounds back to whole paise. Stored values never
        // touch double.
        builder: (context, v, _) => Text(
          '$prefix${formatPaise(v.round())}',
          maxLines: 1,
          style: (style ?? const TextStyle()).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// "↑ ₹51,250" style figure for a hero: ink text, coloured arrow.
class HeroFigure extends StatelessWidget {
  const HeroFigure({
    super.key,
    required this.label,
    required this.paise,
    required this.income,
    this.onTap,
  });

  final String label;
  final int paise;
  final bool income;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = theme.tokens;
    final arrowColor = income ? theme.incomeColor : theme.expenseColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tokens.heroChip,
                shape: BoxShape.circle,
              ),
              child: Icon(
                income ? Icons.south_west : Icons.north_east,
                size: 18,
                color: arrowColor,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.heroMuted,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedAmount(
                      paise,
                      prefix: income ? '+' : '−',
                      semanticsPrefix: '$label ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: tokens.heroInk,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
