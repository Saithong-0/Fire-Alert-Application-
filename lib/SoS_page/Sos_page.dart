import 'package:flutter/material.dart';
import 'package:firealertapp/SoS_page/Sos_alert.dart';

class SosPage extends StatelessWidget {
  const SosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SosAlertPage()),
                );
                  
                },
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.all(60),
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  elevation: 8, 
                  shadowColor: Colors.black.withOpacity(0.5),
                ),
                child: const Text(
                  'แจ้งเหตุ',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'กดปุ่มเพื่อแจ้งเหตุ',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
