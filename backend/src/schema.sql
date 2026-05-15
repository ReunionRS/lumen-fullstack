CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  fio TEXT NOT NULL,
  role TEXT NOT NULL,
  avatar_url TEXT,
  two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  two_factor_secret TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  is_archived BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS projects (
  id TEXT PRIMARY KEY,
  client_fio TEXT NOT NULL,
  client_contacts TEXT,
  client_phone TEXT,
  client_email TEXT,
  client_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  construction_address TEXT NOT NULL,
  thumbnail_url TEXT,
  materials TEXT,
  project_type TEXT NOT NULL,
  area_sqm DOUBLE PRECISION NOT NULL DEFAULT 0,
  estimated_cost DOUBLE PRECISION NOT NULL DEFAULT 0,
  contract_amount DOUBLE PRECISION,
  paid_amount DOUBLE PRECISION,
  next_payment_date TEXT,
  last_payment_date TEXT,
  status TEXT NOT NULL,
  start_date TEXT,
  planned_end_date TEXT,
  actual_end_date TEXT,
  camera_url TEXT,
  stages JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS documents (
  id TEXT PRIMARY KEY,
  project_id TEXT REFERENCES projects(id) ON DELETE CASCADE,
  client_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  project_address TEXT,
  name TEXT NOT NULL,
  mime_type TEXT,
  size_bytes BIGINT,
  version INTEGER NOT NULL DEFAULT 1,
  type TEXT,
  storage_path TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  uploaded_by TEXT REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS support_messages (
  id TEXT PRIMARY KEY,
  client_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sender_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message_text TEXT NOT NULL,
  is_read_by_admin BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stage_comment_notifications (
  id TEXT PRIMARY KEY,
  client_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  stage_id TEXT NOT NULL,
  stage_name TEXT NOT NULL,
  comment_text TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stage_comment_notification_hidden (
  notification_id TEXT NOT NULL REFERENCES stage_comment_notifications(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (notification_id, user_id)
);

CREATE TABLE IF NOT EXISTS support_message_notification_hidden (
  message_id TEXT NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS finance_expenses (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  category TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  expense_date DATE NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_tasks (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  scheduled_date DATE NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled',
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  system_type TEXT,
  specialist_name TEXT,
  report_notes TEXT,
  report_photo_url TEXT,
  completed_at TIMESTAMPTZ,
  completed_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_requests (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  task_id TEXT REFERENCES maintenance_tasks(id) ON DELETE SET NULL,
  client_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  system_type TEXT,
  description TEXT,
  preferred_date DATE,
  specialist_name TEXT,
  status TEXT NOT NULL DEFAULT 'new',
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS maintenance_request_notification_hidden (
  request_id TEXT NOT NULL REFERENCES maintenance_requests(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (request_id, user_id)
);

CREATE TABLE IF NOT EXISTS maintenance_notification_hidden (
  task_id TEXT NOT NULL REFERENCES maintenance_tasks(id) ON DELETE CASCADE,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (task_id, user_id)
);

CREATE TABLE IF NOT EXISTS user_push_tokens (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL DEFAULT 'unknown',
  app_version TEXT,
  locale TEXT,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS home_assistant_connections (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  house_id TEXT,
  base_url TEXT NOT NULL,
  access_token TEXT NOT NULL,
  refresh_token TEXT NOT NULL,
  client_id TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'connected',
  last_checked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS journal_entries (
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
  entry_type TEXT NOT NULL,
  description TEXT NOT NULL,
  specialist TEXT,
  entry_date DATE NOT NULL,
  photo_url TEXT,
  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE documents ADD COLUMN IF NOT EXISTS mime_type TEXT;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS size_bytes BIGINT;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL DEFAULT 1;
ALTER TABLE documents ADD COLUMN IF NOT EXISTS client_user_id TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS client_phone TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS thumbnail_url TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS materials TEXT;
ALTER TABLE support_messages ADD COLUMN IF NOT EXISTS is_read_by_admin BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE stage_comment_notifications ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_archived BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS two_factor_enabled BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS two_factor_secret TEXT;
ALTER TABLE finance_expenses ADD COLUMN IF NOT EXISTS created_by TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE finance_expenses ADD COLUMN IF NOT EXISTS note TEXT;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS notes TEXT;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS completed_by TEXT REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS system_type TEXT;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS specialist_name TEXT;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS report_notes TEXT;
ALTER TABLE maintenance_tasks ADD COLUMN IF NOT EXISTS report_photo_url TEXT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS system_type TEXT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS preferred_date DATE;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS specialist_name TEXT;
ALTER TABLE maintenance_requests ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE user_push_tokens ADD COLUMN IF NOT EXISTS app_version TEXT;
ALTER TABLE user_push_tokens ADD COLUMN IF NOT EXISTS locale TEXT;
ALTER TABLE home_assistant_connections ADD COLUMN IF NOT EXISTS house_id TEXT;
ALTER TABLE home_assistant_connections ADD COLUMN IF NOT EXISTS client_id TEXT;
ALTER TABLE home_assistant_connections ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'connected';
ALTER TABLE home_assistant_connections ADD COLUMN IF NOT EXISTS last_checked_at TIMESTAMPTZ;
ALTER TABLE home_assistant_connections ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_projects_client_user_id ON projects(client_user_id);
CREATE INDEX IF NOT EXISTS idx_documents_project_id ON documents(project_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_client_user_id ON support_messages(client_user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at);
CREATE INDEX IF NOT EXISTS idx_stage_comment_notifications_client_user_id ON stage_comment_notifications(client_user_id);
CREATE INDEX IF NOT EXISTS idx_stage_comment_notifications_project_id ON stage_comment_notifications(project_id);
CREATE INDEX IF NOT EXISTS idx_stage_comment_notifications_created_at ON stage_comment_notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_stage_comment_notification_hidden_user_id ON stage_comment_notification_hidden(user_id);
CREATE INDEX IF NOT EXISTS idx_support_message_notification_hidden_user_id ON support_message_notification_hidden(user_id);
CREATE INDEX IF NOT EXISTS idx_finance_expenses_project_id ON finance_expenses(project_id);
CREATE INDEX IF NOT EXISTS idx_finance_expenses_expense_date ON finance_expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_tasks_project_id ON maintenance_tasks(project_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_tasks_scheduled_date ON maintenance_tasks(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_maintenance_notification_hidden_user_id ON maintenance_notification_hidden(user_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_project_id ON maintenance_requests(project_id);
CREATE INDEX IF NOT EXISTS idx_maintenance_requests_status ON maintenance_requests(status);
CREATE INDEX IF NOT EXISTS idx_maintenance_request_notification_hidden_user_id ON maintenance_request_notification_hidden(user_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_project_id ON journal_entries(project_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_entry_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_user_push_tokens_user_id ON user_push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_home_assistant_connections_user_id ON home_assistant_connections(user_id);
