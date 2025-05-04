import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class ImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  Future<bool> ensureCameraPermission(BuildContext context) async {
    try {
      PermissionStatus status = await Permission.camera.status;
      
      if (status.isDenied) {
        status = await Permission.camera.request();
      }
      
      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await _showPermissionDialog(context, 'กล้อง');
        }
        return false;
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking camera permission: $e');
      return false;
    }
  }

  Future<void> _showPermissionDialog(BuildContext context, String permissionType) async {
    if (!context.mounted) return;
    
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

  Future<String?> takePhotoAndGetBase64(BuildContext context) async {
    try {
      if (!await ensureCameraPermission(context)) {
        return null;
      }

      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (photo == null) return null;

      // Read the image file
      final File imageFile = File(photo.path);
      final List<int> imageBytes = await imageFile.readAsBytes();
      
      // Convert to base64
      final String base64Image = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      
      return base64Image;
    } catch (e) {
      debugPrint('Error taking photo and converting to base64: $e');
      return null;
    }
  }

  Future<List<String>> getImageBase64(String alertId) async {
    try {
      final QuerySnapshot photoSnapshot = await _firestore
          .collection('alertphoto')
          .where('alertId', isEqualTo: alertId)
          .orderBy('timestamp', descending: true)
          .get();

      if (photoSnapshot.docs.isEmpty) return [];

      return photoSnapshot.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['photo'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting base64 images: $e');
      return [];
    }
  }

  Future<bool> deleteAllAlertPhotos(String alertId) async {
    try {
      final QuerySnapshot photoSnapshot = await _firestore
          .collection('alertphoto')
          .where('alertId', isEqualTo: alertId)
          .get();

      for (var doc in photoSnapshot.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting alert photos: $e');
      return false;
    }
  }

  Future<bool> deletePhoto(String alertId, String base64Image) async {
    try {
      final QuerySnapshot photoSnapshot = await _firestore
          .collection('alertphoto')
          .where('alertId', isEqualTo: alertId)
          .where('photo', isEqualTo: base64Image)
          .get();

      if (photoSnapshot.docs.isEmpty) return false;

      await photoSnapshot.docs.first.reference.delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      return false;
    }
  }

  Future<int> getPhotoCount(String alertId) async {
    try {
      final QuerySnapshot photoSnapshot = await _firestore
          .collection('alertphoto')
          .where('alertId', isEqualTo: alertId)
          .get();

      return photoSnapshot.docs.length;
    } catch (e) {
      debugPrint('Error getting photo count: $e');
      return 0;
    }
  }
}