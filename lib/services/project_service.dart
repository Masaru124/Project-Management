import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ProjectService extends ChangeNotifier {
  List<Map<String, dynamic>> _projects = [];

  List<Map<String, dynamic>> get projects => _projects;

  Future<void> loadProjects(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('projects')
          .select()
          .contains('members', [userId]);

      _projects = List<Map<String, dynamic>>.from(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading projects: $e');
      throw Exception('Failed to load projects: ${e.toString()}');
    }
  }

  Future<void> createProject({
    required String name,
    required String ownerId,
    String? description,
  }) async {
    try {
      if (name.isEmpty) {
        throw Exception('Project name cannot be empty');
      }

      final projectData = {
        'name': name.trim(),
        'owner': ownerId,
        'members': [ownerId],
        'roles': {ownerId: 'leader'},
      };

      if (description != null && description.trim().isNotEmpty) {
        projectData['description'] = description.trim();
      }

      final response = await Supabase.instance.client
          .from('projects')
          .insert(projectData)
          .select()
          .single();

      await loadProjects(ownerId);
      debugPrint('Project created successfully: ${response['id']}');
    } on PostgrestException catch (e) {
      debugPrint('Database error creating project: ${e.message}');
      if (e.code == '23505') {
        throw Exception('A project with this name already exists');
      } else {
        throw Exception('Database error: ${e.message}');
      }
    } catch (e) {
      debugPrint('Unexpected error creating project: $e');
      throw Exception('Failed to create project: ${e.toString()}');
    }
  }

  Future<void> deleteProject(String projectId, String userId) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw Exception('Project not found');
      }

      if (project['owner'] != userId) {
        throw Exception('Only the project owner can delete this project');
      }

      await Supabase.instance.client
          .from('projects')
          .delete()
          .eq('id', projectId);

      await loadProjects(userId);
    } catch (e) {
      debugPrint('Error deleting project: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProjectById(String projectId) async {
    try {
      final response = await Supabase.instance.client
          .from('projects')
          .select()
          .eq('id', projectId)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error loading project: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTasks(String projectId) async {
    try {
      final response = await Supabase.instance.client
          .from('tasks')
          .select()
          .eq('project_id', projectId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading tasks: $e');
      return [];
    }
  }

  Future<void> createTask({
    required String projectId,
    required String title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
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
      };

      await Supabase.instance.client.from('tasks').insert(taskData);
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    try {
      final validStatuses = ['To-do', 'In Progress', 'Done'];
      if (!validStatuses.contains(status)) {
        throw Exception('Invalid task status');
      }

      await Supabase.instance.client
          .from('tasks')
          .update({'status': status})
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  // New methods for member management
  Future<void> inviteMember(String projectId, String email, String role) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw Exception('Project not found');
      }

      // Create invitation for new user
      final invitationToken = DateTime.now().millisecondsSinceEpoch.toString();
      await Supabase.instance.client.from('project_invitations').insert({
        'project_id': projectId,
        'email': email,
        'role': role,
        'invited_by': Supabase.instance.client.auth.currentUser?.id,
        'token': invitationToken,
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });

      debugPrint('Invitation sent to $email for project $projectId');
    } catch (e) {
      debugPrint('Error inviting member: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String projectId, String memberId) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) {
        throw Exception('Project not found');
      }

      final members = List<String>.from(project['members'] ?? []);
      members.remove(memberId);

      final roles = Map<String, dynamic>.from(project['roles'] ?? {});
      roles.remove(memberId);

      await Supabase.instance.client
          .from('projects')
          .update({
            'members': members,
            'roles': roles,
          })
          .eq('id', projectId);
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getProjectMembers(String projectId) async {
    try {
      final project = await getProjectById(projectId);
      if (project == null) return [];

      final memberIds = List<String>.from(project['members'] ?? []);
      if (memberIds.isEmpty) return [];

      final response = await Supabase.instance.client
          .from('users')
          .select('id, email, raw_user_meta_data')
          .filter('id', 'in', memberIds);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading project members: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getProjectInvitations(String projectId) async {
    try {
      final response = await Supabase.instance.client
          .from('project_invitations')
          .select()
          .eq('project_id', projectId)
          .gte('expires_at', DateTime.now().toIso8601String());

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading project invitations: $e');
      return [];
    }
  }

  Future<void> updateProject({
    required String projectId,
    required String name,
    String? description,
  }) async {
    try {
      final updateData = {
        'name': name.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (description != null) {
        updateData['description'] = description.trim();
      }

      await Supabase.instance.client
          .from('projects')
          .update(updateData)
          .eq('id', projectId);
    } catch (e) {
      debugPrint('Error updating project: $e');
      rethrow;
    }
  }

  Future<void> updateProjectStatus(String projectId, String status) async {
    try {
      await Supabase.instance.client
          .from('projects')
          .update({'status': status})
          .eq('id', projectId);
    } catch (e) {
      debugPrint('Error updating project status: $e');
      rethrow;
    }
  }

  Future<void> updateTask({
    required String taskId,
    required String title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
  }) async {
    try {
      final updateData = {
        'title': title.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (description != null) {
        updateData['description'] = description.trim();
      }
      if (assignedTo != null) {
        updateData['assigned_to'] = assignedTo;
      }
      if (dueDate != null) {
        updateData['due_date'] = dueDate.toIso8601String();
      }

      await Supabase.instance.client
          .from('tasks')
          .update(updateData)
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      await Supabase.instance.client
          .from('tasks')
          .delete()
          .eq('id', taskId);
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }
}
