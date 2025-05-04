import 'package:flutter/material.dart';

class Mystyle{

     Text Showtitle(String title)=>Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  );
  


    SizedBox showlogo() {
    return SizedBox(
              width: 120.0,
              child: Image.asset('images/Logo.png'),
            );
  }


  Mystyle();
}