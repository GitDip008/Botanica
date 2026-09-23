import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../widgets/app_drawer.dart';
import 'chat_history_screen.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'search_screen.dart';
import 'profile/profile_screen.dart';

class MainNavScreen extends StatefulWidget {
  /// Global key used to open the drawer from anywhere in the nested screens.
  static final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();

  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    MapScreen(),
    SearchScreen(),
    ChatHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        systemNavigationBarColor: C.bg,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: MainNavScreen.scaffoldKey,
        backgroundColor: C.bg,
        drawer: AppDrawer(
          onSelectTab: (i) => setState(() => _currentIndex = i),
        ),
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<LanguageService>().strings;
    return Container(
      decoration: const BoxDecoration(color: C.bg),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.m, Sp.s, Sp.m, Sp.s),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: s.navHome,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.map_rounded,
                label: s.navMap,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.search_rounded,
                label: s.navSearch,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.forum_rounded,
                label: s.navChat,
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: s.navProfile,
                selected: currentIndex == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                decoration: BoxDecoration(
                  color: selected ? C.accentWash : Colors.transparent,
                  borderRadius: BorderRadius.circular(R.pill),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? C.accent : C.textFaint,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? C.accent : C.textFaint,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
