import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'create_postgc_page.dart';
import 'package:intl/intl.dart';
import 'profile_page.dart';  
import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'poll_components.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;

  const GroupDetailPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupDetailPageState createState() => _GroupDetailPageState();
}

// Move this class to the top level of the file
class CupertinoDateTextBox extends StatelessWidget {
  final DateTime initialValue;
  final Function(DateTime?) onDateChange;
  final String? hintText;

  const CupertinoDateTextBox({
    Key? key,
    required this.initialValue,
    required this.onDateChange,
    this.hintText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        DateTime? pickedDate = await showModalBottomSheet<DateTime>(
          context: context,
          builder: (context) {
            DateTime tempPickedDate = initialValue;
            return Container(
              height: 300,
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, tempPickedDate),
                        child: Text('Done'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.dateAndTime,
                      initialDateTime: initialValue,
                      onDateTimeChanged: (DateTime dateTime) {
                        tempPickedDate = dateTime;
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
        
        if (pickedDate != null) {
          onDateChange(pickedDate);
        }
      },
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              DateFormat('E, MMM d @ h:mm a').format(initialValue),
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}


class _GroupDetailPageState extends State<GroupDetailPage> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
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
    _messageController.dispose();
    commentController.dispose();
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

Widget safeNetworkImage(String? url, {BoxFit fit = BoxFit.cover}) {
  if (url == null || url.isEmpty) {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.image_not_supported),
    );
  }
  return Image.network(
    url,
    fit: fit,
    errorBuilder: (context, error, stackTrace) {
      print('Error loading image: $error');
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.error),
      );
    },
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


void _showNotesDialog(BuildContext context, int index, Map<String, dynamic> activity) {
  DateTime initialDate = activity['dateTime'] != null 
      ? DateTime.parse(activity['dateTime'])
      : DateTime.now();
  TextEditingController notesController = TextEditingController(text: activity['notes'] ?? '');
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 20),
            Text(
              'Make a note',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Let your friends know the details.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: CupertinoDateTextBox(
                initialValue: initialDate,
                onDateChange: (DateTime? date) {
                  if (date != null) {
                    initialDate = date;
                  }
                },
                hintText: 'Select date and time',
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: notesController,
                decoration: InputDecoration(
                  hintText: 'Add notes...',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: 3,
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    child: Text(
                      'Save',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 17,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFC107),
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.groupId)
                          .get()
                          .then((doc) {
                        List<dynamic> activities = List.from(doc.data()!['activities']);
                        activities[index] = {
                          ...activities[index],
                          'notes': notesController.text.trim(),
                          'dateTime': initialDate.toIso8601String(),
                        };
                        doc.reference.update({'activities': activities});
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
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
  print("Group Data: $groupData"); // Debug print
  List<dynamic> activities = groupData['activities'] ?? [];
  print("Activities from group: $activities"); // Debug print

  return ListView(
    padding: EdgeInsets.all(16),
    children: [
      // Build map with activities from groupData
      if (activities.isNotEmpty) 
        _buildOverviewMap(activities),
      
      // Activities Section Header
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activities',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            TextButton(
              onPressed: _addActivity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 4),
                  Text('Add'),
                ],
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),

      // Activities List
      if (activities.isEmpty)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No activities added yet',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              Text(
                'Add some activities to get started!',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
...activities.asMap().entries.map((entry) {
  int index = entry.key;
  Map<String, dynamic> activity = entry.value;
  List<String> imageUrls = List<String>.from(groupData['imageUrls'] ?? []);
  String? imageUrl = index < imageUrls.length ? imageUrls[index] : null;
  
  // Parse the datetime
  DateTime? activityDateTime;
  if (activity['dateTime'] != null) {
    activityDateTime = DateTime.parse(activity['dateTime']);
  }
  String timeDisplay = activityDateTime != null 
      ? DateFormat('MMM d, yyyy h:mm a').format(activityDateTime)
      : '[set time/date]';

  String notes = activity['notes'] ?? '[add notes]';
  
  return Card(
    elevation: 0,
    margin: EdgeInsets.only(bottom: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.grey[200]!, width: 1),
    ),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Image (unchanged)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl != null
              ? Image.network(
                  imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[200],
                    child: Icon(Icons.error, color: Colors.grey),
                  ),
                )
              : Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: Icon(Icons.image, color: Colors.grey),
                ),
          ),
          SizedBox(width: 16),
          // Right side - Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity['name'] ?? '[title]',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey[600]),
                      constraints: BoxConstraints(minWidth: 40),
                      padding: EdgeInsets.zero,
                      onPressed: () => _editActivity(index, activity),
                    ),
                  ],
                ),
InkWell(
  onTap: () => _showNotesDialog(context, index, activity),
  child: Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
        SizedBox(width: 4),
        Text(
          activity['dateTime'] != null 
              ? DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(activity['dateTime']))
              : '[set time/date]',
          style: TextStyle(
            color: activity['dateTime'] != null ? Colors.black87 : Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    ),
  ),
),
InkWell(
  onTap: () => _showNotesDialog(context, index, activity),
  child: Padding(
    padding: EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(Icons.note_add_outlined, size: 16, color: Colors.grey[600]),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            activity['notes'] ?? '[add notes]',
            style: TextStyle(
              color: activity['notes'] != null ? Colors.black87 : Colors.grey[600],
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  ),
),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Icon(Icons.thumb_down, color: Colors.grey[400]),
                        Text('Nope', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.remove_red_eye, color: Colors.grey[400]),
                        Text('Maybe', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                    Column(
                      children: [
                        Icon(Icons.favorite, color: Colors.grey[400]),
                        Text('Love it!', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}).toList(),
      
      SizedBox(height: 16), // Bottom padding
    ],
  );
}

Widget _buildFallbackDetailsView(Map<String, dynamic> groupData) {
  List<dynamic> userActivities = groupData['activities'] ?? [];

  return ListView(
    padding: EdgeInsets.all(16),
    children: [
      Text('Group Activities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      if (userActivities.isEmpty)
        Text('No activities added yet. Add some activities to get started!'),
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

Widget _buildOverviewMap(List<dynamic> activities) {
  if (activities.isEmpty) {
    return SizedBox.shrink();
  }

  return FutureBuilder<Set<Marker>>(
    future: _createMarkers(activities),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        print('Error creating markers: ${snapshot.error}');
        return Text('Error loading map');
      }

      Set<Marker> markers = snapshot.data ?? {};
      if (markers.isEmpty) {
        return SizedBox.shrink();
      }

      List<LatLng> points = markers.map((marker) => marker.position).toList();
      LatLngBounds bounds = _calculateBounds(points);
      LatLng center = _calculateCenter(bounds);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
          ),
          SizedBox(height: 16), // Keep some spacing between map and next element
        ],
      );
    },
  );
}

