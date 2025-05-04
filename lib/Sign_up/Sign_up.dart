import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firealertapp/Log_in/Login.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firealertapp/Userdata/Userdata.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  SignUpPageState createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final formKey = GlobalKey<FormState>();
  Userdata userdata = Userdata();
  final Future<FirebaseApp> firebase = Firebase.initializeApp();
  final CollectionReference _userCollection =
      FirebaseFirestore.instance.collection("user");

  File? _imageFile;
  String? _base64Image;

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      final bytes = await pickedFile.readAsBytes();
      _base64Image = base64Encode(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: firebase,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text("${snapshot.error}")));
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.grey[200],
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
            ),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: formKey,
                  child: Column(
                    children: <Widget>[
                      GestureDetector(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: _imageFile != null
                              ? FileImage(_imageFile!)
                              : null,
                          child: _imageFile == null
                              ? const Icon(Icons.camera_alt,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        validator:
                            RequiredValidator(errorText: "กรุณาป้อนชื่อ"),
                        onSaved: (value) => userdata.name = value?.trim(),
                        decoration: const InputDecoration(
                            labelText: 'Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        validator: RequiredValidator(
                            errorText: "กรุณาป้อนหมายเลขโทรศัพท์"),
                        onSaved: (value) =>
                            userdata.phonenumber = value?.trim(),
                        decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        validator: MultiValidator([
                          RequiredValidator(errorText: "กรุณาป้อน Email"),
                          EmailValidator(
                              errorText: "กรุณาป้อน Email ที่ถูกต้อง"),
                        ]),
                        onSaved: (value) => userdata.email = value?.trim(),
                        decoration: const InputDecoration(
                            labelText: 'Email', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        validator:
                            RequiredValidator(errorText: "กรุณาป้อน Password"),
                        onSaved: (value) => userdata.password = value?.trim(),
                        obscureText: true,
                        decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();

                            try {
                              UserCredential userCredential = await FirebaseAuth
                                  .instance
                                  .createUserWithEmailAndPassword(
                                email: userdata.email!,
                                password: userdata.password!,
                              );
                              String uid = userCredential.user!.uid;

                              await _userCollection.doc(uid).set({
                                "name": userdata.name,
                                "email": userdata.email,
                                "phonenumber": userdata.phonenumber,
                                "photo": _base64Image ?? '',
                                "role": "reporter",
                              });

                              
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (formKey.currentState != null) {
                                  formKey.currentState!
                                      .reset();
                                }
                              });

                              setState(() {
                                _imageFile = null;
                                _base64Image = null;
                              });

                              Fluttertoast.showToast(
                                  msg: "สร้างบัญชีผู้ใช้เสร็จสิ้น",
                                  backgroundColor: Colors.green);

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()),
                              );
                            } on FirebaseAuthException catch (e) {
                              String message = '';
                              if (e.code == 'email-already-in-use') {
                                message =
                                    "อีเมลนี้มีผู้ใช้แล้ว กรุณาใช้อีเมลอื่นแทน";
                              } else if (e.code == 'weak-password') {
                                message =
                                    "รหัสผ่านจำเป็นต้องมี 6 ตัวอักษรขึ้นไป";
                              } else {
                                message = e.message ?? "เกิดข้อผิดพลาด";
                              }
                              Fluttertoast.showToast(
                                  msg: message, backgroundColor: Colors.red);
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(200, 50),
                          textStyle: const TextStyle(fontSize: 20),
                        ),
                        child: const Text('Register'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
