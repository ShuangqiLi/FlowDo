import 'package:flutter/material.dart';

import 'task_list_screen.dart';

/// 归档柜：从首页左上角入口进入的独立页，空白处右滑可退回，不占底部导航。
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('归档'),
      ),
      body: const TaskListScreen(status: 'ARCHIVED'),
    );
  }
}
