-- ========================================
-- WIT Service Report — Database Setup
-- รันใน Supabase: SQL Editor → New query → วางทั้งหมด → Run
-- ========================================

-- 1. สร้างตาราง reports
CREATE TABLE IF NOT EXISTS reports (
  id          TEXT PRIMARY KEY,
  report_no   TEXT,
  status      TEXT DEFAULT 'draft',
  data        JSONB NOT NULL DEFAULT '{}',
  created_by  TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- 2. เปิด Row Level Security (ป้องกันคนนอก)
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 3. ล้าง policy เดิม (ถ้ามี)
DROP POLICY IF EXISTS "read_all"    ON reports;
DROP POLICY IF EXISTS "insert_all"  ON reports;
DROP POLICY IF EXISTS "update_all"  ON reports;
DROP POLICY IF EXISTS "delete_all"  ON reports;

-- 4. สร้าง policy: คนที่ login แล้วทำได้ทุกอย่าง
CREATE POLICY "read_all"   ON reports FOR SELECT TO authenticated USING (true);
CREATE POLICY "insert_all" ON reports FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "update_all" ON reports FOR UPDATE TO authenticated USING (true);
CREATE POLICY "delete_all" ON reports FOR DELETE TO authenticated USING (true);

-- 5. Index เรียงลำดับ
CREATE INDEX IF NOT EXISTS reports_updated_at_idx ON reports (updated_at DESC);
CREATE INDEX IF NOT EXISTS reports_report_no_idx   ON reports (report_no);

-- 6. สร้างตาราง settings (สำหรับ counter เลข report กันซ้ำ)
CREATE TABLE IF NOT EXISTS settings (
  key        TEXT PRIMARY KEY,
  value      INTEGER,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "settings_read"   ON settings;
DROP POLICY IF EXISTS "settings_write"  ON settings;
CREATE POLICY "settings_read"  ON settings FOR SELECT TO authenticated USING (true);
CREATE POLICY "settings_write" ON settings FOR INSERT TO authenticated WITH CHECK (true);
DROP POLICY IF EXISTS "settings_update" ON settings;
CREATE POLICY "settings_update" ON settings FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- ✅ เสร็จแล้ว! ไปสร้าง user ต่อ:
--    Authentication → Users → Add user → ใส่ email + password → Create
