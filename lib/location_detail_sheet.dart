import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:google_place/google_place.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'post_detail_page.dart';

class LocationDetailSheet extends StatefulWidget {
  final Map<String, dynamic> activity;
  final GooglePlace googlePlace;
  final String? placeId;

  const LocationDetailSheet({
    Key? key,
    required this.activity,
    required this.googlePlace,
    this.placeId,
  }) : super(key: key);

  @override
  _LocationDetailSheetState createState() => _LocationDetailSheetState();
}

class _LocationDetailSheetState extends State<LocationDetailSheet> {
  DetailsResult? placeDetails;
  List<Photo>? photos;
  bool isLoading = true;
  List<Map<String, dynamic>> featuredPosts = [];
  bool showAllPosts = false;
  static const int postsPerPage = 4;

  @override
  void initState() {
    super.initState();
    _getPlaceDetails();
    _getFeaturedPosts();
  }

  Future<void> _getFeaturedPosts() async {
    try {
      final locationName = placeDetails?.name ?? widget.activity['name'];
      print("⭐️ Searching for posts with locationName: $locationName");
      
      final querySnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .get();

      final filteredPosts = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final activities = data['activities'] as List<dynamic>?;
        if (activities == null) return false;
        
        return activities.any((activity) => 
          (activity as Map<String, dynamic>)['name'] == locationName
        );
      }).toList();

      print("⭐️ Found ${filteredPosts.length} posts");
      
      setState(() {
        featuredPosts = filteredPosts
            .map((doc) => {
                  ...doc.data() as Map<String, dynamic>,
                  'id': doc.id,
                })
            .toList();
      });
    } catch (e) {
      print('⭐️ Error fetching featured posts: $e');
    }
  }

  Future<void> _getPlaceDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      if (widget.placeId != null) {
        var result = await widget.googlePlace.details.get(
          widget.placeId!,
          fields: 'name,photos,geometry,rating,user_ratings_total,price_level,website,formatted_phone_number'
        );
        
        if (result != null && result.result != null) {
          setState(() {
            placeDetails = result.result;
            photos = result.result!.photos;
            isLoading = false;
          });
        }
      } else {
        var searchResult = await widget.googlePlace.search.getTextSearch(
          widget.activity['name'],
          language: 'en',
          region: 'us'
        );

        if (searchResult != null && 
            searchResult.results != null && 
            searchResult.results!.isNotEmpty) {
          String? foundPlaceId = searchResult.results!.first.placeId;
          
          if (foundPlaceId != null) {
            var detailsResult = await widget.googlePlace.details.get(
              foundPlaceId,
              fields: 'name,photos,geometry,rating,user_ratings_total,price_level,website,formatted_phone_number'
            );

            if (detailsResult != null && detailsResult.result != null) {
              setState(() {
                placeDetails = detailsResult.result;
                photos = detailsResult.result!.photos;
                isLoading = false;
              });
              return;
            }
          }
        }
        
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching place details: $e");
      setState(() => isLoading = false);
    }
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          'Directions', 
          Icons.directions,
          () async {
            if (placeDetails?.geometry?.location != null) {
              final lat = placeDetails!.geometry!.location!.lat;
              final lng = placeDetails!.geometry!.location!.lng;
              final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              } catch (e) {
                print('Error launching maps: $e');
              }
            }
          }
        ),
        if (placeDetails?.website != null)
          _buildActionButton(
            'Website', 
            Icons.language,
            () async {
              try {
                final uri = Uri.parse(placeDetails!.website!);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              } catch (e) {
                print('Error launching website: $e');
              }
            }
          ),
        _buildActionButton(
          'Save', 
          Icons.bookmark_border,
          () {
            // TODO: Implement save functionality
          }
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    if (featuredPosts.isEmpty) return SizedBox.shrink();

    final displayedPosts = showAllPosts 
        ? featuredPosts 
        : featuredPosts.take(postsPerPage).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 16.0),
          child: Text(
            'Featured in...',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...displayedPosts.map((post) => _buildFeaturedPostCard(post)).toList(),
        if (featuredPosts.length > postsPerPage)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextButton(
              onPressed: () {
                setState(() {
                  showAllPosts = !showAllPosts;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    showAllPosts ? 'Show Less' : 'See More',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    showAllPosts ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.blue,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFeaturedPostCard(Map<String, dynamic> post) {
    final List<dynamic>? imageUrls = post['imageUrls'];
    final String imageUrl = imageUrls != null && imageUrls.isNotEmpty 
        ? imageUrls[0] 
        : 'https://via.placeholder.com/80';
    final String userId = post['userId'] ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          final postDoc = await FirebaseFirestore.instance
              .collection('posts')
              .doc(post['id'])
              .get();
              
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailPage(post: postDoc),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 80,
                    height: 80,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 80,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post['title'] ?? 'Untitled Post',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .get(),
                              builder: (context, snapshot) {
                                String photoUrl = '';
                                if (snapshot.hasData && snapshot.data != null) {
                                  photoUrl = snapshot.data!['photoURL'] ?? '';
                                }
                                return CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                                  child: photoUrl.isEmpty
                                      ? Icon(Icons.person, size: 12, color: Colors.grey[600])
                                      : null,
                                );
                              },
                            ),
                            SizedBox(width: 4),
                            Text(
                              post['username'] ?? 'Unknown User',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (post['description'] != null && post['description'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  post['description'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Container(
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_getPhotoUrl(photos?.first)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_getStaticMapUrl()),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        placeDetails?.name ?? widget.activity['name'] ?? '',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Text(placeDetails?.rating?.toString() ?? ''),
                          Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(
                            ' • ${placeDetails?.userRatingsTotal ?? 0} Google reviews',
                            style: TextStyle(color: Colors.grey[600])
                          ),
                        ],
                      ),
                      if (placeDetails?.priceLevel != null)
                        Text(
                          '${_getPriceLevel(placeDetails?.priceLevel)} • ${placeDetails?.types?.first ?? 'Business'}',
                          style: TextStyle(color: Colors.grey[600])
                        ),
                      SizedBox(height: 16),
                      _buildActionButtons(),
                      _buildFeaturedSection(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPhotoUrl(Photo? photo) {
    if (photo != null && photo.photoReference != null) {
      return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=${photo.photoReference}&key=AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM';
    } 
    return 'https://source.unsplash.com/800x600/?waterfall,nature';
  }

  String _getStaticMapUrl() {
    if (placeDetails?.geometry?.location != null) {
      final lat = placeDetails!.geometry!.location!.lat;
      final lng = placeDetails!.geometry!.location!.lng;
      return 'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=15&size=400x400&markers=color:red%7C$lat,$lng&key=AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM';
    } else if (widget.activity['location'] != null) {
      final location = widget.activity['location'] as Map<String, dynamic>;
      return 'https://maps.googleapis.com/maps/api/staticmap?center=${location['lat']},${location['lng']}&zoom=15&size=400x400&markers=color:red%7C${location['lat']},${location['lng']}&key=AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM';
    }
    return 'https://via.placeholder.com/400x400';
  }

  String _getPriceLevel(int? priceLevel) {
    if (priceLevel == null) return '';
    return '\$' * priceLevel;
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 8),
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }
}