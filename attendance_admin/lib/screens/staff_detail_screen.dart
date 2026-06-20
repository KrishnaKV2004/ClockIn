import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/attendance_service.dart';

class StaffDetailScreen extends StatefulWidget {
  final dynamic staff;
  const StaffDetailScreen({super.key, required this.staff});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

enum ChartRange { week, month }

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  ChartRange _selectedRange = ChartRange.week;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final service = Provider.of<AttendanceService>(context, listen: false);
    final data = await service.getStaffAttendance(widget.staff['id']);
    setState(() {
      _history = data;
      _isLoading = false;
    });
  }

  double _calculateHours(dynamic record) {
    if (record['check_out'] == null) return 0;
    final start = DateTime.parse(record['check_in']);
    final end = DateTime.parse(record['check_out']);
    return end.difference(start).inMinutes / 60.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Analytics Portal'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildProfileHeader(),
                  const SizedBox(height: 32),
                  _buildAnalyticsSummary(),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedRange == ChartRange.week ? 'Weekly Performance' : 'Monthly Performance',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2),
                            ),
                            _buildRangeSelector(),
                          ],
                        ),
                        const SizedBox(height: 32),
                        _buildChart(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  const Text(
                    'Attendance Logs',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 2),
                  ),
                  const SizedBox(height: 24),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          _buildRangeButton('7D', ChartRange.week),
          _buildRangeButton('30D', ChartRange.month),
        ],
      ),
    );
  }

  Widget _buildRangeButton(String label, ChartRange range) {
    bool isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () => setState(() => _selectedRange = range),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black26,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSummary() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    
    final monthRecords = _history.where((r) {
      final checkIn = DateTime.parse(r['check_in']);
      return checkIn.isAfter(firstDayOfMonth) || checkIn.isAtSameMomentAs(firstDayOfMonth);
    }).toList();

    double totalHours = 0;
    Set<String> activeDays = {};
    
    for (var r in monthRecords) {
      totalHours += _calculateHours(r);
      activeDays.add(r['check_in'].substring(0, 10)); // YYYY-MM-DD
    }

    final avgHours = activeDays.isEmpty ? 0.0 : totalHours / activeDays.length;

    return Row(
      children: [
        _buildSummaryCard(
          'Active Days',
          activeDays.length.toString(),
          'Days this month',
          Icons.calendar_today_rounded,
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          'Total Hours',
          totalHours.toStringAsFixed(1),
          'Hours worked',
          Icons.timer_outlined,
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          'Avg / Day',
          avgHours.toStringAsFixed(1),
          'Average hours',
          Icons.analytics_outlined,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, String sub, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: Colors.black26),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 0.5),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 8, color: Colors.black12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            child: Text(
              (widget.staff['full_name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.staff['full_name'] ?? 'Employee',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Production Staff • Synced',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final daysCount = _selectedRange == ChartRange.week ? 7 : 30;
    final dataPoints = List.generate(daysCount, (index) {
      final date = DateTime.now().subtract(Duration(days: index));
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final records = _history.where((r) => r['check_in'].startsWith(dateStr));
      double totalHours = 0;
      for (var r in records) {
        totalHours += _calculateHours(r);
      }
      return totalHours;
    }).reversed.toList();

    return SizedBox(
      height: 180,
      child: _selectedRange == ChartRange.month
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: SizedBox(
                width: 30 * 40.0,
                child: _buildBarChart(dataPoints, isMonthly: true),
              ),
            )
          : _buildBarChart(dataPoints, isMonthly: false),
    );
  }

  Widget _buildBarChart(List<double> data, {required bool isMonthly}) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: 12,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${rod.toY.toStringAsFixed(1)} hrs',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) return const SizedBox.shrink();
                
                if (isMonthly) {
                  if (index % 7 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('W${(index / 7).floor() + 1}', style: const TextStyle(color: Colors.black26, fontSize: 9, fontWeight: FontWeight.w900)),
                  );
                } else {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final date = DateTime.now().subtract(Duration(days: 6 - index));
                  final dayLabel = days[date.weekday - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(dayLabel, style: const TextStyle(color: Colors.black26, fontSize: 10, fontWeight: FontWeight.w900)),
                  );
                }
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                color: data[i] > 8 ? Colors.black : Colors.black.withValues(alpha: 0.1),
                width: isMonthly ? 10 : 16,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 12,
                  color: Colors.black.withValues(alpha: 0.03),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Center(child: Text('No activity records.', style: TextStyle(color: Colors.black26, fontSize: 12)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final record = _history[index];
        final checkIn = DateTime.parse(record['check_in']);
        final checkOut = record['check_out'] != null ? DateTime.parse(record['check_out']) : null;
        final hours = _calculateHours(record);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(checkIn),
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1, color: Colors.black26),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${DateFormat('hh:mm a').format(checkIn)} - ${checkOut != null ? DateFormat('hh:mm a').format(checkOut) : 'LIVE'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                    ),
                  ],
                ),
              ),
              if (checkOut != null)
                Text(
                   '${hours.toStringAsFixed(1)} H',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 14),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Live',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
