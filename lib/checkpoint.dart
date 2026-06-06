import 'package:cloud_firestore/cloud_firestore.dart';

enum CheckpointStatus { open, closed, crowded }

extension CheckpointStatusExtension on CheckpointStatus {
  String get label {
    switch (this) {
      case CheckpointStatus.open:
        return 'Open';
      case CheckpointStatus.closed:
        return 'Closed';
      case CheckpointStatus.crowded:
        return 'Crowded';
    }
  }

  String get emoji {
    switch (this) {
      case CheckpointStatus.open:
        return '\u{1F7E2}';
      case CheckpointStatus.closed:
        return '\u{1F534}';
      case CheckpointStatus.crowded:
        return '\u{1F7E1}';
    }
  }

  String get firestoreValue => name;
}

CheckpointStatus statusFromString(String value) {
  switch (value.toLowerCase()) {
    case 'closed':
      return CheckpointStatus.closed;
    case 'crowded':
      return CheckpointStatus.crowded;
    default:
      return CheckpointStatus.open;
  }
}

class Checkpoint {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? imageUrl;
  final CheckpointStatus entranceStatus;
  final CheckpointStatus exitStatus;
  final DateTime? updatedAt;
  final String? updatedBy;
  final String? updatedByEmail;

  const Checkpoint({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
    this.entranceStatus = CheckpointStatus.open,
    this.exitStatus = CheckpointStatus.open,
    this.updatedAt,
    this.updatedBy,
    this.updatedByEmail,
  });

  factory Checkpoint.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Checkpoint(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Checkpoint',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
      entranceStatus: statusFromString(data['entranceStatus'] ?? 'open'),
      exitStatus: statusFromString(data['exitStatus'] ?? 'open'),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: data['updatedBy'],
      updatedByEmail: data['updatedByEmail'],
    );
  }

  Map<String, dynamic> toFirestore({Map<String, dynamic> audit = const {}}) {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'entranceStatus': entranceStatus.firestoreValue,
      'exitStatus': exitStatus.firestoreValue,
      'updatedAt': FieldValue.serverTimestamp(),
      ...audit,
    };
  }

  Checkpoint copyWith({
    String? name,
    double? latitude,
    double? longitude,
    String? imageUrl,
    CheckpointStatus? entranceStatus,
    CheckpointStatus? exitStatus,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByEmail,
  }) {
    return Checkpoint(
      id: id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      entranceStatus: entranceStatus ?? this.entranceStatus,
      exitStatus: exitStatus ?? this.exitStatus,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByEmail: updatedByEmail ?? this.updatedByEmail,
    );
  }
}
