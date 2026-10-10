import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_route_screen.dart';
import 'live_map_screen.dart';
import 'send_notification_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    const titles = ['Plan a route', 'Live workers', 'Notify Workers'];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_tab]),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: _tab == 0
          ? const CreateRouteScreen()
          : _tab == 1
              ? const LiveMapScreen()
              : const SendNotificationScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit_road_outlined), selectedIcon: Icon(Icons.edit_road), label: 'Plan'),
          NavigationDestination(icon: Icon(Icons.directions_car_outlined), selectedIcon: Icon(Icons.directions_car), label: 'Live'),
          NavigationDestination(icon: Icon(Icons.notifications_none), selectedIcon: Icon(Icons.notifications), label: 'Notify'),
        ],
      ),
    );
  }
}
