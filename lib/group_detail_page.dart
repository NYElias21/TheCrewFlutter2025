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
  icon: Icon(Icons.more_vert, color: Colors.white),
  onPressed: () {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Icon(Icons.people_outline),
              title: Text('Group Members'),
              onTap: () {
                Navigator.pop(context);
                _showAllMembers(context, groupData['members'] ?? []);
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Edit Group'),
              onTap: () {
                Navigator.pop(context);
                _editPlan(groupData);
              },
            ),
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red),
              title: Text('Leave Group', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showLeaveGroupDialog();
              },
            ),
          ],
        ),
      ),
    );
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
    GestureDetector(
      onTap: () => _showDatePicker(context, date),
      child: Text(
        date != null ? DateFormat('EEE, MMM d').format(date) : 'Set date',
        style: TextStyle(color: Colors.grey),
      ),
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

void _showLeaveGroupDialog() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Leave Group'),
        content: Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              try {
                final String userId = FirebaseAuth.instance.currentUser!.uid;
                
                // Start a batch write
                WriteBatch batch = FirebaseFirestore.instance.batch();
                
                // Remove user from group members
                DocumentReference groupRef = FirebaseFirestore.instance
                    .collection('groups')
                    .doc(widget.groupId);
                    
                batch.update(groupRef, {
                  'members': FieldValue.arrayRemove([userId])
                });
                
                // Remove group from user's groups
                DocumentReference userRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(userId);
                    
                batch.update(userRef, {
                  'groups': FieldValue.arrayRemove([widget.groupId])
                });
                
                // Commit the batch
                await batch.commit();
                
                Navigator.pop(context);  // Close dialog
                Navigator.pop(context);  // Return to previous screen
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('You have left the group'))
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error leaving group: $e'))
                );
              }
            },
            child: Text('Leave'),
          ),
        ],
      );
    },
  );
}

