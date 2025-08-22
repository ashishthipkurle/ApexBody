import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  final bool isAdmin;
  const ProfileScreen({Key? key, this.isAdmin = false}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool editingPicture = false;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController genderController;
  late TextEditingController ageController;

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

  void _saveProfile() {
    // TODO: Save logic (update user in backend)
    setState(() => editingPicture = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Profile updated!')));
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
                // TODO: Save profile picture logic
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile picture updated!')));
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            GestureDetector(
              onTap: editingPicture
                  ? () {
                      // TODO: Implement image picker
                    }
                  : null,
              child: CircleAvatar(
                radius: 40,
                child: Text(
                    user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 32)),
                // TODO: Show actual profile image if available
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              enabled: false,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              enabled: false,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  labelText: 'Email',
                  labelStyle: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              enabled: false,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  labelText: 'Phone',
                  labelStyle: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: genderController,
              enabled: false,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  labelText: 'Gender',
                  labelStyle: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              enabled: false,
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                  labelText: 'Age',
                  labelStyle: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
    );
  }
}
