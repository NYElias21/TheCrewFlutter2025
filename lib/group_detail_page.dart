import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'create_postgc_page.dart';
import 'package:intl/intl.dart';
import 'profile_page.dart';  
import 'dart:io';

class GroupDetailPage extends StatefulWidget {
  final String groupId;

  const GroupDetailPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _isEditing = false;
  late TabController _tabController;
  File? _image;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _postController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(child: Text('Group not found'));
        }

         var groupData = snapshot.data!.data() as Map<String, dynamic>;
          String groupName = groupData['title'] ?? 'Unnamed Group';
          List<dynamic> members = groupData['members'] ?? [];
          String backgroundImageUrl = groupData['imageUrls']?[0] ?? 'https://via.placeholder.com/600x200';
          DateTime? date = groupData['date'] != null ? (groupData['date'] as Timestamp).toDate() : null;

          // Extract city from placeDescription
          String city = 'Location not set';
          if (groupData['activities'] != null && (groupData['activities'] as List).isNotEmpty) {
            var firstActivity = groupData['activities'][0];
            if (firstActivity is Map<String, dynamic> && firstActivity['placeDescription'] != null) {
              String placeDescription = firstActivity['placeDescription'];
              List<String> parts = placeDescription.split(',');
              if (parts.length >= 2) {
                city = parts.sublist(parts.length - 2).join(',').trim();
              }
            }
          }

          int memberCount = members.length;
        return NestedScrollView(
          headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
            return <Widget>[
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    backgroundImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      print('Error loading image: $error');
                      return Container(
                        color: Colors.grey,
                        child: Icon(Icons.error, color: Colors.white),
                      );
                    },
                  ),
                ),
                leading: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: () => _editPlan(groupData),
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      // TODO: Implement notification functionality
                    },
                  ),
                ],
              ),
SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            date != null ? DateFormat('EEE, MMM d').format(date) : 'Set date',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            memberCount == 1 ? '1 Going' : '$memberCount Going',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () => _showAllMembers(context, members),
                            child: Text(
                              'View All',
                              style: TextStyle(color: Colors.blue),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      _buildMemberList(members),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: 'Details'),
                      Tab(text: 'Feed'),
                      Tab(text: 'Chat'),
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(groupData),
              _buildFeedTab(),
              _buildChatTab(),
            ],
          ),
        );
      },
    ),
  );
}


Widget _buildMemberList(List<dynamic> members) {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: members.length + 1,  // +1 for the "+" button
        itemBuilder: (context, index) {
          if (index == 0) {
            // "+" button for inviting friends
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => _showInviteDialog(context),
                child: CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.add, color: Colors.white),
                ),
              ),
            );
          } else {
            // Group members
            var member = members[index - 1];
            return _buildMemberAvatar(member);
          }
        },
      ),
    );
  }


Widget _buildMemberAvatar(dynamic member) {
  if (member is String) {
    // If member is just a user ID, fetch user data
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(member).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (snapshot.hasData && snapshot.data != null) {
          var userData = snapshot.data!.data() as Map<String, dynamic>;
          return _buildAvatarFromData(userData, member);
        }
        return CircleAvatar(child: Text('?'));
      },
    );
  } else if (member is Map<String, dynamic>) {
    return _buildAvatarFromData(member, member['userId']);
  }
  return CircleAvatar(child: Text('?'));
}

Widget _buildAvatarFromData(Map<String, dynamic> userData, String userId) {
  String photoUrl = userData['photoURL'] ?? '';
  String name = userData['fullName'] ?? 'Unknown';
  return Padding(
    padding: const EdgeInsets.only(right: 8.0),
    child: GestureDetector(
      onTap: () => _navigateToProfile(context, userId),
      child: CircleAvatar(
        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty ? Text(name[0].toUpperCase()) : null,
      ),
    ),
  );
}
  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
    );
  }

  void _showDatePicker(BuildContext context, DateTime? currentDate) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: currentDate ?? DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(Duration(days: 365)),
  );
  if (picked != null && picked != currentDate) {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .update({'date': Timestamp.fromDate(picked)});
  }
}

