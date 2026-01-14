class AppLog {
  final int? id;
  final DateTime timestamp;
  final String message;
  final String type; // 'INFO', 'ERROR', 'SUCCESS', 'WARNING'

  AppLog({
    this.id,
    required this.timestamp,
    required this.message,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'type': type,
    };
  }

  factory AppLog.fromMap(Map<String, dynamic> map) {
    return AppLog(
      id: map['id'],
      timestamp: DateTime.parse(map['timestamp']),
      message: map['message'],
      type: map['type'],
    );
  }
}
