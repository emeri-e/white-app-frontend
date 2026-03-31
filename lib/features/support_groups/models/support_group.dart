class SupportGroup {
  final int id;
  final String title;
  final String description;
  final String goals;
  final int programId;
  final String programName;
  final int priceCents;
  final String currency;
  final int sessionCount;
  final int weeklyDayOfWeek;
  final String weeklyStartTime;
  final int weeklyDurationMinutes;
  final int capacity;
  final int seatsTaken;
  final int availableSeats;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final Map<String, dynamic> therapist;
  final bool isMember;
  final bool timelineEnabled;

  SupportGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.goals,
    required this.programId,
    required this.programName,
    required this.priceCents,
    required this.currency,
    required this.sessionCount,
    required this.weeklyDayOfWeek,
    required this.weeklyStartTime,
    required this.weeklyDurationMinutes,
    required this.capacity,
    required this.seatsTaken,
    required this.availableSeats,
    required this.startDate,
    required this.endDate,
    required this.isActive,
    required this.therapist,
    this.isMember = false,
    this.timelineEnabled = true,
  });

  factory SupportGroup.fromJson(Map<String, dynamic> json) {
    return SupportGroup(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      goals: json['goals'] ?? '',
      programId: json['program'],
      programName: json['program_name'] ?? '',
      priceCents: json['price_cents'] ?? 0,
      currency: json['currency'] ?? 'USD',
      sessionCount: json['session_count'] ?? 0,
      weeklyDayOfWeek: json['weekly_day_of_week'] ?? 0,
      weeklyStartTime: json['weekly_start_time'] ?? '',
      weeklyDurationMinutes: json['weekly_duration_minutes'] ?? 0,
      capacity: json['capacity'] ?? 0,
      seatsTaken: json['seats_taken'] ?? 0,
      availableSeats: json['available_seats'] ?? 0,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      isActive: json['is_active'] ?? false,
      therapist: json['therapist'] ?? {},
      isMember: json['is_member'] ?? false,
      timelineEnabled: json['timeline_enabled'] ?? true,
    );
  }

  bool get isFree => priceCents == 0;
  String get formattedPrice => isFree ? 'Free' : '$currency ${priceCents / 100}';

  DateTime getNextSessionDate() {
    final now = DateTime.now();
    // weeklyDayOfWeek is 0=Mon...6=Sun in backend
    // Dart DateTime days are 1=Mon...7=Sun
    final targetDay = weeklyDayOfWeek + 1;
    
    // Parse weeklyStartTime "HH:mm:ss" or "HH:mm"
    final parts = weeklyStartTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    DateTime next = DateTime(now.year, now.month, now.day, hour, minute);
    
    // Find next occurrence of targetDay
    int daysUntil = targetDay - now.weekday;
    if (daysUntil < 0 || (daysUntil == 0 && now.isAfter(next))) {
      daysUntil += 7;
    }
    
    return next.add(Duration(days: daysUntil));
  }
}
