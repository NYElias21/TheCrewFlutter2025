import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_page.dart';
import 'group_detail_page.dart';
import 'notifications_page.dart'; // Add this import


class SocialFeedPage extends StatefulWidget {
  @override
  _SocialFeedPageState createState() => _SocialFeedPageState();
}

class _SocialFeedPageState extends State<SocialFeedPage> with SingleTickerProviderStateMixin {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
return Scaffold(
  appBar: AppBar(
    title: Text(
      'Your Crew',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    elevation: 0,
    centerTitle: true,
    actions: [
      IconButton(
        icon: Icon(Icons.notifications),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotificationsPage()),
          );
        },
      ),
    ],
    bottom: TabBar(
      controller: _tabController,
      tabs: [
        Tab(text: 'Discover Trips'),
        Tab(text: 'Your Trips'),
      ],
      labelColor: Theme.of(context).colorScheme.onSurface,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
    ),
  ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTrips(),
          _buildYourTrips(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTrips() {
    return FutureBuilder<List<String>>(
      future: _getMutualFriends(),
      builder: (context, friendsSnapshot) {
        if (friendsSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (friendsSnapshot.hasError) {
          return Center(child: Text('Error: ${friendsSnapshot.error}'));
        }

        List<String> mutualFriends = friendsSnapshot.data ?? [];
        mutualFriends.add(currentUserId);

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('social_posts')
              .where('sharedBy', whereIn: mutualFriends)
              .where('isCompleted', isEqualTo: false)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            // Filter out posts where the current user is already a member
            var posts = snapshot.data!.docs.where((doc) {
              List<String> groupMembers = List<String>.from(doc['groupMembers'] ?? []);
              return !groupMembers.contains(currentUserId);
            }).toList();

            if (posts.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No new trips to discover right now.\nCheck back later for more adventures!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              itemCount: posts.length,
              separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
              itemBuilder: (context, index) {
                return SocialPostCard(post: posts[index]);
              },
            );
          },
        );
      },
    );
  }

Widget _buildYourTrips() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('social_posts')
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      // Filter posts where user is an active member in the group
      return FutureBuilder<List<bool>>(
        future: Future.wait(
          snapshot.data!.docs.map((post) async {
            String groupId = (post.data() as Map<String, dynamic>)['groupId'] ?? post.id;
            DocumentSnapshot groupDoc = await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .get();
            
            if (groupDoc.exists) {
              List<String> groupMembers = List<String>.from(groupDoc['members'] ?? []);
              return groupMembers.contains(currentUserId);
            }
            return false;
          }),
        ),
        builder: (context, membershipSnapshot) {
          if (membershipSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          List<QueryDocumentSnapshot> posts = [];
          for (int i = 0; i < snapshot.data!.docs.length; i++) {
            if (membershipSnapshot.data?[i] ?? false) {
              posts.add(snapshot.data!.docs[i]);
            }
          }

          if (posts.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You haven\'t joined any trips yet.\nDiscover and join some trips to see them here!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[300]),
            itemBuilder: (context, index) => SocialPostCard(post: posts[index]),
          );
        },
      );
    },
  );
}

  Future<List<String>> _getMutualFriends() async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get();
    List<String> following = List<String>.from(userDoc['following'] ?? []);

    QuerySnapshot followersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('following', arrayContains: currentUserId)
        .get();

    Set<String> followers = followersQuery.docs.map((doc) => doc.id).toSet();
    List<String> mutualFriends = following.where((userId) => followers.contains(userId)).toList();

    return mutualFriends;
  }
}

