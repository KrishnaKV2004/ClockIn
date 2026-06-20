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
      appBar: AppBar(
        title: Text(widget.staff['full_name']?.toUpperCase() ?? 'STAFF DETAIL', style: const TextStyle(fontSize: 14, letterSpacing: 2)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildProfileHeader(),
                  const SizedBox(height: 48),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedRange == ChartRange.week ? 'WEEKLY PRODUCTIVITY (HRS)' : 'MONTHLY PRODUCTIVITY (HRS)',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 2),
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
                    'RECENT ACTIVITY LOGS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white38, letterSpacing: 2),
                  ),
                  const SizedBox(height: 20),
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
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
          color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white24,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6366F1).withValues(alpha: 0.1), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF6366F1),
            child: Text(
              (widget.staff['full_name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.staff['full_name'] ?? 'Employee',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'MEMBER SINCE ${DateFormat('MMM yyyy').format(DateTime.now()).toUpperCase()}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold),
                ),
              ],
            ),
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
                width: 30 * 40.0, // Enough space for 30 bars
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
                  // Only show label for every 7 days to avoid clutter
                  if (index % 7 != 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('W${(index / 7).floor() + 1}', style: const TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)),
                  );
                } else {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  // Need to map the current day correctly
                  final date = DateTime.now().subtract(Duration(days: 6 - index));
                  final dayLabel = days[date.weekday - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(dayLabel, style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold)),
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
                color: data[i] > 8 ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                width: isMonthly ? 10 : 14,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 12,
                  color: Colors.white.withValues(alpha: 0.05),
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
      return const Text('No recent activity.', style: TextStyle(color: Colors.white24));
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, MMM d').format(checkIn),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('hh:mm a').format(checkIn)} - ${checkOut != null ? DateFormat('hh:mm a').format(checkOut) : 'ACTIVE'}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (checkOut != null)
                Text(
                   '${hours.toStringAsFixed(1)} HRS',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF6366F1), fontSize: 13, letterSpacing: 0.5),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
