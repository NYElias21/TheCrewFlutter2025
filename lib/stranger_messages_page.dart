import 'package:flutter/material.dart';

class StrangerMessagesPage extends StatefulWidget {
  @override
  _StrangerMessagesPageState createState() => _StrangerMessagesPageState();
}

class _StrangerMessagesPageState extends State<StrangerMessagesPage> {
  // This list would typically be populated from a backend service
  final List<StrangerMessage> _messages = [
    StrangerMessage(
      senderName: 'Lost City',
      message: 'You are not friends on Lemon8. Protect your privacy.',
      time: '02:48 AM',
    ),
    // Add more sample messages here
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages from Strangers'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: ListView.builder(
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          return StrangerMessageItem(
            message: _messages[index],
            onAccept: () => _handleAccept(_messages[index]),
            onDecline: () => _handleDecline(_messages[index]),
          );
        },
      ),
    );
  }

  void _handleAccept(StrangerMessage message) {
    // TODO: Implement accept logic
    // This would typically involve adding the user to friends list
    // and moving the conversation to regular chats
    setState(() {
      _messages.remove(message);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Accepted message from ${message.senderName}')),
    );
  }

  void _handleDecline(StrangerMessage message) {
    // TODO: Implement decline logic
    // This would typically involve deleting the message
    setState(() {
      _messages.remove(message);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Declined message from ${message.senderName}')),
    );
  }
}

class StrangerMessage {
  final String senderName;
  final String message;
  final String time;

  StrangerMessage({
    required this.senderName,
    required this.message,
    required this.time,
  });
}

class StrangerMessageItem extends StatelessWidget {
  final StrangerMessage message;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const StrangerMessageItem({
    Key? key,
    required this.message,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  message.senderName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  message.time,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(message.message),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: Text('Decline'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onAccept,
                  child: Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}