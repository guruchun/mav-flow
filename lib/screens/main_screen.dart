import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/monitor_state.dart';
import '../widgets/serial_config_panel.dart';
import '../widgets/filter_panel.dart';
import '../widgets/data_table_panel.dart';
import '../widgets/status_bar.dart';

/// SCU-MG3 Serial Monitor 메인 화면.
///
/// Python MainWindow에 대응한다.
/// 레이아웃 (위 → 아래):
///   SerialConfigPanel (포트 설정)
///   FilterPanel       (유형 필터 + 검색)
///   DataTablePanel    (필드 테이블, Expanded)
///   StatusBar         (카운트 / 수신율)
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 에러 snackbar (비동기 연결 오류)
    context.select<MonitorState, String?>((s) => s.lastError).let(
          (err) => err != null
              ? WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        backgroundColor: Colors.red.shade700,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                })
              : null,
        );

    return const Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SerialConfigPanel(),
          FilterPanel(),
          Expanded(child: DataTablePanel()),
          StatusBar(),
        ],
      ),
    );
  }
}

extension _LetExt<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
