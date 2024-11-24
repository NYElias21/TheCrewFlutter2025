import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:google_place/google_place.dart';
import 'package:flutter/gestures.dart';
import 'photo_editor_page.dart';
import 'custom_photo_selector.dart';
import 'services/trending_posts.dart';

// Add this class at the top level of the file, before CreatePostPage class
class HashtagTextController extends TextEditingController {
  HashtagTextController({String? text}) : super(text: text);

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final List<InlineSpan> children = [];
    final RegExp hashtagRegExp = RegExp(r'#\w+');
    final String text = value.text;
    int lastIndex = 0;

    for (Match match in hashtagRegExp.allMatches(text)) {
      if (match.start > lastIndex) {
        children.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }
      children.add(TextSpan(
        text: text.substring(match.start, match.end),
        // Use this specific blue color
        style: style?.copyWith(color: Color(0xFF0095F6)) ?? TextStyle(color: Color(0xFF0095F6)),
      ));
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      children.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return TextSpan(children: children, style: style);
  }
}

class HashtagService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Future<void> updateHashtagMetrics(List<String> hashtags) async {
    final batch = _firestore.batch();
    final now = DateTime.now();
    
    for (String hashtag in hashtags) {
      final hashtagRef = _firestore.collection('hashtags').doc(hashtag.substring(1)); // Remove # symbol
      
      try {
        // Get the current hashtag document
        final hashtagDoc = await hashtagRef.get();
        
        if (hashtagDoc.exists) {
          // Update existing hashtag metrics
          batch.update(hashtagRef, {
            'postCount': FieldValue.increment(1),
            'lastUsed': now,
            'weeklyPostCount': FieldValue.increment(1),
            'trendingScore': FieldValue.increment(1), // Basic scoring
          });
        } else {
          // Create new hashtag document
          batch.set(hashtagRef, {
            'name': hashtag,
            'postCount': 1,
            'weeklyPostCount': 1,
            'created': now,
            'lastUsed': now,
            'trendingScore': 1,
          });
        }
      } catch (e) {
        print('Error updating hashtag metrics: $e');
      }
    }
    
    // Commit all updates in a single batch
    await batch.commit();
  }
  
  // Function to decay trending scores periodically
  Future<void> decayTrendingScores() async {
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(Duration(days: 7));
    
    try {
      // Get hashtags used in the last week
      final querySnapshot = await _firestore
          .collection('hashtags')
          .where('lastUsed', isGreaterThan: oneWeekAgo)
          .get();
      
      final batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        // Decay the trending score by 50%
        final currentScore = doc.data()['trendingScore'] ?? 0;
        batch.update(doc.reference, {
          'trendingScore': currentScore * 0.5,
          'weeklyPostCount': 0, // Reset weekly count
        });
      }
      
      await batch.commit();
    } catch (e) {
      print('Error decaying trending scores: $e');
    }
  }
}


class CreatePostPage extends StatefulWidget {
  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final HashtagService _hashtagService = HashtagService();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _bottomSheetSearchController = TextEditingController();
  //inal TextEditingController _descriptionController = TextEditingController();
  final _descriptionController = HashtagTextController();
  late GooglePlace googlePlace;
  List<AutocompletePrediction> _predictions = [];
  List<XFile> _images = [];
  List<Activity> _activities = [];
  String _title = '';
  String _description = '';
  String _userDescription = '';
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedCity = 'All Cities';
  List<String> _categories = ['All', 'Outdoors', 'Food', 'Dates', 'Nightlife', 'Coffee', 'Free'];
  List<String> _cities = ['All Cities', 'Charlotte', 'Raleigh', 'Asheville', 'Wilmington', 'Durham', 'Chapel Hill'];
  final List<String> _hashtags = [];
  static const int MAX_HASHTAGS = 4;