// In group_detail_page.dart, update the _createMarkers function:

Future<Set<Marker>> _createMarkers(List<dynamic> activities) async {
  Set<Marker> markers = {};
  int markerNumber = 1;

  print("Processing activities: $activities"); // Debug print

  for (var activity in activities) {
    print("Processing activity: $activity"); // Add this debug print

    if (activity is Map<String, dynamic>) {
      // Properly extract location data
      final location = activity['location'];
      if (location != null && location is Map<String, dynamic>) {
        // Extract lat/lng values, handling potential double or int types
        double? lat = location['lat'] is int 
            ? (location['lat'] as int).toDouble() 
            : location['lat'] as double?;
        
        double? lng = location['lng'] is int 
            ? (location['lng'] as int).toDouble() 
            : location['lng'] as double?;

        if (lat != null && lng != null) {
          String name = activity['name'] ?? 'Activity $markerNumber';
          print("Creating marker for $name at $lat, $lng"); // Add this debug print
          
          markers.add(Marker(
            markerId: MarkerId(name),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(
              title: "$markerNumber. $name",
              snippet: activity['description'] ?? ''
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
          markerNumber++;
        } else {
          print("Invalid lat/lng values in location data: $location");
        }
      } else {
        print("No valid location data found in activity: $activity");
      }
    }
  }

  print("Created ${markers.length} markers"); // Debug print
  return markers;
}

LatLngBounds _calculateBounds(List<LatLng> points) {
  if (points.isEmpty) {
    // Default bounds for North Carolina if no points
    return LatLngBounds(
      southwest: LatLng(33.8361, -84.3213),  // Southwest NC
      northeast: LatLng(36.5881, -75.4001),  // Northeast NC
    );
  }

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

  // Add padding to bounds
  double latPadding = (maxLat - minLat) * 0.1;
  double lngPadding = (maxLng - minLng) * 0.1;

  return LatLngBounds(
    southwest: LatLng(minLat - latPadding, minLng - lngPadding),
    northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
  );
}

LatLng _calculateCenter(LatLngBounds bounds) {
  return LatLng(
    (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
    (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
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
          radius: 20,
          backgroundColor: Colors.grey[300],
          backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null && 
                         FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty 
              ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
              : null,
          child: (FirebaseAuth.instance.currentUser?.photoURL == null || 
                 FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)
              ? Icon(Icons.person, size: 24, color: Colors.grey[600])
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
        padding: EdgeInsets.zero,
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

Widget _buildImageTile(String imageUrl) {
  if (imageUrl.isEmpty) {
    return Container(
      color: Colors.grey[300],
      child: Icon(Icons.image_not_supported),
    );
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      imageUrl,
      fit: BoxFit.cover,
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
      errorBuilder: (context, error, stackTrace) {
        print('Error loading image: $error');
        return Container(
          color: Colors.grey[300],
          child: Icon(Icons.error),
        );
      },
    ),
  );
}

Widget _buildPostCard(Map<String, dynamic> postData, String postId) {
  List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);
  
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
                FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(postData['authorId']).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[300],
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    String photoURL = '';
                    if (snapshot.hasData && snapshot.data != null) {
                      photoURL = snapshot.data!['photoURL'] ?? '';
                    }
                    return CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
                      child: photoURL.isEmpty
                          ? Icon(Icons.person, size: 24, color: Colors.grey[600])
                          : null,
                    );
                  },
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        postData['authorName'] ?? 'Unknown',
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
              postData['text'] ?? '',
              style: TextStyle(fontSize: 14),
            ),
            if (imageUrls.isNotEmpty && imageUrls.any((url) => url != null && url.isNotEmpty))
              Container(
                height: 200,
                margin: EdgeInsets.only(top: 12),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    if (imageUrls[index] == null || imageUrls[index].isEmpty) {
                      return Container(); // Skip null or empty URLs
                    }
                    return Container(
                      width: 200,
                      margin: EdgeInsets.only(right: 8),
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('Error loading image: $error');
                          return Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.error),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            // Comments Section
/*             SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ), */
            // Comments Stream
             SizedBox(height: 16),
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('group_posts')
      .doc(postId)
      .collection('comments')
      .orderBy('timestamp', descending: false)
      .snapshots(),
  builder: (context, snapshot) {
    if (snapshot.hasError) {
      return Text('Error loading comments');
    }

    if (snapshot.connectionState == ConnectionState.waiting) {
      return SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    List<DocumentSnapshot> comments = snapshot.data?.docs ?? [];
    int commentCount = comments.length;

    return InkWell(
      onTap: () {
        // Show bottom sheet with full comments
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            builder: (_, controller) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Comments list
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      padding: EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        Map<String, dynamic> commentData = comments[index].data() as Map<String, dynamic>;
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: commentData['authorPhoto'] != null 
                                  ? NetworkImage(commentData['authorPhoto'])
                                  : null,
                                child: commentData['authorPhoto'] == null 
                                  ? Icon(Icons.person, size: 16)
                                  : null,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          commentData['authorName'] ?? 'Anonymous',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          _formatTimestamp(commentData['timestamp'] as Timestamp),
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      commentData['text'] ?? '',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                              if (commentData['authorId'] == FirebaseAuth.instance.currentUser?.uid)
                                IconButton(
                                  icon: Icon(Icons.more_vert, size: 20),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (context) => Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: Icon(Icons.delete_outline, color: Colors.red),
                                            title: Text('Delete comment'),
                                            onTap: () async {
                                              await FirebaseFirestore.instance
                                                  .collection('group_posts')
                                                  .doc(postId)
                                                  .collection('comments')
                                                  .doc(comments[index].id)
                                                  .delete();
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Comment input
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: Colors.grey[200]!),
    ),
  ),
  child: Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[300],
        backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null && 
                       FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty 
            ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
            : null,
        child: (FirebaseAuth.instance.currentUser?.photoURL == null || 
               FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)
            ? Icon(Icons.person, size: 16, color: Colors.grey[600])
            : null,
      ),
      SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: commentController,
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          maxLines: null,
        ),
      ),
      SizedBox(width: 12),
      TextButton(
        onPressed: () async {
          if (commentController.text.trim().isNotEmpty) {
            final user = FirebaseAuth.instance.currentUser;
            await FirebaseFirestore.instance
                .collection('group_posts')
                .doc(postId)
                .collection('comments')
                .add({
              'text': commentController.text.trim(),
              'authorId': user?.uid,
              'authorName': user?.displayName ?? 'Anonymous',
              'authorPhoto': user?.photoURL,
              'timestamp': FieldValue.serverTimestamp(),
            });
            commentController.clear();
          }
        },
        child: Text('Post'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    ],
  ),
)
                ],
              ),
            ),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Icon(Icons.chat_bubble_outline, 
            size: 20, 
            color: Colors.grey[600]
          ),
          SizedBox(width: 4),
          Text(
            commentCount.toString(),
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  },
)
          ],
        ),
      ),
      Divider(height: 1, thickness: 0.5),
    ],
  );
}

