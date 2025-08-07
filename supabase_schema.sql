-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create projects table
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  owner UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  members UUID[] NOT NULL DEFAULT '{}',
  roles JSONB DEFAULT '{}',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create tasks table
CREATE TABLE IF NOT EXISTS tasks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  assigned_to UUID REFERENCES auth.users(id),
  status TEXT DEFAULT 'To-do' CHECK (status IN ('To-do', 'In Progress', 'Done')),
  due_date DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- Create policies for projects
CREATE POLICY "Users can view projects they are members of" ON projects
  FOR SELECT USING (auth.uid() = ANY (members));

CREATE POLICY "Users can create projects" ON projects
  FOR INSERT WITH CHECK (auth.uid() = owner);

CREATE POLICY "Users can update projects they own" ON projects
  FOR UPDATE USING (auth.uid() = owner);

CREATE POLICY "Users can delete projects they own" ON projects
  FOR DELETE USING (auth.uid() = owner);

-- Create policies for tasks
CREATE POLICY "Users can view tasks in their projects" ON tasks
  FOR SELECT USING (
    project_id IN (
      SELECT id FROM projects WHERE auth.uid() = ANY (members)
    )
  );

CREATE POLICY "Users can create tasks in their projects" ON tasks
  FOR INSERT WITH CHECK (
    project_id IN (
      SELECT id FROM projects WHERE auth.uid() = ANY (members)
    )
  );

CREATE POLICY "Users can update tasks in their projects" ON tasks
  FOR UPDATE USING (
    project_id IN (
      SELECT id FROM projects WHERE auth.uid() = ANY (members)
    )
  );

CREATE POLICY "Users can delete tasks in their projects" ON tasks
  FOR DELETE USING (
    project_id IN (
      SELECT id FROM projects WHERE auth.uid() = ANY (members)
    )
  );
