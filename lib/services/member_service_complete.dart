import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'dart:convert';

class MemberService extends ChangeNotifier {
  List<Map<String, dynamic>> _members = [];
  
  List<Map<String, dynamic>> get members => _members;

  Future<void> loadMembers(String projectId) async {
    try {
      final response = await Supabase.instance.client
          .from('projects')
          .select('''
            members,
            roles
          ''')
          .eq('id', projectId)
          .single();

      final membersList = List<String>.from(response['members'] ?? []);
      final roles = Map<String, dynamic>.from(response['roles'] ?? {});
      
      if (membersList.isNotEmpty) {
        final users = await Supabase.instance.client
            .from('auth.users')
            .select('id, email, raw_user_meta_data')
            .inFilter('id', membersList);

        _members = users.map((user) => {
          'id': user['id'],
          'email': user['email'],
          'name': user['raw_user_meta_data']?['name'] ?? user['email'],
          'role': roles[user['id']] ?? 'contributor',
        }).toList();
      } else {
        _members = [];
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading members: $e');
      throw Exception('Failed to load members: ${e.toString()}');
    }
  }

  Future<void> inviteMember({
    required String projectId,
    required String email,
    String role = 'contributor',
  }) async {
    try {
      final token = _generateToken();
      
      await Supabase.instance.client.from('project_invitations').insert({
        'project_id': projectId,
        'email': email,
        'role': role,
        'invited_by': Supabase.instance.client.auth.currentUser?.id,
        'token': token,
        'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      });

      debugPrint('Invitation sent to $email with token: $token');
    } catch (e) {
      debugPrint('Error inviting member: $e');
      rethrow;
    }
  }

  String _generateToken() {
    final random = Random();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  Future<void> acceptInvitation(String token) async {
    try {
      final invitation = await Supabase.instance.client
          .from('project_invitations')
          .select()
          .eq('token', token)
          .single();

      if (DateTime.parse(invitation['expires_at']).isBefore(DateTime.now())) {
        throw Exception('Invitation has expired');
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final project = await Supabase.instance.client
          .from('projects')
          .select('members, roles')
          .eq('id', invitation['project_id'])
          .single();

      final members = List<String>.from(project['members'] ?? []);
      final roles = Map<String, dynamic>.from(project['roles'] ?? {});

      if (!members.contains(userId)) {
        members.add(userId);
        roles[userId] = invitation['role'] ?? 'contributor';

        await Supabase.instance.client
            .from('projects')
            .update({
              'members': members,
              'roles': roles,
            })
            .eq('id', invitation['project_id']);
      }

      await Supabase.instance.client
          .from('project_invitations')
          .delete()
          .eq('token', token);

      await loadMembers(invitation['project_id']);
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      rethrow;
    }
  }

  Future<void> removeMember(String projectId, String memberId) async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select('members, roles')
          .eq('id', projectId)
          .single();

      final members = List<String>.from(project['members'] ?? []);
      final roles = Map<String, dynamic>.from(project['roles'] ?? {});

      members.remove(memberId);
      roles.remove(memberId);

      await Supabase.instance.client
          .from('projects')
          .update({
            'members': members,
            'roles': roles,
          })
          .eq('id', projectId);

      await loadMembers(projectId);
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  Future<void> updateMemberRole(String projectId, String memberId, String role) async {
    try {
      final project = await Supabase.instance.client
          .from('projects')
          .select('roles')
          .eq('id', projectId)
          .single();

      final roles = Map<String, dynamic>.from(project['roles'] ?? {});
      roles[memberId] = role;

      await Supabase.instance.client
          .from('projects')
          .update({'roles': roles})
          .eq('id', projectId);

      await loadMembers(projectId);
    } catch (e) {
      debugPrint('Error updating member role: $e');
      rethrow;
    }
  }
}
