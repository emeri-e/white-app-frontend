class GroundingStep {
  final int id;
  final String sense;
  final int count;
  final String promptText;
  final String helperText;
  final bool allowTypedInput;
  final int order;

  GroundingStep({
    required this.id,
    required this.sense,
    required this.count,
    required this.promptText,
    required this.helperText,
    required this.allowTypedInput,
    required this.order,
  });

  factory GroundingStep.fromJson(Map<String, dynamic> json) {
    return GroundingStep(
      id: json['id'],
      sense: json['sense'] ?? '',
      count: json['count'] ?? 1,
      promptText: json['prompt_text'] ?? '',
      helperText: json['helper_text'] ?? '',
      allowTypedInput: json['allow_typed_input'] ?? true,
      order: json['order'] ?? 0,
    );
  }
}

class GroundingExercise {
  final int id;
  final String title;
  final String description;
  final List<GroundingStep> steps;

  GroundingExercise({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
  });

  factory GroundingExercise.fromJson(Map<String, dynamic> json) {
    var list = json['steps'] as List? ?? [];
    List<GroundingStep> stepsList = list.map((i) => GroundingStep.fromJson(i)).toList();

    return GroundingExercise(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      steps: stepsList,
    );
  }
}
