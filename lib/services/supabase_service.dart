import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class SupabaseService {
  final SupabaseClient _client;
  RealtimeChannel? _channel;

  SupabaseService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  Future<List<Task>> fetchTasks() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('tasks')
        .select()
        .eq('user_id', userId);

    return (response as List)
        .map((data) => Task.fromJson(data as Map<String, dynamic>))
        .toList();
  }

  Future<void> upsertTask(Task task) async {
    final data = task.toJson();
    // Remove local-only client columns before sending to Supabase
    data.remove('synced');
    await _client.from('tasks').upsert(data);
  }

  Future<void> hardDeleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  void subscribeToChanges(void Function(dynamic payload) callback) {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Unsubscribe from existing channel if active
    unsubscribe();

    _channel = _client
        .channel('public:tasks')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: callback,
        )
        .subscribe();
  }

  void unsubscribe() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