/* void _showCommentDialog(BuildContext context, String postId) {
  final TextEditingController commentController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: FirebaseAuth.instance.currentUser?.photoURL != null && 
                                 FirebaseAuth.instance.currentUser!.photoURL!.isNotEmpty 
                      ? NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!)
                      : null,
                  child: (FirebaseAuth.instance.currentUser?.photoURL == null || 
                         FirebaseAuth.instance.currentUser!.photoURL!.isEmpty)
                      ? Icon(Icons.person, size: 16, color: Colors.grey[600])
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: commentController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    if (commentController.text.trim().isNotEmpty) {
                      final user = FirebaseAuth.instance.currentUser;
                      await FirebaseFirestore.instance
                          .collection('group_posts')
                          .doc(postId)
                          .collection('comments')
                          .add({
                        'text': commentController.text.trim(),
                        'authorId': user?.uid,
                        'authorName': user?.displayName ?? 'Anonymous',
                        'authorPhoto': user?.photoURL,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Post'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
} */

Widget _buildChatTab() {
  return Column(
    children: [
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('group_chats')
              .doc(widget.groupId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Something went wrong'));
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, 
                      size: 48, 
                      color: Colors.grey[400]
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      'Be the first to send a message!',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              //reverse: true,
              padding: EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var document = snapshot.data!.docs[snapshot.data!.docs.length - 1 - index];  // Reverse the index
                var message = document.data() as Map<String, dynamic>;
                
                // Handle poll messages
                if (message['type'] == 'poll') {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: PollMessage(
                      message: message,
                      groupId: widget.groupId,
                      messageId: document.id,
                    ),
                  );
                }

                // Handle regular text messages
                bool isMine = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isMine) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: message['senderPhoto'] != null 
                            ? NetworkImage(message['senderPhoto'])
                            : null,
                          child: message['senderPhoto'] == null 
                            ? Icon(Icons.person, size: 16)
                            : null,
                        ),
                        SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMine ? Colors.blue : Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    message['senderName'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                              Text(
                                message['text'] ?? '',
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMine) SizedBox(width: 24),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
Container(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border(top: BorderSide(color: Colors.grey[200]!)),
  ),
  child: Row(
    children: [
      // Single poll menu button
      IconButton(
        icon: Icon(Icons.poll_outlined),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.add_chart),
                  title: Text('Create Poll'),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreatePoll();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.history),
                  title: Text('View Polls'),
                  onTap: () {
                    Navigator.pop(context);
                    _showPollsHistory();
                  },
                ),
              ],
            ),
          );
        },
        color: Colors.grey[600],
      ),
      // Message input
      Expanded(
        child: TextField(
          controller: _messageController,
          decoration: InputDecoration(
            hintText: 'Type a message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      // Send button
      IconButton(
        icon: Icon(Icons.send, color: Colors.blue),
        onPressed: _sendMessage,
      ),
    ],
  ),
)
    ],
  );
}

