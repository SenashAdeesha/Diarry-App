import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../domain/entities/diary_entry.dart';
import '../../../domain/domain_exceptions.dart';
import '../../models/diary_entry_model.dart';

class DiaryRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DiaryRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;
  bool get isAuthenticated => _uid != null;

  CollectionReference get _collection =>
      _firestore.collection('users').doc(_uid!).collection('entries');

  Future<void> pushEntry(DiaryEntry entry) async {
    _ensureAuth();
    try {
      final model = DiaryEntryModel.fromEntity(entry);
      await _collection.doc(entry.id).set(model.toJson());
    } catch (e) {
      throw const RepositoryException('Failed to push entry');
    }
  }

  Future<void> pushBatch(List<DiaryEntry> entries) async {
    _ensureAuth();
    if (entries.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final entry in entries) {
        final model = DiaryEntryModel.fromEntity(entry);
        batch.set(_collection.doc(entry.id), model.toJson());
      }
      await batch.commit();
    } catch (e) {
      throw const RepositoryException('Failed to push entries');
    }
  }

  Future<void> deleteEntry(String id) async {
    _ensureAuth();
    try {
      await _collection.doc(id).delete();
    } catch (e) {
      throw const RepositoryException('Failed to delete remote entry');
    }
  }

  Future<List<DiaryEntry>> pullNewerThan(DateTime since) async {
    _ensureAuth();
    try {
      final snapshot = await _collection
          .where('updated_at', isGreaterThan: since.toIso8601String())
          .orderBy('updated_at', descending: true)
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return DiaryEntryModel.fromJson(data).toEntity();
      }).toList();
    } catch (e) {
      throw const RepositoryException('Failed to pull entries');
    }
  }

  Future<DateTime?> getLatestTimestamp() async {
    _ensureAuth();
    try {
      final snapshot = await _collection
          .orderBy('updated_at', descending: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final data = snapshot.docs.first.data() as Map<String, dynamic>;
      final raw = data['updated_at'];
      if (raw is String) return DateTime.parse(raw);
      if (raw is Timestamp) return raw.toDate();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> entryExists(String id) async {
    _ensureAuth();
    try {
      return (await _collection.doc(id).get()).exists;
    } catch (_) {
      return false;
    }
  }

  void _ensureAuth() {
    if (!isAuthenticated) {
      throw const RepositoryException('User not signed in');
    }
  }
}
