import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PollMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  final String groupId;
  final String messageId;

  const PollMessage({
    Key? key,
    required this.message,
    required this.groupId,
    required this.messageId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<dynamic> options = message['pollOptions'] ?? [];
    Map<String, dynamic> votes = Map<String, dynamic>.from(message['votes'] ?? {});
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message['pollQuestion'] ?? 'No question',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 12),
...options.map((option) {
  List<String> votesForOption = _getVotesForOption(votes, option);
  double percentage = 0;
  int totalVotes = _getTotalVotes(votes);
  
  // Only calculate percentage if there are votes
  if (totalVotes > 0) {
    percentage = (votesForOption.length / totalVotes) * 100;
  }
  
  return Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: PollOption(
      option: option,
      votes: votesForOption.length,
      percentage: percentage,
      isSelected: votesForOption.contains(FirebaseAuth.instance.currentUser?.uid),
      onTap: () => _handleVote(option),
    ),
  );
}).toList(),
          Divider(height: 16),
          Text(
            '${_getTotalVotes(votes)} votes',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getVotesForOption(Map<String, dynamic> votes, String option) {
    return List<String>.from(votes[option] ?? []);
  }

  int _getTotalVotes(Map<String, dynamic> votes) {
    int total = 0;
    votes.forEach((option, voters) {
      total += (voters as List).length;
    });
    return total;
  }

  void _handleVote(String option) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .get();

    Map<String, dynamic> currentVotes = Map<String, dynamic>.from(doc['votes'] ?? {});

    currentVotes.forEach((key, value) {
      if (value is List) {
        value.remove(userId);
      }
    });

    if (!currentVotes.containsKey(option)) {
      currentVotes[option] = [];
    }
    currentVotes[option].add(userId);

    await FirebaseFirestore.instance
        .collection('group_chats')
        .doc(groupId)
        .collection('messages')
        .doc(messageId)
        .update({'votes': currentVotes});
  }
}

class PollOption extends StatelessWidget {
  final String option;
  final int votes;
  final double percentage;
  final bool isSelected;
  final VoidCallback onTap;

  const PollOption({
    Key? key,
    required this.option,
    required this.votes,
    required this.percentage,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[100],
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: percentage / 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.grey[200],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black,
                      ),
                    ),
                  ),
                  Text(
                    '${percentage.round()}%',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CreatePollBottomSheet extends StatefulWidget {
  final Function(String, List<String>) onPollCreated;

  const CreatePollBottomSheet({
    Key? key,
    required this.onPollCreated,
  }) : super(key: key);

  @override
  _CreatePollBottomSheetState createState() => _CreatePollBottomSheetState();
}

class _CreatePollBottomSheetState extends State<CreatePollBottomSheet> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _questionController.dispose();
    for (var controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Create Poll',
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
            SizedBox(height: 16),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: 'Ask a question',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
            ...List.generate(_optionControllers.length, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionControllers[index],
                        decoration: InputDecoration(
                          hintText: 'Option ${index + 1}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (_optionControllers.length > 2)
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () {
                          setState(() {
                            _optionControllers[index].dispose();
                            _optionControllers.removeAt(index);
                          });
                        },
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _optionControllers.add(TextEditingController());
                });
              },
              icon: Icon(Icons.add),
              label: Text('Add Option'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_questionController.text.isNotEmpty &&
                    _optionControllers.every((c) => c.text.isNotEmpty)) {
                  widget.onPollCreated(
                    _questionController.text,
                    _optionControllers.map((c) => c.text).toList(),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Create Poll'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}