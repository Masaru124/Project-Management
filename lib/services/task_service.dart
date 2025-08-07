import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskService extends ChangeNotifier {
  List<Map<String, dynamic>> _tasks = [];
  
  List<Map<String, dynamic>> get tasks => _tasks;

  Future<void> loadTasks(String projectId) async {
    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select('''
            *,
            assigned_user:assigned_to(*),
            created_user:created_by(*)
          ''')
          .eq('project_id', projectId)
          .order('created_at', ascending: false);

      _tasks = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      throw Exception('Failed to load tasks: ${e.toString()}');
    }
  }

  Future<void> createTask({
    required String projectId,
    required String title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    String priority = 'medium',
  }) async {
    try {
      if (title.isEmpty) {
        throw Exception('Task title cannot be empty');
      }

      final taskData = {
        'project_id': projectId,
        'title': title.trim(),
        'description': description?.trim(),
        'assigned_to': assignedTo,
        'due_date': dueDate?.toIso8601String(),
        'priority': priority,
        'created_by': Supabase.instance.client.auth.currentUser?.id,
      };

      await Supabase.instance.client.from('tasks').insert(taskData);
      await loadTasks(projectId);
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final validStatuses = ['todo', 'in_progress', 'review', 'done'];
      if (!validStatuses.contains(status)) {
        throw Exception('Invalid task status');
      }

      await Supabase.instance.client
          .from('tasks')
          .update({'status': status})
          .eq('id', taskId);
      
      // Reload tasks for the current project
      final task = _tasks.firstWhere((t) => t['id'] == taskId);
      await loadTasks(task['project_id']);
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final task = _tasks.firstWhere((t) => t['id'] == taskId);
      await Supabase.instance.client
          .from('tasks')
          .delete()
          .eq('id', taskId);
      
      await loadTasks(task['project_id']);
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }

  Future<void> updateTask({
    required String taskId,
    String? title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    String? priority,
  }) async {
    try {
      final updateData = <String, dynamic>{};
      
      if (title != null) updateData['title'] = title.trim();
      if (description != null) updateData['description'] = description.trim();
      if (assignedTo != null) updateData['assigned_to'] = assignedTo;
      if (dueDate != null) updateData['due_date'] = dueDate.toIso8601String();
      if (priority != null) updateData['priority'] = priority;

      if (updateData.isNotEmpty) {
        await Supabase.instance.client
            .from('tasks')
            .update(updateData)
            .eq('id', taskId);
        
        final task = _tasks.firstWhere((t) => t['id'] == taskId);
        await loadTasks(task['project_id']);
      }
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  List<Map<String, dynamic>> getTasksByStatus(String status) {
    return _tasks.where((task) => task['status'] == status).toList();
  }

  List<Map<String, dynamic>> getTasksByUser(String userId) {
    return _tasks.where((task) => task['assigned_to'] == userId).toList();
  }

  int getTaskCountByStatus(String status) {
    return _tasks.where((task) => task['status'] == status).length;
  }
}
