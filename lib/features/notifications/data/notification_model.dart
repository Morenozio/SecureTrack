import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.data,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // 'announcement', 'attendance', 'leave'
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      userId: (map['userId'] ?? '') as String,
      title: (map['title'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      type: (map['type'] ?? 'announcement') as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: (map['isRead'] as bool?) ?? false,
      data: map['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'data': data,
    };
  }
}
