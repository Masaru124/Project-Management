import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:developer' as developer;
import '../../services/project_service.dart';
import '../../services/auth_service.dart';

class ProjectDetailScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _project;
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadProjectData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectData() async {
    final projectService = Provider.of<ProjectService>(context, listen: false);
    
    try {
      // Load project details
      _project = await projectService.getProjectById(widget.projectId);
      
      // Load tasks for the project
      _tasks = await projectService.getTasks(widget.projectId);
      
      // Load project members
      await _loadProjectMembers();
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading project: ${e.toString()}')),
      );
    }
  }

  Future<void> _loadProjectMembers() async {
    if (_project == null) return;
    
    final memberIds = List<String>.from(_project!['members'] ?? []);
    if (memberIds.isEmpty) {
      setState(() => _members = []);
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, email, raw_user_meta_data')
          .inFilter('id', memberIds);

      setState(() {
        _members = response != null ? List<Map<String, dynamic>>.from(response) : [];
      });
    } catch (e) {
      debugPrint('Error loading members: $e');
      setState(() => _members = []);
    }
  }

  double get _completionRate {
    if (_tasks.isEmpty) return 0;
    final completedTasks = _tasks.where((task) => task['status'] == 'done').length;
    return completedTasks / _tasks.length;
  }

  String get _projectStatus {
    if (_completionRate == 1) return 'Completed';
    if (_completionRate > 0.7) return 'Almost Done';
    if (_completionRate > 0.3) return 'In Progress';
    return 'Starting';
  }

  Color get _statusColor {
    switch (_projectStatus) {
      case 'Completed':
        return Colors.green;
      case 'Almost Done':
        return Colors.orange;
      case 'In Progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _project == null
              ? const Center(child: Text('Project not found'))
              : _buildProjectContent(),
    );
  }

  Widget _buildProjectContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(_project!['name']),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_open, size: 48, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        _project!['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editProject(),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareProject(),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProjectStats(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                  Tab(icon: Icon(Icons.task), text: 'Tasks'),
                  Tab(icon: Icon(Icons.people), text: 'Members'),
                  Tab(icon: Icon(Icons.settings), text: 'Settings'),
                ],
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTasksTab(),
          _buildMembersTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildProjectStats() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.task_outlined,
            title: 'Tasks',
            value: '${_tasks.length}',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            title: 'Progress',
            value: '${(_completionRate * 100).toStringAsFixed(0)}%',
            color: _statusColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            icon: Icons.people_outline,
            title: 'Members',
            value: '${_members.length}',
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProjectDescription(),
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 24),
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildProjectDescription() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _project!['description'] ?? 'No description provided',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Progress',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _completionRate,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Status: $_projectStatus',
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_tasks.where((t) => t['status'] == 'done').length}/${_tasks.length} completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_tasks.isEmpty)
              const Text('No recent activity')
            else
              ..._tasks.take(3).map((task) => _buildActivityItem(task)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> task) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(task['status']),
        child: Icon(
          _getStatusIcon(task['status']),
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(task['title']),
      subtitle: Text('Status: ${task['status'] ?? 'To-do'}'),
      trailing: Text(
        _formatDate(task['created_at']),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Widget _buildTasksTab() {
    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTaskFilters(),
          const SizedBox(height: 16),
          ..._tasks.map((task) => _buildEnhancedTaskCard(task)),
        ],
      ),
    );
  }

  Widget _buildTaskFilters() {
    return Row(
      children: [
        FilterChip(
          label: const Text('All'),
          selected: true,
          onSelected: (selected) {},
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('To-do'),
          selected: false,
          onSelected: (selected) {},
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('In Progress'),
          selected: false,
          onSelected: (selected) {},
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Done'),
          selected: false,
          onSelected: (selected) {},
        ),
      ],
    );
  }

  Widget _buildEnhancedTaskCard(Map<String, dynamic> task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Checkbox(
          value: task['status'] == 'done',
          onChanged: (value) => _toggleTaskStatus(task['id'], value),
        ),
        title: Text(
          task['title'],
          style: TextStyle(
            decoration: task['status'] == 'done' ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task['description'] != null)
              Text(
                task['description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.flag,
                  size: 16,
                  color: _getPriorityColor(task['priority']),
                ),
                const SizedBox(width: 4),
                Text(
                  task['priority'] ?? 'Medium',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (task['due_date'] != null) ...[
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(task['due_date']),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showTaskOptions(task),
        ),
      ),
    );
  }

  Widget _buildMembersTab() {
    return RefreshIndicator(
      onRefresh: _loadProjectData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInviteMemberCard(),
          const SizedBox(height: 16),
          ..._members.map((member) => _buildMemberCard(member)),
        ],
      ),
    );
  }

  Widget _buildInviteMemberCard() {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.add, color: Colors.white),
        ),
        title: const Text('Invite New Member'),
        subtitle: const Text('Add team members to collaborate'),
        onTap: () => _inviteMember(),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final userData = member['raw_user_meta_data'] ?? {};
    final displayName = userData['full_name'] ?? member['email'] ?? 'Unknown';
    final avatarUrl = userData['avatar_url'];
    
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null ? Text(displayName[0].toUpperCase()) : null,
        ),
        title: Text(displayName),
        subtitle: Text(member['email'] ?? ''),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showMemberOptions(member),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSettingsSection(
          title: 'Project Settings',
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Project Details'),
              onTap: () => _editProject(),
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archive Project'),
              onTap: () => _archiveProject(),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Project', style: TextStyle(color: Colors.red)),
              onTap: () => _deleteProject(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Card(
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Helper methods
  Future<void> _toggleTaskStatus(String taskId, bool? completed) async {
    final projectService = Provider.of<ProjectService>(context, listen: false);
    try {
      await projectService.updateTaskStatus(taskId, completed == true ? 'done' : 'todo');
      await _loadProjectData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: ${e.toString()}')),
      );
    }
  }

  void _showTaskOptions(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Task'),
              onTap: () => _editTask(task),
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete Task'),
              onTap: () => _deleteTask(task['id']),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberOptions(Map<String, dynamic> member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('View Profile'),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Send Message'),
              onTap: () {},
            ),
            if (_project?['owner'] == Supabase.instance.client.auth.currentUser?.id)
              ListTile(
                leading: const Icon(Icons.remove_circle_outline, color: Colors.red),
                title: const Text('Remove from Project', style: TextStyle(color: Colors.red)),
                onTap: () => _removeMember(member['id']),
              ),
          ],
        ),
      ),
    );
  }

  void _editProject() {
    _showEditProjectDialog();
  }

  void _shareProject() {
    _showShareProjectDialog();
  }

  void _inviteMember() {
    _showInviteMemberDialog();
  }

  void _removeMember(String memberId) {
    _showRemoveMemberConfirmation(memberId);
  }

  void _archiveProject() {
    _showArchiveProjectDialog();
  }

  void _deleteProject() {
    _showDeleteProjectDialog();
  }

  void _editTask(Map<String, dynamic> task) {
    _showEditTaskDialog(task);
  }

  void _deleteTask(String taskId) {
    _showDeleteTaskConfirmation(taskId);
  }

  void _showEditProjectDialog() {
    final nameController = TextEditingController(text: _project!['name']);
    final descriptionController = TextEditingController(text: _project!['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Project'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final projectService = Provider.of<ProjectService>(context, listen: false);
              try {
                await projectService.updateProject(
                  projectId: widget.projectId,
                  name: nameController.text,
                  description: descriptionController.text,
                );
                Navigator.pop(context);
                await _loadProjectData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Project updated successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating project: ${e.toString()}')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showShareProjectDialog() {
    final shareUrl = 'https://projectmanager.app/project/${widget.projectId}';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Project'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this project with your team:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(shareUrl),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copied to clipboard')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  onPressed: () {
                    Share.share('Check out this project: $shareUrl');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showInviteMemberDialog() {
    final emailController = TextEditingController();
    String selectedRole = 'member';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite Member'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(value: 'contributor', child: Text('Contributor')),
                    DropdownMenuItem(value: 'leader', child: Text('Leader')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedRole = value!);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (emailController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an email address')),
                  );
                  return;
                }

                final projectService = Provider.of<ProjectService>(context, listen: false);
                try {
                  await projectService.inviteMember(
                    widget.projectId,
                    emailController.text,
                    selectedRole,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invitation sent successfully')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error sending invitation: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Send Invitation'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveMemberConfirmation(String memberId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member'),
        content: const Text('Are you sure you want to remove this member from the project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final projectService = Provider.of<ProjectService>(context, listen: false);
              try {
                await projectService.removeMember(widget.projectId, memberId);
                Navigator.pop(context);
                await _loadProjectData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Member removed successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error removing member: ${e.toString()}')),
                );
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showArchiveProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Project'),
        content: const Text('Are you sure you want to archive this project? You can unarchive it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final projectService = Provider.of<ProjectService>(context, listen: false);
              try {
                await projectService.updateProjectStatus(widget.projectId, 'archived');
                Navigator.pop(context);
                await _loadProjectData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Project archived successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error archiving project: ${e.toString()}')),
                );
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }

  void _showDeleteProjectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final projectService = Provider.of<ProjectService>(context, listen: false);
              final authService = Provider.of<AuthService>(context, listen: false);
              try {
                await projectService.deleteProject(widget.projectId, authService.currentUser!.id);
                Navigator.pop(context);
                Navigator.pop(context);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting project: ${e.toString()}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> task) {
    final titleController = TextEditingController(text: task['title']);
    final descriptionController = TextEditingController(text: task['description'] ?? '');
    final assignedToController = TextEditingController(text: task['assigned_to'] ?? '');
    DateTime? dueDate = task['due_date'] != null ? DateTime.parse(task['due_date']) : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Task Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: assignedToController,
                  decoration: const InputDecoration(
                    labelText: 'Assigned To (User ID)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Due Date'),
                  subtitle: Text(dueDate != null ? _formatDate(dueDate!.toIso8601String()) : 'No due date'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: dueDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (selectedDate != null) {
                      setState(() => dueDate = selectedDate);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final projectService = Provider.of<ProjectService>(context, listen: false);
                try {
                  await projectService.updateTask(
                    taskId: task['id'],
                    title: titleController.text,
                    description: descriptionController.text,
                    assignedTo: assignedToController.text,
                    dueDate: dueDate,
                  );
                  Navigator.pop(context);
                  await _loadProjectData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task updated successfully')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating task: ${e.toString()}')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTaskConfirmation(String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final projectService = Provider.of<ProjectService>(context, listen: false);
              try {
                await projectService.deleteTask(taskId);
                Navigator.pop(context);
                await _loadProjectData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task deleted successfully')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting task: ${e.toString()}')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'done':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'todo':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'done':
        return Icons.check_circle;
      case 'in_progress':
        return Icons.hourglass_empty;
      case 'todo':
        return Icons.circle_outlined;
      default:
        return Icons.circle_outlined;
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
