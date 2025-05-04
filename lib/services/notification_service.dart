import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> initialize() async {
  // Request notification permissions
  _notifications.resolvePlatformSpecificImplementation;
      AndroidFlutterLocalNotificationsPlugin().requestPermission();

  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
    
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _notifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'fire_alert') {
      }
    },
  );

  
  await _audioPlayer.setSource(AssetSource('sounds/siren-alert.mp3'));
  await _audioPlayer.setReleaseMode(ReleaseMode.stop);

  
  await _checkAndStartListening();
}

  Future<void> _checkAndStartListening() async {
    try {
      // เช็คว่าเป็น responder หรือไม่
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userRole = prefs.getString('userRole');

      if (userRole == 'responder') {
        listenToAlerts();
      }
    } catch (e) {
      print('Error checking role: $e');
    }
  }

  Future<bool> isResponder() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // เช็คใน collection responder
        DocumentSnapshot responderDoc = await _firestore
            .collection('responder')
            .doc(user.uid)
            .get();
        return responderDoc.exists;
      }
      return false;
    } catch (e) {
      print('Error checking responder status: $e');
      return false;
    }
  }

  void listenToAlerts() {
    FirebaseFirestore.instance
        .collection('alert')
        .where('alertstatus', isEqualTo: 'กำลังแจ้งเหตุ')
        .snapshots()
        .listen((snapshot) async {
      // เช็คอีกครั้งว่าเป็น responder
      bool isUserResponder = await isResponder();
      if (!isUserResponder) return;

      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          
          // แสดงการแจ้งเตือน
          showNotification(
            'แจ้งเหตุเพลิงไหม้!',
            'มีการแจ้งเหตุใหม่จาก ${data['alertemail']}',
          );

          // เล่นเสียง
          await _audioPlayer.resume();
          await Future.delayed(const Duration(seconds: 6));
          await _audioPlayer.stop();
        }
      }
    }, onError: (error) {
      print('Error listening to alerts: $error');
    });
  }

  Future<void> showNotification(String title, String body) async {
    // เช็คอีกครั้งว่าเป็น responder ก่อนแสดงการแจ้งเตือน
    bool isUserResponder = await isResponder();
    if (!isUserResponder) return;

    const androidDetails = AndroidNotificationDetails(
      'fire_alert_channel',
      'Fire Alert Notifications',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      enableVibration: true,
      playSound: false, // ปิดเสียงเริ่มต้นของ notification
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false, // ปิดเสียงเริ่มต้นของ notification
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      title,
      body,
      details,
    );
  }

Future<void> showNotificationTop(String title, String body) async {
  bool isUserResponder = await isResponder();
  if (!isUserResponder) return;

  const androidDetails = AndroidNotificationDetails(
    'fire_alert_channel',
    'Fire Alert Notifications',
    importance: Importance.max,
    priority: Priority.high,
    enableLights: true,
    enableVibration: true,
    playSound: false,
    ticker: 'Fire Alert',  // ข้อความที่จะแสดงในแถบสถานะ
    ongoing: true,  // แจ้งเตือนจะไม่หายไปจนกว่าจะกดปิด
    category: AndroidNotificationCategory.alarm,  // ประเภทการแจ้งเตือนฉุกเฉิน
    fullScreenIntent: true,  // เปิดหน้าจอเมื่อได้รับการแจ้งเตือน
    actions: <AndroidNotificationAction>[
      AndroidNotificationAction(
        'view_action',
        'ดูรายละเอียด',
      ),
      AndroidNotificationAction(
        'dismiss_action',
        'ปิดการแจ้งเตือน',
      ),
    ],
    channelShowBadge: true,
    color: Colors.red,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: false,
    interruptionLevel: InterruptionLevel.timeSensitive,  // ระดับความสำคัญสูงสำหรับ iOS
  );

  const details = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  await _notifications.show(
    0,
    title,
    body,
    details,
    payload: 'fire_alert',
  );
}
  // เพิ่มฟังก์ชันหยุดการฟังและเสียง
  Future<void> stopListening() async {
    await _audioPlayer.stop();
  }

  // เพิ่มฟังก์ชันสำหรับ dispose
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
  void handleNotificationTap(String? payload) {
  if (payload == 'fire_alert') {
    // นำทางไปยังหน้าแสดงรายละเอียดการแจ้งเหตุ
  }
}
}

extension on AndroidFlutterLocalNotificationsPlugin {
  void requestPermission() {}
}