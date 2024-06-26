// patient_services.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PatientServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Beteg azonosítójának lekérdezése
  Future<String> fetchPatientId() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return user.uid;
    } else {
      throw Exception('User not authenticated');
    }
  }

  // Beteg adatok lekérdezése
  Future<Map<String, dynamic>> fetchPatientData(String patientId) async {
    try {
      DocumentSnapshot patientSnapshot =
          await _firestore.collection('patients').doc(patientId).get();

      if (patientSnapshot.exists && patientSnapshot.data() is Map) {
        return patientSnapshot.data() as Map<String, dynamic>;
      } else {
        throw Exception('Patient data not found');
      }
    } catch (e) {
      print('Error fetching patient data: $e');
      throw Exception('Error fetching patient data');
    }
  }

  Future<String> getPatientName(String patientId) async {
    try {
      DocumentSnapshot patientData =
          await _firestore.collection('patients').doc(patientId).get();

      if (patientData.exists && patientData.data() is Map) {
        final data = patientData.data() as Map<String, dynamic>;
        return data['name'] ?? "Unknown";
      } else {
        return "Unknown";
      }
    } catch (e) {
      print('Error fetching patient name: $e');
      return "Unknown";
    }
  }

  Future<String> fetchPatientUserName() async {
    String username = "Unknown";
    User? user = _auth.currentUser;

    if (user != null) {
      try {
        DocumentSnapshot userData =
            await _firestore.collection('users').doc(user.uid).get();
        if (userData.exists && userData.data() is Map) {
          Map<String, dynamic> data = userData.data() as Map<String, dynamic>;
          username = data['userName'] ?? "No username";
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }
    }

    return username;
  }

  //pdf url
  Future<String?> fetchDocumentPDFUrl(
      String patientId, String documentId) async {
    try {
      DocumentSnapshot documentSnapshot = await _firestore
          .collection('patients')
          .doc(patientId)
          .collection('documents')
          .doc(documentId)
          .get();

      if (documentSnapshot.exists && documentSnapshot.data() != null) {
        Map<String, dynamic> data =
            documentSnapshot.data() as Map<String, dynamic>;
        return data['PDFUrl'];
      } else {
        return null;
      }
    } catch (e) {
      print('Error fetching document PDF URL: $e');
      return null;
    }
  }

  // A beteghez rendelt orvos azonosítójának lekérdezése
  Future<String> getAssignedDoctorIdForDocument(
      String patientId, String documentId) async {
    DocumentSnapshot documentSnapshot = await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('documents')
        .doc(documentId)
        .get();

    if (documentSnapshot.exists && documentSnapshot.data() is Map) {
      Map<String, dynamic> data =
          documentSnapshot.data() as Map<String, dynamic>;
      return data['assignedDoctorId'] ?? "No assigned doctor";
    } else {
      throw Exception('Assigned doctor ID not found for document');
    }
  }

  // A dokumentum forDoctorReview mezőjének beállítása true-ra
  Future<void> sendDocumentToDoctor(String patientId, String documentId) async {
    await _firestore
        .collection('patients')
        .doc(patientId)
        .collection('documents')
        .doc(documentId)
        .update({'forDoctorReview': true});
  }

  Future<Map<String, String>> fetchPatientDetails(String uid) async {
    try {
      // Fetching doctor details from 'doctors' collection
      DocumentSnapshot patientData =
          await _firestore.collection('patients').doc(uid).get();
      Map<String, String> details = {};

      if (patientData.exists && patientData.data() is Map) {
        final data = patientData.data() as Map<String, dynamic>;
        details['name'] = data['name'] ?? "No full name";
        details['profilePictureURL'] = data['profilePictureURL'] ?? "";
      }

      // Fetching email from 'users' collection
      DocumentSnapshot userData =
          await _firestore.collection('users').doc(uid).get();
      if (userData.exists && userData.data() is Map) {
        final data = userData.data() as Map<String, dynamic>;
        details['email'] = data['email'] ?? "No email";
      }

      return details;
    } catch (e) {
      print('Error fetching patient details: $e');
      throw Exception('Error fetching patient details');
    }
  }

  Future<void> updatePatientDetails(Map<String, String> updates) async {
    User? user = _auth.currentUser;
    if (user != null && updates.isNotEmpty) {
      await _firestore.collection('patients').doc(user.uid).update(updates);
    }
  }

  // Fetch all doctors
  Future<List<Map<String, dynamic>>> fetchAllDoctors() async {
    List<Map<String, dynamic>> doctors = [];
    try {
      QuerySnapshot snapshot = await _firestore.collection('doctors').get();
      for (var doc in snapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        doctors.add({
          'id': doc.id,
          'fullName': data['fullName'],
          'specialization': data['specialization'],
          'clinic': data['clinic'],
          'address': data['address'],
          'experience': data['experience'],
          'about': data['about'],
          'profilePictureURL': data['profilePictureURL'],
        });
      }
      return doctors;
    } catch (e) {
      print('Error fetching all doctors: $e');
      throw Exception('Error fetching all doctors');
    }
  }

  //fetch my doctors
  Future<List<Map<String, dynamic>>> fetchMyDoctors(String patientId) async {
    List<Map<String, dynamic>> doctors = [];
    try {
      QuerySnapshot requestSnapshot = await _firestore
          .collection('contactRequests')
          .where('patientId', isEqualTo: patientId)
          .where('isAccepted', isEqualTo: true)
          .get();

      // Az elfogadott kapcsolatfelvételi kérésekhez tartozó orvosok id-jainak lekérdezése
      List<String> acceptedDoctorIds = requestSnapshot.docs
          .map<String>(
              (doc) => doc['doctorId'] as String) // Átkonvertáljuk a típust
          .toList();

      // Az orvosok adatainak lekérése a kapcsolatfelvételi kéréseik alapján
      QuerySnapshot doctorSnapshot = await _firestore
          .collection('doctors')
          .where(FieldPath.documentId, whereIn: acceptedDoctorIds)
          .get();

      for (var doc in doctorSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>;
        doctors.add({
          'id': doc.id,
          'fullName': data['fullName'],
          'specialization': data['specialization'],
          'clinic': data['clinic'],
          'address': data['address'],
          'experience': data['experience'],
          'about': data['about'],
          'profilePictureURL': data['profilePictureURL'],
        });
      }
      return doctors;
    } catch (e) {
      print('Error fetching my doctors: $e');
      throw Exception('Error fetching my doctors');
    }
  }

  // Orvosnak küldött kapcsolatfelvétel kérés küldése
  Future<void> sendContactRequest(String doctorId, String patientId) async {
    try {
      // Hozzáadjuk a kapcsolatfelvétel kérést a contactRequests kollekcióhoz
      await _firestore.collection('contactRequests').add({
        'doctorId': doctorId,
        'patientId': patientId,
        'timestamp': DateTime.now(),
        'isAccepted': false, // Alapértelmezetten még nem elfogadott
      });
    } catch (e) {
      print('Error sending contact request: $e');
      throw Exception('Error sending contact request');
    }
  }

  Future<bool> isContactRequestSent(String doctorId, String patientId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('contactRequests')
              .where('doctorId', isEqualTo: doctorId)
              .where('patientId', isEqualTo: patientId)
              .get();

      // Ellenőrizze, hogy a kapcsolatfelvételi kérelem megtalálható-e
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if contact request is sent: $e');
      throw Exception('Error checking if contact request is sent');
    }
  }

  Future<bool> isContactRequestAccepted(
      String doctorId, String patientId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('contactRequests')
              .where('doctorId', isEqualTo: doctorId)
              .where('patientId', isEqualTo: patientId)
              .where('isAccepted', isEqualTo: true)
              .get();

      // Ellenőrizze, hogy a kapcsolatfelvétel elfogadva van-e
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if contact request is accepted: $e');
      throw Exception('Error checking if contact request is accepted');
    }
  }
  // Itt definiálhatsz több függvényt is, például:
}
