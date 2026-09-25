import 'package:flutter/material.dart';

import '../theme.dart';
import 'flowdo_logo.dart';

/// 冷启动 / 初始化时的开屏：品牌图形标 +「随随办办」。
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: context.flowColors.canvas,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FlowDoLogo(size: 96),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '随随办办',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'ZCOOLKuaiLe',
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'FlowDo',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
