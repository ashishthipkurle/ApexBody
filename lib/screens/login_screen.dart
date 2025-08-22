import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_dashboard.dart';
import 'client_panel.dart';
import 'sign_up_screen.dart';
import 'resend_confirmation_screen.dart';
import '../widgets/loading_animation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Card-like container with curved edges
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 5,
                        spreadRadius: 1,
                        offset: const Offset(2, 3),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Login ID",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        decoration: InputDecoration(
                          hintText: "Enter Username/Email ID",
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Password",
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: "Enter Password",
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Login and Sign Up buttons
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading
                                    ? null
                                    : () async {
                                        setState(() => _isLoading = true);
                                        final email = _emailCtrl.text.trim();
                                        final password = _passCtrl.text.trim();
                                        if (email.isEmpty || password.isEmpty) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Please enter email and password.')),
                                          );
                                          return;
                                        }
                                        try {
                                          final success =
                                              await auth.login(email, password);
                                          if (success) {
                                            final role =
                                                auth.user?.role ?? 'client';
                                            if (role == 'admin') {
                                              Navigator.of(context)
                                                  .pushReplacement(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const AdminDashboard()),
                                              );
                                            } else {
                                              Navigator.of(context)
                                                  .pushReplacement(
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ClientPanel()),
                                              );
                                            }
                                          } else {
                                            // Invalid credentials OR potential unconfirmed email.
                                            // Try to detect unconfirmed email from auth provider error message
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    'Invalid credentials or email not confirmed.'),
                                                action: SnackBarAction(
                                                  label: 'Resend',
                                                  onPressed: () async {
                                                    // Open resend screen pre-filled
                                                    if (!mounted) return;
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ResendConfirmationScreen(
                                                                initialEmail:
                                                                    email),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          final err = e.toString();
                                          // If message implies email not confirmed, show action to resend
                                          if (err.toLowerCase().contains(
                                                  'email not confirmed') ||
                                              err
                                                  .toLowerCase()
                                                  .contains('unconfirmed')) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                    'Please confirm your email. Didn\'t get the email?'),
                                                action: SnackBarAction(
                                                  label: 'Resend',
                                                  onPressed: () async {
                                                    if (!mounted) return;
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            ResendConfirmationScreen(
                                                                initialEmail:
                                                                    email),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(content: Text(err)),
                                            );
                                          }
                                        } finally {
                                          if (mounted) {
                                            setState(() => _isLoading = false);
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: LoadingAnimation(size: 24))
                                    : const Text('Login',
                                        style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const SignUpScreen()),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: const Text('Sign up',
                                    style: TextStyle(fontSize: 18)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final emailCtrl = TextEditingController();
                              final res = await showDialog<String?>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Enter Email'),
                                  content: TextField(
                                    controller: emailCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Email'),
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel')),
                                    ElevatedButton(
                                        onPressed: () => Navigator.pop(
                                            ctx, emailCtrl.text.trim()),
                                        child: const Text('Continue')),
                                  ],
                                ),
                              );
                              if (res == null || res.isEmpty) return;

                              // Send password reset email
                              if (!mounted) return;
                              final auth = Provider.of<AuthProvider>(context,
                                  listen: false);
                              final err =
                                  await auth.sendPasswordResetEmail(res);

                              if (!mounted) return;
                              if (err == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Password reset link sent to your email. Please check your inbox.'),
                                    duration: Duration(seconds: 5),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $err')),
                                );
                              }
                            },
                            child: const Text(
                              "Forgot Password ?",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => ResendConfirmationScreen(
                                      initialEmail: _emailCtrl.text.trim())),
                            );
                          },
                          child: const Text(
                            "Resend Confirmation email",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 150),
              // Logo image
              Image.asset(
                "assets/apexbody_logo.png",
                width: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
