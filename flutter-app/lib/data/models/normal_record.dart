import 'package:cloud_firestore/cloud_firestore.dart';

// ignore: constant_identifier_names
enum NormalRecordStatus {
  // ignore: constant_identifier_names
  FOUND,
  // ignore: constant_identifier_names
  AT_CAMP,
  // ignore: constant_identifier_names
  IDENTIFIED,
  // ignore: constant_identifier_names
  UNITED_WITH_FAMILY,
}

class NormalRecord {
  final String id;
  final String name;
  final int age;
  final String? photoUrl;
  final String? photoLocalPath;
  final String campId;
  final String campName;
  final String officerUid;
  final String officerName;
  final String officerContact;
  final NormalRecordStatus status;
  final String additionalDetails;
  final DateTime foundAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NormalRecord({
    required this.id,
    required this.name,
    required this.age,
    this.photoUrl,
    this.photoLocalPath,
    required this.campId,
    required this.campName,
    required this.officerUid,
    required this.officerName,
    required this.officerContact,
    required this.status,
    required this.additionalDetails,
    required this.foundAt,
    this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'photoUrl': photoUrl,
      'campId': campId,
      'campName': campName,
      'officerUid': officerUid,
      'officerName': officerName,
      'officerContact': officerContact,
      'status': status.name,
      'additionalDetails': additionalDetails,
      'foundAt': Timestamp.fromDate(foundAt),
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory NormalRecord.fromMap(String id, Map<String, dynamic> map) {
    return NormalRecord(
      id: id,
      name: map['name'] ?? '',
      age: map['age'] ?? 0,
      photoUrl: map['photoUrl'],
      campId: map['campId'] ?? '',
      campName: map['campName'] ?? '',
      officerUid: map['officerUid'] ?? '',
      officerName: map['officerName'] ?? '',
      officerContact: map['officerContact'] ?? '',
      status: NormalRecordStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => NormalRecordStatus.AT_CAMP,
      ),
      additionalDetails: map['additionalDetails'] ?? '',
      foundAt: (map['foundAt'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
