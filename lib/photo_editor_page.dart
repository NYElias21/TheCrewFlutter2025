import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PhotoEditorPage extends StatefulWidget {
  final List<XFile> images;
  final int initialIndex;

  PhotoEditorPage({
    required this.images,
    this.initialIndex = 0,
  });

  @override
  _PhotoEditorPageState createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends State<PhotoEditorPage> {
  late PageController _pageController;
  int _currentPage = 0;
  List<String> _addedTexts = [];
  List<Offset> _textPositions = [];

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                // Top bar
                _buildTopBar(),
                
                // Image display area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.images.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          // Image
                          Center(
                            child: Image.file(
                              File(widget.images[index].path),
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Added texts
                          ..._buildTextOverlays(),
                        ],
                      );
                    },
                  ),
                ),
                
                // Bottom editing tools
                _buildBottomTools(),
                
                // Next button
                _buildNextButton(),
              ],
            ),
            
            // Page indicators
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: _buildPageIndicators(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          IconButton(
            icon: Icon(Icons.add_photo_alternate_outlined, color: Colors.white),
            onPressed: () {
              // Add photo functionality
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.images.length,
        (index) => Container(
          width: 8,
          height: 8,
          margin: EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _currentPage == index ? Colors.white : Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomTools() {
    return Container(
      height: 100,
      color: Colors.black,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildToolButton('Templates', Icons.dashboard_customize),
            _buildToolButton('Filters', Icons.auto_awesome),
            _buildToolButton('Adjust', Icons.tune),
            _buildToolButton('Tags', Icons.local_offer),
            _buildToolButton('Text', Icons.text_fields, onPressed: _handleAddText),
            _buildToolButton('Doodle', Icons.brush),
            _buildToolButton('Stickers', Icons.emoji_emotions),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(String label, IconData icon, {VoidCallback? onPressed}) {
    return Container(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed ?? () {},
          ),
          Text(
            label,
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

Widget _buildNextButton() {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(16),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow,
        foregroundColor: Colors.black,
        padding: EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: _handleNext,  // Changed this line
      child: Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ),
  );
}

Future<void> _handleNext() async {
  if (mounted) {  // Check if widget is still mounted
    Navigator.pop(context, widget.images);  // Return the images back to previous screen
  }
}

  List<Widget> _buildTextOverlays() {
    List<Widget> textWidgets = [];
    for (int i = 0; i < _addedTexts.length; i++) {
      textWidgets.add(
        Positioned(
          left: _textPositions[i].dx,
          top: _textPositions[i].dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _textPositions[i] = Offset(
                  _textPositions[i].dx + details.delta.dx,
                  _textPositions[i].dy + details.delta.dy,
                );
              });
            },
            child: Text(
              _addedTexts[i],
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                shadows: [
                  Shadow(
                    blurRadius: 3.0,
                    color: Colors.black,
                    offset: Offset(1.0, 1.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return textWidgets;
  }

  void _handleAddText() {
    showDialog(
      context: context,
      builder: (context) {
        String newText = '';
        return AlertDialog(
          title: Text('Add Text'),
          content: TextField(
            onChanged: (value) => newText = value,
            decoration: InputDecoration(hintText: 'Enter your text'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newText.isNotEmpty) {
                  setState(() {
                    _addedTexts.add(newText);
                    _textPositions.add(Offset(100, 100)); // Initial position
                  });
                }
                Navigator.pop(context);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }
}