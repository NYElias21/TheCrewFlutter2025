import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'profile_page.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'location_detail_sheet.dart';
import 'package:google_place/google_place.dart';

class PostDetailPage extends StatefulWidget {
  final DocumentSnapshot post;

  PostDetailPage({required this.post});

  @override
  _PostDetailPageState createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  late final GooglePlace googlePlace;
  bool isFollowing = false;
  int _currentImageIndex = 0;
  late String currentUserId;
  late String postUserId;
  Map<String, Timestamp> _likedPosts = {};
  Map<String, Timestamp> _savedPosts = {};
  int likes = 0;
  TextEditingController _commentController = TextEditingController();
  FocusNode _commentFocusNode = FocusNode();
  List<Comment> comments = [];
  Comment? replyingTo;
  Map<String, bool> _expandedReplies = {};

@override
void initState() {
  super.initState();
  // Initialize googlePlace first
  googlePlace = GooglePlace('AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM');
  // Then initialize other variables
  currentUserId = FirebaseAuth.instance.currentUser!.uid;
  postUserId = widget.post['userId'];
  likes = widget.post['likes'] ?? 0;
  _checkIfFollowing();
  _loadLikedAndSavedPosts();
  _loadComments();
}

  @override
  void dispose() {
    _commentFocusNode.dispose();
    _commentController.dispose();
    super.dispose();
  }


void _showPlaceDetails(BuildContext context, Map<String, dynamic> activity) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LocationDetailSheet(
      activity: activity,
      googlePlace: googlePlace,  
      placeId: activity['placeId'],
    ),
  );
}

  Future<void> _checkIfFollowing() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    
    List<String> following = List<String>.from(userDoc['following'] ?? []);
    setState(() {
      isFollowing = following.contains(postUserId);
    });
  }

