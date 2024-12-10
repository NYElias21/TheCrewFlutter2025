import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_page.dart';
import 'create_post_page.dart';
import 'post_detail_page.dart';
import 'settings_page.dart';
import 'search_page.dart';
import 'notifications_page.dart';
import 'social_feed_page.dart';  // New import


class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  String _selectedCity = 'All Cities';
  List<String> _cities = ['All Cities', 'Charlotte', 'Raleigh', 'Asheville', 'Wilmington', 'Durham', 'Chapel Hill'];
  String _currentFeed = 'Following';

  late List<Widget> _children;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _currentFeed = _tabController.index == 0 ? 'Following' : 'For You';
    _updateChildren();
  }

void _handleTabSelection() {
    // Remove the indexIsChanging check to ensure it updates consistently
    setState(() {
      _currentFeed = _tabController.index == 0 ? 'Following' : 'For You';
    });
  }


  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _updateChildren() {
    _children = [
      HomeContent(feedType: _currentFeed, selectedCity: _selectedCity),
      SearchPage(),
      CreatePostPage(),
      SocialFeedPage(),
      ProfilePage(),
    ];
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onCityChanged(String newValue) {
    setState(() {
      _selectedCity = newValue;
      _updateChildren();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? NestedScrollView(
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    title: _buildAppBarTitle(),
                    pinned: true,
                    floating: true,
                    forceElevated: innerBoxIsScrolled,
                    centerTitle: true,
                    leading: _currentFeed == 'Following' ? Container() : null,
                    leadingWidth: _currentFeed == 'Following' ? 0 : null,
bottom: PreferredSize(
  preferredSize: Size.fromHeight(48),
  child: TabBar(
    controller: _tabController,
    tabs: [
      Tab(text: 'Following'),
      Tab(text: 'For You'),
    ],
    labelColor: Theme.of(context).brightness == Brightness.dark 
      ? Colors.white 
      : Colors.black,
    unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
      ? Colors.grey[400] 
      : Colors.grey,
  ),
),

                  )
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  HomeContent(feedType: 'Following', selectedCity: _selectedCity),
                  HomeContent(feedType: 'ForYou', selectedCity: _selectedCity),
                ],
              ),
            )
          : _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        onTap: onTabTapped,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Social'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

Widget _buildAppBarTitle() {
  print('Current feed: $_currentFeed');
  
  if (_currentFeed == 'Following') {
    return Row(
      children: [
        Text(
          'The Crew',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  } else {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'The Crew',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        GestureDetector(
          onTap: () {
            _showCitySelectorModal(context);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _selectedCity,
                style: TextStyle(fontSize: 14),
              ),
              Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ],
    );
  }
}

  void _showCitySelectorModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 400,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                '🌟 Travel Mode',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Plan like a local by exploring plans across all North Carolina cities.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _cities.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(_cities[index]),
                      trailing: Icon(Icons.arrow_forward),
                      onTap: () {
                        _onCityChanged(_cities[index]);
                        Navigator.pop(context); // Close the modal
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
}

class HomeContent extends StatefulWidget {
  final String feedType;
  final String selectedCity;

  HomeContent({this.feedType = 'ForYou', required this.selectedCity});

  @override
  _HomeContentState createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> with SingleTickerProviderStateMixin {
  String _selectedCategory = 'All';
  List<String> _categories = ['All', 'Outdoors', 'Food', 'Dates', 'Nightlife', 'Coffee', 'Free'];
  Map<String, Timestamp> _likedPosts = {};
  Map<String, Timestamp> _savedPosts = {};

  @override
  void initState() {
    super.initState();
    _loadLikedAndSavedPosts();
  }

Future<void> _loadLikedAndSavedPosts() async {
  User? currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    setState(() {
      var data = userDoc.data() as Map<String, dynamic>?;
      
      if (data != null) {
        _likedPosts = (data['likedPosts'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value is Timestamp ? value : Timestamp.now()),
        ) ?? {};

        _savedPosts = (data['savedPosts'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value is Timestamp ? value : Timestamp.now()),
        ) ?? {};
      } else {
        _likedPosts = {};
        _savedPosts = {};
      }
    });
  }
}

  bool isLiked(String postId) {
    return _likedPosts.containsKey(postId);
  }

  bool isSaved(String postId) {
    return _savedPosts.containsKey(postId);
  }

  Future<void> _toggleLike(String postId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);
      DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

      bool liked = _likedPosts.containsKey(postId);
      if (liked) {
        _likedPosts.remove(postId);
        await userRef.update({
          'likedPosts.$postId': FieldValue.delete()
        });
        await postRef.update({
          'likes': FieldValue.increment(-1)
        });
      } else {
        _likedPosts[postId] = Timestamp.now();
        await userRef.update({
          'likedPosts.$postId': FieldValue.serverTimestamp()
        });
        await postRef.update({
          'likes': FieldValue.increment(1)
        });
      }

      setState(() {});
    }
  }

  Future<void> _toggleSave(String postId) async {
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(currentUser.uid);

      bool saved = _savedPosts.containsKey(postId);
      if (saved) {
        _savedPosts.remove(postId);
        await userRef.update({
          'savedPosts.$postId': FieldValue.delete()
        });
      } else {
        _savedPosts[postId] = Timestamp.now();
        await userRef.update({
          'savedPosts.$postId': FieldValue.serverTimestamp()
        });
      }

      setState(() {});
    }
  }


  @override
  Widget build(BuildContext context) {
    if (widget.feedType == 'Following') {
      return _buildFollowingFeed();
    } else {
      return _buildForYouFeed();
    }
  }

Widget _buildFollowingFeed() {
  return StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots(),
    builder: (context, userSnapshot) {
      if (userSnapshot.hasError) {
        return Center(child: Text('Error: ${userSnapshot.error}'));
      }

      if (userSnapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      List<String> following = List<String>.from(userSnapshot.data!['following'] ?? []);

      if (following.isEmpty) {
        return Center(child: Text('You are not following anyone yet.'));
      }

      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('userId', whereIn: following)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No posts from people you follow.'));
          }

          return ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var post = snapshot.data!.docs[index];
              return _buildFollowingPostCard(post);
            },
          );
        },
      );
    },
  );
}

