import 'package:flutter/material.dart';

class ApexBodyLoadingPage extends StatefulWidget {
  const ApexBodyLoadingPage({Key? key}) : super(key: key);

  @override
  State<ApexBodyLoadingPage> createState() => _ApexBodyLoadingPageState();
}

class _ApexBodyLoadingPageState extends State<ApexBodyLoadingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Infinite rotation
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo at the top
            Image.asset(
              'assets/apexbody_logo.png',
              height: 300,
            ),
            const SizedBox(height: 16),
            // Loading animation below the logo
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Rotating red circle (background)
                  RotationTransition(
                    turns: _controller,
                    child: Image.asset(
                      'assets/ApexBody_circle.png',
                      height: 60,
                    ),
                  ),
                  // Dumbbell (centered over the circle)
                  Image.asset(
                    'assets/ApexBody_dumbbell.png',
                    height: 40,
                  ),
                  // Loading text (centered below dumbbell)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: const Text(
                      "Loading\nApexBody...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}