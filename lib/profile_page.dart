import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'post_detail_page.dart';
import 'settings_page.dart';
import 'followers_following_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  final String? userId;

  ProfilePage({this.userId});

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _username = '';
  String _fullName = '';
  String _bio = '';
  String? _userPhotoURL;  // Change to nullable
  int _following = 0;
  int _followers = 0;
  bool _isLoading = true;
  bool _isFollowing = false;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = widget.userId ?? currentUser!.uid;
    _loadUserData();
    if (widget.userId != null && widget.userId != currentUser!.uid) {
      _checkIfFollowing();
    }
  }
Future<void> _loadUserData() async {
    try {
      DocumentSnapshot userData = await _firestore.collection('users').doc(_userId).get();
      if (userData.exists) {
        var data = userData.data() as Map<String, dynamic>;
        setState(() {
          _username = data['username'] ?? '';
          _fullName = data['fullName'] ?? '';
          _bio = data['bio'] ?? 'Add a bio';
          _following = data['following']?.length ?? 0;
          _followers = data['followers']?.length ?? 0;
          _userPhotoURL = data['photoURL'];  // This can be null
          _isLoading = false;
        });
      } else {
        print('User document does not exist in Firestore');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

    Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _userId == currentUser!.uid ? _navigateToEditProfile : null,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[200],
        backgroundImage: _userPhotoURL != null ? NetworkImage(_userPhotoURL!) : null,
        child: _userPhotoURL == null
            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
            : null,
      ),
    );
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          fullName: _fullName,
          username: _username,
          bio: _bio,
          photoURL: _userPhotoURL,
        ),
      ),
    );

    if (result == true) {
      _loadUserData();
    }
  }

  Future<void> _checkIfFollowing() async {
    DocumentSnapshot currentUserDoc = await _firestore.collection('users').doc(currentUser!.uid).get();
    List<String> following = List<String>.from(currentUserDoc['following'] ?? []);
    setState(() {
      _isFollowing = following.contains(_userId);
    });
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isFollowing = !_isFollowing;
      _followers += _isFollowing ? 1 : -1;
    });

    DocumentReference currentUserRef = _firestore.collection('users').doc(currentUser!.uid);
    DocumentReference profileUserRef = _firestore.collection('users').doc(_userId);

    if (_isFollowing) {
      await currentUserRef.update({
        'following': FieldValue.arrayUnion([_userId])
      });
      await profileUserRef.update({
        'followers': FieldValue.arrayUnion([currentUser!.uid])
      });
    } else {
      await currentUserRef.update({
        'following': FieldValue.arrayRemove([_userId])
      });
      await profileUserRef.update({
        'followers': FieldValue.arrayRemove([currentUser!.uid])
      });
    }
  }

/*
  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      await _uploadProfilePic(imageFile);
    }
  }

  Future<void> _uploadProfilePic(File image) async {
  try {
    final ref = FirebaseStorage.instance.ref().child('profile_pics/${_userId}.jpg');
    await ref.putFile(image);

    final url = await ref.getDownloadURL();
    await _firestore.collection('users').doc(_userId).update({'photoURL': url});

    setState(() {
      _userPhotoURL = url;
      currentUser?.updatePhotoURL(url);
    });
  } catch (e) {
    print('Error uploading profile picture: $e');
  }
}

  Future<void> _deleteProfilePic() async {
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_pics/${_userId}.jpg');
      await ref.delete();

      await _firestore.collection('users').doc(_userId).update({'photoURL': FieldValue.delete()});

      setState(() {
        currentUser?.updatePhotoURL(null);
      });
    } catch (e) {
      print('Error deleting profile picture: $e');
    }
  }

  void _showProfilePicOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(context);
              _pickImage();
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Remove profile picture'),
            onTap: () {
              Navigator.pop(context);
              _deleteProfilePic();
            },
          ),
        ],
      ),
    );
  }

*/

 Widget _buildStatColumn(String label, int value) {
  return GestureDetector(
    onTap: () => _showUserList(label),
    child: Column(
      children: [
        Text(
  value.toString(),
  style: TextStyle(
    fontSize: 18, 
    fontWeight: FontWeight.bold,
    color: Theme.of(context).colorScheme.onSurface, // Add this
  ),
),
Text(
  label,
  style: TextStyle(
    fontSize: 14, 
    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), // Update color
  ),
),
      ],
    ),
  );
}

