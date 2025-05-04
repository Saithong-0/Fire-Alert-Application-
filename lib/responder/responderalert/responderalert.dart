import 'package:firealertapp/responder/responderalert/responderwork.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geocoding/geocoding.dart';


class ResponderAlertPage extends StatefulWidget {
  const ResponderAlertPage({super.key});

  @override
  State<ResponderAlertPage> createState() => _ResponderAlertPageState();
}

class _ResponderAlertPageState extends State<ResponderAlertPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final Map<String, String> _addressCache = {};

  Stream<QuerySnapshot> getAlertStream() {
    return _firestore
        .collection('alert')
        .orderBy('alerttime', descending: true)
        .snapshots();
  }

  void navigateToResponderWork(String documentId, String alertAddress) {
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResponderWork(
            alertId: documentId,
            alertAddress: alertAddress,
          ),
        ),
      );
    }
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

  Future<void> acceptAlert(String documentId) async {
    try {
      await _firestore.collection('alert').doc(documentId).update({
        'alertstatus': 'พนักงานรับเหตุแล้ว',
        'responderAcceptTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รับแจ้งเหตุเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'กำลังแจ้งเหตุ':
        return Colors.yellow[700] ?? Colors.yellow;
      case 'พนักงานรับเหตุแล้ว':
        return Colors.green[600] ?? Colors.green;
      case 'เสร็จสิ้น':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        title: const Text(
          'รายการแจ้งเหตุ',
          style: TextStyle(color: Colors.black),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getAlertStream(),
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
              child: Text('ไม่มีรายการแจ้งเหตุ'),
            );
          }

          // กรองเอาเฉพาะรายการที่ไม่ใช่สถานะ 'เสร็จสิ้น'
          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['alertstatus'] != 'เสร็จสิ้น';
          }).toList();

          if (filteredDocs.isEmpty) {
            return const Center(
              child: Text('ไม่มีรายการแจ้งเหตุที่ต้องดำเนินการ'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10.0),
            itemCount: filteredDocs.length,
            itemBuilder: (context, index) {
              final doc = filteredDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final status = data['alertstatus'] as String;
              
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
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: Colors.red[400],
                            radius: 25,
                            child: const Icon(
                              Icons.warning_amber,
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
                                'เวลา: $formattedTime',
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
                                  color: getStatusColor(status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'สถานะ: $status',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: getStatusColor(status),
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
                                final photoData = data['alertphoto'][photoIndex];
                                if (photoData == null) {
                                  return Container(
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  );
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      Uri.parse(photoData.toString())
                                          .data!
                                          .contentAsBytes(),
                                      fit: BoxFit.cover,
                                      width: 120,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          width: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
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
                        if (status == 'กำลังแจ้งเหตุ')
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await acceptAlert(doc.id);
                                  if (mounted) {
                                    navigateToResponderWork(
                                      doc.id,
                                      data['alertaddress'],
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'รับแจ้งเหตุ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: status == 'พนักงานรับเหตุแล้ว'
                                    ? () => navigateToResponderWork(
                                        doc.id,
                                        data['alertaddress'],
                                      )
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'พนักงานรับเหตุแล้ว'
                                      ? Colors.blue
                                      : Colors.grey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  status == 'พนักงานรับเหตุแล้ว'
                                      ? 'ดูรายละเอียด'
                                      : 'รับแจ้งแล้ว',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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