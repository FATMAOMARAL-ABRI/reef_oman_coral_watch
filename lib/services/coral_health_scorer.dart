import 'dart:typed_data';

/// AI scorer abstraction.
/// Replace this with real TFLite implementation later.
class CoralHealthScorer {
  static const List<String> labels = ['Healthy', 'Bleached', 'Dead'];

  Future<String> scoreCoral(Uint8List imageBytes) async {
    if (imageBytes.isEmpty) return 'Unknown';

    await Future<void>.delayed(const Duration(milliseconds: 200));

    // Simple deterministic scoring based on first bytes
    final hash = imageBytes.take(32).fold<int>(0, (a, b) => (a + b) & 0xFF);
    final idx = hash % labels.length;

    return labels[idx];
  }
}