void _showUserList(String label) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                label,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(_userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  List<String> userIds = [];
                  if (label == 'Followers') {
                    userIds = List<String>.from(snapshot.data!['followers'] ?? []);
                  } else if (label == 'Following') {
                    userIds = List<String>.from(snapshot.data!['following'] ?? []);
                  }

                  return ListView.builder(
                    itemCount: userIds.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(userIds[index])
                            .get(),
                        builder: (context, userSnapshot) {
                          if (userSnapshot.connectionState == ConnectionState.waiting) {
                            return ListTile(title: Text('Loading...'));
                          }

                          if (userSnapshot.hasError || !userSnapshot.hasData) {
                            return ListTile(title: Text('Error loading user'));
                          }

                          var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                          String userPhotoUrl = userData['photoURL'] ?? '';
                          
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: userPhotoUrl.isNotEmpty
                                  ? NetworkImage(userPhotoUrl)
                                  : null,
                              child: userPhotoUrl.isEmpty
                                  ? Icon(Icons.person, size: 24, color: Colors.grey[600])
                                  : null,
                            ),
                            title: Text(userData['username'] ?? 'Unknown'),
                            subtitle: Text(userData['fullName'] ?? ''),
                            onTap: () {
                              Navigator.pop(context);
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
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildTabBar() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
TabBar(
  tabs: [
    Tab(icon: Icon(Icons.grid_on, 
      color: Theme.of(context).colorScheme.onSurface)), // Update color
    Tab(icon: Icon(Icons.bookmark_border, 
      color: Theme.of(context).colorScheme.onSurface)), // Update color
    Tab(icon: Icon(Icons.favorite_border, 
      color: Theme.of(context).colorScheme.onSurface)), // Update color
  ],
),
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            child: TabBarView(
              children: [
                _buildPostsGrid(),
                _buildSavedPostsGrid(),
                _buildLikedPostsGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: _userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error fetching posts: ${snapshot.error}');
          return Center(child: Text('Error loading posts. Please try again later.'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No posts yet'));
        }

        return Padding(
          padding: const EdgeInsets.all(2.0),
          child: MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var post = snapshot.data!.docs[index];
              return _buildPostThumbnail(post, index);
            },
          ),
        );
      },
    );
  }

Widget _buildSavedPostsGrid() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error loading saved posts'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      var savedPosts = snapshot.data?['savedPosts'];
      List<String> postIds;

      if (savedPosts is List) {
        postIds = List<String>.from(savedPosts);
      } else if (savedPosts is Map) {
        postIds = savedPosts.keys.cast<String>().toList();
      } else {
        postIds = [];
      }

      if (postIds.isEmpty) {
        return Center(child: Text('No saved posts yet'));
      }

      return FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchPosts(postIds),
        builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (postsSnapshot.hasError || !postsSnapshot.hasData) {
              return Center(child: Text('Error loading saved posts'));
            }

            return Padding(
              padding: const EdgeInsets.all(2.0),
              child: MasonryGridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                itemCount: postsSnapshot.data!.length,
                itemBuilder: (context, index) {
                  var post = postsSnapshot.data![index];
                  return _buildPostThumbnail(post, index);
                },
              ),
            );
          },
        );
      },
    );
  }

 Widget _buildLikedPostsGrid() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(_userId)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error loading liked posts'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      var likedPosts = snapshot.data?['likedPosts'];
      List<String> postIds;

      if (likedPosts is List) {
        postIds = List<String>.from(likedPosts);
      } else if (likedPosts is Map) {
        postIds = likedPosts.keys.cast<String>().toList();
      } else {
        postIds = [];
      }

      if (postIds.isEmpty) {
        return Center(child: Text('No liked posts yet'));
      }

      return FutureBuilder<List<DocumentSnapshot>>(
        future: _fetchPosts(postIds),
        builder: (context, postsSnapshot) {
            if (postsSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            if (postsSnapshot.hasError || !postsSnapshot.hasData) {
              return Center(child: Text('Error loading liked posts'));
            }

            return Padding(
              padding: const EdgeInsets.all(2.0),
              child: MasonryGridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                itemCount: postsSnapshot.data!.length,
                itemBuilder: (context, index) {
                  var post = postsSnapshot.data![index];
                  return _buildPostThumbnail(post, index);
                },
              ),
            );
          },
        );
      },
    );
  }

   Future<List<DocumentSnapshot>> _fetchPosts(List<String> postIds) async {
    List<DocumentSnapshot> posts = [];
    for (String id in postIds) {
      DocumentSnapshot post = await FirebaseFirestore.instance.collection('posts').doc(id).get();
      if (post.exists) {
        posts.add(post);
      }
    }
    return posts;
  }


  Widget _buildPostThumbnail(DocumentSnapshot post, int index) {
    try {
      List<String> imageUrls = List<String>.from(post['imageUrls'] ?? []);

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(post: post),
            ),
          );
        },
        child: AspectRatio(
          aspectRatio: index % 7 == 0 ? 1 : (index % 5 == 0 ? 2 / 3 : 1 / 1),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrls.isNotEmpty
                ? Image.network(
                    imageUrls.first,
                    fit: BoxFit.cover,
                  )
                : Container(color: Colors.grey[300]),
          ),
        ),
      );
    } catch (e) {
      print('Error building thumbnail for post ${post.id}: $e');
      return Container(
        color: Colors.red[100],
        child: Icon(Icons.error, color: Colors.red),
      );
    }
  }
