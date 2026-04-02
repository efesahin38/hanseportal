import 'package:flutter/material.dart';
import '../services/localization_service.dart';

// Legacy shift plan create screen - deprecated in favor of OperationPlanFormScreen
class ShiftPlanCreateScreen extends StatelessWidget {
  final String? targetCompanyId;
  const ShiftPlanCreateScreen({super.key, this.targetCompanyId});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text(tr('Bu ekran yeni sisteme taşındı.'),
      style: const TextStyle(fontFamily: 'Inter', color: Colors.grey))),
  );
}