Future<void> _loadLikedAndSavedPosts() async {
  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .get();

  setState(() {
    var data = userDoc.data() as Map<String, dynamic>?;
    
    if (data != null) {
      var likedPosts = data['likedPosts'];
      if (likedPosts is Map) {
        _likedPosts = Map<String, Timestamp>.from(likedPosts);
      } else if (likedPosts is List) {
        _likedPosts = Map.fromIterable(
          likedPosts,
          key: (item) => item as String,
          value: (item) => Timestamp.now(),
        );
      } else {
        _likedPosts = {};
      }

      var savedPosts = data['savedPosts'];
      if (savedPosts is Map) {
        _savedPosts = Map<String, Timestamp>.from(savedPosts);
      } else if (savedPosts is List) {
        _savedPosts = Map.fromIterable(
          savedPosts,
          key: (item) => item as String,
          value: (item) => Timestamp.now(),
        );
      } else {
        _savedPosts = {};
      }
    } else {
      _likedPosts = {};
      _savedPosts = {};
    }
  });
}

  bool isLiked(String postId) {
    return _likedPosts.containsKey(postId);
  }

  bool isSaved(String postId) {
    return _savedPosts.containsKey(postId);
  }

  Future<void> _toggleLike(String postId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    bool liked = _likedPosts.containsKey(postId);
    if (liked) {
      _likedPosts.remove(postId);
      await userRef.update({
        'likedPosts.$postId': FieldValue.delete()
      });
      await postRef.update({
        'likes': FieldValue.increment(-1)
      });
      setState(() {
        likes--;
      });
    } else {
      _likedPosts[postId] = Timestamp.now();
      await userRef.update({
        'likedPosts.$postId': FieldValue.serverTimestamp()
      });
      await postRef.update({
        'likes': FieldValue.increment(1)
      });
      setState(() {
        likes++;
      });
    }

    setState(() {});
  }

  Future<void> _toggleSave(String postId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);

    bool saved = _savedPosts.containsKey(postId);
    if (saved) {
      _savedPosts.remove(postId);
      await userRef.update({
        'savedPosts.$postId': FieldValue.delete()
      });
    } else {
      _savedPosts[postId] = Timestamp.now();
      await userRef.update({
        'savedPosts.$postId': FieldValue.serverTimestamp()
      });
    }

    setState(() {});
  }

  Future<void> _toggleFollow() async {
    setState(() {
      isFollowing = !isFollowing;
    });

    DocumentReference currentUserRef = FirebaseFirestore.instance.collection('users').doc(currentUserId);
    DocumentReference postUserRef = FirebaseFirestore.instance.collection('users').doc(postUserId);

    if (isFollowing) {
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([postUserId])
      });
      await postUserRef.update({
        'followers': FieldValue.arrayUnion([currentUserId])
      });
    } else {
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([postUserId])
      });
      await postUserRef.update({
        'followers': FieldValue.arrayRemove([currentUserId])
      });
    }
  }

  Widget _buildUserAvatar(String photoUrl, {double radius = 20}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey[300],
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty
          ? Icon(Icons.person, size: radius * 1.2, color: Colors.grey[600])
          : null,
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

void _sharePost() {
  String caption = '';
  bool isGroupActivity = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          // Get the keyboard height and safe area
          final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
          final safePadding = MediaQuery.of(context).padding;

          return GestureDetector(
            // Dismiss keyboard when tapping outside of text field
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Share this experience',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  
                  Divider(height: 1),
                  
                  // Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      // Add padding to account for keyboard
                      child: Padding(
                        padding: EdgeInsets.only(bottom: keyboardHeight),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Post Preview
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[100],
                              ),
                              padding: EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      (widget.post.data() as Map<String, dynamic>)['imageUrls'][0],
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (widget.post.data() as Map<String, dynamic>)['title'],
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'By @${(widget.post.data() as Map<String, dynamic>)['username']}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
                            
                            // Caption Section
                            Text(
                              'Add your thoughts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            TextField(
                              onChanged: (value) => caption = value,
                              decoration: InputDecoration(
                                hintText: 'Write a caption...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              maxLines: 3,
                              style: TextStyle(fontSize: 16),
                              // Add keyboard actions
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                FocusScope.of(context).unfocus();
                              },
                            ),
                            SizedBox(height: 24),
                            
                            // Group Activity Section
                            Text(
                              'Activity Settings',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[100],
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Allow friends to join',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Create a group activity others can join',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: isGroupActivity,
                                    onChanged: (value) {
                                      setState(() => isGroupActivity = value);
                                    },
                                    activeColor: Colors.blue,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Bottom Action Bar
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + safePadding.bottom),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: ElevatedButton(
                        onPressed: () {
                          _saveSharedPost(caption, isGroupActivity);
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Share',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// In post_detail_page.dart, modify the _saveSharedPost function:

void _saveSharedPost(String caption, bool isGroupActivity) async {
  try {
    final data = widget.post.data() as Map<String, dynamic>;
    String groupId = '';

    // Properly handle activities with location data
    List<Map<String, dynamic>> processedActivities = [];
    if (data['activities'] != null) {
      for (var activity in data['activities']) {
        Map<String, dynamic> processedActivity = Map<String, dynamic>.from(activity);
        
        // Ensure location data is properly structured
        if (activity['location'] != null) {
          // If location is a GeoPoint, convert it to a map with lat/lng
          if (activity['location'] is GeoPoint) {
            GeoPoint geoPoint = activity['location'];
            processedActivity['location'] = {
              'lat': geoPoint.latitude,
              'lng': geoPoint.longitude
            };
          } 
          // If location is already a map, keep it as is
          else if (activity['location'] is Map) {
            processedActivity['location'] = Map<String, dynamic>.from(activity['location']);
          }
        }
        processedActivities.add(processedActivity);
      }
    }

    if (isGroupActivity) {
      // Create a new group document with processed activities
      DocumentReference groupRef = await FirebaseFirestore.instance.collection('groups').add({
        'title': data['title'],
        'description': data['description'],
        'imageUrls': data['imageUrls'],
        'members': [FirebaseAuth.instance.currentUser!.uid],
        'createdAt': FieldValue.serverTimestamp(),
        'originalPostId': widget.post.id,
        'postType': data['postType'],
        'itinerary': data['itinerary'],
        'activities': processedActivities, // Use processed activities
        'date': null,
      });
      groupId = groupRef.id;
    }

    final sharedPostData = {
      'originalPostId': widget.post.id,
      'sharedBy': FirebaseAuth.instance.currentUser!.uid,
      'caption': caption,
      'timestamp': FieldValue.serverTimestamp(),
      'title': data['title'],
      'description': data['description'],
      'imageUrls': data['imageUrls'],
      'postType': data['postType'],
      'itinerary': data['itinerary'],
      'activities': processedActivities, // Use processed activities
      'isGroupActivity': isGroupActivity,
      'groupId': isGroupActivity ? groupId : null,
      'groupMembers': isGroupActivity ? [FirebaseAuth.instance.currentUser!.uid] : [],
      'likes': 0,
      'comments': 0,
      'isCompleted': false,
    };

    await FirebaseFirestore.instance.collection('social_posts').add(sharedPostData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Post shared successfully!')),
    );
  } catch (e) {
    print('Error sharing post: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error sharing post. Please try again.')),
    );
  }
}

Future<void> _loadComments() async {
  // First, load all comments
  QuerySnapshot commentSnapshot = await FirebaseFirestore.instance
      .collection('posts')
      .doc(widget.post.id)
      .collection('comments')
      .orderBy('timestamp', descending: true)
      .get();

  // Separate top-level comments and replies
  List<Comment> topLevelComments = [];
  Map<String, List<Comment>> replies = {};

  for (var doc in commentSnapshot.docs) {
    Comment comment = Comment.fromDocument(doc);
    if (comment.parentId == null) {
      topLevelComments.add(comment);
    } else {
      replies[comment.parentId!] = replies[comment.parentId!] ?? [];
      replies[comment.parentId!]!.add(comment);
    }
  }

  // Attach replies to their parent comments
  for (var comment in topLevelComments) {
    if (replies.containsKey(comment.id)) {
      comment.replies = replies[comment.id]!;
    }
  }

  setState(() {
    comments = topLevelComments;
  });
}

  Future<void> _addComment() async {
    if (_commentController.text.isNotEmpty) {
      DocumentReference commentRef = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id)
          .collection('comments')
          .add({
        'userId': currentUserId,
        'username': await _getUsernameById(currentUserId),
        'text': _commentController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot commentDoc = await commentRef.get();
      setState(() {
        comments.insert(0, Comment.fromDocument(commentDoc));
        _commentController.clear();
      });
    }
  }

  Future<String> _getUsernameById(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return userDoc['username'] ?? 'Unknown User';
  }

Future<Set<Marker>> _createNumberedMarkers(List<dynamic> activities) async {
  Set<Marker> markers = {};
  int markerNumber = 1;

  for (var activity in activities) {
    if (activity['location'] != null) {
      final location = activity['location'] as Map<String, dynamic>;
      final lat = location['lat'] as double;
      final lng = location['lng'] as double;
      
      markers.add(Marker(
        markerId: MarkerId('${activity['name']}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: "$markerNumber. ${activity['name']}", // Add number to the title
          snippet: activity['description']
        ),
      ));

      markerNumber++;
    }
  }

  return markers;
}

//custom pins on map
/* Future<Uint8List> _getMarkerIcon(int number) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);
  
  // Pin dimensions
  final double markerWidth = 48;
  final double markerHeight = 68;
  final double pinHeadRadius = 22;
  final double pinPointHeight = 24;
  
  final Paint pinPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill;

  // Draw pin shadow
  final Paint shadowPaint = Paint()
    ..color = Colors.black.withOpacity(0.3)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

  // Calculate center points
  final topCenter = Offset(markerWidth / 2, pinHeadRadius);
  
  // Create pin path
  final path = Path()
    ..addOval(Rect.fromCircle(center: topCenter, radius: pinHeadRadius))
    ..moveTo(topCenter.dx - pinHeadRadius * 0.7, topCenter.dy + pinHeadRadius * 0.6)
    ..quadraticBezierTo(
      topCenter.dx, 
      topCenter.dy + pinPointHeight * 1.4,
      topCenter.dx + pinHeadRadius * 0.7,
      topCenter.dy + pinHeadRadius * 0.6
    );
  
  // Draw shadow and pin
  canvas.drawPath(path, shadowPaint);
  canvas.drawPath(path, pinPaint);
  
  // Draw number
  final TextPainter textPainter = TextPainter(
    text: TextSpan(
      text: number.toString(),
      style: TextStyle(
        fontSize: 28,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  
  textPainter.layout();
  textPainter.paint(
    canvas,
    Offset(
      topCenter.dx - textPainter.width / 2,
      topCenter.dy - textPainter.height / 2,
    ),
  );

  // Convert to image
  final img = await pictureRecorder.endRecording().toImage(
    markerWidth.toInt(),
    markerHeight.toInt(),
  );
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
 */
  @override
Widget build(BuildContext context) {
    final data = widget.post.data() as Map<String, dynamic>;
    List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
    String title = data['title'] ?? 'Title';
    String username = data['username'] ?? 'Username';
    String description = data['description'] ?? '';
    String postType = data['postType'] ?? 'single';

    return Scaffold(
      body: Column(
        children: [
          _buildAppBar(context, username),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildImageSection(imageUrls),
                ),
                SliverToBoxAdapter(
                  child: _buildPostDetails(title, description, postType),
                ),
                SliverToBoxAdapter(
                  child: _buildCommentSection(),
                ),
              ],
            ),
          ),
          _buildCommentInput(),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String username) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 8),
              GestureDetector(
                onTap: () => _navigateToProfile(context, postUserId),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(postUserId).get(),
                  builder: (context, snapshot) {
                    String userPhotoUrl = '';
                    if (snapshot.hasData && snapshot.data != null) {
                      userPhotoUrl = snapshot.data!['photoURL'] ?? '';
                    }
                    return _buildUserAvatar(userPhotoUrl, radius: 16);
                  },
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                                child: GestureDetector(
                  onTap: () => _navigateToProfile(context, postUserId),
                  child: Text(
                    username, 
                    style: TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (currentUserId != postUserId)
                ElevatedButton(
                  onPressed: _toggleFollow,
                  child: Text(isFollowing ? 'Following' : 'Follow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: Size(60, 30),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildImageSection(List<String> imageUrls) {
  if (imageUrls.isEmpty) {
    return Container(
      height: 300,
      color: Colors.grey,
      child: Icon(Icons.image, color: Colors.white, size: 100),
    );
  } else if (imageUrls.length == 1) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6, // Maximum 60% of screen height
      ),
      child: Image.network(
        imageUrls[0],
        fit: BoxFit.contain, // Changed from cover to contain
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
      ),
    );
  } else {
    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.6, // Maximum 60% of screen height
            viewportFraction: 1.0,
            enlargeCenterPage: false,
            enableInfiniteScroll: imageUrls.length > 1,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items: imageUrls.map((url) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain, // Changed from cover to contain
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                );
              },
            );
          }).toList(),
        ),
        // Image counter indicator
        if (imageUrls.length > 1) Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_currentImageIndex + 1}/${imageUrls.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Pagination dots
        if (imageUrls.length > 1) Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: imageUrls.asMap().entries.map((entry) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(
                    _currentImageIndex == entry.key ? 0.9 : 0.4,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

//part of activity list
/* Widget _buildActivityList(List<dynamic> activities) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: activities.map((activity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show the ActivityCard, remove the RichText section
          ActivityCard(activity: activity),
          SizedBox(height: 8),
        ],
      );
    }).toList(),
  );
} */

Widget _buildPostDetails(String title, String description, String postType) {
  final createdAt = widget.post['createdAt'] as Timestamp?;
  final data = widget.post.data() as Map<String, dynamic>;
  final activities = data['activities'] as List<dynamic>?;

  final uniqueActivities = <String, dynamic>{};
  activities?.forEach((activity) {
    if (!uniqueActivities.containsKey(activity['name'])) {
      uniqueActivities[activity['name']] = activity;
    }
  });

  return Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          description.isNotEmpty ? description : 'No description available',
          style: TextStyle(fontSize: 16),
        ),
        SizedBox(height: 16),
        if (activities != null && activities.isNotEmpty) ...[
          ...uniqueActivities.values.toList().asMap().entries.map((entry) {
            final index = entry.key;
            final activity = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _showPlaceDetails(context, activity),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.black),
                        children: [
                          TextSpan(text: '${index + 1}. '),
                          TextSpan(
                            text: '${activity['name']}',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                              //decoration: TextDecoration.underline, // Added underline to show it's interactive
                            ),
                          ),
                          if (activity['description'] != null)
                            TextSpan(
                              text: ': ${activity['description']}',
                              style: TextStyle(
                                decoration: TextDecoration.none, // Ensure description isn't underlined
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
              ],
            );
          }).toList(),
          Text(
            'Activity Overview',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          _buildOverviewMap(),
          SizedBox(height: 16),
        ],
        Text(
          _formatPostTime(createdAt ?? Timestamp.now()),
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    ),
  );
}

Widget _buildOverviewMap() {
  final data = widget.post.data() as Map<String, dynamic>;
  final activities = data['activities'] as List<dynamic>?;

  if (activities == null || activities.isEmpty) {
    return SizedBox.shrink();
  }

  return FutureBuilder<Set<Marker>>(
    future: _createNumberedMarkers(activities),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator();
      }

      if (snapshot.hasError) {
        return Text('Error: ${snapshot.error}');
      }

      Set<Marker> markers = snapshot.data ?? {};
      List<LatLng> points = markers.map((marker) => marker.position).toList();

      if (points.isEmpty) {
        return SizedBox.shrink();
      }

      LatLngBounds bounds = _calculateBounds(points);
      LatLng center = _calculateCenter(bounds);

      return Container(
        height: 200,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: 10,
          ),
          markers: markers,
          onMapCreated: (GoogleMapController controller) {
            controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
          },
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      );
    },
  );
}

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  LatLng _calculateCenter(LatLngBounds bounds) {
    return LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );
  }

  Widget _buildItineraryDetails() {
    final data = widget.post.data() as Map<String, dynamic>;
    final itinerary = data['itinerary'] as List<dynamic>?;

    if (itinerary == null || itinerary.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Itinerary',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        ...itinerary.asMap().entries.map((entry) {
          final dayIndex = entry.key;
          final day = entry.value as Map<String, dynamic>;
          final activities = day['activities'] as List<dynamic>?;

          if (activities == null || activities.isEmpty) {
            return SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Day ${dayIndex + 1}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              ...activities.map((activity) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity['name'] ?? 'Unnamed Activity',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 4),
                    Text(activity['description'] ?? 'No description available'),
                    if (activity['placeDescription'] != null)
                      Text(
                        'Location: ${activity['placeDescription']}',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                    SizedBox(height: 8),
                  ],
                );
              }).toList(),
              SizedBox(height: 16),
            ],
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLocationMap(GeoPoint location, String? placeDescription) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (placeDescription != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Location: $placeDescription',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        Container(
          height: 200,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(location.latitude, location.longitude),
              zoom: 14,
            ),
            markers: {
              Marker(
                markerId: MarkerId('activity_location'),
                position: LatLng(location.latitude, location.longitude),
              ),
            },
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      ],
    );
  }


  String _formatPostTime(Timestamp timestamp) {
    final now = DateTime.now();
    final postTime = timestamp.toDate();
    final difference = now.difference(postTime);

    if (difference.inDays > 0) {
      return '${postTime.month.toString().padLeft(2, '0')}/${postTime.day.toString().padLeft(2, '0')}/${postTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

Widget _buildCommentSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
        child: Text(
          '${_getTotalCommentCount()} Comments', // Update this line too while we're at it
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: comments.length,
        itemBuilder: (context, index) {
          return _buildCommentItem(comments[index]);
        },
      ),
    ],
  );
}

