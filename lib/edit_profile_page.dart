import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class EditProfilePage extends StatefulWidget {
  final String fullName;
  final String username;
  final String bio;
  final String? photoURL;

  EditProfilePage({
    required this.fullName,
    required this.username,
    required this.bio,
    this.photoURL,
  });

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late String _name;
  late String _username;
  late String _bio;
  String? _photoURL;
  bool _isLoading = false;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _name = widget.fullName;
    _username = widget.username;
    _bio = widget.bio;
    _photoURL = widget.photoURL;

    _nameController = TextEditingController(text: _name);
    _usernameController = TextEditingController(text: _username);
    _bioController = TextEditingController(text: _bio);
  }

  Future<void> _uploadPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      File imageFile = File(image.path);
      try {
        String fileName = 'profile_${currentUser!.uid}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child('profile_photos/$fileName');
        await storageRef.putFile(imageFile);
        String downloadURL = await storageRef.getDownloadURL();

        await _firestore.collection('users').doc(currentUser!.uid).update({
          'photoURL': downloadURL,
        });

        setState(() {
          _photoURL = downloadURL;
        });
      } catch (e) {
        print('Error uploading photo: $e');
      }
    }
  }

  Future<void> _deletePhoto() async {
    try {
      String fileName = 'profile_${currentUser!.uid}.jpg';
      Reference storageRef = FirebaseStorage.instance.ref().child('profile_photos/$fileName');

      await storageRef.delete();

      await _firestore.collection('users').doc(currentUser!.uid).update({
        'photoURL': null,
      });

      setState(() {
        _photoURL = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile photo deleted')),
      );
    } catch (e) {
      print('Error deleting photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting photo. Please try again.')),
      );
    }
  }

  void _showPhotoOptions() {
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
              _uploadPhoto();
            },
          ),
          if (_photoURL != null)
            ListTile(
              leading: Icon(Icons.delete),
              title: Text('Remove profile picture'),
              onTap: () {
                Navigator.pop(context);
                _deletePhoto();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_nameController.text.isNotEmpty &&
          _usernameController.text.isNotEmpty &&
          _bioController.text.isNotEmpty) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'fullName': _nameController.text,
          'username': _usernameController.text,
          'bio': _bioController.text,
          'photoURL': _photoURL,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill in all fields')),
        );
      }
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile. Please try again.')),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: _photoURL != null ? NetworkImage(_photoURL!) : null,
                              child: _photoURL == null
                                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                                  : null,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Icon(Icons.camera_alt, size: 20, color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text('Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your name',
                      ),
                    ),
                    SizedBox(height: 20),
                    Text('Username', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        hintText: 'Enter your username',
                      ),
                    ),
                    SizedBox(height: 20),
                    Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                    TextField(
                      controller: _bioController,
                      decoration: InputDecoration(
                        hintText: 'Enter your bio',
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveProfile,
                        child: Text('Save Profile'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}