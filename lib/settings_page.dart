import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
           automaticallyImplyLeading: false, 
        title: Text('Settings and privacy'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildListTile(context, 'Account', Icons.person_outline),
          _buildListTile(context, 'Privacy', Icons.lock_outline),
          _buildListTile(context, 'Push notifications', Icons.notifications_none),
          _buildListTile(context, 'Share profile', Icons.share_outlined),
          _buildListTile(context, 'Show content on TikTok', Icons.tiktok),
          _buildListTile(context, 'Help Center', Icons.help_outline),
          _buildListTile(context, 'Safety Center', Icons.security),
          _buildListTile(context, 'About TheCrew', Icons.info_outline),
          _buildListTile(
            context, 
            'Log out', 
            Icons.logout,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'TheCrew version 1.0',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: Icon(Icons.chevron_right),
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title functionality not implemented yet')),
        );
      },
    );
  }
}