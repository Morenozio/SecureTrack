import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firebase/firebase_providers.dart';

class WifiNetworkModel {
  WifiNetworkModel({
    required this.id,
    required this.ssid,
    required this.bssid,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String ssid;
  final String bssid;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WifiNetworkModel.fromMap(String id, Map<String, dynamic> data) {
    String _readString(String key) {
      final value = data[key];
      if (value == null) return '';
      return value is String ? value : value.toString();
    }

    DateTime? _readTimestamp(String key) {
      final value = data[key];
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return WifiNetworkModel(
      id: id,
      ssid: _readString('ssid'),
      bssid: _readString('bssid'),
      description: data['description']?.toString(),
      createdAt: _readTimestamp('createdAt'),
      updatedAt: _readTimestamp('updatedAt'),
    );
  }

  Map<String, dynamic> toMap() {
    final trimmedDescription = description?.trim();
    return {
      'ssid': ssid.trim(),
      'bssid': bssid.toLowerCase(), // Normalize BSSID to lowercase
      'description': (trimmedDescription?.isEmpty ?? true) ? null : trimmedDescription,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class WifiNetworkRepository {
  WifiNetworkRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _networks =>
      _db.collection('wifiNetworks');

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllNetworks() {
    try {
      return _networks.snapshots();
    } catch (e) {
      // Return empty stream if there's an error with orderBy
      return _networks.limit(100).snapshots();
    }
  }

  Future<List<WifiNetworkModel>> getAllNetworks() async {
    final snapshot = await _networks.orderBy('ssid').get();
    return snapshot.docs
        .map((doc) => WifiNetworkModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<void> addNetwork({
    required String ssid,
    required String bssid,
    String? description,
  }) async {
    // Normalize BSSID to lowercase for consistent comparison
    final normalizedBssid = bssid.toLowerCase().trim();
    
    // Check if network with same BSSID already exists
    final existing = await _networks
        .where('bssid', isEqualTo: normalizedBssid)
        .limit(1)
        .get();
    
    if (existing.docs.isNotEmpty) {
      throw Exception('WiFi network dengan BSSID ini sudah terdaftar');
    }

    await _networks.add({
      'ssid': ssid.trim(),
      'bssid': normalizedBssid,
      'description': description?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNetwork(String networkId) async {
    await _networks.doc(networkId).delete();
  }

  Future<bool> verifyWifiNetwork({
    required String ssid,
    required String bssid,
  }) async {
    final normalizedBssid = bssid.toLowerCase().trim();
    final normalizedSsid = ssid.trim();

    final snapshot = await _networks
        .where('bssid', isEqualTo: normalizedBssid)
        .where('ssid', isEqualTo: normalizedSsid)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}

final wifiNetworkRepositoryProvider = Provider<WifiNetworkRepository>((ref) {
  return WifiNetworkRepository(ref.watch(firestoreProvider));
});

