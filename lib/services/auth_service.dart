import 'package:firealertapp/Log_in/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../Mainpage/Main_page.dart';
import '../responder/respondermain/respondermain.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class AuthService {
 final FirebaseAuth _auth = FirebaseAuth.instance;
 final FirebaseFirestore _firestore = FirebaseFirestore.instance;

 // เช็คการเชื่อมต่ออินเทอร์เน็ต
 Future<bool> checkInternetConnection() async {
   try {
     final connectivityResult = await Connectivity().checkConnectivity();
     if (connectivityResult == ConnectivityResult.none) {
       return false;
     }

     final result = await InternetAddress.lookup('google.com');
     return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
   } catch (e) {
     print('Error checking internet connection: $e');
     return false;
   }
 }

 // เช็คสถานะการล็อกอินและนำทางไปยังหน้าที่ตาม role
 Future<bool> checkLoginStatus(BuildContext context) async {
   try {
     SharedPreferences prefs = await SharedPreferences.getInstance();
     bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
     String? userRole = prefs.getString('userRole');
     String? userId = prefs.getString('userId');

     if (isLoggedIn && userRole != null && userId != null) {
       // นำทางไปยังหน้าที่ตาม role
       if (context.mounted) {
         if (userRole == 'reporter') {
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (context) => MainPage(uid: userId)),
           );
         } else if (userRole == 'responder') {
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (context) => const ResponderMainPage()),
           );
         }
       }
       return true;
     }
     return false;
   } catch (e) {
     print('Error checking login status: $e');
     return false;
   }
 }

 // ฟังก์ชันล็อกอิน
 Future<void> loginUser(String email, String password, BuildContext context) async {
   try {
     // เช็คการเชื่อมต่ออินเทอร์เน็ต
     bool hasConnection = await checkInternetConnection();
     if (!hasConnection) {
       Fluttertoast.showToast(
         msg: "ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ",
         backgroundColor: Colors.red,
         fontSize: 16.0,
         gravity: ToastGravity.CENTER,
         timeInSecForIosWeb: 3,
       );
       return;
     }

     UserCredential userCredential = await _auth.signInWithEmailAndPassword(
       email: email,
       password: password,
     );

     String uid = userCredential.user!.uid;

     // ตรวจสอบ role ใน collection 'user'
     DocumentSnapshot userDoc = await _firestore.collection('user').doc(uid).get();
     
     String? role;
     if (userDoc.exists) {
       role = (userDoc.data() as Map<String, dynamic>)['role'] as String?;
     } else {
       // ถ้าไม่พบใน user collection ให้ตรวจสอบใน responder collection
       DocumentSnapshot responderDoc = await _firestore.collection('responder').doc(uid).get();
       if (responderDoc.exists) {
         role = 'responder';
       }
     }

     if (role != null) {
       // บันทึกข้อมูลการล็อกอินใน SharedPreferences
       SharedPreferences prefs = await SharedPreferences.getInstance();
       await prefs.setBool('isLoggedIn', true);
       await prefs.setString('userId', uid);
       await prefs.setString('userRole', role);
       await prefs.setString('userEmail', email);

       if (context.mounted) {
         if (role == 'reporter') {
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (context) => MainPage(uid: uid)),
           );
         } else if (role == 'responder') {
           Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (context) => const ResponderMainPage()),
           );
         }
       }
     } else {
       Fluttertoast.showToast(
         msg: "ไม่พบข้อมูลผู้ใช้หรือสิทธิ์การใช้งาน",
         backgroundColor: Colors.red,
         fontSize: 16.0,
       );
     }
   } on FirebaseAuthException catch (e) {
     String message;
     switch (e.code) {
       case 'network-request-failed':
         message = "เกิดปัญหาการเชื่อมต่อ กรุณาตรวจสอบการเชื่อมต่ออินเทอร์เน็ต";
         break;
       case 'user-not-found':
         message = "ไม่พบบัญชีผู้ใช้นี้ในระบบ";
         break;
       case 'wrong-password':
         message = "รหัสผ่านไม่ถูกต้อง";
         break;
       case 'invalid-email':
         message = "รูปแบบอีเมลไม่ถูกต้อง";
         break;
       case 'user-disabled':
         message = "บัญชีผู้ใช้นี้ถูกระงับการใช้งาน";
         break;
       default:
         message = "เกิดข้อผิดพลาดในการเข้าสู่ระบบ: ${e.message}";
     }
     
     Fluttertoast.showToast(
       msg: message,
       backgroundColor: Colors.red,
       fontSize: 16.0,
       gravity: ToastGravity.CENTER,
       timeInSecForIosWeb: 3,
     );
   } on SocketException catch (_) {
     Fluttertoast.showToast(
       msg: "ไม่สามารถเชื่อมต่อกับเซิร์ฟเวอร์ได้ กรุณาลองใหม่อีกครั้ง",
       backgroundColor: Colors.red,
       fontSize: 16.0,
       gravity: ToastGravity.CENTER,
       timeInSecForIosWeb: 3,
     );
   } catch (e) {
     Fluttertoast.showToast(
       msg: "เกิดข้อผิดพลาดที่ไม่คาดคิด: $e",
       backgroundColor: Colors.red,
       fontSize: 16.0,
       gravity: ToastGravity.CENTER,
       timeInSecForIosWeb: 3,
     );
   }
 }

 // ฟังก์ชันล็อกเอาท์
 Future<void> logout(BuildContext context) async {
   try {
     // เช็คการเชื่อมต่ออินเทอร์เน็ต
     bool hasConnection = await checkInternetConnection();
     if (!hasConnection) {
       Fluttertoast.showToast(
         msg: "ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ",
         backgroundColor: Colors.red,
         fontSize: 16.0,
         gravity: ToastGravity.CENTER,
         timeInSecForIosWeb: 3,
       );
       return;
     }

     await _auth.signOut();
     
     // ลบข้อมูลการล็อกอินใน SharedPreferences
     SharedPreferences prefs = await SharedPreferences.getInstance();
     await prefs.clear();

     if (context.mounted) {
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => const LoginPage()),
         (route) => false,
       );
     }
   } catch (e) {
     Fluttertoast.showToast(
       msg: "เกิดข้อผิดพลาดในการออกจากระบบ: $e",
       backgroundColor: Colors.red,
       fontSize: 16.0,
       gravity: ToastGravity.CENTER,
       timeInSecForIosWeb: 3,
     );
   }
 }
}