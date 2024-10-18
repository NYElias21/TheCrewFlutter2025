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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          child: Text('Close', style: TextStyle(color: Colors.black)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('TheCrew', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            child: Text('Publish', style: TextStyle(color: Colors.grey)),
            onPressed: _submitPost,
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: TextField(
              controller: _postController,
              decoration: InputDecoration(
                hintText: "What's going on?",
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
              maxLines: null,
            ),
          ),
          if (_images.isNotEmpty)
            Container(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.file(_images[index], height: 80, width: 80, fit: BoxFit.cover),
                  );
                },
              ),
            ),
          Divider(height: 1),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Checkbox(
                  value: true,
                  onChanged: (value) {},
                ),
                Text('Allow Comments'),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.format_align_left),
                  onPressed: () {},
                ),
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _getImage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

Future<void> _submitPost() async {
  if (_postController.text.isEmpty && _images.isEmpty) return;

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
    'groupId': widget.groupId,  // Add this line
    'authorId': user.uid,
    'authorName': user.displayName ?? 'Anonymous',
    'authorPhotoUrl': user.photoURL,
    'text': _postController.text,
    'imageUrls': imageUrls,
    'timestamp': FieldValue.serverTimestamp(),
    'allowComments': true,
  });

  Navigator.of(context).pop();
}

  Future<String> _uploadImage(File image) async {
    final ref = FirebaseStorage.instance
        .ref()
        .child('group_posts')
        .child('${DateTime.now().toIso8601String()}.jpg');
    await ref.putFile(image);
    return await ref.getDownloadURL();
  }
}