Widget _buildFollowingPostCard(DocumentSnapshot post) {
  final data = post.data() as Map<String, dynamic>;

  List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
  String title = data['title'] ?? 'Title';
  String username = data['username'] ?? 'Username';
  String userId = data['userId'] ?? '';
  int likes = data['likes'] ?? 0;
  String description = data['description'] ?? '';
  Timestamp createdAt = data['createdAt'] ?? Timestamp.now();

  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
    builder: (context, snapshot) {
      String userPhotoUrl = '';
      if (snapshot.hasData && snapshot.data != null) {
        userPhotoUrl = snapshot.data!['photoURL'] ?? '';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
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
            title: Text(username, style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: Icon(Icons.more_horiz),
              onPressed: () {
                // Implement more options functionality
              },
            ),
          ),
          if (imageUrls.isNotEmpty)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PostDetailPage(post: post)),
                );
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrls[0],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _toggleLike(post.id),
                      child: Icon(
                        isLiked(post.id) ? Icons.favorite : Icons.favorite_border,
                        color: isLiked(post.id) ? Colors.red : null,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      '$likes likes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline),
                    SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _toggleSave(post.id),
                      child: Icon(
                        isSaved(post.id) ? Icons.bookmark : Icons.bookmark_border,
                        color: isSaved(post.id) ? Colors.black : null,
                      ),
                    ),
                    SizedBox(width: 16),
                    Icon(Icons.share),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: username,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' '),
                  TextSpan(text: title),
                ],
              ),
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(description),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _formatPostTime(createdAt),
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),
          SizedBox(height: 16),
        ],
      );
    },
  );
}

String _formatPostTime(Timestamp timestamp) {
  final now = DateTime.now();
  final postTime = timestamp.toDate();
  final difference = now.difference(postTime);

  if (difference.inDays > 0) {
    return '${postTime.month.toString().padLeft(2, '0')}/${postTime.day.toString().padLeft(2, '0')}/${postTime.year}';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hours ago';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minutes ago';
  } else {
    return 'Just now';
  }
}


Widget _buildForYouFeed() {
  return Column(
    children: [
      Container(
        height: 40,
        margin: EdgeInsets.symmetric(vertical: 8),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: FilterChip(
                label: Text(_categories[index]),
                selected: _selectedCategory == _categories[index],
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = _categories[index];
                  });
                },
                backgroundColor: Colors.transparent,
                selectedColor: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white.withOpacity(0.2) 
                  : Colors.black.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: _selectedCategory == _categories[index]
                    ? Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black
                    : Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey,
                  fontWeight: _selectedCategory == _categories[index] 
                    ? FontWeight.bold 
                    : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _selectedCategory == _categories[index]
                      ? Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black
                      : Colors.grey,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Expanded(
        child: _buildContentGrid(_selectedCategory),
      ),
    ],
  );
}

 Widget _buildContentGrid(String category) {
  Query query = FirebaseFirestore.instance.collection('posts')
      .orderBy('createdAt', descending: true);

  return StreamBuilder<QuerySnapshot>(
    stream: query.snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }

      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      List<DocumentSnapshot> filteredDocs = snapshot.data!.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        bool categoryMatch = category == 'All' || data['category'] == category;
        bool cityMatch = widget.selectedCity == 'All Cities' || data['city'] == widget.selectedCity;
        return categoryMatch && cityMatch;
      }).toList();

      if (filteredDocs.isEmpty) {
        return Center(child: Text('No posts in this category and city yet.'));
      }

      return GridView.builder(
        padding: EdgeInsets.all(4),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.6,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemCount: filteredDocs.length,
        itemBuilder: (context, index) {
          var post = filteredDocs[index];
          return _buildContentCard(post);
        },
      );
    },
  );
}

  Widget _buildContentCard(DocumentSnapshot post) {
    final data = post.data() as Map<String, dynamic>;

    List<String> imageUrls = List<String>.from(data['imageUrls'] ?? []);
    String title = data['title'] ?? 'Title';
    String username = data['username'] ?? 'Username';
    String userId = data['userId'] ?? '';
    int likes = data['likes'] ?? 0;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String userPhotoUrl = '';
        if (snapshot.hasData && snapshot.data != null) {
          userPhotoUrl = snapshot.data!['photoURL'] ?? '';
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => PostDetailPage(post: post)),
            );
          },
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrls.isNotEmpty
                        ? Image.network(
                            imageUrls[0],
                            fit: BoxFit.cover,
                            height: double.infinity,
                            width: double.infinity,
                          )
                        : Container(
                            color: Colors.grey,
                            child: Icon(Icons.image, color: Colors.white),
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.grey[300],
                            backgroundImage: userPhotoUrl.isNotEmpty
                                ? NetworkImage(userPhotoUrl)
                                : null,
                            child: userPhotoUrl.isEmpty
                                ? Icon(Icons.person, size: 15, color: Colors.grey[600])
                                : null,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              username,
                              style: TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.favorite_border, size: 16),
                          SizedBox(width: 2),
                          Text(likes.toString(), style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}