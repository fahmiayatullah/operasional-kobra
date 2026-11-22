-- =========================================================================
-- DATABASE SCHEMA & SEED DATA SUPABASE (POSTGRESQL)
-- SISTEM OPERASIONAL PERCETAKAN KOBRA HITAM
-- =========================================================================
-- Cara Menjalankan:
-- 1. Buka dashboard Supabase Anda (https://supabase.com).
-- 2. Pilih project Anda > Menu "SQL Editor" di bilah kiri.
-- 3. Tempel seluruh isi file ini, lalu klik tombol "RUN" (Jalankan).
-- =========================================================================

-- 1. TABEL PRODUCTS (Master Barang Inventaris)
CREATE TABLE IF NOT EXISTS public.products (
  id TEXT PRIMARY KEY,
  no INTEGER,
  nama TEXT NOT NULL,
  tanggal_pembelian TEXT DEFAULT '',
  deskripsi TEXT DEFAULT '',
  stok NUMERIC NOT NULL DEFAULT 0,
  isi_kemasan TEXT DEFAULT '',
  harga_beli NUMERIC DEFAULT 0,
  harga_beli_satuan NUMERIC DEFAULT 0,
  harga_jual NUMERIC DEFAULT 0,
  custom_price BOOLEAN DEFAULT FALSE,
  kategori_id TEXT DEFAULT 'cat_atk',
  supplier TEXT DEFAULT '',
  aktif BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. TABEL SERVICES (Layanan Jasa Percetakan & Resep Bahan)
CREATE TABLE IF NOT EXISTS public.services (
  id TEXT PRIMARY KEY,
  nama TEXT NOT NULL,
  satuan TEXT DEFAULT 'unit',
  listrik NUMERIC DEFAULT 0,
  jasa NUMERIC DEFAULT 0,
  markup_pct NUMERIC DEFAULT 50,
  margin_pct NUMERIC DEFAULT 35,
  harga_jual NUMERIC DEFAULT 0,
  custom_price BOOLEAN DEFAULT FALSE,
  aktif BOOLEAN DEFAULT TRUE,
  resep JSONB DEFAULT '[]'::jsonb,
  bahan_items JSONB DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. TABEL BELANJA (Pengadaan Bahan Baku)
CREATE TABLE IF NOT EXISTS public.belanja (
  id TEXT PRIMARY KEY,
  nama TEXT NOT NULL,
  qty NUMERIC DEFAULT 1,
  nominal NUMERIC DEFAULT 0,
  biaya_satuan NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. TABEL SALES (Header Transaksi Penjualan / Nota)
CREATE TABLE IF NOT EXISTS public.sales (
  id TEXT PRIMARY KEY,
  invoice_no TEXT UNIQUE NOT NULL,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  customer_name TEXT DEFAULT 'Pelanggan Umum',
  notes TEXT DEFAULT '',
  subtotal NUMERIC DEFAULT 0,
  discount_amount NUMERIC DEFAULT 0,
  total NUMERIC NOT NULL DEFAULT 0,
  total_hpp NUMERIC DEFAULT 0,
  payment_method TEXT DEFAULT 'Tunai',
  paid_amount NUMERIC DEFAULT 0,
  change_amount NUMERIC DEFAULT 0,
  items JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. TABEL SALES_ITEMS (Rincian Item Penjualan untuk Laporan)
CREATE TABLE IF NOT EXISTS public.sales_items (
  id BIGSERIAL PRIMARY KEY,
  sale_id TEXT REFERENCES public.sales(id) ON DELETE CASCADE,
  invoice_no TEXT NOT NULL,
  ref_id TEXT,
  nama TEXT NOT NULL,
  type TEXT NOT NULL,
  qty NUMERIC NOT NULL DEFAULT 1,
  harga NUMERIC NOT NULL DEFAULT 0,
  hpp_unit NUMERIC NOT NULL DEFAULT 0,
  subtotal NUMERIC NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. TABEL JOURNAL (Jurnal Keuangan & Arus Kas Masuk/Keluar)
CREATE TABLE IF NOT EXISTS public.journal (
  id TEXT PRIMARY KEY,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  type TEXT NOT NULL,
  ref_no TEXT DEFAULT '-',
  description TEXT NOT NULL,
  direction TEXT NOT NULL,
  amount NUMERIC NOT NULL DEFAULT 0,
  hpp NUMERIC DEFAULT 0,
  payment_method TEXT DEFAULT 'Tunai',
  meta JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. TABEL STOCK_MOVEMENTS (Mutasi Stok Masuk & Keluar)
CREATE TABLE IF NOT EXISTS public.stock_movements (
  id TEXT PRIMARY KEY,
  date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  type TEXT NOT NULL,
  source TEXT NOT NULL,
  product_id TEXT,
  product_name TEXT,
  qty NUMERIC NOT NULL,
  stock_before NUMERIC,
  stock_after NUMERIC,
  unit_cost NUMERIC DEFAULT 0,
  total_cost NUMERIC DEFAULT 0,
  ref_no TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. TABEL SETTINGS (Pengaturan Profil Usaha & Format Nota)
CREATE TABLE IF NOT EXISTS public.settings (
  key TEXT PRIMARY KEY,
  value JSONB NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- AKTIFKAN ROW LEVEL SECURITY (RLS) & IZINKAN AKSES ANON
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.belanja ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.journal ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Anon Access Products" ON public.products;
CREATE POLICY "Public Anon Access Products" ON public.products FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Services" ON public.services;
CREATE POLICY "Public Anon Access Services" ON public.services FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Belanja" ON public.belanja;
CREATE POLICY "Public Anon Access Belanja" ON public.belanja FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Sales" ON public.sales;
CREATE POLICY "Public Anon Access Sales" ON public.sales FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Sales Items" ON public.sales_items;
CREATE POLICY "Public Anon Access Sales Items" ON public.sales_items FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Journal" ON public.journal;
CREATE POLICY "Public Anon Access Journal" ON public.journal FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Movements" ON public.stock_movements;
CREATE POLICY "Public Anon Access Movements" ON public.stock_movements FOR ALL TO anon USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Public Anon Access Settings" ON public.settings;
CREATE POLICY "Public Anon Access Settings" ON public.settings FOR ALL TO anon USING (true) WITH CHECK (true);

-- AKTIFKAN REPLIKASI SUPABASE REALTIME (WEBSOCKETS)
ALTER PUBLICATION supabase_realtime ADD TABLE public.sales, public.journal, public.products, public.stock_movements;

-- =========================================================================
-- SEED DATA AWAL: 83 BARANG DARI GOOGLE SPREADSHEET (HARGA DASAR)
-- =========================================================================
INSERT INTO public.products (id, no, nama, tanggal_pembelian, deskripsi, stok, isi_kemasan, harga_beli, harga_beli_satuan, harga_jual, kategori_id, supplier, aktif)
VALUES
  ('prd_001', 1, 'Amplop Kecil', '6/7/2025', 'amplop 110L isi 100 Kecil', 0, '100', 17450, 175, 227, 'cat_atk', '', true),
  ('prd_002', 2, 'Amplop panjang', '6/7/2025', 'amplop 90pps isi100lembar', 0, '100', 18100, 181, 235, 'cat_atk', '', true),
  ('prd_003', 3, 'Batray ABC AAA', '7/21/2025', 'Baterai ABC AAA Hitam isi 12 pcs', 4, '12', 26750, 2229, 2898, 'cat_lain', '', true),
  ('prd_004', 4, 'Bolpoin Pilot Hitam', '6/7/2025', '2box bulpen pilot isi 12x2=24pcs', 8, '24', 36000, 1500, 1950, 'cat_lain', '', true),
  ('prd_005', 5, 'Buku 36 lembar Bo mtk', '6/12/2025', 'Buku Garis Best one Campus 36 lembar isi 10', 5, '20', 60000, 3000, 3900, 'cat_atk', '', true),
  ('prd_006', 6, 'Buku Gambar A4 Okiey', '7/21/2025', 'Buku Gambar A4 Okiey 5 Pcs', 9, '5', 16660, 3332, 4332, 'cat_kertas', '', true),
  ('prd_007', 7, 'Buku Gambar A4 Sidu', '7/21/2025', 'Buku Gambar A4 Sidu  10 Pcs', 1, '10', 29000, 2900, 3770, 'cat_kertas', '', true),
  ('prd_008', 8, 'Buku garis 38 Lembar Bo', '6/12/2025', 'buku best one 38 lembar isi 10', 0, '10', 22000, 2200, 2860, 'cat_atk', '', true),
  ('prd_009', 9, 'Buku Garis 38 lembar oh', '6/12/2025', 'buku one heart 38 lembar isi 1o', 0, '10', 21000, 2100, 2730, 'cat_atk', '', true),
  ('prd_010', 10, 'Buku Garis Sidu 38', '7/21/2025', 'Buku Garis Sidu 38 lembar 40Pcs @2750', 24, '40', 110000, 2750, 3575, 'cat_atk', '', true),
  ('prd_011', 11, 'Buku Garis Sidu 58', '7/21/2025', 'Buku Garis Sidu 58 Halaman pack @42.000 @4.200', 0, '20', 84000, 4200, 5460, 'cat_atk', '', true),
  ('prd_012', 12, 'Buku Kuarto 100ppl', '6/11/2025', '2 box Buku Kuarto 100PPL @19.250 isi 5', 0, '10', 38500, 3850, 5005, 'cat_atk', '', true),
  ('prd_013', 13, 'Buku Kuarto 200 Glatik', '6/11/2025', '2 Box Buku Kuarto 200Glatik @39.750 isi 3', 2, '6', 79500, 13250, 17225, 'cat_atk', '', true),
  ('prd_014', 14, 'Buku Kuarto 50 Vision', '6/11/2025', '1 pack Buku Kuarto 50visior@5.000 isi10', 5, '10', 50000, 5000, 6500, 'cat_atk', '', true),
  ('prd_015', 15, 'Buku Notes A5 Paperlin', '7/8/2025', 'Buku Notes A5 Paperline 148x210mm', 7, '10', 19500, 1950, 2535, 'cat_atk', '', true),
  ('prd_016', 16, 'Bulpoin Hitam Poco', '6/7/2025', 'bulpen picolo Hitam Isi 12pcs', 7, '12', 14500, 1208, 1571, 'cat_lain', '', true),
  ('prd_017', 17, 'Bulpoin Hitam Standart', '6/7/2025', 'bulpen standar Hitam 1 Box isi 12pcs', 2, '12', 17500, 1458, 1896, 'cat_lain', '', true),
  ('prd_018', 18, 'Bulpoin Hitech joico Hitam', '6/7/2025', '1box bulpent hitech joyco Hitam isi 12pcs', 0, '12', 25944, 2162, 2811, 'cat_lain', '', true),
  ('prd_019', 19, 'Bulpoin Hitech Seco Hitam', '6/7/2025', '1box bulpent hitech seco Hitam  isi 12pcs', 6, '12', 19000, 1583, 2058, 'cat_lain', '', true),
  ('prd_020', 20, 'Clip No1', '6/7/2025', '3 clip No1 Rp 1.800', 1, '3', 5400, 1800, 2340, 'cat_lain', '', true),
  ('prd_021', 21, 'Cutter Kecil', '6/7/2025', 'cutter kecil 1 renteng isi 12', 8, '12', 8000, 667, 867, 'cat_atk', '', true),
  ('prd_022', 22, 'Dobel Tape Uk 1" Nashua', '7/8/2025', 'Dobel tape 1" Nashua Top 1', 2, '3', 11700, 3900, 5070, 'cat_lain', '', true),
  ('prd_023', 23, 'Gunting Benefit', '6/7/2025', '1 renteng Gunting Benefit Sc-204 Isi 12', 2, '12', 31000, 2583, 3358, 'cat_atk', '', true),
  ('prd_024', 24, 'isi cuter besar', '6/12/2025', '1 slop isi 12 packs', 9, '12', 49632, 4136, 5377, 'cat_lain', '', true),
  ('prd_025', 25, 'isi cuter kecil', '6/12/2025', '1 slop isi 12 packs', 9, '12', 31584, 2632, 3422, 'cat_lain', '', true),
  ('prd_026', 26, 'Isi Steples Uk10 pack', '6/7/2025', 'isi etona isi Staples no10 Isi 20pcs', 9, '20', 28000, 1400, 1820, 'cat_jilid', '', true),
  ('prd_027', 27, 'Isolasi Bening 2"', '6/11/2025', '1Slop Isolasi Bening Isi 6 @4.830', 2, '6', 29000, 4833, 6283, 'cat_lain', '', true),
  ('prd_028', 28, 'isolasi kecil', '6/12/2025', 'Isolasi Nachi uk 1/2 inc 1 rill isi 12', 3, '12', 10000, 833, 1083, 'cat_lain', '', true),
  ('prd_029', 29, 'Kalkulator', '6/7/2025', '1 kalkulator 1unit', 1, '1', 60000, 60000, 78000, 'cat_lain', '', true),
  ('prd_030', 30, 'kertas A4 75g rim', '6/11/2025', '1box A4 Paper One 75g @36.000', 0, '5', 180000, 36000, 46800, 'cat_kertas', '', true),
  ('prd_031', 31, 'Kertas A4 80g rim', '6/11/2025', '1box A4 Paper One 80g @44.000', 0, '5', 220000, 44000, 57200, 'cat_kertas', '', true),
  ('prd_032', 32, 'Kertas A5 80g', '7/8/2025', 'Kertas A5 80g Paper one', 1, '500', 23500, 47, 61, 'cat_kertas', '', true),
  ('prd_033', 33, 'Kertas Binder A5 Big Bos', '7/8/2025', 'Kertas isi binder A5 50lembar Big Boss Campus', 2, '3', 9600, 3200, 4160, 'cat_kertas', '', true),
  ('prd_034', 34, 'Kertas Binder B5 Big Bos', '7/8/2025', 'Kertas isi binder B5 50lembar  Big Boss Campus', 2, '3', 14025, 4675, 6078, 'cat_kertas', '', true),
  ('prd_035', 35, 'Kertas Buffallow F4 Orange', '7/17/2025', 'Kertas Bufallow orange F4 Phiton', 56, '100', 26500, 265, 345, 'cat_kertas', '', true),
  ('prd_036', 36, 'Kertas Buffalo Hijau Muda', '7/17/2025', 'Kertas Bufallow hijau Muda F4 Phiton', 40, '100', 26500, 265, 345, 'cat_kertas', '', true),
  ('prd_037', 37, 'Kertas Buffalow F4 Hijau', '7/8/2025', 'Kertas Bufallow hijau F4 Oci', 89, '100', 32000, 320, 416, 'cat_kertas', '', true),
  ('prd_038', 38, 'Kertas Buffalow f4 Merah', '6/12/2025', 'isi 100 warna merah', 72, '100', 32000, 320, 416, 'cat_kertas', '', true),
  ('prd_039', 39, 'Kertas Buffalow Putih', '8/9/2025', '1 Box isi 100', 35, '100', 20000, 200, 260, 'cat_kertas', '', true),
  ('prd_040', 40, 'Kertas F4 Rim', '6/7/2025', 'kertas F4 1rim', 0, '500', 42500, 85, 111, 'cat_kertas', '', true),
  ('prd_041', 41, 'Kertas Folio Garis', '7/21/2025', 'Keras Folio 200', 38, '200', 32000, 160, 208, 'cat_kertas', '', true),
  ('prd_042', 42, 'Kertas Foto A4 210g', '7/8/2025', 'Kertas Foto A4 210g 210x297mm type GPP-9110A', 109, '60', 33000, 550, 715, 'cat_kertas', '', true),
  ('prd_043', 43, 'kertas legong', '8/13/2025', 'kertas legong A4', 95, '100', 40000, 400, 520, 'cat_kertas', '', true),
  ('prd_044', 44, 'Label Harga Kecil', '6/18/2025', 'label stiker oci isi 10 lembar', 0, '10', 5000, 500, 650, 'cat_kertas', '', true),
  ('prd_045', 45, 'Lakban 1,5 Nachi', '7/8/2025', 'Lakban 1,5" Nachi 12meter', 0, '3', 25875, 8625, 11213, 'cat_jilid', '', true),
  ('prd_046', 46, 'Lakban 2" Nashua', '7/8/2025', 'Lakban 2" Nashua 10m', 0, '3', 30000, 10000, 13000, 'cat_jilid', '', true),
  ('prd_047', 47, 'Lakban Hitam 1,5" Pajero', '6/11/2025', 'Lakban 1,,5" 3 roll @7.500', 3, '3', 27000, 9000, 11700, 'cat_jilid', '', true),
  ('prd_048', 48, 'Lakban hitam 2" pajero', '6/11/2025', 'Lakaban Pajero 2" 3roll @10.000', 3, '3', 36000, 12000, 15600, 'cat_jilid', '', true),
  ('prd_049', 49, 'Lem g', '6/11/2025', 'Lem g Saset Kecil 50pcs', 22, '50', 160000, 3200, 4160, 'cat_atk', '', true),
  ('prd_050', 50, 'lem Seico Cair 25ml', '6/11/2025', '1 Box Lem Seico Water Glue 25Ml 24Pcs @1.250', 10, '24', 40000, 1667, 2167, 'cat_atk', '', true),
  ('prd_051', 51, 'Map Coklat', '6/23/2025', 'Map Coklat Lamaran', 10, '10', 7500, 750, 975, 'cat_atk', '', true),
  ('prd_052', 52, 'Map Jaring', '6/7/2025', '3 map jaring', 3, '3', 27000, 9000, 11700, 'cat_jilid', '', true),
  ('prd_053', 53, 'Map kertas', '6/7/2025', '2 map kertas Mr Broo isi 50', 70, '50', 38000, 760, 988, 'cat_kertas', '', true),
  ('prd_054', 54, 'Materai 10rb', '6/23/2025', 'Materai Rp 10.000', 0, '10', 100000, 10000, 13000, 'cat_lain', '', true),
  ('prd_055', 55, 'Mika Jilid', '7/21/2025', 'Mika Asahi Jilid 100 Lembar', 0, '100', 40000, 400, 520, 'cat_jilid', '', true),
  ('prd_056', 56, 'Mika Laminating  KTP', '6/28/2025', 'Laminating Pouch Filem 68.5mm x 97mm', 27, '38', 19000, 500, 650, 'cat_jilid', '', true),
  ('prd_057', 57, 'Mika Laminating F4', '6/28/2025', 'Laminating Film New Toho 225mm x 340mm', 17, '100', 105000, 1100, 1430, 'cat_kertas', '', true),
  ('prd_058', 58, 'Nota A6 Kiky', '7/8/2025', 'Nota A6 3ply KIKY 25lembar', 4, '10', 34000, 3400, 4420, 'cat_atk', '', true),
  ('prd_059', 59, 'Penggaris 15cm', '6/7/2025', 'penggaris 15cm isi 24', 20, '24', 33000, 1375, 1788, 'cat_lain', '', true),
  ('prd_060', 60, 'Penggaris 30cm', '6/7/2025', 'penggaris 30cm isi 12pcs', 10, '12', 23000, 1917, 2492, 'cat_lain', '', true),
  ('prd_061', 61, 'Penghapus', '6/7/2025', 'penghapus 1box isi 40', 21, '40', 23876, 597, 776, 'cat_lain', '', true),
  ('prd_062', 62, 'pensil 2b', '6/7/2025', '1box pensil artline  2b isi 12pcs', 15, '12', 24000, 2000, 2600, 'cat_atk', '', true),
  ('prd_063', 63, 'Plastik', '6/7/2025', 'plastik fotocopy Isi 950Pcs', 200, '950', 60000, 63, 82, 'cat_kertas', '', true),
  ('prd_064', 64, 'Plong / Punch Joyko', '7/8/2025', 'plong punch Joyko no 40 XL 2 Holes/lubang', 2, '3', 88500, 29500, 38350, 'cat_lain', '', true),
  ('prd_065', 65, 'Rautan', '6/11/2025', '2bos Roter/Rautan Greebel 24pcs @37.000/box (1.542)', 39, '24', 74000, 3083, 4008, 'cat_lain', '', true),
  ('prd_066', 66, 'Spidol Hitam', '6/7/2025', 'sepack spidol  BK Isi 12pcs', 2, '12', 77000, 6417, 8342, 'cat_atk', '', true),
  ('prd_067', 67, 'Spidol Snowman', '9/2/2025', '', 5, '12', 78000, 6500, 8450, 'cat_atk', '', true),
  ('prd_068', 68, 'stabilo', '8/13/2025', 'stabilo warna', 9, '12', 55500, 4625, 6013, 'cat_lain', '', true),
  ('prd_069', 69, 'Steples Kenko HD-10', '6/11/2025', '1box Steples kenko HD-10 12Pcs@7.283,33', 4, '12', 87400, 7283, 9468, 'cat_jilid', '', true),
  ('prd_070', 70, 'Stipo roll kertas', '8/13/2025', 'stipo warna  grebel', 10, '12', 45000, 3750, 4875, 'cat_kertas', '', true),
  ('prd_071', 71, 'Stipo Sico 10 ml', '6/11/2025', '1 Box Stipo Sico 12 Pcs 10Ml @2.750', 7, '12', 33000, 2750, 3575, 'cat_lain', '', true),
  ('prd_072', 72, 'Surat Jalan', '7/8/2025', 'Surat Jalan A5 2play Best Quality', 10, '10', 60000, 6000, 7800, 'cat_lain', '', true),
  ('prd_073', 73, 'Tissu multi hijau', '6/12/2025', '160 site 2play 2 pcs', 0, '2', 9000, 4500, 5850, 'cat_lain', '', true),
  ('prd_074', 74, 'Dobel Tape Uk 1" Nashua', '5/1/2026', 'dobel tip nashua', 0, '3', 10500, 3500, 4550, 'cat_lain', '', true),
  ('prd_075', 75, 'mika jilid pop', '5/1/2026', 'mika jilid pop', 95, '100', 28000, 280, 364, 'cat_jilid', '', true),
  ('prd_076', 76, 'kertas a4', '5/1/2026', 'kertas a4 sinarline rim', 3, '10', 320000, 32000, 41600, 'cat_kertas', '', true),
  ('prd_077', 77, 'Kertas F4 Rim', '5/1/2026', 'kertas f4 sinarline 2 rim', 2, '2', 79000, 39500, 51350, 'cat_kertas', '', true),
  ('prd_078', 78, 'stopmap', '5/1/2026', 'stopmap hijau okey', 12, '12', 10000, 833, 1083, 'cat_atk', '', true),
  ('prd_079', 79, 'stop map putih', '5/1/2026', 'stop map putih kiky', 12, '12', 11000, 917, 1192, 'cat_atk', '', true),
  ('prd_080', 80, 'folio garis glatik', '5/1/2026', 'folio garis glatik', 200, '200', 32500, 163, 211, 'cat_kertas', '', true),
  ('prd_081', 81, 'bulpoint faster', '7/1/2026', 'bulpoin faster hitam f3', 4, '12', 21000, 1750, 2275, 'cat_lain', '', true),
  ('prd_082', 82, 'baterai abc besar', '2/4/2026', 'baterai abc besar', 4, '6', 36000, 6000, 7800, 'cat_lain', '', true),
  ('prd_083', 83, 'peluit', '2/4/2026', 'peluit parkir', 10, '12', 27500, 2292, 2979, 'cat_lain', '', true)
ON CONFLICT (id) DO UPDATE SET
  nama = EXCLUDED.nama,
  stok = EXCLUDED.stok,
  harga_beli = EXCLUDED.harga_beli,
  harga_beli_satuan = EXCLUDED.harga_beli_satuan,
  harga_jual = EXCLUDED.harga_jual,
  updated_at = NOW();

-- =========================================================================
-- SEED DATA AWAL: 6 LAYANAN JASA PERCETAKAN LENGKAP DENGAN RESEP & HPP
-- =========================================================================
INSERT INTO public.services (id, nama, satuan, listrik, jasa, markup_pct, margin_pct, harga_jual, resep, bahan_items)
VALUES
  ('svc_fotokopi', 'Foto Copy Dokumen', 'lembar', 2, 163, 50, 35, 300, 
   '[{"id":"r1","label":"Kertas HVS","productId":"prd_042","qtyPerUnit":1}]'::jsonb, 
   '[{"id":"b1","nama":"Kertas HVS F4","biaya":135}]'::jsonb),
  ('svc_print_bw', 'Print Hitam Putih (B/W)', 'lembar', 21, 189, 50, 35, 500, 
   '[{"id":"r2","label":"Kertas HVS","productId":"prd_042","qtyPerUnit":1},{"id":"r3","label":"Tinta Hitam","productId":"prd_077","qtyPerUnit":0.0005}]'::jsonb, 
   '[{"id":"b2","nama":"Kertas + Tinta Hitam","biaya":290}]'::jsonb),
  ('svc_print_warna', 'Print Warna', 'lembar', 42, 228, 50, 35, 1000, 
   '[{"id":"r4","label":"Kertas HVS","productId":"prd_042","qtyPerUnit":1},{"id":"r5","label":"Tinta Warna","productId":"prd_078","qtyPerUnit":0.001}]'::jsonb, 
   '[{"id":"b3","nama":"Kertas + Tinta Warna","biaya":430}]'::jsonb),
  ('svc_jilid', 'Jilid Mika & Lakban', 'buku', 0, 0, 50, 35, 3000, 
   '[{"id":"r6","label":"Mika Bening","productId":"prd_057","qtyPerUnit":2},{"id":"r7","label":"Buffalo","productId":"prd_044","qtyPerUnit":1},{"id":"r8","label":"Lakban Hitam","productId":"prd_051","qtyPerUnit":0.05}]'::jsonb, 
   '[{"id":"b4","nama":"Mika + Buffalo + Lakban","biaya":2100}]'::jsonb),
  ('svc_lam_f4', 'Laminating F4 Panas', 'lembar', 320, 1000, 50, 35, 3500, 
   '[{"id":"r9","label":"Plastik Laminating F4","productId":"prd_055","qtyPerUnit":1}]'::jsonb, 
   '[{"id":"b5","nama":"Plastik Laminating F4","biaya":2180}]'::jsonb),
  ('svc_lam_a4', 'Laminating A4 Panas', 'lembar', 320, 1000, 50, 35, 3000, 
   '[{"id":"r10","label":"Plastik Laminating A4","productId":"prd_056","qtyPerUnit":1}]'::jsonb, 
   '[{"id":"b6","nama":"Plastik Laminating A4","biaya":1680}]'::jsonb)
ON CONFLICT (id) DO UPDATE SET
  nama = EXCLUDED.nama,
  harga_jual = EXCLUDED.harga_jual,
  resep = EXCLUDED.resep,
  updated_at = NOW();

-- =========================================================================
-- SEED DATA AWAL: 10 DAFTAR BELANJA MODAL
-- =========================================================================
INSERT INTO public.belanja (id, nama, qty, nominal, biaya_satuan)
VALUES
  ('blj_1', 'Kertas HVS Sinar Dunia F4 75gr', 5, 275000, 55000),
  ('blj_2', 'Kertas HVS Sinar Dunia A4 70gr', 5, 240000, 48000),
  ('blj_3', 'Tinta Epson 003 Black Original', 3, 270000, 90000),
  ('blj_4', 'Tinta Epson 003 Cyan/Magenta/Yellow', 3, 270000, 90000),
  ('blj_5', 'Plastik Laminating Roll F4 Joyko', 2, 230000, 115000),
  ('blj_6', 'Mika Bening Jilid 0.10 isi 100', 2, 70000, 35000),
  ('blj_7', 'Kertas Buffalo Warna Campur', 2, 60000, 30000),
  ('blj_8', 'Lakban Hitam Daimaru 1.5 inch', 6, 72000, 12000),
  ('blj_9', 'Staples Max No. 10', 10, 35000, 3500),
  ('blj_10', 'Isi Staples Joyko No. 10', 20, 40000, 2000)
ON CONFLICT (id) DO NOTHING;

-- SELESAI! Seluruh tabel, RLS, Realtime, dan data 83 barang telah terkonfigurasi.
