import 'package:cloud_firestore/cloud_firestore.dart';

class Collection {
  final String id;
  final String name;
  final List<String> postIds;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String userId;

  Collection({
    required this.id,
    required this.name,
    required this.postIds,
    this.coverImageUrl,
    required this.createdAt,
    required this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'postIds': postIds,
      'coverImageUrl': coverImageUrl,
      'createdAt': createdAt,
      'userId': userId,
    };
  }

  factory Collection.fromMap(Map<String, dynamic> map, String id) {
    return Collection(
      id: id,
      name: map['name'] ?? '',
      postIds: List<String>.from(map['postIds'] ?? []),
      coverImageUrl: map['coverImageUrl'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      userId: map['userId'] ?? '',
    );
  }
}