void _editPlan(Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Plan'),
        content: TextField(
          controller: _nameController..text = groupData['title'] ?? '',
          decoration: InputDecoration(labelText: 'Plan Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .update({'title': _nameController.text});
              Navigator.pop(context);
            },
            child: Text('Save'),
          ),
        ],
      ),
    );
  }


  void _deletePlan() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Plan'),
        content: Text('Are you sure you want to delete this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .delete();
              Navigator.pop(context);
              Navigator.pop(context); // Return to previous screen after deletion
            },
            child: Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


 void _showAllMembers(BuildContext context, List<dynamic> members) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('All Members'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              return FutureBuilder<Widget>(
                future: _buildMemberListTile(members[index]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListTile(title: Text('Loading...'));
                  }
                  return snapshot.data ?? ListTile(title: Text('Error loading member'));
                },
              );
            },
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('Close'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Future<Widget> _buildMemberListTile(dynamic member) async {
  if (member is String) {
    // If member is just a user ID, fetch user data
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(member).get();
    if (userDoc.exists) {
      var userData = userDoc.data() as Map<String, dynamic>;
      return _buildListTileFromData(userData, member);
    }
  } else if (member is Map<String, dynamic>) {
    return _buildListTileFromData(member, member['userId']);
  }
  return ListTile(title: Text('Unknown Member'));
}

Widget _buildListTileFromData(Map<String, dynamic> userData, String userId) {
  String photoUrl = userData['photoURL'] ?? '';
  String name = userData['fullName'] ?? 'Unknown';
  return ListTile(
    leading: CircleAvatar(
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty ? Text(name[0].toUpperCase()) : null,
    ),
    title: Text(name),
    onTap: () => _navigateToProfile(context, userId),
  );
}


  Widget _buildGroupName(String groupName) {
    return Text(
      groupName,
      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }
/*
  Widget _buildGroupName(String groupName) {
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Enter group name',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _saveGroupName,
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: Text(
              groupName,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              setState(() {
                _isEditing = true;
                _nameController.text = groupName;
              });
            },
          ),
        ],
      );
    }
  }

*/
  

  Widget _buildActionButtons(Map<String, dynamic> groupData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildCircularButton(
          icon: Icons.info_outline,
          label: 'Details',
          onTap: () => _showDetailsDialog(groupData),
        ),
        _buildCircularButton(
          icon: Icons.event_available,
          label: 'RSVP',
          onTap: () => _showRSVPDialog(groupData),
        ),
      ],
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
            ),
            child: Icon(icon, size: 30),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

Widget _buildDetailsTab(Map<String, dynamic> groupData) {
  Map<String, dynamic> originalPostData = groupData['originalPost'] ?? {};
  List<dynamic> originalActivities = [];
  
  if (originalPostData['postType'] == 'itinerary') {
    originalActivities = originalPostData['itinerary'] ?? [];
  } else {
    // For single posts or if itinerary is not available, use the title and description
    originalActivities = [{
      'name': originalPostData['title'] ?? 'Untitled Activity',
      'description': originalPostData['description'] ?? 'No description',
    }];
  }

  List<dynamic> userActivities = groupData['activities'] ?? [];

  return ListView(
    padding: EdgeInsets.all(16),
    children: [
      Text('Original Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      ...originalActivities.expand((day) {
        if (day is Map && day['activities'] != null) {
          return (day['activities'] as List).map((activity) => ListTile(
            title: Text(activity['name'] ?? 'Unnamed Activity'),
            subtitle: Text(activity['description'] ?? 'No description'),
          ));
        } else if (day is Map) {
          return [ListTile(
            title: Text(day['name'] ?? 'Unnamed Activity'),
            subtitle: Text(day['description'] ?? 'No description'),
          )];
        } else {
          return []; // Return an empty list if the day is not in the expected format
        }
      }).toList(),
      SizedBox(height: 16),
      Text('Group Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      ...userActivities.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> activity = entry.value;
        return ListTile(
          title: Text(activity['name'] ?? 'Unnamed Activity'),
          subtitle: Text(activity['description'] ?? 'No description'),
          trailing: IconButton(
            icon: Icon(Icons.edit),
            onPressed: () => _editActivity(index, activity),
          ),
        );
      }).toList(),
      ElevatedButton(
        onPressed: _addActivity,
        child: Text('Add Activity'),
      ),
    ],
  );
}

