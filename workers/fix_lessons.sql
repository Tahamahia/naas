PRAGMA foreign_keys=off;
CREATE TABLE lessons_new (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  section_id TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  type TEXT NOT NULL DEFAULT 'video' CHECK(type IN ('video', 'pdf', 'quiz', 'live', 'article')),
  video_url TEXT,
  video_duration INTEGER,
  video_status TEXT DEFAULT 'pending' CHECK(video_status IN ('pending', 'uploading', 'processing', 'ready', 'failed')),
  pdf_url TEXT,
  pdf_name TEXT,
  article_content TEXT,
  quiz_id TEXT,
  is_free INTEGER NOT NULL DEFAULT 0,
  sort_order INTEGER NOT NULL DEFAULT 0,
  drip_delay INTEGER,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
);
INSERT INTO lessons_new SELECT * FROM lessons;
DROP TABLE lessons;
ALTER TABLE lessons_new RENAME TO lessons;
PRAGMA foreign_keys=on;
