import 'package:flutter/material.dart';

import 'chat/chat_controller.dart';
import 'chat/chat_screen.dart';
import 'room/iso_room.dart';

/// 하단 탭 셸 — [🏠 방](아이소 파니룸) / [💬 톡](채팅).
/// 두 화면은 같은 ChatController 를 공유한다(방에서도 노아가 톡에 반응).
class HomeShell extends StatefulWidget {
  final ChatController controller;
  const HomeShell({super.key, required this.controller});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0; // 0=방, 1=톡

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          RoomScreen(controller: c),
          ChatScreen(controller: c),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFFBD7E0),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cottage_outlined),
            selectedIcon: Icon(Icons.cottage, color: Color(0xFFE2474F)),
            label: '방',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble, color: Color(0xFFE2474F)),
            label: '톡',
          ),
        ],
      ),
    );
  }
}
