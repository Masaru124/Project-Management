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
            roles,
            user_details:auth.users!inner(*)
          ''')
          .eq('id', projectId)
          .single();

      final membersList = List<Map<String, dynamic>>.from(response['user_details']);
      final roles = Map<String, dynamic>.from(response['roles'] ?? {});
      
      _members = membersList.map((member) => {
        ...member,
        'role': roles[member['id']] ?? 'contributor',
      }).toList();
      
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
      // Generate invitation token
      final token = _generateInvitationToken();
      
      await Supabase.instance.client.from('project_invitations').insert({
        'project_id': projectId,
        'email': email,
        'role': role,
        'invited_by': Supabase.instance.client.auth.currentUser?.id,
        'token': token,
        'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(),
      });

      // TODO: Send email with invitation link
      debugPrint('Invitation sent to $email with token: $token');
    } catch (e) {
      debugPrint('Error inviting member: $e');
      rethrow;
    }
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

      // Add user to project
      await Supabase.instance.client.rpc('add_project_member', params: {
        'project_id': invitation['project_id'],
        'user_id': userId,
        'role': invitation['role'],
      });

      // Mark invitation as used
      await Supabase.instance.client
          .from('project_invitations')
          .update({'used_at': DateTime.now().toIso8601String()})
          .eq('id', invitation['id']);

      notifyListeners();
    } catch (e) {
      debugPrint('Error accepting invitation: $e');
      rethrow;
    }
  }

  String _generateInvitationToken() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  Future<void> removeMember(String projectId, String userId) async {
    try {
      await Supabase.instance.client.rpc('remove_project_member', params: {
        'project_id': projectId,
        'user_id': userId,
      });
      
      await loadMembers(projectId);
    } catch (e) {
      debugPrint('Error removing member: $e');
      rethrow;
    }
  }

  Future<void> updateMemberRole(String projectId, String userId, String newRole) async {
    try {
      await Supabase.instance.client
          .from('projects')
          .update({
            'roles': {
              userId: newRole,
            }
          })
          .eq('id', projectId);
      
      await loadMembers(projectId);
    } catch (e) {
      debugPrint('Error updating member role: $e');
      rethrow;
    }
  }
}
