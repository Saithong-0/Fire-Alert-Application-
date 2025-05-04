import 'package:flutter/material.dart';

Future<void> normalDialog(BuildContext context, String message) async {
  showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: Colors.white,
            title: Text(message),
            children: <Widget>[
              TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.red),
                  ))
            ],
          ));
}