class SocialPostCard extends StatelessWidget {
  final DocumentSnapshot post;
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  SocialPostCard({required this.post});

Future<void> _showDeleteConfirmation(BuildContext context, String groupId) async {
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Delete Group'),
        content: Text('Are you sure you want to delete this group? This action cannot be undone.'),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () async {
              try {
                // Start a batch write
                WriteBatch batch = FirebaseFirestore.instance.batch();

                // Delete the group document
                DocumentReference groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
                batch.delete(groupRef);

                // Delete the social post
                batch.delete(post.reference);

                // Delete all chat messages associated with this group
                QuerySnapshot chatMessages = await FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .collection('messages')
                    .get();
                
                for (var message in chatMessages.docs) {
                  batch.delete(message.reference);
                }

                // Delete all notifications related to this group
                QuerySnapshot notifications = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('groupId', isEqualTo: groupId)
                    .get();

                for (var notification in notifications.docs) {
                  batch.delete(notification.reference);
                }

                // Delete all group activities
                QuerySnapshot activities = await FirebaseFirestore.instance
                    .collection('social_posts')
                    .where('groupId', isEqualTo: groupId)
                    .get();

                for (var activity in activities.docs) {
                  batch.delete(activity.reference);
                }

                // Commit the batch
                await batch.commit();
                
                Navigator.pop(context); // Close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Group deleted successfully')),
                );
              } catch (e) {
                print('Error deleting group: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete group. Please try again.')),
                );
              }
            },
          ),
        ],
      );
    },
  );
}
  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = post.data() as Map<String, dynamic>;
    String userId = data['sharedBy'] ?? '';
    String caption = data['caption'] ?? '';
    List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
    Map<String, int> reactions = Map<String, int>.from(data['reactions'] ?? {});
    Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    bool isGroupActivity = data['isGroupActivity'] ?? false;
    List<String> groupMembers = List<String>.from(data['groupMembers'] ?? []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: CircularProgressIndicator(),
                ),
                title: Text('Loading...'),
                subtitle: Text(_formatTimestamp(timestamp)),
              );
            }

            if (snapshot.hasError) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.error),
                ),
                title: Text('Error loading user'),
                subtitle: Text(_formatTimestamp(timestamp)),
              );
            }

            var userData = snapshot.data!.data() as Map<String, dynamic>?;
            String username = userData?['username'] ?? 'Unknown User';
            String userPhotoUrl = userData?['photoURL'] ?? '';

            return ListTile(
              leading: GestureDetector(
                onTap: () => _navigateToProfile(context, userId),
                child: CircleAvatar(
                  backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                  child: userPhotoUrl.isEmpty ? Icon(Icons.person) : null,
                ),
              ),
              title: GestureDetector(
                onTap: () => _navigateToProfile(context, userId),
                child: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              subtitle: Text(_formatTimestamp(timestamp)),
              trailing: userId == currentUserId
                  ? IconButton(
                      icon: Icon(Icons.more_horiz),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (BuildContext context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(Icons.delete, color: Colors.red),
                                    title: Text('Delete Group', style: TextStyle(color: Colors.red)),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showDeleteConfirmation(context, post.id);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    )
                  : null,
            );
          },
        ),
        if (caption.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(caption),
          ),
        if (imageUrls.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _buildImageGrid(imageUrls),
          ),
        Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isGroupActivity)
                Expanded(
                  child: _buildGroupMembersSection(context, groupMembers),
                ),
              _buildActionButton(context, isGroupActivity, groupMembers, userId),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: _buildReactionsSection(context, reactions),
        ),
      ],
    );
  }

  Widget _buildImageGrid(List<String> imageUrls) {
    if (imageUrls.isEmpty) return SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 1.91,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: Image.network(
                imageUrls[0],
                fit: BoxFit.cover,
                height: double.infinity,
              ),
            ),
            if (imageUrls.length > 1) ...[
              SizedBox(width: 2),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    Expanded(
                      child: Image.network(
                        imageUrls[1],
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                    if (imageUrls.length > 2) ...[
                      SizedBox(height: 2),
                      Expanded(
                        child: Image.network(
                          imageUrls[2],
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

Widget _buildGroupMembersSection(BuildContext context, List<String> postGroupMembers) {
  String groupId = (post.data() as Map<String, dynamic>)['groupId'] ?? post.id;

  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('groups').doc(groupId).get(),
    builder: (context, groupSnapshot) {
      if (groupSnapshot.connectionState == ConnectionState.waiting) {
        return SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator()),
        );
      }

      // Only use current group members
      List<String> currentMembers = [];
      if (groupSnapshot.hasData && groupSnapshot.data != null) {
        currentMembers = List<String>.from(groupSnapshot.data!['members'] ?? []);
      }

      if (currentMembers.isEmpty) {
        return SizedBox(height: 40);
      }

      return SizedBox(
        height: 40,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            for (var i = 0; i < currentMembers.length; i++)
              if (i < 4)
                Positioned(
                  left: i * 24.0,
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('users').doc(currentMembers[i]).get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return CircleAvatar(
                          backgroundColor: Colors.grey[300],
                          radius: 18,
                          child: Icon(Icons.error, size: 18),
                        );
                      }
                      var userData = snapshot.data!.data() as Map<String, dynamic>?;
                      String userPhotoUrl = userData?['photoURL'] ?? '';
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
                          radius: 18,
                          child: userPhotoUrl.isEmpty ? Icon(Icons.person, size: 18) : null,
                        ),
                      );
                    },
                  ),
                ),
            if (currentMembers.length > 4)
              Positioned(
                left: 4 * 24.0,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    color: Colors.grey[300],
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.transparent,
                    radius: 18,
                    child: Text(
                      '+${currentMembers.length - 4}',
                      style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<bool> _checkGroupMembership(String groupId) async {
  try {
    // Get both current and historical membership data
    DocumentSnapshot socialPost = await FirebaseFirestore.instance
        .collection('social_posts')
        .doc(post.id)
        .get();
    
    DocumentSnapshot groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();

    // If either document doesn't exist, user is not a member
    if (!socialPost.exists || !groupDoc.exists) return false;

    Map<String, dynamic> groupData = groupDoc.data() as Map<String, dynamic>;
    Map<String, dynamic> postData = socialPost.data() as Map<String, dynamic>;

    // Check active members
    List<String> groupMembers = List<String>.from(groupData['members'] ?? []);
    
    // Check if user is currently a member
    return groupMembers.contains(currentUserId);
  } catch (e) {
    print('Error checking group membership: $e');
    return false;
  }
}

Future<void> _joinGroup(BuildContext context, String groupId) async {
  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
      DocumentReference postRef = post.reference;
      
      // Read documents to ensure they exist and initialize arrays if needed
      DocumentSnapshot groupSnap = await transaction.get(groupRef);
      DocumentSnapshot postSnap = await transaction.get(postRef);
      
      if (!groupSnap.exists || !postSnap.exists) {
        throw Exception('Group or post not found');
      }

      transaction.update(groupRef, {
        'members': FieldValue.arrayUnion([currentUserId])
      });
      
      transaction.update(postRef, {
        'groupMembers': FieldValue.arrayUnion([currentUserId])
      });
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Successfully joined the group!')),
    );
  } catch (e) {
    print('Error joining group: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to join the group. Please try again.')),
    );
  }
}

Widget _buildActionButton(BuildContext context, bool isGroupActivity, List<String> groupMembers, String postCreatorId) {
  bool isCreator = currentUserId == postCreatorId;
  String groupId = (post.data() as Map<String, dynamic>)['groupId'] ?? post.id;

  return FutureBuilder<bool>(
    future: _checkGroupMembership(groupId),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return CircularProgressIndicator();
      }

      bool isMember = snapshot.data ?? false;
      bool showViewGroupButton = isCreator || (isGroupActivity && isMember);

      if (showViewGroupButton) {
        return ElevatedButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => GroupDetailPage(groupId: groupId)),
          ),
          child: Text('View Group'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      } else if (isGroupActivity) {
        return ElevatedButton(
          onPressed: () => _joinGroup(context, groupId),
          child: Text('Join'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      }
      
      return SizedBox.shrink();
    },
  );
}

  Widget _buildReactionsSection(BuildContext context, Map<String, int> reactions) {
    return Row(
      children: [
        Wrap(
          spacing: 8,
          children: reactions.entries.map((entry) {
            return Chip(
              label: Text('${entry.key} ${entry.value}'),
              backgroundColor: Colors.grey[200],
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${dateTime.month}/${dateTime.day}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }
}