void _showCreatePoll() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CreatePollBottomSheet(
      onPollCreated: (question, options) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        try {
          await FirebaseFirestore.instance
              .collection('group_chats')
              .doc(widget.groupId)
              .collection('messages')
              .add({
            'type': 'poll',  // Make sure this is set correctly
            'pollQuestion': question,
            'pollOptions': options,
            'votes': {},
            'timestamp': FieldValue.serverTimestamp(),
            'senderId': user.uid,
            'senderName': user.displayName ?? 'Anonymous',
            'senderPhoto': user.photoURL,
          });
          print('Poll created successfully'); // Debug message
        } catch (e) {
          print('Error creating poll: $e'); // Debug message
        }
      },
    ),
  );
}

void _showPollsHistory() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Polls',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Polls List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('group_chats')
                    .doc(widget.groupId)
                    .collection('messages')
                    .where('type', isEqualTo: 'poll')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  print('Stream status: ${snapshot.connectionState}');
                  print('Has data: ${snapshot.hasData}');
                  if (snapshot.hasData) {
                    print('Number of docs: ${snapshot.data!.docs.length}');
                  }
                  
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    print('Error loading polls: ${snapshot.error}');
                    return Center(child: Text('Error loading polls'));
                  }

                  final polls = snapshot.data?.docs ?? [];
                  
                  if (polls.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.poll_outlined, 
                            size: 64, 
                            color: Colors.grey[300]
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No polls yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Create a poll to get started',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(height: 24),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showCreatePoll();
                            },
                            icon: Icon(Icons.add),
                            label: Text('Create Poll'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Debug message for successful polls loading
                  print('Successfully loaded ${polls.length} polls');
                  
                  return ListView.separated(
                    controller: controller,
                    padding: EdgeInsets.all(16),
                    itemCount: polls.length,
                    separatorBuilder: (context, index) => SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      var pollData = polls[index].data() as Map<String, dynamic>;
                      String messageId = polls[index].id;
                      
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Poll content
                              PollMessage(
                                message: pollData,
                                groupId: widget.groupId,
                                messageId: messageId,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void _sendMessage() async {
  if (_messageController.text.trim().isEmpty) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'text': _messageController.text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Anonymous',
      'senderPhoto': user.photoURL,
    });

    _messageController.clear();
  } catch (e) {
    print('Error sending message: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send message')),
    );
  }
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
  // Initialize GooglePlace instance
  final googlePlace = GooglePlace('AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ActivityBottomSheet(
      googlePlace: googlePlace,
      onActivityAdded: (activity) async {
        await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).update({
          'activities': FieldValue.arrayUnion([activity.toMap()])
        });
      },
    ),
  );
}


