import 'package:cloud_firestore/cloud_firestore.dart';

class Userdata {
  String? name;
  String? phonenumber;
  String? email;
  String? password;
  String? role;
  bool isGuest = false;  // เพิ่ม property สำหรับระบุว่าเป็น guest

  Userdata({
    this.name,
    this.email,
    this.password,
    this.phonenumber,
    this.role,
    this.isGuest = false
  });
}

class ResponderData {
  String? name;
  String? phone;
  String? email;
  String? role;

  ResponderData({
    this.name,
    this.email,
    this.phone,
    this.role,
  });

  factory ResponderData.fromFirestore(DocumentSnapshot snapshot) {
    Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
    return ResponderData(
      name: data['name'],
      email: data['email'],
      phone: data['phone'],
      role: data['role'],
    );
  }
}