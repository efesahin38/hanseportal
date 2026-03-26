import 'package:flutter/material.dart';
// Legacy admin dashboard - deprecated in favor of DashboardScreen + MainShell
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Bu ekran yeni sisteme taşındı.',
      style: TextStyle(fontFamily: 'Inter', color: Colors.grey))),
  );
}