void _showAddNoteDialog(BuildContext context, int index, Map<String, dynamic> activity) {
  final TextEditingController noteController = TextEditingController();

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
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Note',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Write your note...',
                  helperText: 'Swipe left to delete, right to edit notes',
                  helperStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  border: InputBorder.none,
                ),
                maxLines: 3,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (noteController.text.trim().isNotEmpty) {
                        await _addNoteToActivity(index, {
                          'text': noteController.text.trim(),
                          'timestamp': DateTime.now().toIso8601String(),
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _addNoteToActivity(int activityIndex, Map<String, dynamic> note) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(widget.groupId)
      .get()
      .then((doc) {
    List<dynamic> activities = List.from(doc.data()!['activities']);
    var currentNotes = activities[activityIndex]['notes'];
    List<dynamic> notes = [];
    
    if (currentNotes is String) {
      // Convert old format to new format if there's existing content
      if (currentNotes.isNotEmpty) {
        notes.add({
          'text': currentNotes,
          'timestamp': activities[activityIndex]['dateTime'] ?? DateTime.now().toIso8601String(),
        });
      }
    } else if (currentNotes is List) {
      notes = List.from(currentNotes);
    }
    
    notes.add(note);
    activities[activityIndex] = {
      ...activities[activityIndex],
      'notes': notes,
    };
    doc.reference.update({'activities': activities});
  });
}

void _editNote(BuildContext context, int activityIndex, int noteIndex, Map<String, dynamic> note) {
  final TextEditingController noteController = TextEditingController(text: note['text']);

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
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit Note',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: 'Write your note...',
                  border: InputBorder.none,
                ),
                maxLines: 3,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (noteController.text.trim().isNotEmpty) {
                        await _updateNote(activityIndex, noteIndex, {
                          'text': noteController.text.trim(),
                          'timestamp': DateTime.now().toIso8601String(),
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _updateNote(int activityIndex, int noteIndex, Map<String, dynamic> updatedNote) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(widget.groupId)
      .get()
      .then((doc) {
    List<dynamic> activities = List.from(doc.data()!['activities']);
    var currentNotes = activities[activityIndex]['notes'];
    List<dynamic> notes = [];
    
    if (currentNotes is String) {
      // Convert old format to new format
      if (currentNotes.isNotEmpty) {
        notes = [{
          'text': currentNotes,
          'timestamp': activities[activityIndex]['dateTime'] ?? DateTime.now().toIso8601String(),
        }];
      }
    } else if (currentNotes is List) {
      notes = List.from(currentNotes);
    }

    if (noteIndex < notes.length) {
      notes[noteIndex] = updatedNote;
    }
    
    activities[activityIndex] = {
      ...activities[activityIndex],
      'notes': notes,
    };
    doc.reference.update({'activities': activities});
  });
}

Future<void> _deleteNote(BuildContext context, int activityIndex, int noteIndex) async {
  await FirebaseFirestore.instance
      .collection('groups')
      .doc(widget.groupId)
      .get()
      .then((doc) {
    List<dynamic> activities = List.from(doc.data()!['activities']);
    var currentNotes = activities[activityIndex]['notes'];
    List<dynamic> notes = [];
    
    if (currentNotes is String) {
      // Convert old format to new format
      if (currentNotes.isNotEmpty) {
        notes = [{
          'text': currentNotes,
          'timestamp': activities[activityIndex]['dateTime'] ?? DateTime.now().toIso8601String(),
        }];
      }
    } else if (currentNotes is List) {
      notes = List.from(currentNotes);
    }

    if (noteIndex < notes.length) {
      notes.removeAt(noteIndex);
    }
    
    activities[activityIndex] = {
      ...activities[activityIndex],
      'notes': notes,
    };
    doc.reference.update({'activities': activities});
  });
}

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage(userId: userId)),
    );
  }

void _showDatePicker(BuildContext context, DateTime? currentDate) {
  DateTime initialDateTime = currentDate ?? DateTime.now();
  DateTime tempDateTime = initialDateTime;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set Date & Time',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              
              // Selected date display
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[900] 
                    : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  DateFormat('EEE, MMM d @ h:mm a').format(tempDateTime),
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),

              // Date picker
              Container(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime dateTime) {
                    setState(() {
                      tempDateTime = dateTime;
                    });
                  },
                ),
              ),
              SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection('groups')
                            .doc(widget.groupId)
                            .update({'date': Timestamp.fromDate(tempDateTime)});
                        Navigator.pop(context);
                      },
                      child: Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFFC107),
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _editPlan(Map<String, dynamic> groupData) {
  DateTime selectedDate = groupData['date'] != null 
      ? (groupData['date'] as Timestamp).toDate()
      : DateTime.now();
  List<dynamic> activities = List.from(groupData['activities'] ?? []);
  _nameController.text = groupData['title'] ?? '';
  String currentCoverPhoto = groupData['imageUrls']?[0] ?? '';
  File? selectedImage;

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      selectedImage = File(image.path);
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('groups/$fileName');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Edit plan',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Photo Section
                      Text(
                        'Cover Photo',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          await pickImage();
                          setState(() {}); // Rebuild to show new image
                        },
                        child: Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            image: selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : currentCoverPhoto.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(currentCoverPhoto),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: selectedImage == null && currentCoverPhoto.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to add cover photo',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),

                      SizedBox(height: 24),

                      Text(
                        'Name of Plan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.close, color: Colors.grey),
                              onPressed: () => _nameController.clear(),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      
                      Text(
                        'Date & time',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: CupertinoDateTextBox(
                          initialValue: selectedDate,
                          onDateChange: (DateTime? date) {
                            if (date != null) {
                              setState(() {
                                selectedDate = date;
                              });
                            }
                          },
                        ),
                      ),

                      SizedBox(height: 24),
                      Text(
                        'Activities',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Drag and drop in the order you want to do them',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: activities.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (oldIndex < newIndex) {
                              newIndex -= 1;
                            }
                            final item = activities.removeAt(oldIndex);
                            activities.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final activity = activities[index];
                          return Container(
                            key: ValueKey(activity['name'] + index.toString()),
                            margin: EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  activity['photoUrl'] ?? 'https://via.placeholder.com/50',
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[300],
                                      child: Icon(Icons.image, color: Colors.grey[600]),
                                    );
                                  },
                                ),
                              ),
                              title: Text(activity['name'] ?? ''),
                              subtitle: Text(
                                activity['placeDescription']?.split(',').first ?? '',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.drag_handle, color: Colors.grey[400]),
                                  SizedBox(width: 12),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.grey),
                                    onPressed: () {
                                      setState(() {
                                        activities.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Update Button
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    if (_nameController.text.trim().isNotEmpty) {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return Center(child: CircularProgressIndicator());
                        },
                      );

                      try {
                        // Upload new image if selected
                        String? newImageUrl;
                        if (selectedImage != null) {
                          newImageUrl = await uploadImage(selectedImage!);
                        }

                        // Prepare update data
                        Map<String, dynamic> updateData = {
                          'title': _nameController.text.trim(),
                          'date': Timestamp.fromDate(selectedDate),
                          'activities': activities,
                        };

                        // Add new image URL if available
                        if (newImageUrl != null) {
                          updateData['imageUrls'] = [newImageUrl];
                        }

                        // Update Firestore
                        await FirebaseFirestore.instance
                          .collection('groups')
                          .doc(widget.groupId)
                          .update(updateData);

                        // Close loading dialog and edit sheet
                        Navigator.of(context).pop(); // Close loading indicator
                        Navigator.of(context).pop(); // Close edit sheet
                      } catch (e) {
                        // Close loading dialog and show error
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error updating plan: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFC107),
                    foregroundColor: Colors.black,
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showDateTimePicker(BuildContext context, int index, Map<String, dynamic> activity) {
  DateTime initialDate = activity['dateTime'] != null 
      ? DateTime.parse(activity['dateTime'])
      : DateTime.now();
  DateTime tempDateTime = initialDate;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Text(
              'Set Date & Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 24),
            
            // Current selection display
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[900] 
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                DateFormat('EEE, MMM d @ h:mm a').format(tempDateTime),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),

            // Date Picker
            Container(
              height: 200,
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: initialDate,
                onDateTimeChanged: (DateTime dateTime) {
                  setState(() {
                    tempDateTime = dateTime;
                  });
                },
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),
            ),
            SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                // Cancel Button
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 16),
                // Save Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFC107),
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text('Save'),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                        .collection('groups')
                        .doc(widget.groupId)
                        .get()
                        .then((doc) {
                          List<dynamic> activities = List.from(doc.data()!['activities']);
                          activities[index] = {
                            ...activities[index],
                            'dateTime': tempDateTime.toIso8601String(),
                          };
                          doc.reference.update({'activities': activities});
                        });
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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
  List<dynamic> activities = groupData['activities'] ?? [];

  return ListView(
    padding: EdgeInsets.all(16),
    children: [
      if (activities.isNotEmpty) 
        _buildOverviewMap(activities),
      
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
            TextButton.icon(
              onPressed: _addActivity,
              icon: Icon(Icons.add, size: 20),
              label: Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),

      if (activities.isEmpty)
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'No activities added yet',
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              Text(
                'Add some activities to get started!',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),

      ...activities.asMap().entries.map((entry) {
        int index = entry.key;
        Map<String, dynamic> activity = entry.value;
        List<String> imageUrls = List<String>.from(groupData['imageUrls'] ?? []);
        String? imageUrl = index < imageUrls.length ? imageUrls[index] : null;
        List<dynamic> notes = [];
var rawNotes = activity['notes'];
if (rawNotes is String && rawNotes.isNotEmpty) {
  // Convert old format (single string) to new format (list of notes)
  notes = [{
    'text': rawNotes,
    'timestamp': activity['dateTime'] ?? DateTime.now().toIso8601String(),
  }];
} else if (rawNotes is List) {
  notes = List.from(rawNotes);
}
        
        DateTime? activityDateTime;
        if (activity['dateTime'] != null) {
          activityDateTime = DateTime.parse(activity['dateTime']);
        }

        return Card(
          margin: EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
// Inside the activities map in _buildDetailsTab, update the image display:
child: SizedBox(
  width: 80,
  height: 80,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: activity['photoUrl'] != null && activity['photoUrl'].toString().isNotEmpty
      ? Image.network(
          activity['photoUrl'],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null 
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('Error loading activity image: $error for URL: ${activity['photoUrl']}');
            return Container(
              color: Colors.grey[200],
              child: Icon(Icons.image, color: Colors.grey[600], size: 24),
            );
          },
        )
      : Container(
          color: Colors.grey[200],
          child: Icon(Icons.image, color: Colors.grey[600], size: 24),
        ),
  ),
),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
Text(
  activity['name'] ?? '[title]',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    fontWeight: FontWeight.w600,
    fontSize: 16,
  ),
),
                          SizedBox(height: 8),
InkWell(
  onTap: () => _showDateTimePicker(context, index, activity),
  child: Row(
    children: [
      Icon(Icons.access_time, 
        size: 16, 
        color: Theme.of(context).brightness == Brightness.dark 
          ? Colors.white54 
          : Colors.grey[600]
      ),
      SizedBox(width: 4),
      Expanded(
        child: Text(
          activity['dateTime'] != null 
            ? DateFormat('MMM d, yyyy h:mm a')
                .format(DateTime.parse(activity['dateTime']))
            : 'Set time/date',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 14,
            color: activity['dateTime'] != null 
              ? Theme.of(context).brightness == Brightness.dark 
                ? Colors.white54 
                : Colors.black87
              : Colors.grey[600]
          ),
        ),
      ),
    ],
  ),
),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
children: [
Container(
  decoration: BoxDecoration(
    border: Border(
      top: BorderSide(color: Colors.grey[200]!),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Description Section
      if (activity['description'] != null && activity['description'].toString().isNotEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
Text(
  'Description',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
),
                  SizedBox(height: 8),
Text(
  activity['description'],
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontSize: 15,
    height: 1.4,
  ),
),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey[200]),
          ],
        ),

      // Notes Section
      // Notes Section
Padding(
  padding: EdgeInsets.fromLTRB(16, 16, 16, 8), // Reduced bottom padding
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        'Notes',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      TextButton.icon(
        onPressed: () => _showAddNoteDialog(context, index, activity),
        icon: Icon(Icons.add, size: 20),
        label: Text('Add'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.blue,
          padding: EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    ],
  ),
),
if (notes.isEmpty)
  Center(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 16), // Reduced padding
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.note_alt_outlined, 
            size: 48, 
            color: Colors.grey[400]
          ),
          SizedBox(height: 12),
          Text(
            'No notes yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Add notes to keep track of details',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  )
else
  ListView.builder(
    shrinkWrap: true,
    physics: NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero, // Removed top padding
    itemCount: notes.length,
    itemBuilder: (context, noteIndex) {
      // Rest of the note item code remains the same
            final note = notes[noteIndex];
            DateTime noteTime = DateTime.parse(note['timestamp']);

            return Dismissible(
              key: Key('note-$noteIndex-${note['timestamp']}'),
              background: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                color: Colors.blue[100],
                alignment: Alignment.centerLeft,
                child: Icon(Icons.edit, color: Colors.blue),
              ),
              secondaryBackground: Container(
                padding: EdgeInsets.symmetric(horizontal: 16),
                color: Colors.red[100],
                alignment: Alignment.centerRight,
                child: Icon(Icons.delete, color: Colors.red),
              ),
              confirmDismiss: (direction) async {
                if (direction == DismissDirection.startToEnd) {
                  // Edit
                  _editNote(context, index, noteIndex, note);
                  return false;
                } else {
                  // Delete
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('Delete Note'),
                        content: Text('Are you sure you want to delete this note?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                              _deleteNote(context, index, noteIndex);
                            },
                            child: Text('Delete', 
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
child: Container(
  decoration: BoxDecoration(
    border: noteIndex < notes.length - 1 ? Border(
      bottom: BorderSide(
        color: Colors.grey[200]!,
        width: 0.5, // Made thinner
      ),
    ) : null, // No border for the last item
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          note['text'],
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
          ),
        ),
        SizedBox(height: 8),
        Text(
          DateFormat('MMM d, yyyy h:mm a').format(noteTime),
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    ),
  ),
),
            );
          },
        ),
    ],
  ),
),
              ],
            ),
          ),
        );
      }).toList(),
      
      SizedBox(height: 16),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
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
    textInputAction: TextInputAction.done,  // Add this line
    onEditingComplete: () => FocusScope.of(context).unfocus(),  // Add this line
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

