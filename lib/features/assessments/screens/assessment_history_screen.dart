import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:whiteapp/features/assessments/models/assessment.dart';
import 'package:whiteapp/features/assessments/services/assessment_service.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class AssessmentHistoryScreen extends StatefulWidget {
  final int assessmentId;
  final String assessmentTitle;

  const AssessmentHistoryScreen({
    super.key, 
    required this.assessmentId, 
    required this.assessmentTitle
  });

  @override
  State<AssessmentHistoryScreen> createState() => _AssessmentHistoryScreenState();
}

class _AssessmentHistoryScreenState extends State<AssessmentHistoryScreen> {
  late Future<List<UserAssessmentResult>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = AssessmentService.getHistory(assessmentId: widget.assessmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.assessmentTitle} Progression', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: FutureBuilder<List<UserAssessmentResult>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No historical data available yet. Complete an assessment first.', style: TextStyle(color: Colors.white70)));
            }
  
            final results = snapshot.data!;
            // API returns newest first, so sort oldest first for the chart X-axis
            final sortedResults = List<UserAssessmentResult>.from(results)
              ..sort((a, b) => DateTime.parse(a.completedAt).compareTo(DateTime.parse(b.completedAt)));
  
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                 _buildChart(sortedResults),
                 const SizedBox(height: 24),
                 Text('Historical Records', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                 const SizedBox(height: 12),
                 ...results.map((r) => _buildResultCard(r)).toList(),
              ],
            );
          }
        ),
      ),
    );
  }

  Widget _buildChart(List<UserAssessmentResult> sortedResults) {
    if (sortedResults.length < 2) {
       return Container(
         padding: const EdgeInsets.all(24.0),
         decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(16)),
         child: const Text('Take this assessment at least twice to securely calculate internal score progressions graphically over time.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
       );
    }
    
    // sortedResults is oldest first.
    final oldestScore = sortedResults.first.score;
    final newestScore = sortedResults.last.score;
    final trendDiff = newestScore - oldestScore;
    
    List<FlSpot> spots = [];
    double minY = sortedResults.first.score;
    double maxY = sortedResults.first.score;

    for (int i = 0; i < sortedResults.length; i++) {
       final score = sortedResults[i].score;
       if (score < minY) minY = score;
       if (score > maxY) maxY = score;
       spots.add(FlSpot(i.toDouble(), score));
    }
    
    minY = (minY - (maxY - minY) * 0.2).clamp(0, double.infinity);
    maxY = maxY + (maxY - minY) * 0.2;
    if (minY == maxY) {
       minY -= 10;
       maxY += 10;
    }

    return Container(
      height: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text('Trend Outline', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
               if (trendDiff != 0)
                 Row(
                   children: [
                     Icon(trendDiff > 0 ? Icons.trending_up : Icons.trending_down, 
                          color: trendDiff > 0 ? Colors.greenAccent : Colors.redAccent, size: 24),
                     const SizedBox(width: 6),
                     Text('${trendDiff > 0 ? '+' : ''}${trendDiff.toStringAsFixed(1)}', 
                          style: GoogleFonts.outfit(color: trendDiff > 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                   ]
                 ),
            ]
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= sortedResults.length) return const SizedBox.shrink();
                        final date = DateTime.parse(sortedResults[index].completedAt).toLocal();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Text(DateFormat('MM/dd').format(date), style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        );
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (sortedResults.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: Colors.blueAccent,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: Colors.blueAccent
                      )
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blueAccent.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildResultCard(UserAssessmentResult result) {
    final date = DateTime.parse(result.completedAt).toLocal();
    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(result.resultLabel, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        subtitle: Text(DateFormat('MMM dd, yyyy - h:mm a').format(date), style: const TextStyle(color: Colors.white70)),
        trailing: Text(result.score.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
      )
    );
  }
}
