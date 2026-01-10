import 'package:flutter/material.dart';
import 'package:whiteapp/features/progress/models/mood_entry.dart';
import 'package:whiteapp/features/progress/screens/daily_checkup_screen.dart';
import 'package:whiteapp/features/progress/screens/mood_checkin_screen.dart';
import 'package:whiteapp/features/progress/screens/relapse_log_screen.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:whiteapp/features/progress/widgets/mood_chart.dart';
import 'package:whiteapp/core/widgets/abstract_background.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({Key? key}) : super(key: key);

  @override
  _ProgressScreenState createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic> _stats = {};
  List<MoodEntry> _moodHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await ProgressService.getDashboardStats();
      final moodHistory = await ProgressService.getMoodHistory();
      
      setState(() {
        _stats = stats;
        _moodHistory = moodHistory;
      });
    } catch (e) {
      // Handle error
      print("Error loading progress data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("My Progress"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Overview"),
            Tab(text: "Mood"),
            Tab(text: "History"),
          ],
        ),
      ),
      body: AbstractBackground(
        scrollProgress: 1.0,
        child: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMoodTab(),
                _buildHistoryTab(),
              ],
            ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DailyCheckupScreen()),
          ).then((_) => _loadData());
        },
        label: Text("Daily Checkup"),
        icon: Icon(Icons.check_circle_outline),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatCard("Clean Streak", "Coming Soon", Icons.local_fire_department, Colors.orange),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard("Mood Entries", "${_stats['mood_entries'] ?? 0}", Icons.mood, Colors.blue)),
            SizedBox(width: 16),
            Expanded(child: _buildStatCard("Relapses", "${_stats['relapses'] ?? 0}", Icons.warning, Colors.red)),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard("Levels Done", "${_stats['levels_completed'] ?? 0}", Icons.star, Colors.purple)),
            SizedBox(width: 16),
            Expanded(child: _buildStatCard("Tracker Logs", "${_stats['tracker_entries'] ?? 0}", Icons.list, Colors.green)),
          ],
        ),
        SizedBox(height: 24),
        Text("Quick Actions", style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ActionChip(
              avatar: Icon(Icons.mood),
              label: Text("Log Mood"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MoodCheckinScreen()),
                ).then((_) => _loadData());
              },
            ),
            ActionChip(
              avatar: Icon(Icons.warning, color: Colors.red),
              label: Text("Log Relapse"),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RelapseLogScreen()),
                ).then((_) => _loadData());
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMoodTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text("Mood History", style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 16),
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: MoodChart(entries: _moodHistory),
        ),
        SizedBox(height: 24),
        ..._moodHistory.map((entry) => ListTile(
          leading: CircleAvatar(
            child: Text(entry.intensity.toString()),
            backgroundColor: _getMoodColor(entry.intensity),
          ),
          title: Text(entry.primaryEmotion.toUpperCase()),
          subtitle: Text(entry.date),
          trailing: entry.note != null && entry.note!.isNotEmpty ? Icon(Icons.note) : null,
        )).toList(),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Center(child: Text("Detailed history coming soon..."));
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
  
  Color _getMoodColor(int intensity) {
    if (intensity >= 8) return Colors.green;
    if (intensity >= 5) return Colors.blue;
    return Colors.orange;
  }
}
