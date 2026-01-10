class Assessment {
  final int id;
  final String title;
  final String description;
  final String scoringMethod;
  final String iconName;
  final String colorHex;
  final List<Question>? questions;
  final List<ScoringRange>? scoringRanges;

  Assessment({
    required this.id,
    required this.title,
    required this.description,
    this.scoringMethod = 'raw',
    this.iconName = 'assignment',
    this.colorHex = '4CAF50',
    this.questions,
    this.scoringRanges,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      scoringMethod: json['scoring_method'] ?? 'raw',
      iconName: json['icon_name'] ?? 'assignment',
      colorHex: json['color_hex'] ?? '4CAF50',
      questions: json['questions'] != null 
          ? (json['questions'] as List).map((i) => Question.fromJson(i)).toList() 
          : null,
      scoringRanges: json['scoring_ranges'] != null
          ? (json['scoring_ranges'] as List).map((i) => ScoringRange.fromJson(i)).toList()
          : null,
    );
  }
}

class Question {
  final int id;
  final String text;
  final int order;
  final List<Option> options;

  Question({
    required this.id,
    required this.text,
    required this.order,
    required this.options,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'],
      text: json['text'],
      order: json['order'],
      options: (json['options'] as List).map((i) => Option.fromJson(i)).toList(),
    );
  }
}

class Option {
  final int id;
  final String text;
  final int value;
  final int order;

  Option({
    required this.id,
    required this.text,
    required this.value,
    required this.order,
  });

  factory Option.fromJson(Map<String, dynamic> json) {
    return Option(
      id: json['id'],
      text: json['text'],
      value: json['value'],
      order: json['order'],
    );
  }
}

class ScoringRange {
  final int minScore;
  final int maxScore;
  final String label;
  final String description;
  final String colorHex;

  ScoringRange({
    required this.minScore,
    required this.maxScore,
    required this.label,
    required this.description,
    required this.colorHex,
  });

  factory ScoringRange.fromJson(Map<String, dynamic> json) {
    return ScoringRange(
      minScore: json['min_score'],
      maxScore: json['max_score'],
      label: json['label'],
      description: json['description'] ?? '',
      colorHex: json['color_hex'] ?? '4CAF50',
    );
  }
}

class UserAssessmentResult {
  final int id;
  final String assessmentTitle;
  final double score;
  final String resultLabel;
  final String completedAt;

  UserAssessmentResult({
    required this.id,
    required this.assessmentTitle,
    required this.score,
    required this.resultLabel,
    required this.completedAt,
  });

  factory UserAssessmentResult.fromJson(Map<String, dynamic> json) {
    return UserAssessmentResult(
      id: json['id'],
      assessmentTitle: json['assessment_title'] ?? '',
      score: (json['score'] as num).toDouble(),
      resultLabel: json['result_label'] ?? '',
      completedAt: json['completed_at'],
    );
  }
}
