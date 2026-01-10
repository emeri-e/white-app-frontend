class ProgramTrackerConfig {
  final int id;
  final String label;
  final int minValue;
  final int maxValue;
  final String? helpText;

  ProgramTrackerConfig({
    required this.id,
    required this.label,
    required this.minValue,
    required this.maxValue,
    this.helpText,
  });

  factory ProgramTrackerConfig.fromJson(Map<String, dynamic> json) {
    return ProgramTrackerConfig(
      id: json['id'],
      label: json['label'],
      minValue: json['min_value'],
      maxValue: json['max_value'],
      helpText: json['help_text'],
    );
  }
}

class ProgramTrackerEntry {
  final int? id;
  final int configId;
  final String? configLabel;
  final String date;
  final int value;
  final String? note;

  ProgramTrackerEntry({
    this.id,
    required this.configId,
    this.configLabel,
    required this.date,
    required this.value,
    this.note,
  });

  factory ProgramTrackerEntry.fromJson(Map<String, dynamic> json) {
    return ProgramTrackerEntry(
      id: json['id'],
      configId: json['config'],
      configLabel: json['config_label'],
      date: json['date'],
      value: json['value'],
      note: json['note'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'config': configId,
      'date': date,
      'value': value,
      'note': note,
    };
  }
}
