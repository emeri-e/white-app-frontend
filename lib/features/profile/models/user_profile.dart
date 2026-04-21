import 'package:whiteapp/features/profile/models/user.dart';

class UserProfile {
  final User user;
  final String? bio;
  final String? avatar;
  final String? location;
  final String? birthDate;
  final String timezone;
  final String language;
  final String? cleanDate;
  final int cleanDays;
  final int streakRecord;
  final int dailyGoal;
  final String? gender;
  final String? countryCode;
  final bool disableAutoTranslation;
  final bool viewAllCountries;
  final int? currentChallengeDay;
  final int gold;
  final int gems;
  final int trophies;

  UserProfile({
    required this.user,
    this.bio,
    this.avatar,
    this.location,
    this.birthDate,
    this.timezone = 'UTC',
    this.language = 'en',
    this.cleanDate,
    this.cleanDays = 0,
    this.streakRecord = 0,
    this.dailyGoal = 0,
    this.gender,
    this.countryCode,
    this.disableAutoTranslation = false,
    this.viewAllCountries = true,
    this.currentChallengeDay,
    this.gold = 0,
    this.gems = 0,
    this.trophies = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      user: User.fromJson(json['user']),
      bio: json['bio'],
      avatar: json['avatar'],
      location: json['location'],
      birthDate: json['birth_date'],
      timezone: json['timezone'] ?? 'UTC',
      language: json['language'] ?? 'en',
      cleanDate: json['clean_date'],
      cleanDays: json['clean_days'] != null ? (json['clean_days'] as num).toInt() : 0,
      streakRecord: json['streak_record'] != null ? (json['streak_record'] as num).toInt() : 0,
      dailyGoal: json['daily_goal'] != null ? (json['daily_goal'] as num).toInt() : 0,
      gender: json['gender'],
      countryCode: json['country_code'],
      disableAutoTranslation: json['disable_auto_translation'] ?? false,
      viewAllCountries: json['view_all_countries'] ?? true,
      currentChallengeDay: json['current_challenge_day'] != null ? (json['current_challenge_day'] as num).toInt() : null,
      gold: json['gold'] != null ? (json['gold'] as num).toInt() : 0,
      gems: json['gems'] != null ? (json['gems'] as num).toInt() : 0,
      trophies: json['trophies'] != null ? (json['trophies'] as num).toInt() : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user': user.toJson(),
      'bio': bio,
      'avatar': avatar,
      'location': location,
      'birth_date': birthDate,
      'timezone': timezone,
      'language': language,
      'clean_date': cleanDate,
      'clean_days': cleanDays,
      'daily_goal': dailyGoal,
      'gender': gender,
      'country_code': countryCode,
      'disable_auto_translation': disableAutoTranslation,
      'view_all_countries': viewAllCountries,
      'current_challenge_day': currentChallengeDay,
    };
  }
}
