import 'package:firealertapp/responder/respondermain/responderHistory.dart';
import 'package:flutter/material.dart';
import 'package:firealertapp/responder/responderalert/responderalert.dart';
import 'package:firealertapp/responder/responderprofile/responderprofile.dart';

class ResponderMainPage extends StatefulWidget {
  const ResponderMainPage({super.key});

  @override
  _ResponderMainPageState createState() => _ResponderMainPageState();
}

class _ResponderMainPageState extends State<ResponderMainPage> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const ResponderAlertPage(),
    const ResponderHistory(),
    const ResponderProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex], 
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Alert',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black,
        backgroundColor: const Color.fromARGB(255, 220, 78, 68),
        type: BottomNavigationBarType.fixed,  // เพิ่มบรรทัดนี้
        onTap: _onItemTapped,
      ),
    );
  }
}