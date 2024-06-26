import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPDFService {
  final String apiKey;
  final String apiUrl = 'https://api.chatpdf.com/v1';

  // Konstruktor létrehozása az API-kulcs beállításával
  ChatPDFService({required this.apiKey});

  Future<String> addPDFViaURL(String url) async {
    final response = await http.post(
      Uri.parse('$apiUrl/sources/add-url'),
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'url': url}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)['sourceId'];
    } else {
      throw Exception('Failed to add PDF via URL: ${response.reasonPhrase}');
    }
  }

  Future<String> askQuestion(
      String sourceId, List<Map<String, String>> messages) async {
    final response = await http.post(
      Uri.parse('$apiUrl/chats/message'),
      headers: {
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'sourceId': sourceId,
        'messages': messages,
      }),
    );

    if (response.statusCode == 200) {
      // Parse the response
      Map<String, dynamic> responseData = jsonDecode(response.body);

      // Return the content of the response
      return responseData['content'];
    } else {
      throw Exception(
          'Failed to ask question to PDF: ${response.reasonPhrase}');
    }
  }

  Future<void> saveChatMessagesToFirestore(String pdfId, String doctorId,
      List<Map<String, dynamic>> messages) async {
    try {
      // Ellenőrizzük, hogy van-e már dokumentum az adott PDF-hez
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('AIChats')
              .where('pdfId', isEqualTo: pdfId)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Ha van már dokumentum, akkor frissítjük az üzeneteket
        DocumentReference docRef = querySnapshot.docs.first.reference;

        // Ellenőrizzük, hogy van-e már messages list a dokumentumban
        List<Map<String, dynamic>> existingMessages =
            List.from(querySnapshot.docs.first.data()['messages']);
        existingMessages.addAll(messages);

        // Frissítjük a dokumentum üzeneteit
        await docRef.update({
          'messages': existingMessages,
        });
      } else {
        // Ha nincs még dokumentum, akkor létrehozzuk
        CollectionReference chatCollection =
            FirebaseFirestore.instance.collection('AIChats');
        await chatCollection.add({
          'pdfId': pdfId,
          'doctorId': doctorId,
          'messages': messages,
        });
      }

      print('Chat messages saved successfully to Firestore.');
    } catch (e) {
      // Hiba kezelése
      print('Error saving chat messages to Firestore: $e');
    }
  }

// get messages
  Future<List<Map<String, dynamic>>> getChatMessagesFromFirestore(
      String pdfUrl, String doctorId) async {
    try {
      // Ellenőrizzük, hogy van-e már dokumentum az adott PDF-hez
      QuerySnapshot<Map<String, dynamic>> querySnapshot =
          await FirebaseFirestore.instance
              .collection('AIChats')
              .where('pdfId', isEqualTo: pdfUrl)
              .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Ha van már dokumentum, akkor visszaadjuk az üzeneteket
        List<Map<String, dynamic>> messages = [];
        querySnapshot.docs.first.data()['messages'].forEach((message) {
          messages.add({
            'sender': message['sender'],
            'content': message['content'],
            'timestamp': message['timestamp']
                .toDate(), // Convert Firestore timestamp to DateTime
          });
        });
        return messages;
      } else {
        return [];
      }
    } catch (e) {
      // Hiba kezelése
      print('Error getting chat messages from Firestore: $e');
      throw e;
    }
  }
}
