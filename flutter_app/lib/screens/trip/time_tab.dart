import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:centavoo/format.dart';
import 'package:centavoo/stats/stats.dart';
import 'package:centavoo/theme.dart';
import 'package:centavoo/widgets/trip/primitives.dart';

const _weekdayOrder = [1, 2, 3, 4, 5, 6, 0];
const _orange = Color(0xFFFF922B);

class TimeTab extends StatefulWidget {
  final TripStats stats;
  final String currency;

  const TimeTab({super.key, required this.stats, required this.currency});

  @override
  State<TimeTab> createState() => _TimeTabState();
}

class _TimeTabState extends State<TimeTab> {
  final Set<String> _hiddenDaySeries = {};

  void _toggleDaySeries(String name) {
    setState(() {
      if (_hiddenDaySeries.contains(name)) {
        _hiddenDaySeries.remove(name);
      } else {
        _hiddenDaySeries.add(name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final dayKeys = <String>{};
    for (final d in stats.dayData) {
      dayKeys.addAll(d.values.keys);
    }
    final daySeries = stats.usedCategories.where((c) => dayKeys.contains(c.name)).toList();
    final hintColor = Theme.of(context).hintColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionHeader(context, 'Gastos por dia', first: true),
          if (stats.dayData.isEmpty)
            Text('Nenhuma transação com data.', style: TextStyle(color: hintColor))
          else ...[
            _DayBarChart(dayData: stats.dayData, series: daySeries, hidden: _hiddenDaySeries, currency: widget.currency),
            if (daySeries.isNotEmpty)
              toggleLegend(
                context,
                series: [for (final c in daySeries) ToggleSeries(name: c.name, color: hexColor(c.color))],
                hidden: _hiddenDaySeries,
                onToggle: _toggleDaySeries,
              ),
          ],
          sectionHeader(context, 'Por dia da semana'),
          _WeekdayBarChart(weekdayAmounts: stats.weekdayAmounts),
          sectionHeader(context, 'Acumulado'),
          if (stats.cumulativeByDay.isEmpty)
            Text('Nenhuma transação com data.', style: TextStyle(color: hintColor))
          else
            _CumulativeAreaChart(points: stats.cumulativeByDay, currency: widget.currency),
        ],
      ),
    );
  }
}

class _DayBarChart extends StatelessWidget {
  final List<DayDatum> dayData;
  final List<UsedCategory> series;
  final Set<String> hidden;
  final String currency;

  const _DayBarChart({required this.dayData, required this.series, required this.hidden, required this.currency});

  @override
  Widget build(BuildContext context) {
    final visible = series.where((s) => !hidden.contains(s.name)).toList();
    var maxY = 0.0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < dayData.length; i++) {
      final day = dayData[i];
      var cumulative = 0.0;
      final stackItems = <BarChartRodStackItem>[];
      for (final s in visible) {
        final v = day.values[s.name] ?? 0;
        if (v <= 0) continue;
        stackItems.add(BarChartRodStackItem(cumulative, cumulative + v, hexColor(s.color)));
        cumulative += v;
      }
      if (cumulative > maxY) maxY = cumulative;
      groups.add(BarChartGroupData(x: i, barRods: [
        BarChartRodData(
          toY: cumulative,
          rodStackItems: stackItems,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ]));
    }
    final labelInterval = (dayData.length / 8).ceil().clamp(1, dayData.length);

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
                '${dayData[group.x].date}\n${money(rod.toY, currency: currency)}',
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
                  if (i < 0 || i >= dayData.length || i % labelInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(dayData[i].date, style: const TextStyle(fontSize: 10)),
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

class _WeekdayBarChart extends StatelessWidget {
  final List<double> weekdayAmounts;
  const _WeekdayBarChart({required this.weekdayAmounts});

  @override
  Widget build(BuildContext context) {
    final base = DateTime(2023, 1, 2);
    final labels = _weekdayOrder.map((wd) {
      final offset = wd == 0 ? 6 : wd - 1;
      return DateFormat('EEE', 'pt_BR').format(base.add(Duration(days: offset)));
    }).toList();
    final values = _weekdayOrder.map((wd) => weekdayAmounts[wd]).toList();
    final maxY = values.fold<double>(0, (m, v) => v > m ? v : m);
    final numberFormat = NumberFormat.decimalPattern('pt_BR');

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY == 0 ? 1 : maxY * 1.25,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(padding: const EdgeInsets.only(top: 4), child: Text(labels[i]));
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: values[i],
                  color: _orange,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  label: BarChartRodLabel(
                    show: true,
                    text: numberFormat.format(values[i].round()),
                    offset: const Offset(0, -16),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _CumulativeAreaChart extends StatelessWidget {
  final List<CumulativePoint> points;
  final String currency;
  const _CumulativeAreaChart({required this.points, required this.currency});

  @override
  Widget build(BuildContext context) {
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].total)];
    final maxY = points.fold<double>(0, (m, p) => p.total > m ? p.total : m);
    final labelInterval = (points.length / 6).ceil().clamp(1, points.length);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.1,
          gridData: const FlGridData(drawVerticalLine: false),
          borderData: FlBorderData(show: false),
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
                  if (i < 0 || i >= points.length || i % labelInterval != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(points[i].date, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: _orange,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [_orange.withValues(alpha: 0.35), _orange.withValues(alpha: 0.02)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
