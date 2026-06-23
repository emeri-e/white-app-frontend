import 'dart:convert';

class BuddyPairing {
  final int id;
  final String? buddyEmail;
  final String? buddyName;
  final String status; // pending, active, expired, removed
  final String inviteCode;
  final String inviteLink;
  final DateTime? pairedAt;
  final DateTime inviteExpiresAt;
  final String userEmail;

  BuddyPairing({
    required this.id,
    this.buddyEmail,
    this.buddyName,
    required this.status,
    required this.inviteCode,
    required this.inviteLink,
    this.pairedAt,
    required this.inviteExpiresAt,
    required this.userEmail,
  });

  factory BuddyPairing.fromJson(Map<String, dynamic> json) {
    return BuddyPairing(
      id: json['id'],
      buddyEmail: json['buddy_email'],
      buddyName: json['buddy_name'],
      status: json['status'],
      inviteCode: json['invite_code'],
      inviteLink: json['invite_link'],
      pairedAt: json['paired_at'] != null ? DateTime.parse(json['paired_at']) : null,
      inviteExpiresAt: DateTime.parse(json['invite_expires_at']),
      userEmail: json['user_email'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buddy_email': buddyEmail,
      'buddy_name': buddyName,
      'status': status,
      'invite_code': inviteCode,
      'invite_link': inviteLink,
      'paired_at': pairedAt?.toIso8601String(),
      'invite_expires_at': inviteExpiresAt.toIso8601String(),
      'user_email': userEmail,
    };
  }
}

class BuddyAlert {
  final int id;
  final String alertType;
  final String severity; // low, medium, high, critical
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  BuddyAlert({
    required this.id,
    required this.alertType,
    required this.severity,
    required this.title,
    required this.body,
    this.data,
    required this.createdAt,
  });

  factory BuddyAlert.fromJson(Map<String, dynamic> json) {
    return BuddyAlert(
      id: json['id'],
      alertType: json['alert_type'],
      severity: json['severity'],
      title: json['title'],
      body: json['body'],
      data: json['data'] != null ? Map<String, dynamic>.from(json['data']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alert_type': alertType,
      'severity': severity,
      'title': title,
      'body': body,
      'data': data,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class BuddyDashboardData {
  final BuddyPairing pairing;
  final int currentStreak;
  final int longestStreak;
  final List<BuddyAlert> recentAlerts;
  final List<dynamic> weeklyReports;

  BuddyDashboardData({
    required this.pairing,
    required this.currentStreak,
    required this.longestStreak,
    required this.recentAlerts,
    required this.weeklyReports,
  });

  factory BuddyDashboardData.fromJson(Map<String, dynamic> json) {
    return BuddyDashboardData(
      pairing: BuddyPairing.fromJson(json['pairing']),
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      recentAlerts: (json['recent_alerts'] as List? ?? [])
          .map((item) => BuddyAlert.fromJson(item))
          .toList(),
      weeklyReports: json['weekly_reports'] ?? [],
    );
  }
}
