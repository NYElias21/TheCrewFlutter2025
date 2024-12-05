import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;

  const ChatPage({
    Key? key, 
    required this.chatId, 
    required this.chatName, 
    required this.chatAvatar
  }) : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUserId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              backgroundImage: widget.chatAvatar.isNotEmpty ? NetworkImage(widget.chatAvatar) : null,
              child: widget.chatAvatar.isEmpty
                  ? Text(widget.chatName.isNotEmpty ? widget.chatName[0].toUpperCase() : '?')
                  : null,
            ),
            SizedBox(width: 10),
            Text(widget.chatName),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var messageData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                    bool isMe = messageData['senderId'] == currentUserId;
                    return ChatMessage(
                      text: messageData['text'],
                      isMe: isMe,
                      senderId: messageData['senderId'],
                      senderAvatar: isMe ? '' : widget.chatAvatar, // Pass empty string for current user
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

Widget _buildMessageComposer() {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8.0),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          offset: Offset(0, -2),
          blurRadius: 4,
          color: Colors.black.withOpacity(0.1),
        ),
      ],
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.photo),
          onPressed: () {
            // TODO: Implement image sending
          },
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            textInputAction: TextInputAction.send, // Add this line
            onSubmitted: (_) => _sendMessage(), // Add this line
            decoration: InputDecoration(
              hintText: 'Type a message',
              border: InputBorder.none,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.send),
          onPressed: _sendMessage,
        ),
      ],
    ),
  );
}

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add({
        'text': _messageController.text,
        'senderId': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update({
        'lastMessage': _messageController.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollController.animateTo(
        0.0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }
}

class ChatMessage extends StatelessWidget {
  final String text;
  final bool isMe;
  final String senderId;
  final String senderAvatar;

  const ChatMessage({
    Key? key,
    required this.text,
    required this.isMe,
    required this.senderId,
    required this.senderAvatar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              backgroundImage: senderAvatar.isNotEmpty ? NetworkImage(senderAvatar) : null,
              child: senderAvatar.isEmpty
                  ? Icon(Icons.person, size: 20, color: Colors.grey[600])
                  : null,
            ),
          SizedBox(width: 10),
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 15.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: isMe ? Colors.blue[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(text),
            ),
          ),
        ],
      ),
    );
  }
}