Future<void> _selectDateTime(BuildContext context) async {
  DateTime initialDateTime = DateTime.now();
  if (_selectedDate != null && _selectedTime != null) {
    initialDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  DateTime? pickedDateTime = await showModalBottomSheet<DateTime>(
    context: context,
    builder: (context) {
      DateTime tempDateTime = initialDateTime;
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
                  onPressed: () => Navigator.pop(context, tempDateTime),
                  child: Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: initialDateTime,
                onDateTimeChanged: (DateTime dateTime) {
                  tempDateTime = dateTime;
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  if (pickedDateTime != null) {
    setState(() {
      _selectedDate = DateTime(
        pickedDateTime.year,
        pickedDateTime.month,
        pickedDateTime.day,
      );
      _selectedTime = TimeOfDay(
        hour: pickedDateTime.hour,
        minute: pickedDateTime.minute,
      );
    });
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
              child: SingleChildScrollView(
                controller: controller,
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 100,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
        label: Text(
          _selectedDate != null && _selectedTime != null
            ? DateFormat('EEE, MMM d @ h:mm a').format(
                DateTime(
                  _selectedDate!.year,
                  _selectedDate!.month,
                  _selectedDate!.day,
                  _selectedTime!.hour,
                  _selectedTime!.minute,
                )
              )
            : 'Select date & time'
        ),
        onPressed: () => _selectDateTime(context),
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
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
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
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
    String? photoUrl;
    
    if (result?.result?.geometry?.location != null) {
      location = {
        'lat': result!.result!.geometry!.location!.lat!,
        'lng': result!.result!.geometry!.location!.lng!
      };
    }

    // Get photo URL and add logging
    if (result?.result?.photos != null && result!.result!.photos!.isNotEmpty) {
      String photoReference = result.result!.photos![0].photoReference!;
      photoUrl = 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoReference&key=AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM';
      print('Generated photo URL: $photoUrl'); // Add this debug line
    } else {
      print('No photos available for this place');
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
      photoUrl: photoUrl,
      notes: [
        {
          'text': _notesController.text.trim(),
          'timestamp': DateTime.now().toIso8601String(),
        }
      ],
      dateTime: dateTime,
    );

    print('Adding activity with data: ${activity.toMap()}'); // Add this debug line
    
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
  final String? photoUrl;  // Add this field
  final List<Map<String, dynamic>> notes;
  final DateTime? dateTime;
  final Key key;

  Activity({
    required this.name,
    this.description = '',
    this.placeDescription,
    this.location,
    this.photoUrl,  // Add this parameter
    this.notes = const [],
    this.dateTime,
  }) : key = UniqueKey();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'placeDescription': placeDescription,
      'location': location,
      'photoUrl': photoUrl,  // Include in the map
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