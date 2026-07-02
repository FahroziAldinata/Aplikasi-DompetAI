import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../chat/chat_screen.dart';
import '../goals/saving_goals_screen.dart';
import '../debt/debt_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Start on index 1 (Beranda/Dashboard)
  int _selectedIndex = 1;

  final List<Widget> _screens = [
    const ChatScreen(),
    const DashboardScreen(),
    const SavingGoalsScreen(),
    const DebtScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh, // #2A2A2D
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 20,
                offset: Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: colorScheme.primary, // #C0C1FF
              unselectedItemColor: colorScheme.onSurfaceVariant,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.chat_bubble_outline),
                  activeIcon: Icon(Icons.chat_bubble),
                  label: "Chat",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_outlined),
                  activeIcon: Icon(Icons.grid_view),
                  label: "Beranda",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.radio_button_unchecked),
                  activeIcon: Icon(Icons.circle_outlined),
                  label: "Target",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.receipt_long_outlined),
                  activeIcon: Icon(Icons.receipt_long),
                  label: "Utang",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
