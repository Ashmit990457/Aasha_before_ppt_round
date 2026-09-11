import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, official }

class AppUser {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool approved;
  final DateTime? createdAt;
  final String? organization;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.approved = true,
    this.createdAt,
    this.organization,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'approved': approved,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'organization': organization,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.user,
      ),
      approved: map['approved'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      organization: map['organization'],
    );
  }
}
