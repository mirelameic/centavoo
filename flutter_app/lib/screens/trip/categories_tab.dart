import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

final _beforeColor = hexColor('#B8860B');
final _duringColor = hexColor('#7A3B12');

String _fmtNum(double n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

class CategoriesTab extends StatefulWidget {
  final TripStats stats;
  final String currency;

  const CategoriesTab({super.key, required this.stats, required this.currency});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final Set<String> _hiddenBdSeries = {};

  void _toggle(String name) {
    setState(() {
      if (_hiddenBdSeries.contains(name)) {
        _hiddenBdSeries.remove(name);
      } else {
        _hiddenBdSeries.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionHeader(context, 'Resumo por categoria', first: true),
          for (final c in stats.categoryTable)
            summaryRow(
              context,
              leading: categoryChip(context, color: hexColor(c.color), name: c.name, icon: c.icon),
              metaLines: [
                Text('${_fmtNum(c.pct)}% · ${c.count} ${c.count == 1 ? 'transação' : 'transações'}'),
                Text('Ticket médio: ${money(c.avgTicket, currency: widget.currency)}'),
              ],
              amount: money(c.total, currency: widget.currency),
            ),
          sectionHeader(context, 'Antes × Durante'),
          _BeforeDuringChart(data: stats.beforeDuringData, hidden: _hiddenBdSeries, currency: widget.currency),
          toggleLegend(
            context,
            series: [
              ToggleSeries(name: 'before', color: _beforeColor, label: 'Antes'),
              ToggleSeries(name: 'during', color: _duringColor, label: 'Durante'),
            ],
            hidden: _hiddenBdSeries,
            onToggle: _toggle,
          ),
        ],
      ),
    );
  }
}

class _BeforeDuringChart extends StatelessWidget {
  final List<BeforeDuringRow> data;
  final Set<String> hidden;
  final String currency;

  const _BeforeDuringChart({required this.data, required this.hidden, required this.currency});

  @override
  Widget build(BuildContext context) {
    var maxY = 0.0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < data.length; i++) {
      final row = data[i];
      final rods = <BarChartRodData>[];
      if (!hidden.contains('before')) {
        rods.add(BarChartRodData(toY: row.before, color: _beforeColor, width: 10, borderRadius: BorderRadius.circular(4)));
        if (row.before > maxY) maxY = row.before;
      }
      if (!hidden.contains('during')) {
        rods.add(BarChartRodData(toY: row.during, color: _duringColor, width: 10, borderRadius: BorderRadius.circular(4)));
        if (row.during > maxY) maxY = row.during;
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 4));
    }
    final labelInterval = data.isEmpty ? 1 : (data.length / 8).ceil().clamp(1, data.length);

    return SizedBox(
      height: 340,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.1,
          barGroups: groups,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                '${data[group.x].category}\n${money(rod.toY, currency: currency)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 64,
                getTitlesWidget: (value, meta) =>
                    Text(money(value, currency: currency), style: const TextStyle(fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length || i % labelInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(data[i].category, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
