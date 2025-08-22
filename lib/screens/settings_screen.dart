import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'apexbody_home_page.dart';
import '../widgets/loading_animation.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    phoneController.text = user?.phone ?? '';
    emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    phoneController.dispose();
    emailController.dispose();
    oldPasswordController.dispose();
    newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final newPass = newPasswordController.text.trim();
    if (newPass.isEmpty || newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a new password (min 6 chars)')));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final err = await auth.changePassword(newPassword: newPass);
    if (err == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Password changed!')));
      oldPasswordController.clear();
      newPasswordController.clear();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $err')));
    }
  }

  Future<void> _updateContact() async {
    // TODO: Implement phone/email update logic
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Contact info updated!')));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loggingOut = true);
    try {
      await Provider.of<AuthProvider>(context, listen: false).signOut();
      // Navigate to home (clear stack)
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ApexBodyHomePage()),
          (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Change Password',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextFormField(
                          controller: oldPasswordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'Old Password')),
                      const SizedBox(height: 8),
                      TextFormField(
                          controller: newPasswordController,
                          obscureText: true,
                          decoration:
                              const InputDecoration(labelText: 'New Password')),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate())
                                _changePassword();
                            },
                            child: const Text('Change Password')),
                      )
                    ],
                  ),
                ),
              ),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Contact Info',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextFormField(
                            controller: phoneController,
                            decoration:
                                const InputDecoration(labelText: 'Phone')),
                        const SizedBox(height: 8),
                        TextFormField(
                            controller: emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email')),
                        const SizedBox(height: 12),
                        SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                                onPressed: _updateContact,
                                child: const Text('Update Contact'))),
                      ]),
                ),
              ),
              const SizedBox(height: 8),
              _loggingOut
                  ? const Center(
                      child: LoadingAnimation(
                      size: 100,
                      text: "Signing out...",
                    ))
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.error),
                        onPressed: _logout,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
