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

-- 5.1 อัปเดต updated_at ทุกครั้งที่มีการแก้ report จากทุก client/API
CREATE OR REPLACE FUNCTION set_reports_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS reports_set_updated_at ON reports;
CREATE TRIGGER reports_set_updated_at
BEFORE UPDATE ON reports
FOR EACH ROW
EXECUTE FUNCTION set_reports_updated_at();

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

-- 7. สร้าง Supabase Storage bucket สำหรับรูป full/thumbnail และ PDF ฉบับ final
--    ถ้า bucket มีอยู่แล้ว คำสั่งนี้จะไม่สร้างซ้ำ
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'wit-service-files',
  'wit-service-files',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 8. Storage policy: ผู้ใช้ที่ login แล้วอ่าน/เขียน/ลบไฟล์ report ได้ทั้งหมด
--    โครงสร้างไฟล์: reports/{report_id}/photos/photo-01.jpg, photo-01-thumb.jpg, pdf/{report_no}.pdf
DROP POLICY IF EXISTS "wit_files_read"   ON storage.objects;
DROP POLICY IF EXISTS "wit_files_insert" ON storage.objects;
DROP POLICY IF EXISTS "wit_files_update" ON storage.objects;
DROP POLICY IF EXISTS "wit_files_delete" ON storage.objects;
CREATE POLICY "wit_files_read"   ON storage.objects FOR SELECT TO authenticated USING (bucket_id = 'wit-service-files');
CREATE POLICY "wit_files_insert" ON storage.objects FOR INSERT TO authenticated WITH CHECK (bucket_id = 'wit-service-files');
CREATE POLICY "wit_files_update" ON storage.objects FOR UPDATE TO authenticated USING (bucket_id = 'wit-service-files') WITH CHECK (bucket_id = 'wit-service-files');
CREATE POLICY "wit_files_delete" ON storage.objects FOR DELETE TO authenticated USING (bucket_id = 'wit-service-files');

-- ✅ เสร็จแล้ว! ไปสร้าง user ต่อ:
--    Authentication → Users → Add user → ใส่ email + password → Create

-- 9. Atomic increment function สำหรับ report counter (กันเลขซ้ำเมื่อ submit พร้อมกัน)
--    รันใน Supabase SQL Editor → New query → วาง → Run
CREATE OR REPLACE FUNCTION atomic_increment(k TEXT, OUT new_val INTEGER) AS $$
BEGIN
  INSERT INTO settings (key, value) VALUES (k, 1)
    ON CONFLICT (key) DO UPDATE SET value = settings.value + 1
    RETURNING value INTO new_val;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9.1 Force delete fallback สำหรับกรณี client delete ติด RLS/policy แต่ผู้ใช้ login แล้ว
CREATE OR REPLACE FUNCTION delete_report_force(report_id TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM public.reports WHERE id = report_id;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count > 0 OR NOT EXISTS (
    SELECT 1 FROM public.reports WHERE id = report_id
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

GRANT EXECUTE ON FUNCTION delete_report_force(TEXT) TO authenticated;

-- 10. เปิด Realtime ให้ทุกเครื่องเห็นรายการ report เปลี่ยนพร้อมกัน
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'reports'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE reports;
  END IF;
END $$;
