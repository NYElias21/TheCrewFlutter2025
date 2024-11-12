import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';  // At the top of the file with other imports

class SeasonalPromotion {
  final String id;
  final String hashtag;
  final String title;
  final String subtitle;
  final String imageUrl;
  //final String startColorHex;
  //final String endColorHex;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  SeasonalPromotion({
    required this.id,
    required this.hashtag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    //required this.startColorHex,
    //required this.endColorHex,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
  });

  factory SeasonalPromotion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return SeasonalPromotion(
      id: doc.id,
      hashtag: data['hashtag'] ?? '',
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      //startColorHex: data['startColorHex'] ?? '0xFFE57373',
      //endColorHex: data['endColorHex'] ?? '0xFFC62828',
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
    );
  }

  //Color get startColor => Color(int.parse(startColorHex));
  //Color get endColor => Color(int.parse(endColorHex));
}

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  TextEditingController _searchController = TextEditingController();
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  int _currentPage = 0;

 @override
void initState() {
  super.initState();
  // Start auto-scroll timer
  _autoScrollTimer = Timer.periodic(Duration(seconds: 5), (timer) {
    if (_pageController.hasClients) {
      // Get the number of pages from the PageController
      final int numberOfPages = _pageController.position.maxScrollExtent ~/
          _pageController.position.viewportDimension +
          1;

      if (_currentPage >= numberOfPages - 1) {
        // If we're at the last page, animate back to first
        _pageController.animateToPage(
          0,
          duration: Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else {
        // Otherwise, go to next page
        _pageController.nextPage(
          duration: Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    }
  });
}

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search...',
            border: InputBorder.none,
          ),
          onChanged: (value) {
            setState(() {});
          },
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: _buildSearchResults(),
    );
  }

  Widget _buildSearchResults() {
    String query = _searchController.text.trim();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPromotionalBanner(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local favorites',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Based on thousands of local votes',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildLocalFavorites(),
            ],
          ),
          _buildSectionTitle('Trending Hashtags'),
          _buildHashtagGrid(),
        ],
      ),
    );
  }

Widget _buildPromotionalBanner() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('promotions')
        .where('isActive', isEqualTo: true)
        .where('startDate', isLessThanOrEqualTo: Timestamp.now())
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.now())
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
        return SizedBox.shrink();
      }

      return Container(
        height: 220,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                SeasonalPromotion promotion = SeasonalPromotion.fromFirestore(
                  snapshot.data!.docs[index],
                );

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background Image
                        Image.network(
                          promotion.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.error),
                            );
                          },
                        ),
                        // Gradient Overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                              stops: [0.5, 1.0], // Adjusted gradient stops
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Left side - Title and Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          promotion.title,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 26, // Increased font size
                                            fontWeight: FontWeight.w800, // Made bolder
                                            letterSpacing: -0.5, // Tighter letter spacing
                                            height: 1.1, // Tighter line height
                                          ),
                                        ),
                                        SizedBox(height: 8), // Increased spacing
                                        Text(
                                          promotion.subtitle,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.95),
                                            fontSize: 18, // Increased font size
                                            fontWeight: FontWeight.w400,
                                            letterSpacing: 0.1,
                                            height: 1.2,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16), // Added spacing
                                  // Right side - More button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(25), // More rounded
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          // Handle more button tap
                                        },
                                        borderRadius: BorderRadius.circular(25),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          child: Text(
                                            'More',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
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
            ),
            // Page Indicators
            Positioned(
              bottom: 30, // Moved indicators up a bit
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  snapshot.data!.docs.length,
                  (index) => Container(
                    width: 6, // Slightly smaller dots
                    height: 6,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.white
                          : Colors.white.withOpacity(0.4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


Widget _buildLocalFavorites() {
  final List<Map<String, dynamic>> localFavorites = [
    {
      'icon': Icons.coffee,
      'title': 'Cafes to work from',
    },
    {
      'icon': Icons.local_bar,
      'title': 'Top neighborhood bars',
    },
    {
      'icon': Icons.wb_sunny,
      'title': 'Places to watch sunset',
    },
  ];

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items from the top
        children: localFavorites.map((item) {
          return Container(
            width: 120, // Make width smaller for better spacing
            margin: EdgeInsets.only(right: 16), // Increase margin between items
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align text to start
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        item['icon'],
                        size: 32,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 12), // Consistent spacing
                Text(
                  item['title'],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.2, // Add line height
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    ),
  );
}

  Widget _buildHashtagGrid() {
    // Replace this with Firestore query or real data
    List<Map<String, String>> hashtagData = [
      {'title': 'summertrips', 'views': '17.6M', 'imageUrl': 'https://via.placeholder.com/150'},
      {'title': 'waterfalls', 'views': '7.2M', 'imageUrl': 'https://via.placeholder.com/150'},
      {'title': 'fallfest', 'views': '14.3M', 'imageUrl': 'https://via.placeholder.com/150'},
      {'title': 'october', 'views': '1.4M', 'imageUrl': 'https://via.placeholder.com/150'},
    ];

    return Column(
      children: hashtagData.map((data) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tag, size: 24, color: Colors.grey),
                  SizedBox(width: 8),
                  Text(
                    '#${data['title']}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Spacer(),
                  Text(
                    '${data['views']} views',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Container(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 5, // Sample count, adjust based on actual data
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl']!,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}