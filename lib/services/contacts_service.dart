import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:convert/convert.dart';

class Contact {
  final String name;
  final String phone;
  final String hash; // 20-character SHA-256 prefix

  Contact({
    required this.name,
    required this.phone,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'hash': hash,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        hash: json['hash'] ?? '',
      );
}

class ContactsService {
  static const MethodChannel _channel = MethodChannel('com.hyperlink/contacts');
  static final Logger _log = Logger();

  static List<Contact> _contacts = [];
  static Map<String, Contact> _hashToContact = {};

  static List<Contact> get contacts => _contacts;

  static Future<void> syncContacts() async {
    try {
      final List<dynamic>? rawContacts =
          await _channel.invokeListMethod<dynamic>('getContacts');
      if (rawContacts == null) return;

      final List<Contact> synced = [];
      final Map<String, Contact> hashMapping = {};

      for (final item in rawContacts) {
        final map = Map<String, String>.from(item as Map);
        final name = map['name'] ?? 'Unknown';
        final phone = map['phone'] ?? '';
        if (phone.isEmpty) continue;

        final normalized = normalizePhone(phone);
        if (normalized.isEmpty) continue;

        final hash = computePhoneHash(normalized);
        final contact = Contact(name: name, phone: normalized, hash: hash);
        synced.add(contact);
        hashMapping[hash] = contact;
      }

      _contacts = synced;
      _hashToContact = hashMapping;
      _log.i('Synced ${_contacts.length} contact(s)');
    } catch (e) {
      _log.e('Failed to sync contacts: $e');
    }
  }

  static String normalizePhone(String phone) {
    // Strip all non-digit characters
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  static String computePhoneHash(String normalizedPhone) {
    final bytes = utf8.encode(normalizedPhone);
    final digest = SHA256Digest().process(Uint8List.fromList(bytes));
    final fullHash = hex.encode(digest);
    return fullHash.substring(0, 20);
  }

  static Contact? lookupHash(String hash) {
    return _hashToContact[hash];
  }
}
