import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:whiteapp/features/progress/services/progress_service.dart';
import 'package:intl/intl.dart';

class ProgressCalendar extends StatefulWidget {
  const ProgressCalendar({super.key});

  @override
  State<ProgressCalendar> createState() => _ProgressCalendarState();
}

class _ProgressCalendarState extends State<ProgressCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<String, List<dynamic>> _allEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchMonthData(_focusedDay);
  }

  Future<void> _fetchMonthData(DateTime day) async {
    setState(() => _isLoading = true);
    try {
      final data = await ProgressService.getCalendarData(day.year, day.month);
      setState(() {
        _allEvents = Map<String, List<dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching calendar data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateFormat('yyyy-MM-dd').format(day);
    return _allEvents[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
              _fetchMonthData(focusedDay);
            },
            eventLoader: _getEventsForDay,
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white70),
              rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white70),
            ),
            calendarStyle: CalendarStyle(
              defaultTextStyle: GoogleFonts.outfit(color: Colors.white),
              weekendTextStyle: GoogleFonts.outfit(color: Colors.white70),
              outsideTextStyle: GoogleFonts.outfit(color: Colors.white30),
              todayDecoration: BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
                shape: BoxShape.circle,
              ),
              markerMargin: const EdgeInsets.only(top: 6),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) return null;
                
                final hasRelapse = events.any((e) => (e as Map<String, dynamic>)['type'] == 'relapse');
                final hasMood = events.any((e) => (e as Map<String, dynamic>)['type'] == 'mood');
                final hasTracker = events.any((e) => (e as Map<String, dynamic>)['type'] == 'tracker');
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (hasRelapse)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      ),
                    if (hasMood)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                      ),
                    if (hasTracker)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildActivityList(),
      ],
    );
  }

  Widget _buildActivityList() {
    final events = _getEventsForDay(_selectedDay ?? DateTime.now());
    if (events.isEmpty) {
      if (_isLoading) {
        return const Center(child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ));
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          "No activities recorded for this day.",
          style: GoogleFonts.outfit(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index] as Map<String, dynamic>;
        IconData icon;
        Color color;
        String title;
        String? subtitle;

        switch (event['type']) {
          case 'mood':
            icon = Icons.mood_rounded;
            color = Colors.blueAccent;
            final timeStr = event['time'] != null ? " at ${event['time'].toString().substring(0, 5)}" : "";
            title = "Mood: ${event['emotion'].toString().toUpperCase()}$timeStr";
            subtitle = "Intensity: ${event['intensity']}/10. ${event['note'] ?? ''}";
            break;
          case 'relapse':
            icon = Icons.warning_amber_rounded;
            color = Colors.redAccent;
            final rTimeStr = event['time'] != null ? " at ${event['time'].toString().substring(0, 5)}" : "";
            title = "Relapse Logged$rTimeStr";
            subtitle = "Cause: ${event['cause'] ?? 'Unspecified'}. ${event['notes'] ?? ''}";
            break;
          case 'tracker':
            icon = Icons.track_changes_rounded;
            color = Colors.greenAccent;
            title = "Tracker: ${event['title']}";
            subtitle = "Value: ${event['value']}";
            break;
          default:
            icon = Icons.event_note_rounded;
            color = Colors.white;
            title = "Activity";
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 2),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(subtitle, style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
