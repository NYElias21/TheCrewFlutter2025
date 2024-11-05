import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class CreatePostGCPage extends StatefulWidget {
  final String groupId;

  CreatePostGCPage({required this.groupId});

  @override
  _CreatePostGCPageState createState() => _CreatePostGCPageState();
}

class _CreatePostGCPageState extends State<CreatePostGCPage> {
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<File> _images = [];
  bool _allowComments = true;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Post', 
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          )
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: _isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                )
              : TextButton(
                  onPressed: _postController.text.isNotEmpty || _images.isNotEmpty 
                    ? _submitPost 
                    : null,
                  child: Text('Post',
                    style: TextStyle(
                      color: _postController.text.isNotEmpty || _images.isNotEmpty
                        ? Colors.blue
                        : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
  padding: const EdgeInsets.all(16.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircleAvatar(
              radius: 20,
              backgroundColor: Colors.grey[300],
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          String photoURL = '';
          if (snapshot.hasData && snapshot.data != null) {
            var userData = snapshot.data!.data() as Map<String, dynamic>;
            photoURL = userData['photoURL'] ?? '';
          }

          return CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[300],
            backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
            child: photoURL.isEmpty
                ? Icon(Icons.person, size: 24, color: Colors.grey[600])
                : null,
          );
        },
      ),
      SizedBox(width: 12),
      Expanded(
        child: TextField(
          controller: _postController,
          maxLines: null,
          decoration: InputDecoration(
            hintText: "What's going on?",
            hintStyle: TextStyle(
              color: Colors.grey[500],
              fontSize: 16,
            ),
            border: InputBorder.none,
          ),
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
          ),
        ),
      ),
    ],
  ),
),
                  if (_images.isNotEmpty) ...[
                    Container(
                      height: 120,
                      margin: EdgeInsets.symmetric(vertical: 16),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _images.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _images.length) {
                            return _buildAddPhotoButton();
                          }
                          return Stack(
                            children: [
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                width: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(_images[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 16,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _images.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildAddPhotoButton(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.comment_outlined, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  'Allow comments',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 16,
                  ),
                ),
                Spacer(),
                Switch(
                  value: _allowComments,
                  onChanged: (value) {
                    setState(() {
                      _allowComments = value;
                    });
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildAddPhotoButton() {
  return GestureDetector(
    onTap: _getMultipleImages,
    child: Container(
      width: 120,
      height: 120,  // Added fixed height to match photo dimensions
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, 
            size: 32,
            color: Colors.grey[600],
          ),
          SizedBox(height: 4),
          Text(
            'Add Photos',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

  Future<void> _getMultipleImages() async {
    try {
      final List<XFile> selectedImages = await _picker.pickMultiImage();
      if (selectedImages.isNotEmpty) {
        setState(() {
          _images.addAll(selectedImages.map((image) => File(image.path)).toList());
        });
      }
    } catch (e) {
      print('Error picking images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting images'))
      );
    }
  }

  Future<void> _submitPost() async {
    if (_postController.text.isEmpty && _images.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      List<String> imageUrls = [];
      for (var image in _images) {
        String url = await _uploadImage(image);
        imageUrls.add(url);
      }

      await FirebaseFirestore.instance
          .collection('group_posts')
          .add({
        'groupId': widget.groupId,
        'authorId': user.uid,
        'authorName': user.displayName ?? 'Anonymous',
        'authorPhotoUrl': user.photoURL,
        'text': _postController.text,
        'imageUrls': imageUrls,
        'timestamp': FieldValue.serverTimestamp(),
        'allowComments': _allowComments,
      });

      Navigator.of(context).pop();
    } catch (e) {
      print('Error creating post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating post'))
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _uploadImage(File image) async {
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('group_posts')
          .child('${DateTime.now().toIso8601String()}_${image.path.split('/').last}');
      await ref.putFile(image);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      throw e;
    }
  }
}