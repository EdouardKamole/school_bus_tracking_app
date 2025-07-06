// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Mock data - replace with real data from Firebase later
  String name = 'Mohammed Ali';
  String phone = '+966501234567';
  String schoolId = '20230045';
  String photoUrl = 'https://example.com/student.jpg'; // Replace with actual image

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _schoolIdController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: name);
    _phoneController = TextEditingController(text: phone);
    _schoolIdController = TextEditingController(text: schoolId);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(photoUrl),
                    onBackgroundImageError: (exception, stackTrace) => Icon(Icons.person, size: 60),
                  ),
                  FloatingActionButton.small(
                    onPressed: _changePhoto,
                    child: Icon(Icons.camera_alt),
                  ),
                ],
              ),
              SizedBox(height: 30),
              _buildEditableField(
                label: 'Full Name',
                controller: _nameController,
                icon: Icons.person,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              _buildEditableField(
                label: 'Phone Number',
                controller: _phoneController,
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              _buildEditableField(
                label: 'School ID',
                controller: _schoolIdController,
                icon: Icons.school,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your school ID';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  void _saveProfile() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        name = _nameController.text;
        phone = _phoneController.text;
        schoolId = _schoolIdController.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully')),
      );
    }
  }

  void _changePhoto() {
    // Implement photo change functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Photo'),
        content: Text('Select photo source'),
        actions: [
          TextButton(
            child: Text('Camera'),
            onPressed: () {
              Navigator.pop(context);
              // Open camera
            },
          ),
          TextButton(
            child: Text('Gallery'),
            onPressed: () {
              Navigator.pop(context);
              // Open gallery
            },
          ),
        ],
      ),
    );
  }
}