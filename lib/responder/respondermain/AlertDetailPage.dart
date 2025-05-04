import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AlertDetailPage extends StatelessWidget {
  final Map<String, dynamic> alertData;
  final String address;

  const AlertDetailPage({
    super.key,
    required this.alertData,
    required this.address,
  });

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    String alertTime = '';
    String completedTime = '';

    if (alertData['alerttime'] is Timestamp) {
      alertTime = dateFormat.format(alertData['alerttime'].toDate());
    }
    if (alertData['completedTime'] is Timestamp) {
      completedTime = dateFormat.format(alertData['completedTime'].toDate());
    }

    return Scaffold(
      appBar: AppBar(
        
        title: const Text(
          'รายละเอียดเหตุการณ์',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey[200],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ข้อมูลเหตุการณ์',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('สถานที่:', address),
                    const SizedBox(height: 12),
                    _buildInfoRow('ผู้แจ้ง:', alertData['alertemail']),
                    const SizedBox(height: 12),
                    _buildInfoRow('เวลาแจ้งเหตุ:', alertTime),
                    const SizedBox(height: 12),
                    _buildInfoRow('เวลาเสร็จสิ้น:', completedTime),
                    const SizedBox(height: 12),
                    _buildInfoRow('สถานะ:', 'เสร็จสิ้น', color: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (alertData['alertphoto'] != null && alertData['alertphoto'] is List)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'รูปภาพเหตุการณ์',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: (alertData['alertphoto'] as List).length,
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              Uri.parse(alertData['alertphoto'][index])
                                  .data!
                                  .contentAsBytes(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                    size: 32,
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}