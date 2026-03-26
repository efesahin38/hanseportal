import 'package:flutter/material.dart';
// Legacy shift plan create screen - deprecated in favor of OperationPlanFormScreen
class ShiftPlanCreateScreen extends StatelessWidget {
  final String? targetCompanyId;
  const ShiftPlanCreateScreen({super.key, this.targetCompanyId});
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Bu ekran yeni sisteme taşındı.',
      style: TextStyle(fontFamily: 'Inter', color: Colors.grey))),
  );
}