// Add the new method here
int _getTotalCommentCount() {
  int total = 0;
  for (var comment in comments) {
    // Count the top-level comment
    total++;
    // Add the number of replies
    total += comment.replies.length;
  }
  return total;
}

Widget _buildCommentInput() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: Colors.grey[300]!, width: 0.5)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (replyingTo != null)
          Container(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  'Replying to ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  replyingTo!.username,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      replyingTo = null;
                    });
                  },
                  child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocusNode,
                decoration: InputDecoration(
                  hintText: replyingTo != null 
                      ? 'Write a reply...' 
                      : 'Write a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 14),
              ),
            ),
            SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                if (replyingTo != null) {
                  _addReply(replyingTo!);
                } else {
                  _addComment();
                }
                _commentFocusNode.unfocus();
              },
              child: Text(
                replyingTo != null ? 'Reply' : 'Post',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> _addReply(Comment parentComment) async {
  if (_commentController.text.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.post.id)
        .collection('comments')
        .add({
      'userId': currentUserId,
      'username': await _getUsernameById(currentUserId),
      'text': _commentController.text,
      'timestamp': FieldValue.serverTimestamp(),
      'parentId': parentComment.id,
    });

    setState(() {
      _commentController.clear();
      replyingTo = null;
    });
    
    _loadComments(); // Reload comments to show the new reply
  }
}