/*
   Widget _buildProfilePicture() {
    return GestureDetector(
      onTap: _userId == currentUser!.uid ? _navigateToEditProfile : null,
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.grey[200],
        backgroundImage: _userPhotoURL != null && _userPhotoURL!.isNotEmpty
            ? NetworkImage(_userPhotoURL!)
            : null,
        child: _userPhotoURL == null || _userPhotoURL!.isEmpty
            ? Icon(Icons.person, size: 50, color: Colors.grey[400])
            : null,
      ),
    );
  }

  void _navigateToEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          fullName: _fullName,
          username: _username,
          bio: _bio,
          photoURL: _userPhotoURL ?? '',
        ),
      ),
    );

    if (result == true) {
      // Profile was updated, reload user data
      _loadUserData();
    }
  }

*/

  Future<void> _editBio() async {
    String newBio = await _showEditBioDialog();
    if (newBio.isNotEmpty && newBio != _bio) {
      setState(() {
        _bio = newBio;
      });
      await _firestore.collection('users').doc(_userId).update({'bio': newBio});
    }
  }

  Future<String> _showEditBioDialog() async {
    TextEditingController bioController = TextEditingController(text: _bio);
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: Container(
                width: MediaQuery.of(context).size.width,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(''),
                              ),
                              Text(
                                'Add your bio',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 48),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: TextField(
                              controller: bioController,
                              maxLength: 80,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Tell people about yourself',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: Colors.grey[200],
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: bioController.text.isNotEmpty
                            ? () => Navigator.of(context).pop(bioController.text)
                            : null,
                        child: Text('Done'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow,
                          foregroundColor: Colors.black,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((value) => value ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
appBar: AppBar(
  automaticallyImplyLeading: widget.userId != null,
  title: Text(
    '@$_username', 
    style: TextStyle(fontWeight: FontWeight.bold)  // Remove color: Colors.black
  ),
  // Remove backgroundColor: Colors.white,
  elevation: 0,
  actions: [
    if (_userId == currentUser!.uid) ...[
      IconButton(
        icon: Icon(Icons.auto_awesome),  // Remove color: Colors.black
        onPressed: () {
          // TODO: Implement star functionality
        },
      ),
      IconButton(
        icon: Icon(Icons.settings),  // Remove color: Colors.black
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        },
      ),
    ],
  ],
),
     body: _isLoading
    ? Center(child: CircularProgressIndicator())
    : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatColumn('Following', _following),
                SizedBox(width: 40),
                _buildProfilePicture(),
                SizedBox(width: 40),
                _buildStatColumn('Followers', _followers),
              ],
            ),
                  SizedBox(height: 10),
                  Text(
                    _fullName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 5),
                  Text(
                    _bio,
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  if (_userId == currentUser!.uid)
  Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(
          fullName: _fullName,
          username: _username,
          bio: _bio,
          photoURL: _userPhotoURL,
        ),
      ),
    );
  },
  child: Text('Edit profile'),
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: Theme.of(context).colorScheme.onSurface, // Update color
    side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)), // Update color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
    padding: EdgeInsets.symmetric(horizontal: 40.0, vertical: 8.0),
    minimumSize: Size(150, 36),
    textStyle: TextStyle(fontSize: 16),
  ),
),

    SizedBox(width: 2), // Reduced space between buttons
ElevatedButton(
  onPressed: () {
    // TODO: Implement share profile functionality
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: Theme.of(context).colorScheme.onSurface, // Update color
    side: BorderSide(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)), // Update color
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 0,
    padding: EdgeInsets.all(0),
    minimumSize: Size(36, 36),
    fixedSize: Size(36, 36),
  ),
  child: Center(
    child: Icon(Icons.ios_share, size: 20),
  ),
),
  ],
)
else
  ElevatedButton(
    onPressed: _toggleFollow,
    child: Text(_isFollowing ? 'Unfollow' : 'Follow'),
    style: ElevatedButton.styleFrom(
      backgroundColor: _isFollowing ? Colors.grey : Colors.blue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      elevation: 0, // Remove shadow
      minimumSize: Size(200, 36), // Reduced height
    ),
  ),
SizedBox(height: 20),
_buildTabBar(),


                ],
              ),
            ),
    );
  }
}
