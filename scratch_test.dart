import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://iuplkgvitovzjbmtzpme.supabase.co',
    'sb_publishable_b5D9jzxkduw55AJj3njOnQ_m1E7cxJP',
  );

  try {
    print('Signing in as tenant...');
    final authRes = await client.auth.signInWithPassword(
      email: 'tenant@carmelita.test',
      password: 'CarmeLinkTest123!',
    );
    print('Signed in as: ${authRes.user?.id}');

    print('Querying conversations...');
    final convs = await client
        .from('conversations')
        .select('id, type, tenant_id, guardian_id, last_message_preview, last_message_at, created_at, updated_at, tenant_profile:profiles!tenant_id(full_name, role), guardian_profile:profiles!guardian_id(full_name, role)');
    print('Convs found: ${convs.length}');
    print('Conv 0: $convs');

    if (convs.isNotEmpty) {
      final convId = convs.first['id'] as String;
      print('Inserting message to conversation: $convId');
      final msgInsert = await client.from('messages').insert({
        'conversation_id': convId,
        'sender_id': authRes.user!.id,
        'sender_role': 'tenant',
        'body': 'Hello from test script!',
        'is_read': false,
      }).select('id, conversation_id, sender_id, sender_role, body, is_read, created_at, profiles!sender_id(full_name, role)').single();
      print('Message inserted successfully: $msgInsert');

      print('Fetching messages...');
      final messages = await client.from('messages').select('id, conversation_id, sender_id, sender_role, body, is_read, created_at, profiles!sender_id(full_name, role)').eq('conversation_id', convId);
      print('Messages found in DB: ${messages.length}');
    }
  } catch (e, st) {
    print('ERROR: $e');
    print('STACK: $st');
  }
}

