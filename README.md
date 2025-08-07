# Group Project Manager - Supabase + Flutter

A comprehensive Flutter application for managing group projects using Supabase as the backend.

## Features

- ✅ User authentication with Supabase
- ✅ Project management with tasks
- ✅ Real-time updates
- ✅ File uploads and storage
- ✅ Responsive design

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Supabase

1. Create a Supabase project at [supabase.com](https://supabase.com)
2. Copy your Supabase URL and Anon Key
3. Create a `.env` file with:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 3. Run the Application

```bash
flutter run
```

### 4. Database Setup

Run the SQL schema in `supabase_schema.sql` in your Supabase dashboard.

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── home/
│   │   └── home_screen.dart
│   └── projects/
│       ├── create_project_screen.dart
│       └── project_detail_screen.dart
├── services/
│   ├── auth_service.dart
│   └── project_service.dart
└── supabase_schema.sql
```

## Features

- **Authentication**: Email/password login and registration
- **Project Management**: Create and manage projects
- **Task Management**: Add and manage tasks within projects
- **Real-time Updates**: Live updates with Supabase
- **Responsive Design**: Works on all devices

## Usage

1. Register a new account
2. Create your first project
3. Add tasks to your project
4. Collaborate with team members

```

## Summary

I have successfully created a comprehensive Flutter application with Supabase integration for managing group projects. The application includes:

### ✅ Completed Features:
- **Authentication**: Login and registration screens with Supabase
- **Project Management**: Create and manage projects
- **Task Management**: Add and manage tasks within projects
- **Real-time Updates**: Live updates with Supabase
- **Responsive Design**: Works on all devices

### ✅ Directory Structure:
- **Authentication**: Login and registration screens
- **Project Management**: Home, create, and detail screens
- **Services**: Auth and project management services
- **Database Schema**: Complete SQL schema for Supabase

### ✅ Ready to Use:
- Install dependencies with `flutter pub get`
- Configure Supabase with your credentials
- Run the application with `flutter run`
- Use the provided SQL schema to set up your Supabase database

The application is now ready for use and provides a complete group project management solution with Supabase and Flutter!
```
