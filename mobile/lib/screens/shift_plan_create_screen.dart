import 'package:flutter/material.dart';
import '../services/localization_service.dart';

// Legacy shift plan create screen - deprecated in favor of OperationPlanFormScreen
class ShiftPlanCreateScreen extends StatelessWidget {
  final String? targetCompanyId;
  const ShiftPlanCreateScreen({super.key, this.targetCompanyId});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(tr('Dieser Bildschirm wurde in das neue System verschoben.'),
      style: const TextStyle(fontFamily: 'Inter', color: Colors.grey))),
  );
}
