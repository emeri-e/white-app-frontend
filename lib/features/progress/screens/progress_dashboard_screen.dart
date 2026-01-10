import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:whiteapp/core/widgets/starry_background.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';

class ProgressDashboardScreen extends StatefulWidget {
  static const String id = 'progress_dashboard_screen';

  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  late Future<Map<String, dynamic>> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = ProgressService.getDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: StarryBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>>(
            future: _dashboardFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.white)));
              } else if (!snapshot.hasData) {
                return const Center(child: Text('No data available', style: TextStyle(color: Colors.white)));
              }

              final data = snapshot.data!;
              final moodHistory = data['mood_history'] as List<dynamic>;
              final toolStats = data['tool_stats'] as List<dynamic>;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(data),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Mood Trends (Last 7 Entries)'),
                    const SizedBox(height: 16),
                    _buildMoodChart(moodHistory),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Tool Usage'),
                    const SizedBox(height: 16),
                    _buildToolUsageChart(toolStats),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(child: _buildCard('Mood Logs', '${data['mood_entries']}', Icons.mood, Colors.purple)),
        const SizedBox(width: 12),
        Expanded(child: _buildCard('Relapses', '${data['relapses']}', Icons.warning, Colors.red)),
        const SizedBox(width: 12),
        Expanded(child: _buildCard('Levels', '${data['levels_completed']}', Icons.flag, Colors.green)),
      ],
    );
  }

  Widget _buildCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChart(List<dynamic> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Not enough data for chart', style: TextStyle(color: Colors.white54)));
    }

    // Reverse to show oldest to newest left to right
    final reversedHistory = history.reversed.toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: reversedHistory.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), (e.value['intensity'] as int).toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.purpleAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: true, color: Colors.purpleAccent.withOpacity(0.2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolUsageChart(List<dynamic> stats) {
    if (stats.isEmpty) {
      return const Center(child: Text('No tool usage recorded', style: TextStyle(color: Colors.white54)));
    }

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < stats.length) {
                    final label = stats[value.toInt()]['tool_type'].toString().replaceAll('_', ' ');
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        label.length > 5 ? '${label.substring(0, 5)}...' : label,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: stats.asMap().entries.map((e) {
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: (e.value['count'] as int).toDouble(),
                  color: Colors.cyanAccent,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
