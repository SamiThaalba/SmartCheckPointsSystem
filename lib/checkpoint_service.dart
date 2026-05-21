import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'checkpoint.dart';

class CheckpointService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _collection = 'checkpoints';

  /// Stream of all checkpoints (real-time)
  Stream<List<Checkpoint>> getCheckpoints() {
    return _firestore
        .collection(_collection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Checkpoint.fromFirestore(doc)).toList();
    });
  }

  /// Add a new checkpoint (admin only)
  Future<void> addCheckpoint({
    required String name,
    required double latitude,
    required double longitude,
    XFile? image,
  }) async {
    final checkpointRef = _firestore.collection(_collection).doc();
    final imageUrl = image == null
        ? null
        : await _uploadCheckpointImage(
            checkpointId: checkpointRef.id,
            image: image,
          );

    final checkpoint = Checkpoint(
      id: checkpointRef.id,
      name: name,
      latitude: latitude,
      longitude: longitude,
      imageUrl: imageUrl,
      entranceStatus: CheckpointStatus.open,
      exitStatus: CheckpointStatus.open,
    );

    await checkpointRef.set(
      checkpoint.toFirestore(
        audit: {
          ..._auditFields(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _auth.currentUser?.uid,
          'createdByEmail': _auth.currentUser?.email,
        },
      ),
    );
  }

  /// Update entrance and/or exit status
  Future<void> updateStatus({
    required String checkpointId,
    CheckpointStatus? entranceStatus,
    CheckpointStatus? exitStatus,
  }) async {
    final Map<String, dynamic> updates = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (entranceStatus != null) {
      updates['entranceStatus'] = entranceStatus.firestoreValue;
    }
    if (exitStatus != null) {
      updates['exitStatus'] = exitStatus.firestoreValue;
    }
    updates.addAll(_auditFields());

    await _firestore.collection(_collection).doc(checkpointId).update(updates);
  }

  /// Delete a checkpoint (admin only)
  Future<void> deleteCheckpoint(String checkpointId) async {
    await _firestore.collection(_collection).doc(checkpointId).delete();
  }

  /// Seed some demo checkpoints (run once for testing)
  Future<void> seedDemoData() async {
    final existing = await _firestore.collection(_collection).limit(1).get();
    if (existing.docs.isNotEmpty) return; // already seeded

    final demos = [
      {'name': 'Checkpoint Alpha', 'latitude': 31.7054, 'longitude': 35.2024},
      {'name': 'Checkpoint Beta', 'latitude': 31.7100, 'longitude': 35.2100},
      {'name': 'Checkpoint Gamma', 'latitude': 31.7150, 'longitude': 35.1950},
    ];

    for (final d in demos) {
      await _firestore.collection(_collection).add({
        ...d,
        'entranceStatus': 'open',
        'exitStatus': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Map<String, dynamic> _auditFields() {
    final user = _auth.currentUser;
    return {
      'updatedBy': user?.uid,
      'updatedByEmail': user?.email,
    };
  }

  Future<String> _uploadCheckpointImage({
    required String checkpointId,
    required XFile image,
  }) async {
    final bytes = await image.readAsBytes();
    final extension = image.name.split('.').last.toLowerCase();
    final normalizedExtension = extension == 'png' ? 'png' : 'jpg';
    final contentType =
        normalizedExtension == 'png' ? 'image/png' : 'image/jpeg';
    final path =
        'checkpoint_images/$checkpointId/${DateTime.now().millisecondsSinceEpoch}.$normalizedExtension';

    final ref = _storage.ref(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }
}
