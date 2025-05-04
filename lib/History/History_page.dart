import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final Map<String, String> _addressCache = {};

  Stream<QuerySnapshot> getAlertStream() {
    String? currentUserEmail = _auth.currentUser?.email;
    
    if (currentUserEmail == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('alert')
        .where('alertemail', isEqualTo: currentUserEmail)
        .orderBy('alerttime', descending: true)
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

  Color getStatusColor(String status) {
    switch (status) {
      case 'กำลังแจ้งเหตุ':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'พนักงานรับเหตุแล้ว':
        return Colors.green[600] ?? Colors.green;
      default:
        return Colors.grey[600] ?? Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ประวัติการแจ้งเหตุ',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[200],
        automaticallyImplyLeading: false,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getAlertStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'เกิดข้อผิดพลาด: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
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
              child: Text(
                'ไม่พบประวัติการแจ้งเหตุ',
                style: TextStyle(fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              
              String formattedTime = '';
              if (data['alerttime'] != null) {
                if (data['alerttime'] is Timestamp) {
                  formattedTime = dateFormat.format(
                    (data['alerttime'] as Timestamp).toDate(),
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
                          contentPadding: const EdgeInsets.all(16.0),
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[400],
                            radius: 25,
                            child: const Icon(
                              Icons.location_on,
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
                                formattedTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: getStatusColor(data['alertstatus'])
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'สถานะ: ${data['alertstatus']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: getStatusColor(data['alertstatus']),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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