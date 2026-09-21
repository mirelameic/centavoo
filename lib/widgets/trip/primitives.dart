import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/category_icons.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/models/category.dart';
import 'package:centavoo/theme.dart';

class LegendRow {
  final String key;
  final Color color;
  final String label;
  final String? icon;
  final double amount;

  LegendRow({required this.key, required this.color, required this.label, this.icon, required this.amount});
}

Widget categoryDot(Color color) {
  return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

const hiddenAxis = AxisTitles(sideTitles: SideTitles(showTitles: false));

AxisTitles moneyLeftAxis({required String currency, double reservedSize = 64, double? interval}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: reservedSize,
      interval: interval,
      getTitlesWidget: (value, meta) => Text(money(value, currency: currency), style: const TextStyle(fontSize: 10)),
    ),
  );
}

AxisTitles sparseBottomAxis(List<String> labels, {int interval = 1}) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      getTitlesWidget: (value, meta) {
        final i = value.toInt();
        if (i < 0 || i >= labels.length || i % interval != 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(labels[i], style: const TextStyle(fontSize: 10)),
        );
      },
    ),
  );
}

DropdownMenuItem<String> categoryDropdownItem(
  Category category, {
  double iconSize = 16,
  double spacing = 8,
  TextStyle? textStyle,
}) {
  return DropdownMenuItem(
    value: category.id,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(categoryIcon(category.icon) ?? Icons.category_outlined, size: iconSize, color: hexColor(category.color)),
        SizedBox(width: spacing),
        Text(category.name, style: textStyle),
      ],
    ),
  );
}

Widget categoryFilterChip(Category category, {required bool selected, required ValueChanged<bool> onSelected}) {
  return FilterChip(
    label: Text(category.name),
    avatar: Icon(categoryIcon(category.icon) ?? Icons.category_outlined, size: 16, color: hexColor(category.color)),
    selected: selected,
    onSelected: onSelected,
  );
}

Widget categoryChip(BuildContext context, {required Color color, required String name, String? icon}) {
  final iconData = categoryIcon(icon);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      categoryDot(color),
      const SizedBox(width: 6),
      if (iconData != null) ...[
        Icon(iconData, size: 14, color: Theme.of(context).hintColor),
        const SizedBox(width: 6),
      ],
      Text(name, style: const TextStyle(fontSize: 14)),
    ],
  );
}

Widget sectionHeader(BuildContext context, String text, {bool first = false}) {
  return Padding(
    padding: EdgeInsets.only(top: first ? 0 : 32, bottom: 10),
    child: Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Theme.of(context).hintColor),
    ),
  );
}

class ToggleSeries {
  final String name;
  final Color color;
  final String? label;

  ToggleSeries({required this.name, required this.color, this.label});
}

Widget toggleLegend(
  BuildContext context, {
  required List<ToggleSeries> series,
  required Set<String> hidden,
  required ValueChanged<String> onToggle,
}) {
  final hintColor = Theme.of(context).hintColor;
  return Wrap(
    alignment: WrapAlignment.center,
    spacing: 16,
    runSpacing: 4,
    children: [
      for (final s in series)
        InkWell(
          onTap: () => onToggle(s.name),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(opacity: hidden.contains(s.name) ? 0.35 : 1, child: categoryDot(s.color)),
                const SizedBox(width: 6),
                Text(
                  s.label ?? s.name,
                  style: TextStyle(
                    fontSize: 13,
                    color: hidden.contains(s.name) ? hintColor : null,
                    decoration: hidden.contains(s.name) ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

Widget donutChart(
  BuildContext context, {
  required double size,
  required double thickness,
  required List<double> values,
  required List<Color> colors,
  required String centerLabel,
}) {
  return SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: size / 2 - thickness,
            startDegreeOffset: -90,
            sections: [
              for (var i = 0; i < values.length; i++)
                PieChartSectionData(value: values[i], color: colors[i], radius: thickness, showTitle: false),
            ],
          ),
        ),
        Text(centerLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

Widget summaryRow(
  BuildContext context, {
  required Widget leading,
  required List<Widget> metaLines,
  required String amount,
}) {
  final hintColor = Theme.of(context).hintColor;
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(style: const TextStyle(fontWeight: FontWeight.w600), child: leading),
              for (final line in metaLines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: DefaultTextStyle.merge(style: TextStyle(fontSize: 12, color: hintColor), child: line),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

Widget legendList(BuildContext context, {required String currency, required List<LegendRow> rows}) {
  return ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 220),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(child: categoryChip(context, color: r.color, name: r.label, icon: r.icon)),
                const SizedBox(width: 12),
                Text(
                  money(r.amount, currency: currency),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget donutWithLegend(
  BuildContext context, {
  required double size,
  required double thickness,
  required List<double> values,
  required List<Color> colors,
  required String centerLabel,
  required String currency,
  required List<LegendRow> rows,
}) {
  return Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 32,
    runSpacing: 24,
    children: [
      donutChart(context, size: size, thickness: thickness, values: values, colors: colors, centerLabel: centerLabel),
      legendList(context, currency: currency, rows: rows),
    ],
  );
}
