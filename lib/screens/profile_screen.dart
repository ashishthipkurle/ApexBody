import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  final bool isAdmin;
  const ProfileScreen({super.key, this.isAdmin = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool editingPicture = false;
  bool isUploading = false;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController genderController;
  late TextEditingController ageController;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    nameController = TextEditingController(text: user?.name ?? '');
    emailController = TextEditingController(text: user?.email ?? '');
    phoneController = TextEditingController(text: user?.phone ?? '');
    genderController = TextEditingController(text: user?.gender ?? '');
    ageController = TextEditingController(text: user?.age?.toString() ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    genderController.dispose();
    ageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        // Check mime type and name for validation
        String fileName = pickedFile.name.toLowerCase();
        bool isValidImage = fileName.endsWith('.jpg') ||
            fileName.endsWith('.jpeg') ||
            fileName.contains('image/jpeg');

        if (!isValidImage) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a JPG/JPEG image')),
          );
          return;
        }

        setState(() {
          _imageFile = kIsWeb ? File(pickedFile.path) : File(pickedFile.path);
          isUploading = true;
        });

        // Capture provider before awaiting to avoid using BuildContext across
        // async gaps, then perform the async upload.
        final auth = Provider.of<AuthProvider>(context, listen: false);

        // Delete old profile image if exists
        if (auth.user?.profilePictureUrl != null &&
            auth.user!.profilePictureUrl!.isNotEmpty) {
          await auth.deleteProfilePicture();
        }

        // Upload new image to backend
        final bytes = await pickedFile.readAsBytes(); // Use XFile directly
        final error = await auth.uploadProfilePicture(bytes);

        if (!mounted) return;

        // Force refresh user data after upload
        setState(() {
          editingPicture = false;
          isUploading = false;
        });

        // Re-fetch user from provider to get latest profilePictureUrl
        final updatedUser = Provider.of<AuthProvider>(context, listen: false).user;

        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading image: $error'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Admin Profile' : 'Client Profile'),
        actions: [
          IconButton(
            icon: Icon(editingPicture ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() => editingPicture = !editingPicture);
              if (!editingPicture) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Tap on the image to change it')),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: editingPicture ? _pickImage : null,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                      ),
                      child: ClipOval(
                        child: _imageFile != null
                            ? kIsWeb
                                ? Image.network(
                                    _imageFile!.path,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    _imageFile!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                            : user?.profilePictureUrl != null
                                ? Image.network(
                                    user!.profilePictureUrl!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      user?.name?.isNotEmpty == true
                                          ? user!.name![0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 48,
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                  if (editingPicture)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              enabled: false,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              enabled: false,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              enabled: false,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Phone',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: genderController,
              enabled: false,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Gender',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              enabled: false,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Age',
                labelStyle: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}
