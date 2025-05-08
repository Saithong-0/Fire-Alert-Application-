import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';

class ResponderWork extends StatefulWidget {
  final String alertId;
  final String alertAddress;

  const ResponderWork({
    super.key,
    required this.alertId,
    required this.alertAddress,
  });

  @override
  State<ResponderWork> createState() => _ResponderWorkState();
}

class _ResponderWorkState extends State<ResponderWork> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  loc.LocationData? _currentLocation;
  final loc.Location _locationService = loc.Location();
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Timer? _locationTimer;
  bool _isLoading = false;
  LatLng? _destinationLocation;

  @override
  void initState() {
    super.initState();
    _setupDestinationLocation();
    _setupLocationService();
  }

  void _setupDestinationLocation() {
    try {
      final List<String> coordinates = widget.alertAddress.split(',');
      _destinationLocation = LatLng(
        double.parse(coordinates[0].trim()),
        double.parse(coordinates[1].trim()),
      );
    } catch (e) {
      print('Error setting up destination location: $e');
    }
  }

  Future<void> _setupLocationService() async {
    try {
      final permissionStatus = await Permission.location.request();
      if (permissionStatus.isGranted) {
        await _initializeLocation();
      } else {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print('Error setting up location service: $e');
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('การเข้าถึงตำแหน่งถูกปฏิเสธ'),
          content: const Text(
            'แอปพลิเคชันจำเป็นต้องเข้าถึงตำแหน่งของคุณเพื่อการนำทาง กรุณาอนุญาตการเข้าถึงตำแหน่งในการตั้งค่า',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('ไปที่การตั้งค่า'),
              onPressed: () {
                openAppSettings();
              },
            ),
            TextButton(
              child: const Text('ปิด'),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      final locationData = await _locationService.getLocation();
      if (!mounted) return;

      setState(() {
        _currentLocation = locationData;
      });

      _updateMarkers();
      await _updatePolylines();

      // ขยับแผนที่ไปยังตำแหน่งปัจจุบัน
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                locationData.latitude!,
                locationData.longitude!
              ),
              zoom: 15,
            ),
          ),
        );
      }

      _locationTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _updateCurrentLocation(),
      );
    } catch (e) {
      print('Error initializing location: $e');
    }
  }

  void _updateMarkers() {
    if (_currentLocation == null || _destinationLocation == null) return;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            _currentLocation!.latitude!,
            _currentLocation!.longitude!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'ตำแหน่งของคุณ'),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'จุดเกิดเหตุ'),
        ),
      };
    });
  }

  Future<void> _updateCurrentLocation() async {
    if (!mounted) return;

    try {
      final locationData = await _locationService.getLocation();

      setState(() {
        _currentLocation = locationData;
      });

      _updateMarkers();
      await _updatePolylines();
    } catch (e) {
      print('Error updating location: $e');
    }
  }

  Future<void> _updatePolylines() async {
    if (_currentLocation == null || _destinationLocation == null || !mounted) return;

    try {
      String url = 'https://api.openrouteservice.org/v2/directions/driving-car?'
          'start=${_currentLocation!.longitude},${_currentLocation!.latitude}'
          '&end=${_destinationLocation!.longitude},${_destinationLocation!.latitude}'
          '&api_key=Your api';

      var response = await http.get(Uri.parse(url));
      Map<String, dynamic> decodedResponse = json.decode(response.body);

      if (decodedResponse['features'] != null && decodedResponse['features'].isNotEmpty) {
        List<LatLng> polylineCoordinates = [];
        List<dynamic> coordinates = decodedResponse['features'][0]['geometry']['coordinates'];

        for (List<dynamic> coordinate in coordinates) {
          polylineCoordinates.add(LatLng(coordinate[1], coordinate[0]));
        }

        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.red,
              points: polylineCoordinates,
              width: 5,
            ),
          };
        });
      }
    } catch (e) {
      print('Error getting directions: $e');
    }
  }

  Future<void> _completeTask() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestore.collection('alert').doc(widget.alertId).update({
        'alertstatus': 'เสร็จสิ้น',
        'completedTime': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'บันทึกการเสร็จสิ้นภารกิจเรียบร้อยแล้ว',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentLocation == null || _destinationLocation == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('นำทางไปจุดเกิดเหตุ'),
          backgroundColor: Colors.grey[200],
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('นำทางไปจุดเกิดเหตุ'),
        backgroundColor: Colors.grey[200],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _currentLocation!.latitude!,
                _currentLocation!.longitude!
              ),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              if (!mounted) return;
              setState(() {
                _mapController = controller;
              });
            },
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _completeTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 10,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 1,
                        ),
                      )
                    : const Text(
                        'เสร็จสิ้นภารกิจ',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