Widget _buildCommentItem(Comment comment, {bool isReply = false}) {
  bool isCurrentUserComment = comment.userId == currentUserId;
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      GestureDetector(
        onLongPress: isCurrentUserComment ? () => _showCommentOptions(comment) : null,
        child: Padding(
          padding: EdgeInsets.only(
            left: isReply ? 56.0 : 16.0,
            right: 16.0,
            top: 8.0,
            bottom: 8.0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _navigateToProfile(context, comment.userId),
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(comment.userId)
                      .get(),
                  builder: (context, snapshot) {
                    String photoURL = '';
                    if (snapshot.hasData && snapshot.data != null) {
                      photoURL = snapshot.data!['photoURL'] ?? '';
                    }
                    return _buildUserAvatar(photoURL, radius: 16);
                  },
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToProfile(context, comment.userId),
                          child: Text(
                            comment.username,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          _formatTimestamp(comment.timestamp),
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(comment.text),
                    SizedBox(height: 4),
                    if (!isReply) // Only show reply button for top-level comments
  GestureDetector(
    onTap: () {
      setState(() {
        replyingTo = comment;
        _commentFocusNode.requestFocus();
      });
    },
    child: Text(
      'Reply',
      style: TextStyle(
        color: Colors.blue,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Show replies
if (!isReply && comment.replies.isNotEmpty)
  Column(
    children: [
      // Show first 3 replies or all if expanded
      ...comment.replies
          .take(_expandedReplies[comment.id] == true ? comment.replies.length : 3)
          .map((reply) => _buildCommentItem(reply, isReply: true)),
      // Show "Show more" button if there are more than 3 replies and not expanded
      if (comment.replies.length > 3 && _expandedReplies[comment.id] != true)
        Padding(
          padding: EdgeInsets.only(left: 56.0, top: 4.0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _expandedReplies[comment.id] = true;
              });
            },
            child: Text(
              'Show ${comment.replies.length - 3} more replies',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      // Show "Show less" button when expanded
      if (_expandedReplies[comment.id] == true)
        Padding(
          padding: EdgeInsets.only(left: 56.0, top: 4.0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _expandedReplies[comment.id] = false;
              });
            },
            child: Text(
              'Show less',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
    ],
  ),
    ],
  );
}

void _showCommentOptions(Comment comment) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                _deleteComment(comment);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy),
              title: Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: comment.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Comment copied to clipboard')),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.edit),
              title: Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editComment(comment);
              },
            ),
          ],
        ),
      );
    },
  );
}

  void _editComment(Comment comment) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      String editedText = comment.text;
      return AlertDialog(
        title: Text('Edit Comment'),
        content: TextField(
          controller: TextEditingController(text: comment.text),
          onChanged: (value) {
            editedText = value;
          },
          decoration: InputDecoration(
            hintText: 'Edit your comment',
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Save'),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .doc(comment.id)
                  .update({'text': editedText});
              Navigator.of(context).pop();
              _loadComments(); // Reload comments to reflect the change
            },
          ),
        ],
      );
    },
  );
}

