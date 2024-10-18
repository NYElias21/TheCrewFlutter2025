import 'package:flutter/material.dart';
import 'auth_pages.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: ImageCollage(),
          ),
          Expanded(
            flex: 2,
            child: ContentSection(
              pageController: _pageController,
              onPageChanged: (int page) {
                setState(() {
                  _currentPage = page;
                });
              },
              currentPage: _currentPage,
            ),
          ),
        ],
      ),
    );
  }
}

class ImageCollage extends StatefulWidget {
  @override
  _ImageCollageState createState() => _ImageCollageState();
}

class _ImageCollageState extends State<ImageCollage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<String> imageUrls = [
    'https://images.unsplash.com/photo-1582555645330-9fa5f195e1ca?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxjaGFybG90dGV8ZW58MHx8fHwxNzEzODAxMjcxfDA&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1605131259382-af31fd185cdc?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwyfHxyYWxlaWdofGVufDB8fHx8MTcxMzgwMTMyNnww&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1541424729898-d4420afb9602?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw3fHxub3J0aCUyMGNhcm9saW5hfGVufDB8fHx8MTcxMzgwMTM1MHww&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1574079630059-3b6cc5834483?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxub3J0aCUyMGNhcm9saW5hfGVufDB8fHx8MTcxMzgwMTM1MHww&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1523844203081-56a85e95590c?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxOXx8bm9ydGglMjBjYXJvbGluYXxlbnwwfHx8fDE3MTM4MDEzNTB8MA&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1556290287-14de2be0657b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwyMXx8bm9ydGglMjBjYXJvbGluYXxlbnwwfHx8fDE3MTM4MDEzNTB8MA&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1508615263227-c5d58c1e5821?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxiYnF8ZW58MHx8fHwxNzEzODAxNDUzfDA&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1624829072249-ceb2152d688b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHwxfHxjYXJvd2luZHN8ZW58MHx8fHwxNzEzODAxNDY0fDA&ixlib=rb-4.0.3&q=80&w=1080',
    'https://images.unsplash.com/photo-1604364462036-ad11ec4276f0?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=M3w0NTYyMDF8MHwxfHNlYXJjaHw3fHx3aWxtaW5ndG9ufGVufDB8fHx8MTcxMzgwMTQ3N3ww&ixlib=rb-4.0.3&q=80&w=1080',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, math.sin(_controller.value * 2 * math.pi) * 5),
          child: Container(
            padding: EdgeInsets.all(8),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                return _buildImageTile(imageUrls[index]);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageTile(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey[300],
            child: Icon(Icons.error),
          );
        },
      ),
    );
  }
}

class ContentSection extends StatelessWidget {
  final PageController pageController;
  final Function(int) onPageChanged;
  final int currentPage;

  ContentSection({
    required this.pageController,
    required this.onPageChanged,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: [
              _buildContentPage("Unlock Your City", "Dive into the hidden treasures that your city has to offer."),
              _buildContentPage("Discover Together", "Join a community of explorers sharing their favorite spots and secrets."),
            ],
          ),
        ),
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPageIndicator(0),
            SizedBox(width: 8),
            _buildPageIndicator(1),
          ],
        ),
        SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              ElevatedButton(
                 onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  },
                child: Text("Login"),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
              ),
              SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CreateAccountPage()),
    );
  },
                child: Text("Create an Account"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentPage(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int pageIndex) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: currentPage == pageIndex ? Colors.black : Colors.grey,
      ),
    );
  }
}