  @override
  void initState() {
    super.initState();
    googlePlace = GooglePlace('AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM');
  }

@override
void dispose() {
  _descriptionController.dispose();
  _bottomSheetSearchController.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post'),
        actions: [
          IconButton(
            icon: Icon(Icons.remove_red_eye),
            onPressed: () {
              // Implement preview functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
children: [
  _buildImageSelectionSection(),
  SizedBox(height: 16),
  _buildTitleField(),
  Divider(height: 1, thickness: 1, color: Colors.grey[300]),
  SizedBox(height: 16),
  _buildDescriptionField(),
  SizedBox(height: 16),
  _buildInteractionButtons(),
  SizedBox(height: 24),
  _buildPostButton(),
],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSelectionSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ..._images.map((image) => Container(
                height: 80,
                width: 80,
                margin: EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: FileImage(File(image.path)),
                    fit: BoxFit.cover,
                  ),
                ),
              )),
          if (_images.length < 10)
            GestureDetector(
              onTap: _getImages,
              child: Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.add_a_photo, size: 30, color: Colors.grey[800]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      decoration: InputDecoration(
        hintText: 'Add a headline',
        border: InputBorder.none,
      ),
      validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
      onChanged: (value) => _title = value,
    );
  }

    List<String> _extractHashtags(String text) {
    RegExp hashtagRegExp = RegExp(r'#\w+');
    return hashtagRegExp.allMatches(text).map((match) => match.group(0)!).toList();
  }

Widget _buildDescriptionField() {
    return Container(
      constraints: BoxConstraints(minHeight: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Tap to add a description...',
              border: InputBorder.none,
            ),
            maxLines: null,
            onChanged: (value) {
              List<String> newHashtags = _extractHashtags(value);
              
              if (newHashtags.length > MAX_HASHTAGS) {
                // If exceeding limit, trim the text to remove the last hashtag
                int lastHashIndex = value.lastIndexOf('#');
                value = value.substring(0, lastHashIndex);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Maximum ${MAX_HASHTAGS} hashtags allowed'),
                    duration: Duration(seconds: 2),
                  ),
                );
                
                // Update the controller to reflect the trimmed text
                _descriptionController.value = TextEditingValue(
                  text: value,
                  selection: TextSelection.collapsed(offset: value.length),
                );
              }
              
              setState(() {
                _userDescription = value;
                _hashtags.clear();
                _hashtags.addAll(_extractHashtags(value).take(MAX_HASHTAGS));
                _updateDescription();
              });
            },
          ),
          if (_activities.isNotEmpty) ...[
          SizedBox(height: 16),
          ..._activities.map((activity) {
            return Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(text: '📍 '),
                    TextSpan(
                      text: activity.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (activity.description.isNotEmpty) ...[
                      TextSpan(text: ': '),
                      TextSpan(text: activity.description),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ],
    ),
  );
}


/* List<TextSpan> _buildTextSpans(String text) {
  List<TextSpan> spans = [];
  RegExp hashtagRegExp = RegExp(r'(#\w+)');
  int lastIndex = 0;

  for (Match match in hashtagRegExp.allMatches(text)) {
    // Add text before hashtag
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: TextStyle(color: Colors.black),
      ));
    }
    
    // Add hashtag with color
    spans.add(TextSpan(
      text: match.group(0),
      style: TextStyle(color: Colors.green),
    ));
    
    lastIndex = match.end;
  }

  // Add remaining text after last hashtag
  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: TextStyle(color: Colors.black),
    ));
  }

  return spans;
} */

//previous version with the single activity button, new version under this includes all 3.
/*   Widget _buildActivityButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _showAddActivityBottomSheet,
          icon: Icon(Icons.add, size: 20, color: Colors.black),
          label: Text(
            'Activity',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ],
    );
  } */

  Widget _buildInteractionButtons() {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        // Activity Button
        TextButton.icon(
          onPressed: _showAddActivityBottomSheet,
          icon: Icon(Icons.add, size: 20, color: Colors.black),
          label: Text(
            'Activity',
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
            ),
          ),
          style: TextButton.styleFrom(
            backgroundColor: Colors.grey[100],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        SizedBox(width: 8),
        // Category Button
        PopupMenuButton<String>(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCategory,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.black, size: 20),
              ],
            ),
          ),
          onSelected: (String value) {
            setState(() {
              _selectedCategory = value;
            });
          },
          itemBuilder: (BuildContext context) {
            return _categories.map((String category) {
              return PopupMenuItem<String>(
                value: category,
                child: Text(category),
              );
            }).toList();
          },
        ),
        SizedBox(width: 8),
        // City Button
        PopupMenuButton<String>(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _selectedCity,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: Colors.black, size: 20),
              ],
            ),
          ),
          onSelected: (String value) {
            setState(() {
              _selectedCity = value;
            });
          },
          itemBuilder: (BuildContext context) {
            return _cities.map((String city) {
              return PopupMenuItem<String>(
                value: city,
                child: Text(city),
              );
            }).toList();
          },
        ),
      ],
    ),
  );
}

  /* Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Category',
        border: OutlineInputBorder(),
      ),
      value: _selectedCategory,
      items: _categories.map((String category) {
        return DropdownMenuItem<String>(
          value: category,
          child: Text(category),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCategory = newValue!;
        });
      },
    );
  }

  Widget _buildCityDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'City',
        border: OutlineInputBorder(),
      ),
      value: _selectedCity,
      items: _cities.map((String city) {
        return DropdownMenuItem<String>(
          value: city,
          child: Text(city),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedCity = newValue!;
        });
      },
    );
  }
 */
  Widget _buildPostButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _createPost,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 16),
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      child: _isLoading
          ? SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.black,
                strokeWidth: 2,
              ),
            )
          : Text('Post'),
    );
  }

