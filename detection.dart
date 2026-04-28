enum DetectionCategory { threat, obstacle, landmark }

class Detection {
  final DetectionCategory category;
  final String label;
  final double confidence;
  final DateTime timestamp;

  Detection({
    required this.category,
    required this.label,
    required this.confidence,
    required this.timestamp,
  });
}
