import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About ApexBody'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'About ApexBody',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'ApexBody is a smart gym management and fitness tracking application built to simplify and modernize the way fitness centers operate. Designed for both clients and trainers, the app combines attendance tracking, workout planning, body analysis, and progress monitoring into one seamless platform.\n\n'
              'With ApexBody, clients can manage their profiles, log workouts, and track their fitness journey, while trainers and admins can efficiently handle client records, personalized workout plans, attendance, and communication. The app also supports profile photo uploads, secure data management, and real-time updates, ensuring a smooth and engaging experience.\n\n'
              'By integrating technology with fitness, ApexBody empowers gyms, trainers, and fitness enthusiasts to achieve their goals faster, stay motivated, and build stronger connections in their fitness community.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 32),
            Text(
              'About the Developer – Ashish Thipkurle',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'ApexBody is developed by Ashish Thipkurle, a passionate Computer Science and Engineering student with strong expertise in mobile and web application development. Skilled in Kotlin, Flutter, Dart, React.js, and Firebase, Ashish has built over 10+ projects, ranging from fitness applications and chat apps to real-time location trackers and management systems.\n\n'
              'With hands-on experience in full-stack development, he has also contributed to real-world projects like a Blood Donation and Management app (Rakshak) and professional web development at Technospot Infotech LLP. His technical skills extend across app development, UI/UX design, cloud databases (Firebase, Supabase, MongoDB), and emerging fields like Machine Learning and Generative AI.\n\n'
              'Recognized for his innovation, Ashish has achieved awards in national-level competitions, published research, and continuously strives to build impactful solutions that bridge technology and real-life needs. ApexBody is one such project, blending his passion for fitness technology and modern app development.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
