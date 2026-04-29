import 'package:objectbox/objectbox.dart';

@Entity()
class AgentMemory {
  @Id()
  int id = 0;
  
  String fact;
  DateTime timestamp;

  AgentMemory({
    this.id = 0,
    required this.fact,
    required this.timestamp,
  });
}
