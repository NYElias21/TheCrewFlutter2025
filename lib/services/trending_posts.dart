// services/trending_posts.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TrendingPost {
  final String id;
  final String title;
  final String subtitle;
  final String username;
  final String userPhotoUrl;
  final List<String> imageUrls;
  final String location;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final DateTime createdAt;
  final double trendingScore;

  TrendingPost({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.username,
    required this.userPhotoUrl,
    required this.imageUrls,
    required this.location,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.views,
    required this.createdAt,
    required this.trendingScore,
  });

  factory TrendingPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Calculate trending score based on engagement metrics and time decay
    final now = DateTime.now();
    final postAge = now.difference(data['createdAt'].toDate()).inHours;
    
    // Weights for different engagement metrics
    const likeWeight = 1.0;
    const commentWeight = 1.2;
    const shareWeight = 1.5;
    const viewWeight = 0.2;
    
    // Time decay factor (half-life of 24 hours)
    final timeDecay = 1.0 / (1.0 + (postAge / 24));
    
    // Calculate trending score
    final trendingScore = (
      (data['likes'] ?? 0) * likeWeight +
      (data['comments'] ?? 0) * commentWeight +
      (data['shares'] ?? 0) * shareWeight +
      (data['views'] ?? 0) * viewWeight
    ) * timeDecay;

    return TrendingPost(
      id: doc.id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      username: data['username'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      location: data['location'] ?? '',
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      views: data['views'] ?? 0,
      createdAt: data['createdAt'].toDate(),
      trendingScore: trendingScore,
    );
  }
}

class TrendingPostsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> updateTrendingScore(String postId) async {
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    if (!postDoc.exists) return;
    
    final post = TrendingPost.fromFirestore(postDoc);
    
    // Update the post's trending score
    await _firestore.collection('posts').doc(postId).update({
      'trendingScore': post.trendingScore,
      'lastTrendingUpdate': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<TrendingPost>> getTrendingPosts() {
    // Get posts from the last 48 hours
    final DateTime cutoff = DateTime.now().subtract(Duration(hours: 48));
    
    return _firestore
        .collection('posts')
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .orderBy('trendingScore', descending: true)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => TrendingPost.fromFirestore(doc))
              .toList();
        });
  }

  // Updated to handle both increment and decrement
  Future<void> incrementEngagement(String postId, String type, {bool increment = true}) async {
    final validTypes = ['likes', 'comments', 'shares', 'views'];
    if (!validTypes.contains(type)) return;

    await _firestore.collection('posts').doc(postId).update({
      type: FieldValue.increment(increment ? 1 : -1),
    });
    
    // Update trending score after engagement
    await updateTrendingScore(postId);
  }
}