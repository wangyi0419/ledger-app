import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/ledger_store.dart';
import 'screens/unlock_screen.dart';
import 'screens/home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LedgerStore(),
      child: MaterialApp(
        title: '记账同步',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.dark,
        ),
        home: const RootGate(),
      ),
    );
  }
}

/// 根据是否已解锁，决定显示解锁页还是主页
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Provider.of<LedgerStore>(context);
    return store.unlocked ? const HomeScreen() : const UnlockScreen();
  }
}
