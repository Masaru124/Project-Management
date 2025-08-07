import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/project_service.dart';
import '../../services/auth_service.dart';

class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createProject() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a project name')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final projectService = Provider.of<ProjectService>(
        context,
        listen: false,
      );

      final userId = authService.currentUser?.id;
      if (userId != null) {
        await projectService.createProject(
          name: _nameController.text,
          ownerId: userId,
          description: _descriptionController.text,
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Project created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Wait a moment before navigating back
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.pop();
      } else {
        throw Exception('User not authenticated');
      }
    } on PostgrestException catch (e) {
      // Handle specific database errors
      String errorMessage = 'Error creating project';
      
      if (e.code == '23505') {
        errorMessage = 'A project with this name already exists';
      } else if (e.code == '23503') {
        errorMessage = 'Invalid user reference';
      } else if (e.message.contains('members')) {
        errorMessage = 'Error with project members configuration';
      } else {
        errorMessage = 'Database error: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating project: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Project'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Project Name *',
                  hintText: 'Enter a unique project name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Brief description of your project',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _createProject,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Create Project',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(
                  child: Text('Creating your project...'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
