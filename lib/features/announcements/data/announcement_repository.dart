import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'announcement_model.dart';

// Provider for the AnnouncementRepository
final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(
    firestore: FirebaseFirestore.instance,
    storage: FirebaseStorage.instance,
  );
});

class AnnouncementRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  AnnouncementRepository({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _firestore = firestore,
       _storage = storage;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _announcementsRef =>
      _firestore.collection('announcements');

  // Create a new announcement
  Future<void> createAnnouncement(Announcement announcement) async {
    // We use the ID from the model if provided, otherwise add() generates one.
    // However, typically we might want to let Firestore generate the ID or use the one we created.
    // Here we'll treat the passed ID as potential custom ID or ignore it if we use .doc().set().
    // Let's use .doc(announcement.id).set() to ensure consistency if the ID was generated beforehand,
    // or .add() if the ID is empty.

    if (announcement.id.isEmpty) {
      await _announcementsRef.add(announcement.toMap());
    } else {
      await _announcementsRef.doc(announcement.id).set(announcement.toMap());
    }
  }

  // Delete an announcement
  Future<void> deleteAnnouncement(String id) async {
    await _announcementsRef.doc(id).delete();
  }

  // Stream latest announcements (for feeds)
  Stream<List<Announcement>> streamAnnouncements({int limit = 10}) {
    return _announcementsRef
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Announcement.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // Upload an image to Firebase Storage and return the download URL
  Future<String> uploadAnnouncementImage(File file) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = _storage.ref().child('announcement_images/$fileName');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }
}
