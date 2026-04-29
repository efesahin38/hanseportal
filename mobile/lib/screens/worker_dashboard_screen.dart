import 'package:flutter/material.dart';
// Legacy worker dashboard - deprecated in favor of FieldWorkerShell + FieldMyTasksScreen
class WorkerDashboardScreen extends StatelessWidget {
  const WorkerDashboardScreen({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Dieser Bereich wurde in das neue System überführt.',
      style: TextStyle(fontFamily: 'Inter', color: Colors.grey))),
  );
}
