import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/progress/widgets/progress_calendar.dart';
import 'package:whiteapp/features/progress/widgets/relapse_trend_chart.dart';
import 'package:visibility_detector/visibility_detector.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _assessmentGraphs = {};
  
  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final summary = await ProgressService.getProgressSummary();
      final graphs = await ProgressService.getAssessmentGraphs();
      
      if (mounted) {
        setState(() {
          _summary = summary;
          _assessmentGraphs = graphs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading progress screen data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: VisibilityDetector(
        key: const Key('progress-screen-visibility'),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.5) {
            _loadAllData();
          }
        },
        child: AbstractBackground(
          scrollProgress: 1.0,
          child: RefreshIndicator(
                  onRefresh: _loadAllData,
                  color: Colors.blueAccent,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 60)), // Reduced from 120
                      
                      // 7-Day Summary Header
                      SliverToBoxAdapter(child: _buildSummaryHeader()),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),

                      // Relapse Trend
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              const Icon(Icons.history_rounded, color: Colors.redAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Relapse History",
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: RelapseTrendChart(),
                        ),
                      ),

                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                      
                      // Calendar Section
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Activity Tracker",
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                      const SliverToBoxAdapter(child: ProgressCalendar()),
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 48)),
                      
                      // Assessment Progress
                      if (_assessmentGraphs.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Row(
                              children: [
                                const Icon(Icons.show_chart_rounded, color: Colors.purpleAccent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  "Assessment Trends",
                                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final key = _assessmentGraphs.keys.elementAt(index);
                              final data = _assessmentGraphs[key] as List;
                              return _buildAssessmentChart(key, data);
                            },
                            childCount: _assessmentGraphs.length,
                          ),
                        ),
                      ],
                      
                      const SliverToBoxAdapter(child: SizedBox(height: 60)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    final moodImp = _summary['mood_improvement'] ?? 0.0;
    final relapseChange = _summary['relapse_change'] ?? 0;
    final streak = _summary['current_streak'] ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "WEEKLY INSIGHT",
              style: GoogleFonts.outfit(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInsightCard(
                  "Mood",
                  "${moodImp > 0 ? '+' : ''}$moodImp",
                  moodImp >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                  moodImp >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  "Intensity diff",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Relapses",
                  "${relapseChange > 0 ? '+' : ''}$relapseChange",
                  relapseChange <= 0 ? Colors.greenAccent : Colors.redAccent,
                  relapseChange <= 0 ? Icons.shield_rounded : Icons.warning_amber_rounded,
                  "vs last week",
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInsightCard(
                  "Streak",
                  "$streak",
                  Colors.blueAccent,
                  Icons.local_fire_department_rounded,
                  "Days clean",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String title, String value, Color color, IconData icon, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value, 
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)
          ),
          Text(
            title, 
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)
          ),
          const SizedBox(height: 2),
          Text(
            subtitle, 
            style: GoogleFonts.outfit(color: Colors.white24, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentChart(String title, List<dynamic> history) {
    if (history.length < 2) {
       return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              Text(
                "Take this assessment again to see progress trends.",
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
       );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 2),
                    Text("Historical Score Progress", style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${history.last['score']}",
                  style: GoogleFonts.outfit(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.white10, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: history.asMap().entries.map((e) {
                      final item = e.value as Map<String, dynamic>;
                      final score = item['score'] ?? 0;
                      return FlSpot(e.key.toDouble(), (score as num).toDouble());
                    }).toList(),
                    isCurved: true,
                    gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.purpleAccent]),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.blueAccent.withOpacity(0.2), Colors.transparent],
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
    );
  }
}
