import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ledger_store.dart';
import 'list_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'add_txn_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  final _pages = const [ListScreen(), StatsScreen(), SettingsScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台时与远端对账
      Provider.of<LedgerStore>(context, listen: false).sync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('记账同步'),
        actions: [
          Consumer<LedgerStore>(
            builder: (_, s, __) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(s.lastSyncMsg,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: '记录'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AddTxnScreen()),
              ),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