void _editActivity(int index, Map<String, dynamic> activity) {
  final googlePlace = GooglePlace('AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM');

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ActivityBottomSheet(
      googlePlace: googlePlace,
      onActivityAdded: (activity) async {
        await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).get().then((doc) {
          List<dynamic> activities = List.from(doc.data()!['activities']);
          activities[index] = activity.toMap();
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

/* class ActivityDialog extends StatefulWidget {
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
 */

class ActivityBottomSheet extends StatefulWidget {
  final Function(Activity) onActivityAdded;
  final GooglePlace googlePlace;

  const ActivityBottomSheet({
    Key? key,
    required this.onActivityAdded,
    required this.googlePlace,
  }) : super(key: key);

  @override
  _ActivityBottomSheetState createState() => _ActivityBottomSheetState();
}

class _ActivityBottomSheetState extends State<ActivityBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  List<AutocompletePrediction> _predictions = [];
  bool _isDescriptionMode = false;
  AutocompletePrediction? _selectedPrediction;
  String? _selectedAddress;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() => _selectedTime = picked);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isDescriptionMode ? 'Add activity details' : 'Add place',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1),

            if (!_isDescriptionMode) ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search places',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              Expanded(
                child: _predictions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_on_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'Search a location to add to your activity',
                              style: TextStyle(color: Colors.grey[600], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        itemCount: _predictions.length,
                        itemBuilder: (context, index) {
                          final prediction = _predictions[index];
                          return ListTile(
                            leading: Icon(Icons.location_on_outlined),
                            title: Text(prediction.description ?? "Unknown"),
                            onTap: () {
                              setState(() {
                                _selectedPrediction = prediction;
                                _selectedAddress = prediction.description;
                                _isDescriptionMode = true;
                                _predictions = [];
                                _searchController.clear();
                              });
                            },
                          );
                        },
                      ),
              ),
            ] else if (_selectedAddress != null) ...[
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.place, color: Colors.grey[600]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _extractPlaceName(_selectedAddress!),
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                ),
                                Text(
                                  _selectedAddress!.substring(_extractPlaceName(_selectedAddress!).length + 2),
                                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),

                    Text('When?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text(_selectedDate != null 
                              ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                              : 'Select date'),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.access_time),
                            label: Text(_selectedTime != null 
                              ? _selectedTime!.format(context)
                              : 'Select time'),
                            onPressed: () => _selectTime(context),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),

                    Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Add notes about this activity...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 24),

                    Text('Description', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Write something about this place...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => _addActivity(context),
                  child: Text('Add Activity'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() => _predictions = []);
      return;
    }

    try {
      var result = await widget.googlePlace.autocomplete.get(
        value,
        components: [Component("country", "us")],
      );
      
      if (result?.predictions != null && mounted) {
        setState(() => _predictions = result!.predictions!);
      }
    } catch (e) {
      print("Error during places search: $e");
    }
  }

  String _extractPlaceName(String fullAddress) {
    return fullAddress.split(',')[0].trim();
  }

  Future<void> _addActivity(BuildContext context) async {
    if (_selectedPrediction != null) {
      var result = await widget.googlePlace.details.get(_selectedPrediction!.placeId ?? '');
      Map<String, double>? location;
      
      if (result?.result?.geometry?.location != null) {
        location = {
          'lat': result!.result!.geometry!.location!.lat!,
          'lng': result.result!.geometry!.location!.lng!
        };
      }

      DateTime? dateTime;
      if (_selectedDate != null && _selectedTime != null) {
        dateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
      }

      final activity = Activity(
        name: _extractPlaceName(_selectedAddress!),
        description: _descriptionController.text.trim(),
        placeDescription: _selectedAddress,
        location: location,
        notes: _notesController.text.trim(),
        dateTime: dateTime,
      );

      widget.onActivityAdded(activity);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${activity.name}'), duration: Duration(seconds: 2)),
      );
    }
  }
}

class Activity {
  final String name;
  final String description;
  final String? placeDescription;
  final Map<String, double>? location;
  final String? imageUrl;
  final String? notes;
  final DateTime? dateTime;
  final Key key;

  Activity({
    required this.name,
    this.description = '',
    this.placeDescription,
    this.location,
    this.imageUrl,
    this.notes,
    this.dateTime,
  }) : key = UniqueKey();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'placeDescription': placeDescription,
      'location': location,
      'imageUrl': imageUrl,
      'notes': notes,
      'dateTime': dateTime?.toIso8601String(),
    };
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