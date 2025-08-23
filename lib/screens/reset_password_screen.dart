import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? accessToken;
  const ResetPasswordScreen({Key? key, this.accessToken}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _resolvedToken;
  StreamSubscription? _linkSub;
  final _linkCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If the token wasn't passed via Navigator (sometimes happens on resume),
    // try to read the initial app link which may contain the access_token.
    if (widget.accessToken == null) {
      final appLinks = AppLinks();
      // Try initial link (app cold start)
      appLinks.getInitialAppLink().then((Uri? uri) {
        if (uri == null) return;
        final u = uri;
        // Accept either access_token or code (Supabase uses `code`)
        String? token =
            u.queryParameters['access_token'] ?? u.queryParameters['code'];
        if ((token == null || token.isEmpty) && (u.fragment.isNotEmpty)) {
          try {
            final frag = Uri.splitQueryString(u.fragment);
            token = frag['access_token'] ?? frag['code'];
          } catch (e) {}
        }
        if (token != null && token.isNotEmpty) {
          setState(() => _resolvedToken = token);
        }
      }).catchError((e) {});

      // Also subscribe to runtime links (when app is resumed from background)
      _linkSub = appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri == null) return;
        final u = uri;
        String? token =
            u.queryParameters['access_token'] ?? u.queryParameters['code'];
        if ((token == null || token.isEmpty) && (u.fragment.isNotEmpty)) {
          try {
            final frag = Uri.splitQueryString(u.fragment);
            token = frag['access_token'] ?? frag['code'];
          } catch (e) {}
        }
        if (token != null && token.isNotEmpty) {
          setState(() => _resolvedToken = token);
        }
      }, onError: (e) {
        // ignore
      });
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if ((widget.accessToken ?? _resolvedToken) == null) ...[
                const Text(
                  'No recovery token found. If the reset link did not open correctly, paste the full link from your email here:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Paste reset link here',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final text = _linkCtrl.text.trim();
                    if (text.isEmpty) return;
                    try {
                      final uri = Uri.parse(text);
                      String? token = uri.queryParameters['access_token'] ??
                          uri.queryParameters['code'];
                      if ((token == null || token.isEmpty) &&
                          uri.fragment.isNotEmpty) {
                        final frag = Uri.splitQueryString(uri.fragment);
                        token = frag['access_token'] ?? frag['code'];
                      }
                      if (token != null && token.isNotEmpty) {
                        setState(() => _resolvedToken = token);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Token extracted. You can now set a new password.')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'No token found in the pasted link.')));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invalid URL')));
                    }
                  },
                  child: const Text('Use pasted link'),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (v) {
                  if (v == null || v.trim().length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm password'),
                validator: (v) {
                  if (v != _passCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _loading = true);
                        final auth =
                            Provider.of<AuthProvider>(context, listen: false);
                        final tokenToUse = widget.accessToken ?? _resolvedToken;
                        final err = await auth.resetPasswordWithAccessToken(
                            tokenToUse, _passCtrl.text.trim());
                        setState(() => _loading = false);
                        if (err == null) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Password updated. Please login.')),
                          );
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        } else {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $err')));
                        }
                      },
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Set new password'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