void _showAddActivityBottomSheet() {
  bool isDescriptionMode = false;
  AutocompletePrediction? selectedPrediction;
  String? selectedAddress;
  final descriptionController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isDescriptionMode ? 'Add activity details' : 'Add place',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        _bottomSheetSearchController.clear();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              Divider(height: 1),

              if (!isDescriptionMode) ...[
                // Search Mode UI
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _bottomSheetSearchController,
                    decoration: InputDecoration(
                      hintText: 'Search places',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    onChanged: (value) async {
                      if (value.isNotEmpty) {
                        try {
                          var result = await googlePlace.autocomplete.get(
                            value,
                            components: [Component("country", "us")],
                          );
                          
                          if (result != null && result.predictions != null) {
                            setSheetState(() {
                              _predictions = result.predictions!;
                            });
                          }
                        } catch (e) {
                          print("Error during places search: $e");
                          setSheetState(() {
                            _predictions = [];
                          });
                        }
                      } else {
                        setSheetState(() {
                          _predictions = [];
                        });
                      }
                    },
                  ),
                ),
                Expanded(
                  child: _predictions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Search a location to add to your post',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: controller,
                          itemCount: _predictions.length,
                          itemBuilder: (context, index) {
                            final prediction = _predictions[index];
                            return ListTile(
                              leading: Icon(Icons.location_on_outlined),
                              title: Text(prediction.description ?? "Unknown"),
                              onTap: () {
                                setSheetState(() {
                                  selectedPrediction = prediction;
                                  selectedAddress = prediction.description;
                                  isDescriptionMode = true;
                                  _predictions = [];
                                  _bottomSheetSearchController.clear();
                                });
                              },
                            );
                          },
                        ),
                ),
              ] else ...[
// Description Mode UI
if (selectedAddress != null) ...[
  SizedBox(height: 16),
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.place, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _extractPlaceName(selectedAddress!),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  selectedAddress!.substring(_extractPlaceName(selectedAddress!).length + 2),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
  SizedBox(height: 16),
  GestureDetector(
    onTap: () {
      FocusScope.of(context).unfocus();
    },
    child: Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: TextField(
        controller: descriptionController,
        decoration: InputDecoration(
          hintText: 'Write something about this place...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black),
          ),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: EdgeInsets.all(16),
        ),
        maxLines: null,
        style: TextStyle(fontSize: 16),
        textInputAction: TextInputAction.done,
        onEditingComplete: () {
          FocusScope.of(context).unfocus();
        },
      ),
    ),
  ),
  Padding(
    padding: const EdgeInsets.all(16),
    child: ElevatedButton(
      onPressed: () async {
        if (selectedPrediction != null) {
          var result = await googlePlace.details.get(selectedPrediction!.placeId ?? '');
          Map<String, double>? location;
          
          if (result != null && result.result != null) {
            final lat = result.result?.geometry?.location?.lat;
            final lng = result.result?.geometry?.location?.lng;
            if (lat != null && lng != null) {
              location = {
                'lat': lat,
                'lng': lng
              };
            }
          }

          setState(() {
            _activities.add(Activity(
              name: _extractPlaceName(selectedAddress!),
              description: descriptionController.text.trim(),
              placeDescription: selectedAddress,
              location: location,
            ));
            _updateDescription();
          });
          Navigator.pop(context);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${_extractPlaceName(selectedAddress!)}'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Text('Add Activity'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 16),
        minimumSize: Size(double.infinity, 50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

// Add this helper function to extract just the place name
String _extractPlaceName(String fullAddress) {
  // Split the address by comma and take the first part
  return fullAddress.split(',')[0].trim();
}

// Update the _showActivityDescriptionDialog method
/* void _showActivityDescriptionDialog(BuildContext context, String fullAddress, AutocompletePrediction prediction) async {
  final descriptionController = TextEditingController();
  final placeName = _extractPlaceName(fullAddress);
  
  var result = await googlePlace.details.get(prediction.placeId ?? '');
  Map<String, double>? location;
  
  if (result != null && result.result != null) {
    final lat = result.result?.geometry?.location?.lat;
    final lng = result.result?.geometry?.location?.lng;
    if (lat != null && lng != null) {
      location = {
        'lat': lat,
        'lng': lng
      };
    }
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(bottom: keyboardSpace),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Header with place name
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Add activity details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.place, color: Colors.grey[600]),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    placeName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (fullAddress != placeName)
                                    Text(
                                      fullAddress.substring(placeName.length + 2),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Description input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Write something about this place...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.black),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: EdgeInsets.all(16),
                    ),
                    maxLines: 4,
                    style: TextStyle(fontSize: 16),
                  ),
                ),

                // Add button
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _activities.add(Activity(
                          name: placeName,
                          description: descriptionController.text.trim(),
                          placeDescription: fullAddress,
                          location: location,
                        ));
                        _updateDescription();
                      });
                      Navigator.pop(context);
                      Navigator.pop(context);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $placeName'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text('Add Activity'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
} */

void _onSearchChanged() async {
  print("Searching for: ${_bottomSheetSearchController.text}");
  if (_bottomSheetSearchController.text.isNotEmpty) {
    try {
      var result = await googlePlace.autocomplete.get(
        _bottomSheetSearchController.text,
        components: [Component("country", "us")],
      );
      
      if (result != null && result.predictions != null && mounted) {
        setState(() {
          _predictions = result.predictions!;
          print("Predictions updated: ${_predictions.length} results");
        });
      } else {
        setState(() {
          _predictions = [];
        });
      }
    } catch (e) {
      print("Error during places search: $e");
      setState(() {
        _predictions = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching places: $e')),
        );
      }
    }
  } else {
    setState(() {
      _predictions = [];
    });
  }
}

//og code to update the descirption with the activities

/* void _updateDescription() {
  // Build the complete description for storage
  String finalDescription = _userDescription;
  
  if (_activities.isNotEmpty && _userDescription.isNotEmpty) {
    finalDescription += '\n\n';
  }
  
  // Add activities in plain text format for storage
  for (var activity in _activities) {
    if (activity.description.isNotEmpty) {
      finalDescription += '📍 ${activity.name}: ${activity.description}\n';
    } else {
      finalDescription += '📍 ${activity.name}\n';
    }
  }
  
  setState(() {
    _description = finalDescription.trim();
  });
} */

//remove the activity from the desc.
void _updateDescription() {
  // Only use the user's manual description
  setState(() {
    _description = _userDescription.trim();
  });
}

/* // Don't forget to dispose of the controller in the dispose method
@override
void dispose() {
  _descriptionController.dispose();
  _bottomSheetSearchController.dispose();
  super.dispose();
} */

Future<void> _getImages() async {
  try {
    Navigator.push<List<XFile>>(
      context,
      MaterialPageRoute(
        builder: (context) => CustomPhotoSelector(
          onImagesSelected: (selectedImages) {
            Navigator.pop(context, selectedImages); // Return selected images to this page
          },
        ),
      ),
    ).then((selectedImages) async {
      if (selectedImages != null && selectedImages.isNotEmpty) {
        final editedImages = await Navigator.push<List<XFile>>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorPage(
              images: selectedImages,
            ),
          ),
        );
        
        if (editedImages != null && mounted) {
          setState(() {
            _images = editedImages;
          });
        }
      }
    });
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting images: $e')),
      );
    }
    print('Error selecting images: $e');
  }
}

Future<void> _createPost() async {
    if (_formKey.currentState!.validate() && _images.isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        List<String> imageUrls = await _uploadImages();
        User? currentUser = FirebaseAuth.instance.currentUser;
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .get();

        String username = userDoc['username'];
        String userPhotoURL = userDoc['photoURL'] ?? ''; // Changed from photoUrl to photoURL

        // Create post document with trending fields
        Map<String, dynamic> postData = {
          'userId': currentUser.uid,
          'title': _title,
          'description': _description,
          'hashtags': _hashtags,
          'imageUrls': imageUrls,
          'createdAt': FieldValue.serverTimestamp(),
          'username': username,
          'userPhotoURL': userPhotoURL, // Changed from userPhotoUrl to userPhotoURL
          'category': _selectedCategory,
          'city': _selectedCity,
          // Add trending-related fields
          'likes': 0,
          'comments': 0,
          'shares': 0,
          'views': 0,
          'trendingScore': 0.0,
          'lastTrendingUpdate': FieldValue.serverTimestamp(),
          'activities': _activities.map((a) => a.toMap()).toList(),
          'location': _selectedCity,
        };

        // Add post to Firestore
        DocumentReference postRef = await FirebaseFirestore.instance.collection('posts').add(postData);
        
        // Update hashtag metrics
        await _hashtagService.updateHashtagMetrics(_hashtags);

        // Initialize trending score
        final trendingService = TrendingPostsService();
        await trendingService.updateTrendingScore(postRef.id);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post created successfully')),
        );

        Navigator.pushReplacementNamed(context, '/home');
      } catch (e) {
        print("Error creating post: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating post: $e')),
        );
      }

      setState(() {
        _isLoading = false;
      });
    } else if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select at least one image')),
      );
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> imageUrls = [];
    for (var image in _images) {
String fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + image.name;
      Reference firebaseStorageRef = FirebaseStorage.instance.ref().child('posts/$fileName');
      await firebaseStorageRef.putFile(File(image.path));
      String imageUrl = await firebaseStorageRef.getDownloadURL();
      imageUrls.add(imageUrl);
    }
    return imageUrls;
  }
}

class Activity {
  final String name;
  final String description;
  final String? placeDescription;
  final Map<String, double>? location;  // Add location field
  final Key key;

  Activity({
    required this.name,
    this.description = '',
    this.placeDescription,
    this.location,  // Add to constructor
  }) : key = UniqueKey();

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'placeDescription': placeDescription,
      'location': location,  // Include in map
    };
  }
}

