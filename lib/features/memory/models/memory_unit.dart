import 'package:objectbox/objectbox.dart';

@Entity()
class MemoryUnit {
  @Id()
  int id = 0;

  final String text;
  final DateTime timestamp;
  final bool isNote;
  final String mood;

  @HnswIndex(dimensions: 384, distanceType: VectorDistanceType.cosine)
  final List<double>? vector;

  MemoryUnit({
    required this.text,
    required this.timestamp,
    required this.isNote,
    required this.mood,
    this.vector,
  });
}
