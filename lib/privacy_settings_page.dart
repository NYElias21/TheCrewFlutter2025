import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacySettingsPage extends StatefulWidget {
  @override
  _PrivacySettingsPageState createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? user = FirebaseAuth.instance.currentUser;
  
  bool _isPrivateLikes = false;
  bool _isPrivateSaves = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    if (user != null) {
      try {
        DocumentSnapshot userData = await _firestore.collection('users').doc(user!.uid).get();
        setState(() {
          _isPrivateLikes = userData['isPrivateLikes'] ?? false;
          _isPrivateSaves = userData['isPrivateSaves'] ?? false;
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading privacy settings: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updatePrivacySetting(String setting, bool value) async {
    if (user != null) {
      try {
        await _firestore.collection('users').doc(user!.uid).update({
          setting: value,
        });
        setState(() {
          if (setting == 'isPrivateLikes') {
            _isPrivateLikes = value;
          } else if (setting == 'isPrivateSaves') {
            _isPrivateSaves = value;
          }
        });
      } catch (e) {
        print('Error updating privacy settings: $e');
        // Revert state if update fails
        setState(() {
          if (setting == 'isPrivateLikes') {
            _isPrivateLikes = !value;
          } else if (setting == 'isPrivateSaves') {
            _isPrivateSaves = !value;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Interactions',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                SwitchListTile(
                  title: Text('Private likes'),
                  subtitle: Text(
                    'When enabled, only you can see your liked posts',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  value: _isPrivateLikes,
                  onChanged: (value) => _updatePrivacySetting('isPrivateLikes', value),
                ),
                Divider(),
                SwitchListTile(
                  title: Text('Private saves'),
                  subtitle: Text(
                    'When enabled, only you can see your saved posts',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  value: _isPrivateSaves,
                  onChanged: (value) => _updatePrivacySetting('isPrivateSaves', value),
                ),
                Divider(),
              ],
            ),
    );
  }
}