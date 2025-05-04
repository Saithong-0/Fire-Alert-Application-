import 'package:firealertapp/Sign_up/Sign_up.dart';
import 'package:firealertapp/SoS_page/Sos_alert.dart';
import 'package:firealertapp/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:form_field_validator/form_field_validator.dart';
import 'package:firealertapp/Utility/style.dart';
import 'package:firealertapp/Userdata/Userdata.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  Userdata userdata = Userdata();
  final Future<FirebaseApp> firebase = Firebase.initializeApp();

  // เพิ่มฟังก์ชันสำหรับเปิดหน้าแจ้งเหตุแบบ guest
  void openSosAlertAsGuest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SosAlertPage(isGuest: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: firebase,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text("${snapshot.error}"),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.done) {
            return Scaffold(
              appBar: AppBar(
                backgroundColor: Colors.grey[200],
              ),
              body: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 40),
                            child: SizedBox(
                              width: 160,
                              child: Column(
                                children: [
                                  Mystyle().showlogo(),
                                  Mystyle().Showtitle('Fire alert'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            validator: MultiValidator([
                              RequiredValidator(errorText: "กรุณาป้อน Email"),
                              EmailValidator(errorText: "กรุณาป้อน Email ที่ถูกต้อง"),
                            ]).call,
                            onSaved: (value) {
                              userdata.email = value?.trim();
                            },
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            validator: RequiredValidator(errorText: "กรุณาป้อน Password").call,
                            onSaved: (value) {
                              userdata.password = value?.trim();
                            },
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.key),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () async {
                              if (formKey.currentState!.validate()) {
                                formKey.currentState!.save();
                                await _authService.loginUser(
                                  userdata.email!,
                                  userdata.password!,
                                  context,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.green,
                              minimumSize: const Size(200, 50),
                              textStyle: const TextStyle(fontSize: 20),
                            ),
                            child: const Text('Login'),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const SignUpPage()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.blueAccent,
                              minimumSize: const Size(200, 50),
                              textStyle: const TextStyle(fontSize: 20),
                            ),
                            child: const Text('Register'),
                          ),
                          const SizedBox(height: 10),
                          
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: openSosAlertAsGuest,
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.all(50),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              elevation: 8,
                              shadowColor: Colors.black.withOpacity(0.5),
                            ),
                            child: const Text(
                              'แจ้งเหตุด่วน',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        });
  }
}