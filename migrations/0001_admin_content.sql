PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS courses (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  language TEXT NOT NULL DEFAULT 'en',
  level TEXT NOT NULL DEFAULT 'A1',
  tags TEXT NOT NULL DEFAULT '[]',
  thumbnail_url TEXT,
  total_lessons INTEGER NOT NULL DEFAULT 0,
  total_xp INTEGER NOT NULL DEFAULT 0,
  estimated_duration INTEGER NOT NULL DEFAULT 0,
  is_published INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS units (
  id TEXT PRIMARY KEY,
  course_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  order_index INTEGER NOT NULL DEFAULT 0,
  background_color TEXT,
  icon_url TEXT,
  total_lessons INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(course_id) REFERENCES courses(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS lessons (
  id TEXT PRIMARY KEY,
  unit_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  outcome TEXT,
  order_index INTEGER NOT NULL DEFAULT 0,
  lesson_type TEXT NOT NULL DEFAULT 'lesson',
  xp_reward INTEGER NOT NULL DEFAULT 10,
  pass_threshold INTEGER NOT NULL DEFAULT 80,
  total_exercises INTEGER NOT NULL DEFAULT 0,
  estimated_minutes INTEGER NOT NULL DEFAULT 10,
  prerequisites TEXT NOT NULL DEFAULT '[]',
  content TEXT NOT NULL DEFAULT '{"exercises":[]}',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY(unit_id) REFERENCES units(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS vocabulary (
  id TEXT PRIMARY KEY,
  word TEXT NOT NULL UNIQUE COLLATE NOCASE,
  definition TEXT NOT NULL DEFAULT '',
  translation TEXT NOT NULL DEFAULT '{}',
  part_of_speech TEXT NOT NULL DEFAULT 'noun',
  pronunciation TEXT NOT NULL DEFAULT '',
  difficulty_level TEXT NOT NULL DEFAULT 'A1',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_courses_published_level ON courses(is_published, level);
CREATE INDEX IF NOT EXISTS idx_units_course_order ON units(course_id, order_index);
CREATE INDEX IF NOT EXISTS idx_lessons_unit_order ON lessons(unit_id, order_index);
CREATE INDEX IF NOT EXISTS idx_vocab_level_word ON vocabulary(difficulty_level, word);

INSERT OR IGNORE INTO courses(
  id,title,description,language,level,tags,thumbnail_url,total_lessons,total_xp,estimated_duration,is_published,created_at,updated_at
) VALUES(
  'course-b1-starter',
  'English B1 Starter',
  'Khóa học mẫu để kiểm tra luồng học và trang quản trị.',
  'en',
  'B1',
  '["daily","conversation","starter"]',
  NULL,
  2,
  25,
  20,
  1,
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
);

INSERT OR IGNORE INTO units(
  id,course_id,title,description,order_index,background_color,icon_url,total_lessons,created_at,updated_at
) VALUES(
  'unit-b1-daily',
  'course-b1-starter',
  'Daily Conversation',
  'Luyện các tình huống giao tiếp hằng ngày.',
  0,
  '#E8F5E9',
  NULL,
  2,
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
);

INSERT OR IGNORE INTO lessons(
  id,unit_id,title,description,outcome,order_index,lesson_type,xp_reward,pass_threshold,total_exercises,estimated_minutes,prerequisites,content,created_at,updated_at
) VALUES
(
  'lesson-b1-greetings',
  'unit-b1-daily',
  'Greetings and introductions',
  'Luyện chào hỏi và tự giới thiệu.',
  'Bạn có thể chào hỏi và giới thiệu bản thân tự nhiên.',
  0,
  'lesson',
  10,
  80,
  0,
  8,
  '[]',
  '{"exercises":[]}',
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
),
(
  'lesson-b1-small-talk',
  'unit-b1-daily',
  'Everyday small talk',
  'Luyện hội thoại ngắn về cuộc sống hằng ngày.',
  'Bạn có thể duy trì một đoạn small talk ngắn.',
  1,
  'practice',
  15,
  80,
  0,
  12,
  '[]',
  '{"exercises":[]}',
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
);

INSERT OR IGNORE INTO vocabulary(
  id,word,definition,translation,part_of_speech,pronunciation,difficulty_level,created_at,updated_at
) VALUES
(
  'vocab-confident',
  'confident',
  'feeling sure about your own ability',
  '{"vi":"tự tin"}',
  'adjective',
  '/ˈkɒnfɪdənt/',
  'B1',
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
),
(
  'vocab-routine',
  'routine',
  'the usual order in which you do things',
  '{"vi":"thói quen; lịch sinh hoạt"}',
  'noun',
  '/ruːˈtiːn/',
  'B1',
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
),
(
  'vocab-improve',
  'improve',
  'to become better or make something better',
  '{"vi":"cải thiện"}',
  'verb',
  '/ɪmˈpruːv/',
  'B1',
  '2026-09-26T00:00:00.000Z',
  '2026-09-26T00:00:00.000Z'
);
