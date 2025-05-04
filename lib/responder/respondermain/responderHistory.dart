import 'package:firealertapp/responder/respondermain/AlertDetailPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';

class ResponderHistory extends StatefulWidget {
  const ResponderHistory({super.key});

  @override
  State<ResponderHistory> createState() => _ResponderHistoryState();
}

class _ResponderHistoryState extends State<ResponderHistory> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final Map<String, String> _addressCache = {};

  Stream<QuerySnapshot> getCompletedAlerts() {
    return _firestore
        .collection('alert')
        .where('alertstatus', isEqualTo: 'เสร็จสิ้น')
        .orderBy('completedTime', descending: true)
        .snapshots();
  }

  Future<String> getAddressFromCoordinates(String coordinates) async {
    if (_addressCache.containsKey(coordinates)) {
      return _addressCache[coordinates]!;
    }

    try {
      List<String> coords = coordinates.split(',');
      double lat = double.parse(coords[0].trim());
      double lng = double.parse(coords[1].trim());

      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        List<String> addressParts = [];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }

        String address = addressParts.join(', ');
        _addressCache[coordinates] = address.isNotEmpty ? address : coordinates;
        return _addressCache[coordinates]!;
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    _addressCache[coordinates] = coordinates;
    return coordinates;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ประวัติการรับแจ้งเหตุ',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.grey[200],
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getCompletedAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'เกิดข้อผิดพลาด: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('ไม่มีประวัติการรับแจ้งเหตุ'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              String formattedTime = '';
              if (data['completedTime'] != null) {
                if (data['completedTime'] is Timestamp) {
                  formattedTime = dateFormat.format(
                    (data['completedTime'] as Timestamp).toDate(),
                  );
                }
              }

              return FutureBuilder<String>(
                future: getAddressFromCoordinates(data['alertaddress']),
                builder: (context, addressSnapshot) {
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[400],
                            radius: 25,
                            child: const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            addressSnapshot.data ?? 'กำลังโหลดที่อยู่...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                'ผู้แจ้ง: ${data['alertemail']}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'เวลาเสร็จสิ้น: $formattedTime',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'สถานะ: เสร็จสิ้น',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.arrow_forward_ios),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AlertDetailPage(
                                    alertData: data,
                                    address: addressSnapshot.data ?? 'ไม่พบที่อยู่',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (data['alertphoto'] != null &&
                            data['alertphoto'] is List &&
                            (data['alertphoto'] as List).isNotEmpty)
                          Container(
                            height: 120,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: (data['alertphoto'] as List).length,
                              itemBuilder: (context, photoIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      Uri.parse(data['alertphoto'][photoIndex])
                                          .data!
                                          .contentAsBytes(),
                                      fit: BoxFit.cover,
                                      width: 120,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 120,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.error,
                                            color: Colors.red,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}