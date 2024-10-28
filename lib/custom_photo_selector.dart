import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';  
import 'photo_editor_page.dart';  


class CustomPhotoSelector extends StatefulWidget {
  final Function(List<XFile>) onImagesSelected;

  CustomPhotoSelector({required this.onImagesSelected});

  @override
  _CustomPhotoSelectorState createState() => _CustomPhotoSelectorState();
}

class _CustomPhotoSelectorState extends State<CustomPhotoSelector> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AssetEntity> _mediaList = [];
  List<AssetEntity> _selectedMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchMedia();
  }

  Future<void> _fetchMedia() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      // Only load images
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      
      if (albums.isNotEmpty) {
        final recentAlbum = albums.first;
        final media = await recentAlbum.getAssetListRange(start: 0, end: 100);
        setState(() {
          _mediaList = media;
          _isLoading = false;
        });
      }
    } else {
      // Handle permission denied
      print('Permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: PopupMenuButton<String>(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Recents',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
              Icon(Icons.arrow_drop_down, color: Colors.black),
            ],
          ),
          onSelected: (String value) {
            // Handle album selection
          },
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(
              value: 'recents',
              child: Text('Recents'),
            ),
            PopupMenuItem(
              value: 'camera',
              child: Text('Camera Roll'),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: [
            Tab(text: 'All'),
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
            Tab(text: 'Live Photos'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
                    padding: EdgeInsets.all(1),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: _mediaList.length,
                    itemBuilder: (context, index) {
                      return FutureBuilder<Uint8List?>(
                        future: _mediaList[index].thumbnailData,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final isSelected = _selectedMedia.contains(_mediaList[index]);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedMedia.remove(_mediaList[index]);
                                  } else {
                                    _selectedMedia.add(_mediaList[index]);
                                  }
                                });
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                  ),
                                  if (isSelected)
                                    Container(
                                      color: Colors.white.withOpacity(0.3),
                                      alignment: Alignment.topRight,
                                      padding: EdgeInsets.all(4),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }
                          return Container(color: Colors.grey[200]);
                        },
                      );
                    },
                  ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Selected (${_selectedMedia.length})',
            style: TextStyle(fontSize: 16),
          ),
          ElevatedButton(
            onPressed: _selectedMedia.isEmpty ? null : _handleNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text('Next (${_selectedMedia.length})'),
          ),
        ],
      ),
    );
  }

Future<void> _handleNext() async {
  List<XFile> selectedFiles = [];
  for (var asset in _selectedMedia) {
    final file = await asset.file;
    if (file != null) {
      selectedFiles.add(XFile(file.path));
    }
  }
  if (mounted) {
    Navigator.pop(context, selectedFiles);  // Return selected files back to CreatePostPage
  }
}

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}