Widget _buildFeedTab() {
  return Column(
    children: [
      Container(
        height: 10,
        color: Colors.grey[200],
      ), // Add space above the post input with gray color
      _buildPostInput(),
      Container(
        height: 10,
        color: Colors.grey[200],
      ), // Add space below the post input with gray color
      Expanded(child: _buildPostsList()),
    ],
  );
}

Widget _buildPostInput() {
  return Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser?.photoURL ?? ''),
          child: FirebaseAuth.instance.currentUser?.photoURL == null
              ? Icon(Icons.person)
              : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => CreatePostGCPage(groupId: widget.groupId)),
              );
            },
            child: Text(
              'Post something...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
        Icon(Icons.photo_library, color: Colors.grey),
      ],
    ),
  );
}
Widget _buildPostsList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('group_posts')
        .where('groupId', isEqualTo: widget.groupId)
        .orderBy('timestamp', descending: true)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return Center(child: Text('No posts yet.'));
      }

      return ListView.builder(
        itemCount: snapshot.data!.docs.length,
        itemBuilder: (context, index) {
          DocumentSnapshot document = snapshot.data!.docs[index];
          Map<String, dynamic> data = document.data() as Map<String, dynamic>;
          return _buildPostCard(data, document.id);
        },
      );
    },
  );
}

Widget _buildPostCard(Map<String, dynamic> postData, String postId) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: postData['authorPhotoUrl'] != null
                      ? NetworkImage(postData['authorPhotoUrl'])
                      : null,
                  child: postData['authorPhotoUrl'] == null
                      ? Text(postData['authorName'][0])
                      : null,
                  radius: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postData['authorName'],
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _formatTimestamp(postData['timestamp'] as Timestamp),
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              postData['text'],
              style: TextStyle(fontSize: 14),
            ),
            if (postData['imageUrls'] != null && (postData['imageUrls'] as List).isNotEmpty)
              Container(
                height: 200,
                margin: EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (postData['imageUrls'] as List).length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 200,
                      margin: EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(postData['imageUrls'][index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      Divider(height: 1, thickness: 0.5),
    ],
  );
}

  Widget _buildChatTab() {
    // Placeholder for chat functionality
    return Center(child: Text('Group Chat - To be implemented'));
  }

void _showInviteDialog(BuildContext context) {
  Set<String> selectedFriends = {};

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, controller) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Invite friends',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onChanged: (value) {
                        // Implement search functionality
                      },
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<Map<String, List<DocumentSnapshot>>>(
                      future: _getGroupedFriends(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        if (!snapshot.hasData || (snapshot.data!['canBeInvited']!.isEmpty && snapshot.data!['alreadyJoined']!.isEmpty)) {
                          return Center(child: Text('No friends found'));
                        }
                        
                        return ListView(
                          controller: controller,
                          children: [
                            if (snapshot.data!['canBeInvited']!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Can be invited', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...snapshot.data!['canBeInvited']!.map((friend) => _buildFriendListTile(friend, true, selectedFriends, setState)),
                            ],
                            if (snapshot.data!['alreadyJoined']!.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text('Already joined', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ...snapshot.data!['alreadyJoined']!.map((friend) => _buildFriendListTile(friend, false, selectedFriends, setState)),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  if (selectedFriends.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                        child: Text('Invite Selected (${selectedFriends.length})'),
                        onPressed: () {
                          _inviteMultipleFriends(selectedFriends);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        }
      );
    },
  );
}

Future<Map<String, List<DocumentSnapshot>>> _getGroupedFriends() async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return {'canBeInvited': [], 'alreadyJoined': []};

  List<DocumentSnapshot> allFriends = await _getFriends();
  List<String> groupMembers = await _getGroupMembers();

  List<DocumentSnapshot> canBeInvited = [];
  List<DocumentSnapshot> alreadyJoined = [];

  for (var friend in allFriends) {
    if (groupMembers.contains(friend.id)) {
      alreadyJoined.add(friend);
    } else {
      canBeInvited.add(friend);
    }
  }

  return {
    'canBeInvited': canBeInvited,
    'alreadyJoined': alreadyJoined,
  };
}

Future<List<DocumentSnapshot>> _getFriends() async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return [];

  // Fetch the current user's following list
  DocumentSnapshot userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUser.uid)
      .get();
  
  List<String> followingIds = List<String>.from(userDoc['following'] ?? []);

  // Fetch user documents for all followed users
  List<DocumentSnapshot> friendDocs = await Future.wait(
    followingIds.map((id) => FirebaseFirestore.instance.collection('users').doc(id).get())
  );

  return friendDocs;
}

