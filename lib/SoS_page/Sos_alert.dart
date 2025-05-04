import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firealertapp/SoS_page/imageserviceclass.dart';

class SosAlertPage extends StatefulWidget {
  final bool isGuest;
  const SosAlertPage({super.key, this.isGuest = false});

  @override
  _SosAlertPageState createState() => _SosAlertPageState();
}

class _SosAlertPageState extends State<SosAlertPage> {
  late GoogleMapController _mapController;
  final LatLng _center = const LatLng(13.1944, 100.9361);
  Marker? _selectedMarker;
  LatLng? _selectedPosition;
  final List<String> _base64Images = [];
  loc.LocationData? _currentLocation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImageService _imageService = ImageService();
  
  bool _isLoading = false;
  CameraPosition? _currentCameraPosition;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getCurrentLocation();
  }

  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.location,
        Permission.camera,
      ].request();
      
      if (statuses[Permission.location]?.isGranted != true) {
        await _showPermissionDialog('ตำแหน่งที่ตั้ง');
      }

      if (statuses[Permission.camera]?.isGranted != true) {
        await _showPermissionDialog('กล้อง');
      }
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
    }
  }

  Future<void> _showPermissionDialog(String permissionType) async {
    if (!mounted) return;
    
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('ต้องการสิทธิ์การใช้งาน$permissionType'),
          content: Text('แอปพลิเคชันจำเป็นต้องได้รับสิทธิ์ในการใช้งาน$permissionType เพื่อการทำงานที่ถูกต้อง'),
          actions: <Widget>[
            TextButton(
              child: const Text('ตั้งค่า'),
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
            ),
            TextButton(
              child: const Text('ยกเลิก'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final loc.Location location = loc.Location();

      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      var permissionStatus = await location.hasPermission();
      if (permissionStatus == loc.PermissionStatus.denied) {
        permissionStatus = await location.requestPermission();
        if (permissionStatus != loc.PermissionStatus.granted) return;
      }

      final loc.LocationData locationData = await location.getLocation();
      if (mounted) {
        setState(() {
          _currentLocation = locationData;
          _selectedPosition = LatLng(locationData.latitude!, locationData.longitude!);
          _updateMarkerPosition(_selectedPosition!);
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _updateMarkerPosition(LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!));
    }
  }

  void _updateMarkerPosition(LatLng position) {
    setState(() {
      _selectedMarker = Marker(
        markerId: const MarkerId('selected_location'),
        position: position,
        infoWindow: const InfoWindow(title: 'ตำแหน่งที่เลือก'),
      );
      _selectedPosition = position;
    });
  }

  void _onCameraMove(CameraPosition position) {
    _currentCameraPosition = position;
    _updateMarkerPosition(position.target);
  }

  Future<void> _takePhoto() async {
    try {
      final String? base64Image = await _imageService.takePhotoAndGetBase64(context);
      if (base64Image != null && mounted) {
        setState(() {
          _base64Images.add(base64Image);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการถ่ายภาพ: $e')),
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _base64Images.removeAt(index);
    });
  }

  
  Future<void> _submitAlert() async {
    if (_base64Images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาถ่ายรูปเหตุการณ์อย่างน้อย 1 รูป')),
      );
      return;
    }

    if (_currentCameraPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกตำแหน่งบนแผนที่')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ตรวจสอบว่าเป็น guest หรือ user
      final String alertEmail = widget.isGuest ? 'guest' : (_auth.currentUser?.email ?? 'unknown');

      await _firestore.collection('alert').add({
        'alertaddress': '${_currentCameraPosition!.target.latitude.toStringAsFixed(6)}, ${_currentCameraPosition!.target.longitude.toStringAsFixed(6)}',
        'alertemail': alertEmail,
        'alerttime': DateTime.now(),
        'alertphoto': _base64Images,
        'alertstatus': 'กำลังแจ้งเหตุ',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ')),
        );
        
        
        if (widget.isGuest) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text('แจ้งเหตุ', style: TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 300.0,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                        ),
                      ],
                    ),
                    child: GoogleMap(
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: _center,
                        zoom: 15.0,
                      ),
                      markers: _selectedMarker != null ? {_selectedMarker!} : {},
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      mapType: MapType.normal,
                      onCameraMove: _onCameraMove,
                    ),
                  ),
                  const Positioned(
                    top: 16,
                    left: 16,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'ลากแผนที่เพื่อเลือกตำแหน่งที่ต้องการ',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                height: 120,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _base64Images.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _base64Images.length) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 32, color: Colors.grey),
                                SizedBox(height: 4),
                                Text('เพิ่มรูป', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              Uri.parse(_base64Images[index]).data!.contentAsBytes(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(Icons.error, color: Colors.red),
                                );
                              },
                            ),
                          ),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitAlert,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'แจ้งเหตุ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}