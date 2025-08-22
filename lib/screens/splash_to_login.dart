import 'package:flutter/material.dart';
import 'apexbody_loading_page.dart';
import 'apexbody_home_page.dart';
import '../services/local_storage_service.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'admin_dashboard.dart';
import 'client_panel.dart';

class SplashToLogin extends StatefulWidget {
  const SplashToLogin({Key? key}) : super(key: key);

  @override
  State<SplashToLogin> createState() => _SplashToLoginState();
}

class _SplashToLoginState extends State<SplashToLogin> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final saved = await LocalStorageService.getUser();
    if (saved != null) {
      // restore into AuthProvider
      final auth = Provider.of<AuthProvider>(context, listen: false);
      auth.setSelectedUserForAutoLogin(saved);
      // Navigate based on saved role
      if (saved.role == 'admin' || saved.role == 'trainer') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ClientPanel()),
        );
      }
      return;
    }
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ApexBodyHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const ApexBodyLoadingPage();
  }
}
