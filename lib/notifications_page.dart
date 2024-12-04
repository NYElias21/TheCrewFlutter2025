import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';
import 'new_message_page.dart';
import 'group_detail_page.dart';

class NotificationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => NewMessagePage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          // Group Invites Section
          _buildGroupInvitesSection(currentUserId),
          Divider(height: 1, color: Colors.grey[300]),

          // Fixed top section
          _buildNotificationItem(
            icon: Icons.person_add_alt_1_outlined,
            color: Colors.orangeAccent,
            title: 'New followers',
            onTap: () {
              // Handle new followers tap
            },
          ),
          _buildNotificationItem(
            icon: Icons.favorite_border,
            color: Colors.redAccent,
            title: 'Likes and saves',
            onTap: () {
              // Handle likes and saves tap
            },
          ),
          _buildNotificationItem(
            icon: Icons.comment_outlined,
            color: Colors.blueAccent,
            title: 'Comments and mentions',
            onTap: () {
              // Handle comments and mentions tap
            },
          ),
          Divider(height: 1, color: Colors.grey[300]),

          // Chats section
          _buildChatsSection(currentUserId),
        ],
      ),
    );
  }

Widget _buildGroupInvitesSection(String currentUserId) {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Error loading invites'));
      }
      if (!snapshot.hasData || !snapshot.data!.exists) {
        return SizedBox.shrink();
      }

      // Safely cast the data with null check
      var userData = snapshot.data!.data();
      if (userData == null) {
        return SizedBox.shrink();
      }

      var data = userData as Map<String, dynamic>;
      List<dynamic> pendingInvites = data['pendingInvites'] ?? [];
      
      if (pendingInvites.isEmpty) {
        return SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Group Invites',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: pendingInvites.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('groups').doc(pendingInvites[index]).get(),
                builder: (context, groupSnapshot) {
                  if (!groupSnapshot.hasData || !groupSnapshot.data!.exists) {
                    return SizedBox.shrink();
                  }

                  // Safely cast the group data with null check
                  var groupData = groupSnapshot.data!.data();
                  if (groupData == null) {
                    return SizedBox.shrink();
                  }

                  var group = groupData as Map<String, dynamic>;
                  
                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group['title'] ?? 'Unnamed Group',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You have been invited to join this group',
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                child: Text('Decline'),
                                onPressed: () => _declineInvite(context, currentUserId, pendingInvites[index]),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blueAccent,
                                ),
                              ),
                              SizedBox(width: 16),
                              ElevatedButton(
                                child: Text('Accept'),
                                onPressed: () => _acceptInvite(context, currentUserId, pendingInvites[index]),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );
    },
  );
}

  Widget _buildChatsSection(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading messages'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No messages yet'));
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var chatDoc = snapshot.data!.docs[index];
            Map<String, dynamic> chatData = chatDoc.data() as Map<String, dynamic>;
            String otherUserId = chatData['participants']
                .firstWhere((id) => id != currentUserId);
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) return ListTile(title: Text('Loading...'));
                var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                return ChatListItem(
                  avatar: userData['photoURL'] ?? '',
                  name: userData['username'] ?? 'Unknown User',
                  message: chatData['lastMessage'] ?? 'No messages yet',
                  time: _formatTimestamp(chatData['lastMessageTime'] as Timestamp?),
                  unreadCount: chatData['unreadCount'] ?? 0,
                  onTap: () => _openChat(context, chatDoc.id, userData['username'] ?? 'Unknown User', userData['photoURL'] ?? ''),
                  userId: otherUserId,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _openChat(BuildContext context, String chatId, String chatName, String chatAvatar) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ChatPage(
        chatId: chatId, 
        chatName: chatName,
        chatAvatar: chatAvatar,
      )),
    );
  }

  void _acceptInvite(BuildContext context, String userId, String groupId) async {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      DocumentReference groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);

      DocumentSnapshot userSnapshot = await transaction.get(userRef);
      DocumentSnapshot groupSnapshot = await transaction.get(groupRef);

      List<dynamic> pendingInvites = List<dynamic>.from(userSnapshot['pendingInvites'] ?? []);
      List<dynamic> groupMembers = List<dynamic>.from(groupSnapshot['members'] ?? []);

      pendingInvites.remove(groupId);
      groupMembers.add(userId);

      transaction.update(userRef, {'pendingInvites': pendingInvites});
      transaction.update(groupRef, {'members': groupMembers});
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You have joined the group')));

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupDetailPage(groupId: groupId)),
    );
  }

  void _declineInvite(BuildContext context, String userId, String groupId) async {
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({
      'pendingInvites': FieldValue.arrayRemove([groupId])
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite declined')));
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No time';
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();
    if (dateTime.year == now.year && dateTime.month == now.month && dateTime.day == now.day) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class ChatListItem extends StatelessWidget {
  final String avatar;
  final String name;
  final String message;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;
  final String userId;

  const ChatListItem({
    Key? key,
    required this.avatar,
    required this.name,
    required this.message,
    required this.time,
    required this.unreadCount,
    required this.onTap,
    required this.userId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          String userPhotoUrl = '';
          if (snapshot.hasData && snapshot.data != null) {
            // Use null-aware operator to safely access 'photoURL'
            userPhotoUrl = (snapshot.data!.data() as Map<String, dynamic>)?['photoURL'] ?? '';
          }
          return CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
            child: userPhotoUrl.isEmpty
                ? Icon(Icons.person, size: 30, color: Colors.grey[600])
                : null,
          );
        },
      ),
      title: Text(name, style: TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: TextStyle(color: Colors.grey, fontSize: 12)),
          SizedBox(height: 4),
          if (unreadCount > 0)
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: Text(
                unreadCount.toString(),
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}