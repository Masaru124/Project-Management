import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/project_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final projectService = Provider.of<ProjectService>(context, listen: false);

    if (authService.currentUser != null) {
      await projectService.loadProjects(authService.currentUser!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final projectService = Provider.of<ProjectService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
            },
          ),
        ],
      ),
      body: Consumer<ProjectService>(
        builder: (context, projectService, child) {
          if (projectService.projects.isEmpty) {
            return const Center(
              child: Text('No projects yet. Create your first project!'),
            );
          }

          return ListView.builder(
            itemCount: projectService.projects.length,
            itemBuilder: (context, index) {
              final project = projectService.projects[index];
              return ListTile(
                title: Text(project['name']),
                subtitle: Text('Owner: ${project['owner']}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  context.go('/project/${project['id']}');
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/create-project');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