Future<List<String>> _getGroupMembers() async {
  DocumentSnapshot groupDoc = await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get();
  return List<String>.from(groupDoc['members'] ?? []);
}

Widget _buildFriendListTile(DocumentSnapshot friend, bool canInvite, Set<String> selectedFriends, StateSetter setState) {
  var userData = friend.data() as Map<String, dynamic>;
  String name = userData['fullName'] ?? 'Unknown';
  String photoUrl = userData['photoURL'] ?? '';

  return CheckboxListTile(
    value: selectedFriends.contains(friend.id),
    onChanged: canInvite ? (bool? value) {
      setState(() {
        if (value == true) {
          selectedFriends.add(friend.id);
        } else {
          selectedFriends.remove(friend.id);
        }
      });
    } : null,
    title: Text(name),
    subtitle: canInvite ? null : Text('Already in group', style: TextStyle(color: Colors.grey)),
    secondary: CircleAvatar(
      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: photoUrl.isEmpty ? Text(name[0].toUpperCase()) : null,
    ),
    controlAffinity: ListTileControlAffinity.trailing,
  );
}

void _inviteMultipleFriends(Set<String> friendIds) async {
  for (String friendId in friendIds) {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(friendId);
      DocumentSnapshot userDoc = await transaction.get(userRef);

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        List<dynamic> pendingInvites = userData['pendingInvites'] ?? [];
        if (!pendingInvites.contains(widget.groupId)) {
          pendingInvites.add(widget.groupId);
          transaction.update(userRef, {'pendingInvites': pendingInvites});
        }
      }
    });
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Invitations sent to ${friendIds.length} friends!')),
  );
}

  void _showDetailsDialog(Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Group Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${groupData['title'] ?? 'N/A'}'),
              SizedBox(height: 8),
              Text('Description: ${groupData['description'] ?? 'N/A'}'),
              // Add more details as needed
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showRSVPDialog(Map<String, dynamic> groupData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('RSVP'),
        content: Text('RSVP functionality to be implemented.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _saveGroupName() async {
    if (_nameController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({'title': _nameController.text});
      setState(() {
        _isEditing = false;
      });
    }
  }

  void _addActivity() {
    showDialog(
      context: context,
      builder: (context) => ActivityDialog(
        onSave: (name, description) {
          FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
            'activities': FieldValue.arrayUnion([{'name': name, 'description': description}])
          });
        },
      ),
    );
  }

void _editActivity(int index, Map<String, dynamic> activity) {
    showDialog(
      context: context,
      builder: (context) => ActivityDialog(
        initialName: activity['name'],
        initialDescription: activity['description'],
        onSave: (name, description) {
          FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get().then((doc) {
            List<dynamic> activities = List.from(doc.data()!['activities']);
            activities[index] = {'name': name, 'description': description};
            doc.reference.update({'activities': activities});
          });
        },
      ),
    );
  }

  

  Future<void> _getImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

Future<void> _submitPost() async {
  if (_postController.text.isEmpty && _image == null) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  String? imageUrl;
  if (_image != null) {
    imageUrl = await _uploadImage(_image!);
  }

  await FirebaseFirestore.instance.collection('group_posts').add({
    'groupId': widget.groupId,
    'authorId': user.uid,
    'authorName': user.displayName ?? 'Anonymous',
    'authorPhotoUrl': user.photoURL,
    'text': _postController.text,
    'imageUrl': imageUrl,
    'timestamp': FieldValue.serverTimestamp(),
  });

  _postController.clear();
  setState(() {
    _image = null;
  });
}
  Future<String> _uploadImage(File image) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('group_posts')
        .child('${DateTime.now().toIso8601String()}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

class ActivityDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final Function(String, String) onSave;

  ActivityDialog({this.initialName, this.initialDescription, required this.onSave});

  @override
  _ActivityDialogState createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<ActivityDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(text: widget.initialDescription);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialName == null ? 'Add Activity' : 'Edit Activity'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Activity Name'),
          ),
          TextField(
            controller: _descriptionController,
            decoration: InputDecoration(labelText: 'Description'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_nameController.text, _descriptionController.text);
            Navigator.pop(context);
          },
          child: Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
