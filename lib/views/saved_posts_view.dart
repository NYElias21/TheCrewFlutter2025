import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedPostsView extends StatefulWidget {
  final String userId;
  final bool isPrivate;

  SavedPostsView({
    required this.userId,
    required this.isPrivate,
  });

  @override
  _SavedPostsViewState createState() => _SavedPostsViewState();
}

class _SavedPostsViewState extends State<SavedPostsView> {
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    if (!isOwnProfile && widget.isPrivate) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('This content is private'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // All Saved Section
        _buildAllSavedSection(),
        
        // New Collection Button
        if (isOwnProfile) 
          _buildNewCollectionButton(),
        
        // Collections Row
        _buildCollectionsRow(),

        // Unorganized Posts
        Expanded(
          child: _buildUnorganizedPosts(isOwnProfile),
        ),
      ],
    );
  }

  Widget _buildAllSavedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          int postCount = 0;
          if (snapshot.hasData) {
            var userData = snapshot.data?.data() as Map<String, dynamic>?;
            var savedPosts = userData?['savedPosts'] as Map<String, dynamic>?;
            postCount = savedPosts?.length ?? 0;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildAllSavedPreview(),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'All posts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$postCount posts',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAllSavedPreview() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var userData = snapshot.data?.data() as Map<String, dynamic>?;
        var savedPosts = userData?['savedPosts'] as Map<String, dynamic>?;
        if (savedPosts == null) return Container();

        return FutureBuilder<List<DocumentSnapshot>>(
          future: _fetchPosts(savedPosts.keys.take(2).toList()),
          builder: (context, postsSnapshot) {
            if (!postsSnapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }

            return Row(
              children: [
                ...postsSnapshot.data!.take(2).map((post) {
                  var postData = post.data() as Map<String, dynamic>;
                  List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.all(1),
                      color: Colors.grey[300],
                      child: imageUrls.isNotEmpty
                          ? Image.network(
                              imageUrls.first,
                              fit: BoxFit.cover,
                              height: double.infinity,
                            )
                          : Icon(Icons.image, color: Colors.grey[400]),
                    ),
                  );
                }),
                if (postsSnapshot.data!.length < 2)
                  ...List.generate(2 - postsSnapshot.data!.length, (index) => 
                    Expanded(
                      child: Container(
                        margin: EdgeInsets.all(1),
                        color: Colors.grey[300],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
  Widget _buildNewCollectionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: _showCreateCollectionDialog,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 20),
              SizedBox(width: 8),
              Text(
                'New collection',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCollectionsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('saved_collections')
          .where('userId', isEqualTo: widget.userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox.shrink();
        }

        var collections = snapshot.data?.docs ?? [];
        if (collections.isEmpty) {
          return SizedBox.shrink();
        }

        return Container(
          height: 250,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: collections.length,
            itemBuilder: (context, index) {
              var collection = collections[index].data() as Map<String, dynamic>;
              List<String> postIds = List<String>.from(collection['postIds'] ?? []);
              
              return Padding(
                padding: EdgeInsets.only(right: 16),
                child: Container(
                  width: MediaQuery.of(context).size.width / 2 - 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<List<DocumentSnapshot>>(
                            future: _fetchPosts(postIds.take(4).toList()),
                            builder: (context, postsSnapshot) {
                              if (!postsSnapshot.hasData) {
                                return Center(child: CircularProgressIndicator());
                              }

                              return GridView.count(
                                crossAxisCount: 2,
                                physics: NeverScrollableScrollPhysics(),
                                padding: EdgeInsets.all(2),
                                children: List.generate(4, (index) {
                                  if (index < (postsSnapshot.data?.length ?? 0)) {
                                    var post = postsSnapshot.data![index].data() as Map<String, dynamic>;
                                    List<String> imageUrls = List<String>.from(post['imageUrls'] ?? []);
                                    return Container(
                                      margin: EdgeInsets.all(1),
                                      child: imageUrls.isNotEmpty
                                          ? Image.network(
                                              imageUrls.first,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(color: Colors.grey[300]),
                                    );
                                  }
                                  return Container(
                                    margin: EdgeInsets.all(1),
                                    color: Colors.grey[300],
                                  );
                                }),
                              );
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        collection['name'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${postIds.length} posts',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildUnorganizedPosts(bool isOwnProfile) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Unorganized posts',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isOwnProfile)
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Implement organize functionality
                    },
                    icon: Icon(
                      Icons.add_to_photos_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                    label: Text(
                      'Organize',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          _buildSavedPostsGrid(),
        ],
      ),
    );
  }

  Widget _buildSavedPostsGrid() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var userData = snapshot.data?.data() as Map<String, dynamic>?;
        var savedPosts = userData?['savedPosts'] as Map<String, dynamic>?;
        if (savedPosts == null || savedPosts.isEmpty) {
          return Center(child: Text('No saved posts'));
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: savedPosts.length,
            itemBuilder: (context, index) {
              String postId = savedPosts.keys.elementAt(index);
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('posts')
                    .doc(postId)
                    .get(),
                builder: (context, postSnapshot) {
                  if (!postSnapshot.hasData) {
                    return Container(color: Colors.grey[300]);
                  }
                  return _buildPostThumbnail(postSnapshot.data!);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPostThumbnail(DocumentSnapshot post) {
    try {
      var postData = post.data() as Map<String, dynamic>;
      List<String> imageUrls = List<String>.from(postData['imageUrls'] ?? []);

      return GestureDetector(
        onTap: () {
          // TODO: Navigate to post detail
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: imageUrls.isNotEmpty
                ? Image.network(
                    imageUrls.first,
                    fit: BoxFit.cover,
                  )
                : Icon(Icons.image, color: Colors.grey[400]),
          ),
        ),
      );
    } catch (e) {
      print('Error building thumbnail for post: $e');
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.error, color: Colors.red),
      );
    }
  }

  Future<List<DocumentSnapshot>> _fetchPosts(List<String> postIds) async {
    List<DocumentSnapshot> posts = [];
    for (String id in postIds) {
      try {
        DocumentSnapshot post = await FirebaseFirestore.instance
            .collection('posts')
            .doc(id)
            .get();
        if (post.exists) {
          posts.add(post);
        }
      } catch (e) {
        print('Error fetching post $id: $e');
      }
    }
    return posts;
  }

  void _showCreateCollectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          title: Text('New collection'),
          content: TextField(
            controller: textController,
            decoration: InputDecoration(
              labelText: 'Collection name',
              hintText: 'Enter a name for your collection',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isNotEmpty) {
                  // TODO: Implement collection creation
                  Navigator.pop(context);
                }
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }
}