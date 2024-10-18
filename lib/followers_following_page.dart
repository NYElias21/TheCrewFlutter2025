import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';

class FollowersFollowingPage extends StatelessWidget {
  final String userId;
  final bool isFollowers;

  FollowersFollowingPage({required this.userId, required this.isFollowers});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isFollowers ? 'Followers' : 'Following'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(child: Text('No data available'));
          }

          List<String> userIds = List<String>.from(
            isFollowers ? (snapshot.data!['followers'] ?? []) : (snapshot.data!['following'] ?? [])
          );

          return ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, index) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(userIds[index]).get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return ListTile(title: Text('Loading...'));
                  }

                  var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(userData['photoURL'] ?? 'https://via.placeholder.com/100'),
                    ),
                    title: Text(userData['username'] ?? 'Unknown'),
                    subtitle: Text(userData['fullName'] ?? ''),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfilePage(userId: userIds[index]),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}