import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';
import 'notification_model.dart';

class NotificationRepository {
  NotificationRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _userNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .doc(userId)
        .collection('items');
  }

  /// Stream all notifications for a user, newest first
  Stream<List<AppNotification>> streamNotifications(String userId) {
    return _userNotifications(userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Count unread notifications
  Stream<int> streamUnreadCount(String userId) {
    return _userNotifications(userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _userNotifications(
      userId,
    ).doc(notificationId).update({'isRead': true});
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead(String userId) async {
    final unread = await _userNotifications(
      userId,
    ).where('isRead', isEqualTo: false).get();
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  /// Delete a notification
  Future<void> deleteNotification(String userId, String notificationId) async {
    await _userNotifications(userId).doc(notificationId).delete();
  }

  /// Send a notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final notification = AppNotification(
      id: '',
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      data: data,
    );
    await _userNotifications(userId).add(notification.toMap());
  }

  /// Send notification to all employees (for announcements)
  Future<void> notifyAllEmployees({
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    final employees = await _firestore.collection('users').get();

    final batch = _firestore.batch();
    for (final emp in employees.docs) {
      final ref = _userNotifications(emp.id).doc();
      batch.set(ref, {
        'userId': emp.id,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': Timestamp.now(),
        'isRead': false,
        'data': data,
      });
    }
    await batch.commit();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(firestoreProvider));
});
