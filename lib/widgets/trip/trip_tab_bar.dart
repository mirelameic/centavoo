import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:centavoo/core/theme.dart';
import 'package:centavoo/l10n/arb/app_localizations.dart';

enum TripTab {
  summary(Icons.pie_chart_outline),
  top(Icons.bar_chart_outlined),
  time(Icons.calendar_month_outlined),
  cities(Icons.location_on_outlined),
  cats(Icons.category_outlined),
  tx(Icons.receipt_long_outlined);

  final IconData icon;
  const TripTab(this.icon);

  String label(AppLocalizations l10n) => switch (this) {
    TripTab.summary => l10n.tabSummary,
    TripTab.top => l10n.tabTop,
    TripTab.time => l10n.tabTime,
    TripTab.cities => l10n.tabCities,
    TripTab.cats => l10n.tabCats,
    TripTab.tx => l10n.tabTransactions,
  };
}

Widget _glassBar({required BuildContext context, required Widget child}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bar = ClipRRect(
    borderRadius: BorderRadius.circular(28),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        decoration: BoxDecoration(
          color: glassTint(context),
          borderRadius: BorderRadius.circular(28),
          border: isDark ? null : Border.all(color: lightDivider),
        ),
        child: child,
      ),
    ),
  );
  if (isDark) return bar;
  return DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
    ),
    child: bar,
  );
}

class TripTabsRow extends StatelessWidget {
  final TripTab? activeTab;
  final ValueChanged<TripTab> onTap;
  const TripTabsRow({super.key, required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: _glassBar(
          context: context,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final item in TripTab.values)
                  ChoiceChip(
                    label: Text(item.label(l10n)),
                    avatar: Icon(item.icon, size: 18),
                    selected: activeTab == item,
                    onSelected: (_) => onTap(item),
                    shape: const StadiumBorder(),
                    showCheckmark: false,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TripBottomNav extends StatelessWidget {
  final TripTab? activeTab;
  final ValueChanged<TripTab> onTap;
  const TripBottomNav({super.key, required this.activeTab, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hintColor = Theme.of(context).hintColor;
    final l10n = AppLocalizations.of(context)!;
    return _glassBar(
      context: context,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (final item in TripTab.values)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: activeTab == item ? primary.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(item.icon, size: 20, color: activeTab == item ? primary : hintColor),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            item.label(l10n),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 10,
                              color: activeTab == item ? primary : hintColor,
                              fontWeight: activeTab == item ? FontWeight.w600 : FontWeight.normal,
                            ),
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
