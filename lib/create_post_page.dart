import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:google_place/google_place.dart';

enum PostType { single, itinerary }

class CreatePostPage extends StatefulWidget {
  @override
  _CreatePostPageState createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();
  PostType _postType = PostType.single;
  List<XFile> _images = [];
  String _title = '';
  String _description = '';
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedCity = 'All Cities';
  List<String> _categories = ['All', 'Outdoors', 'Food', 'Dates', 'Nightlife', 'Coffee', 'Free'];
  List<String> _cities = ['All Cities', 'Charlotte', 'Raleigh', 'Asheville', 'Wilmington', 'Durham', 'Chapel Hill'];
  
  List<ItineraryDay> _itineraryDays = [ItineraryDay(activities: [Activity()])];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Post'),
        actions: [
          IconButton(
            icon: Icon(Icons.remove_red_eye),
            onPressed: () {
              // Implement preview functionality if needed
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
              SegmentedButton<PostType>(
                segments: [
                  ButtonSegment(value: PostType.single, label: Text('Single Post')),
                  ButtonSegment(value: PostType.itinerary, label: Text('Itinerary')),
                ],
                selected: <PostType>{_postType},
                onSelectionChanged: (Set<PostType> newSelection) {
                  setState(() {
                    _postType = newSelection.first;
                  });
                },
              ),
              SizedBox(height: 16),
              _buildImageSelectionSection(),
              SizedBox(height: 16),
              _buildCategoryDropdown(),
              SizedBox(height: 16),
              _buildCityDropdown(),
              SizedBox(height: 16),
              _buildTitleField(),
              SizedBox(height: 16),
              _buildDescriptionField(),
              SizedBox(height: 16),
              if (_postType == PostType.itinerary)
                ..._buildItineraryFields(),
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

  Widget _buildCategoryDropdown() {
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

  Widget _buildTitleField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Add a catchy headline to get more views',
        border: OutlineInputBorder(),
      ),
      validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
      onChanged: (value) => _title = value,
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      decoration: InputDecoration(
        labelText: 'Tap to add a description',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
      onChanged: (value) => _description = value,
    );
  }

  List<Widget> _buildItineraryFields() {
    return [
      Text('Itinerary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ..._itineraryDays.asMap().entries.map((entry) {
        int dayIndex = entry.key;
        ItineraryDay day = entry.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Day ${dayIndex + 1}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...day.activities.asMap().entries.map((activityEntry) {
              int activityIndex = activityEntry.key;
              Activity activity = activityEntry.value;
              return Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Activity Name'),
                    onChanged: (value) => activity.name = value,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Activity Description'),
                    onChanged: (value) => activity.description = value,
                  ),
                  ElevatedButton(
                    onPressed: () => _selectLocation(activity),
                    child: Text(activity.location != null ? 'Change Location' : 'Add Location'),
                  ),
                if (activity.placeDescription != null)
  Text('Location: ${activity.placeDescription}'),

                  if (activityIndex == day.activities.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          day.activities.add(Activity());
                        });
                      },
                      child: Text('Add Activity'),
                    ),
                ],
              );
            }).toList(),
            if (dayIndex == _itineraryDays.length - 1)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _itineraryDays.add(ItineraryDay(activities: [Activity()]));
                  });
                },
                child: Text('Add Day'),
              ),
          ],
        );
      }).toList(),
    ];
  }

Future<void> _selectLocation(Activity activity) async {
  final LatLng? selectedLocation = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => LocationPickerPage(
        activity: activity,  // Pass the activity here
        apiKey: 'AIzaSyCrQnPUOQ6ho_LItD4mC1yRFcA0SEWKYBM',
      ),
    ),
  );

  if (selectedLocation != null) {
    setState(() {
      activity.location = selectedLocation;
    });
  }
}


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

  Future<void> _getImages() async {
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles);
        if (_images.length > 10) {
          _images = _images.sublist(0, 10);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can only select up to 10 images.')),
          );
        }
      });
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

      Map<String, dynamic> postData = {
        'userId': currentUser.uid,
        'title': _title,
        'description': _description,
        'imageUrls': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'username': username,
        'likes': 0,
        'category': _selectedCategory,
        'city': _selectedCity,
        'postType': _postType == PostType.single ? 'single' : 'itinerary',
        'isCompleted': false,  // Add this line
      };

      if (_postType == PostType.itinerary) {
        postData['itinerary'] = _itineraryDays.map((day) => day.toMap()).toList();
      }

      await FirebaseFirestore.instance.collection('social_posts').add(postData);

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

