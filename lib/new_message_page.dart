import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_page.dart';

class NewMessagePage extends StatefulWidget {
  @override
  _NewMessagePageState createState() => _NewMessagePageState();
}

class _NewMessagePageState extends State<NewMessagePage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New Message'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for people',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('username', isGreaterThanOrEqualTo: _searchController.text)
                  .where('username', isLessThan: _searchController.text + 'z')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No users found'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    String userId = snapshot.data!.docs[index].id;
                    if (userId == FirebaseAuth.instance.currentUser!.uid) {
                      return SizedBox.shrink();
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(userData['avatar'] ?? 'https://example.com/default_avatar.png'),
                      ),
                      title: Text(userData['username'] ?? 'Unknown User'),
                      onTap: () => _startChat(context, userId, userData['username'] ?? 'Unknown User', userData['avatar'] ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _startChat(BuildContext context, String userId, String username, String avatar) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      
      final existingChatQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      String chatId;
      DocumentReference chatDocRef;

      final existingChat = existingChatQuery.docs.firstWhereOrNull(
        (doc) => (doc.data()['participants'] as List).contains(userId),
      );

      if (existingChat != null) {
        chatId = existingChat.id;
        chatDocRef = existingChat.reference;
      } else {
        chatDocRef = await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUserId, userId],
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'unreadCount': 0,
        });
        chatId = chatDocRef.id;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatPage(
          chatId: chatId, 
          chatName: username,
          chatAvatar: avatar,
        )),
      );
    } catch (e) {
      print('Error starting chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start chat. Please try again.')),
      );
    }
  }
}

extension FirstWhereOrNullExtension<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (E element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}