void _deleteComment(Comment comment) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Comment'),
        content: Text('Are you sure you want to delete this comment?'),
        actions: <Widget>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Delete'),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('comments')
                  .doc(comment.id)
                  .delete();
              Navigator.of(context).pop();
              _loadComments(); // Reload comments to reflect the change
            },
          ),
        ],
      );
    },
  );
}

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _toggleSave(widget.post.id),
                    child: Icon(
                      isSaved(widget.post.id) ? Icons.bookmark : Icons.bookmark_border,
                      size: 28,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(widget.post.id),
                          child: Icon(
                            isLiked(widget.post.id) ? Icons.favorite : Icons.favorite_border,
                            color: isLiked(widget.post.id) ? Colors.red : null,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(likes.toString(), style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
Padding(
  padding: EdgeInsets.only(left: 16),
  child: Row(
    children: [
      Icon(Icons.chat_bubble_outline, size: 28),
      SizedBox(width: 4),
      Text(
        _getTotalCommentCount().toString(), // Replace comments.length with this
        style: TextStyle(fontSize: 14)
      ),
    ],
  ),
),
                ],
              ),
              GestureDetector(
                onTap: _sharePost,
                child: Icon(Icons.share, size: 28),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* // activity_card.dart
class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;
  final String? placeId;

  ActivityCard({
    required this.activity,
    this.placeId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Will add Google Places detail view later
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Square image
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.brown[400],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: activity['photoUrl'] != null
                        ? Image.network(
                            activity['photoUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.place, color: Colors.white, size: 24),
                          )
                        : Icon(Icons.place, color: Colors.white, size: 24),
                  ),
                ),
                SizedBox(width: 12),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity['name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (activity['placeDescription'] != null) ...[
                        SizedBox(height: 2),
                        Text(
                          activity['placeDescription'],
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} */

// Update the existing Comment class
class Comment {
  final String id;
  final String userId;
  final String username;
  final String text;
  final Timestamp timestamp;
  final String? parentId; // Add this line - null means it's a top-level comment
  List<Comment> replies; // Add this line

  Comment({
    required this.id,
    required this.userId,
    required this.username,
    required this.text,
    required this.timestamp,
    this.parentId,
    this.replies = const [], // Initialize empty replies list
  });

  factory Comment.fromDocument(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      userId: data['userId'] ?? '',
      username: data['username'] ?? 'Unknown User',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      parentId: data['parentId'],
      replies: [], // Initialize empty replies list
    );
  }
}