class ItineraryDay {
  List<Activity> activities;

  ItineraryDay({required this.activities});

  Map<String, dynamic> toMap() {
    return {
      'activities': activities.map((activity) => activity.toMap()).toList(),
    };
  }
}

class Activity {
  String name = '';
  String description = '';
  LatLng? location;
  String? placeDescription;  // Add this field to store place description

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'location': location != null ? GeoPoint(location!.latitude, location!.longitude) : null,
      'placeDescription': placeDescription,  // Store place description
    };
  }
}


class LocationPickerPage extends StatefulWidget {
  final LatLng? initialLocation;
  final String apiKey;
  final Activity activity;  // Add this field to accept the activity

  LocationPickerPage({
    this.initialLocation,
    required this.apiKey,
    required this.activity,  // Initialize it here
  });

  @override
  _LocationPickerPageState createState() => _LocationPickerPageState();
}


class _LocationPickerPageState extends State<LocationPickerPage> {
  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  final _searchController = TextEditingController();
  List<AutocompletePrediction> _predictions = [];
  late GooglePlace googlePlace;

 @override
void initState() {
  super.initState();
  _selectedLocation = widget.initialLocation;
  if (_selectedLocation == null) {
    _getCurrentLocation();
  }
  googlePlace = GooglePlace(widget.apiKey);
}


  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    } 

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      print("Error getting current location: $e");
      setState(() {
        _selectedLocation = LatLng(0, 0); // Default to null island
      });
    }
  }

void _onSearchChanged() async {
  if (_searchController.text.isNotEmpty) {
    try {
      var result = await googlePlace.autocomplete.get(_searchController.text);
      if (result != null && result.predictions != null && mounted) {
        setState(() {
          _predictions = result.predictions!;
        });
      } else {
        // Handle the case where no predictions are found
        print("No predictions found");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No places found')));
      }
    } catch (e) {
      // Handle any errors that occur during the search request
      print("Error during places search: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching places: $e')));
    }
  } else {
    setState(() {
      _predictions = [];
    });
  }
}


Widget _buildSearchBar() {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search for a location',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onChanged: (value) {
            _onSearchChanged();
          },
        ),
        if (_predictions.isNotEmpty)
          Container(
            height: 200, // Set a max height for the dropdown
            color: Colors.white,
            child: ListView.builder(
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: Icon(Icons.location_on),
                  title: Text(_predictions[index].description!),
                  onTap: () {
                    _selectSearchResult(_predictions[index]);
                  },
                );
              },
            ),
          ),
      ],
    ),
  );
}


void _selectSearchResult(AutocompletePrediction prediction) async {
  final details = await googlePlace.details.get(prediction.placeId!);
  if (details != null && details.result != null && mounted) {
    final lat = details.result!.geometry!.location!.lat;
    final lng = details.result!.geometry!.location!.lng;
    setState(() {
      _selectedLocation = LatLng(lat!, lng!);
      _predictions = [];
      _searchController.text = prediction.description!;

      // Modify the passed activity's location and placeDescription
      widget.activity.location = LatLng(lat!, lng!);
      widget.activity.placeDescription = prediction.description;
    });
    _mapController.animateCamera(CameraUpdate.newLatLng(_selectedLocation!));
  }
}



@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Select Location'),
      actions: [
        IconButton(
          icon: Icon(Icons.check),
          onPressed: () {
            Navigator.pop(context, _selectedLocation);
          },
        ),
      ],
    ),
    body: Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: Stack(
            children: [
              _selectedLocation == null
                  ? Center(child: CircularProgressIndicator())
                  : GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: _selectedLocation!,
                        zoom: 14.0,
                      ),
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                      },
                      onTap: (LatLng location) {
                        setState(() {
                          _selectedLocation = location;
                        });
                      },
                      markers: _selectedLocation != null
                          ? {
                              Marker(
                                markerId: MarkerId('selected_location'),
                                position: _selectedLocation!,
                              ),
                            }
                          : {},
                    ),
            ],
          ),
        ),
      ],
    ),
  );
}

}