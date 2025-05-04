import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertManager {
  static final AlertManager _instance = AlertManager._internal();
  final NotificationService _notificationService = NotificationService();

  factory AlertManager() {
    return _instance;
  }

  AlertManager._internal();

  Future<void> initialize() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userRole = prefs.getString('userRole');
    
    if (userRole == 'responder') {
      await _notificationService.initialize();
    }
  }

  Future<void> dispose() async {
    await _notificationService.dispose();
  }
}