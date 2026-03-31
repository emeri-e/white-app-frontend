import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:visibility_detector/visibility_detector.dart';

class RelapseTrendChart extends StatefulWidget {
  const RelapseTrendChart({Key? key}) : super(key: key);

  @override
  State<RelapseTrendChart> createState() => _RelapseTrendChartState();
}

class _RelapseTrendChartState extends State<RelapseTrendChart> {
  String _selectedRange = '7D'; // 7D, 1M, 1Y
  List<FlSpot> _spots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final data = await ProgressService.getRelapseTrend(_selectedRange);
      final spots = <FlSpot>[];
      for (int i = 0; i < data.length; i++) {
        final count = data[i]['count'] ?? 0;
        spots.add(FlSpot(i.toDouble(), (count as int).toDouble()));
      }
      if (mounted) {
        setState(() {
          _spots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onRangeSelected(String range) {
    if (_selectedRange != range) {
      setState(() => _selectedRange = range);
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('relapse-trend-${_selectedRange}'),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5) {
          _fetchData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Text(
                      "Relapse Trend",
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text("Frequency over time", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                Row(
                  children: [
                    _buildRangeButton('7D'),
                    const SizedBox(width: 4),
                    _buildRangeButton('1M'),
                    const SizedBox(width: 4),
                    _buildRangeButton('1Y'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140, // Reduced from 180
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
                  : _spots.isEmpty 
                    ? Center(child: Text("No relapses recorded", style: GoogleFonts.outfit(color: Colors.white38)))
                    : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1,
                          getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                        ),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _spots,
                            isCurved: true,
                            color: Colors.redAccent,
                            barWidth: 4,
                            isStrokeCapRound: true,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [Colors.redAccent.withOpacity(0.2), Colors.transparent],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeButton(String range) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () => _onRangeSelected(range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.redAccent.withOpacity(0.5) : Colors.white10),
        ),
        child: Text(
          range,
          style: GoogleFonts.outfit(
            color: isSelected ? Colors.redAccent : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
