import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AttachmentService {
  AttachmentService(this.client);
  final SupabaseClient client;
  static const _uuid = Uuid();
  static const bucket = 'receipts';

  Future<void> upload({
    required String householdId,
    required String transactionId,
    required String originalName,
    required String contentType,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const FormatException('Lampiran harus berukuran 1 byte–5 MB.');
    }
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('UNAUTHENTICATED');
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    final objectKey =
        '$householdId/$userId/$transactionId/${_uuid.v4()}.$extension';
    await client.storage
        .from(bucket)
        .uploadBinary(
          objectKey,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: false),
        );
    try {
      await client.rpc(
        'register_attachment',
        params: {
          'payload': {
            'transactionId': transactionId,
            'objectKey': objectKey,
            'originalName': originalName,
            'contentType': contentType,
            'fileSize': bytes.length,
          },
        },
      );
    } catch (_) {
      await client.storage.from(bucket).remove([objectKey]);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> list(String transactionId) async =>
      (await client.rpc(
                'list_transaction_attachments',
                params: {'target_transaction_id': transactionId},
              )
              as List)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Future<String> signedUrl(String objectKey) =>
      client.storage.from(bucket).createSignedUrl(objectKey, 300);

  Future<void> delete(String attachmentId) async {
    final result = Map<String, dynamic>.from(
      await client.rpc(
            'delete_attachment',
            params: {'attachment_id': attachmentId},
          )
          as Map,
    );
    await client.storage.from(bucket).remove([result['objectKey'] as String]);
  }
}
