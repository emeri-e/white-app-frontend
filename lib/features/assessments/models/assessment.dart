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
      id: (json['id'] as num).toInt(),
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
      id: (json['id'] as num).toInt(),
      text: json['text'],
      order: (json['order'] as num).toInt(),
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
      id: (json['id'] as num).toInt(),
      text: json['text'],
      value: (json['value'] as num).toInt(),
      order: (json['order'] as num).toInt(),
    );
  }
}

class ScoringRange {
  final double minScore;
  final double maxScore;
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
      minScore: (json['min_score'] as num).toDouble(),
      maxScore: (json['max_score'] as num).toDouble(),
      label: json['label'],
      description: json['description'] ?? '',
      colorHex: json['color_hex'] ?? '4CAF50',
    );
  }
}

class UserAssessmentSubscaleResult {
  final int id;
  final String domain;
  final double score;
  final String resultLabel;

  UserAssessmentSubscaleResult({
    required this.id,
    required this.domain,
    required this.score,
    required this.resultLabel,
  });

  factory UserAssessmentSubscaleResult.fromJson(Map<String, dynamic> json) {
    return UserAssessmentSubscaleResult(
      id: (json['id'] as num).toInt(),
      domain: json['domain'],
      score: (json['score'] as num).toDouble(),
      resultLabel: json['result_label'] ?? '',
    );
  }
}

class UserAssessmentResult {
  final int id;
  final String assessmentTitle;
  final double score;
  final String resultLabel;
  final String completedAt;
  final List<UserAssessmentResponse>? responses;
  final List<UserAssessmentSubscaleResult>? subscaleResults;
  final List<dynamic>? newBadges;

  UserAssessmentResult({
    required this.id,
    required this.assessmentTitle,
    required this.score,
    required this.resultLabel,
    required this.completedAt,
    this.responses,
    this.subscaleResults,
    this.newBadges,
  });

  factory UserAssessmentResult.fromJson(Map<String, dynamic> json) {
    return UserAssessmentResult(
      id: (json['id'] as num).toInt(),
      assessmentTitle: json['assessment_title'] ?? '',
      score: (json['score'] as num).toDouble(),
      resultLabel: json['result_label'] ?? '',
      completedAt: json['completed_at'],
      responses: json['responses'] != null
          ? (json['responses'] as List).map((i) => UserAssessmentResponse.fromJson(i)).toList()
          : null,
      subscaleResults: json['subscale_results'] != null
          ? (json['subscale_results'] as List).map((i) => UserAssessmentSubscaleResult.fromJson(i)).toList()
          : null,
      newBadges: json['new_badges'],
    );
  }
}

class UserAssessmentResponse {
  final int id;
  final int? questionId;
  final String questionText;
  final int? selectedOptionId;
  final String? optionText;
  final int? value;

  UserAssessmentResponse({
    required this.id,
    this.questionId,
    required this.questionText,
    this.selectedOptionId,
    this.optionText,
    this.value,
  });

  factory UserAssessmentResponse.fromJson(Map<String, dynamic> json) {
    return UserAssessmentResponse(
      id: (json['id'] as num).toInt(),
      questionId: json['question'] != null ? (json['question'] as num).toInt() : null,
      questionText: json['question_text'] ?? '',
      selectedOptionId: json['selected_option'] != null ? (json['selected_option'] as num).toInt() : null,
      optionText: json['option_text'],
      value: json['value'] != null ? (json['value'] as num).toInt() : null,
    );
  }
}
