import 'dart:async';

import 'guest_book_message.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, PhoneAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

class ApplicationState extends ChangeNotifier {
  ApplicationState() {
    init();
  }

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;

  StreamSubscription<QuerySnapshot>? _guestBookSubscription;
  List<GuestBookMessage> _guestBookMessages = [];
  List<GuestBookMessage> get guestBookMessages => _guestBookMessages;

  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseUIAuth.configureProviders([EmailAuthProvider()]);

    FirebaseAuth.instance.userChanges().listen((user) {
      if (user != null) {
        _loggedIn = true;
        _guestBookSubscription = FirebaseFirestore.instance
            .collection('guestbook')
            .orderBy('timestamp', descending: true)
            .snapshots()
            .listen((snapshot) {
              _guestBookMessages = [];
              for (final document in snapshot.docs) {
                _guestBookMessages.add(
                  GuestBookMessage(
                    name: document.data()['name'] as String,
                    message: document.data()['text'] as String,
                  ),
                );
              }
              notifyListeners();
            });
      } else {
        _loggedIn = false;
        _guestBookMessages = [];
        _guestBookSubscription?.cancel();
      }
      notifyListeners();
    });
  }

  Future<DocumentReference> addMessageToGuestBook(String message) async {
    if (!_loggedIn) {
      throw Exception('Must be logged in');
    }

    // Récupération de l'utilisateur actuel
    final user = FirebaseAuth.instance.currentUser!;

    try {
      final ref = await FirebaseFirestore.instance.collection('guestbook').add(
        <String, dynamic>{
          'text': message,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          // Utilise le displayName s'il existe, sinon l'email, sinon 'Anonyme'
          'name': user.displayName ?? user.email ?? 'Anonyme',
          'userId': user.uid,
        },
      );
      print("Succès ! Document créé avec l'ID: ${ref.id}");
      return ref;
    } catch (e) {
      print("Erreur Firestore : $e");
      rethrow;
    }
  }
}
