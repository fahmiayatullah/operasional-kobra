# Kobra Hitam — Sistem Operasional Percetakan

Project web operasional percetakan berbasis **Vite**.

---

## 🚀 Menjalankan Secara Lokal (Development)

Untuk menjalankan server lokal di komputer Anda:

```bash
npm run dev
```

> **Catatan Windows PowerShell:**  
> Jika muncul error `File ... npm.ps1 cannot be loaded because running scripts is disabled`, Anda bisa:
> 1. Gunakan perintah `npm.cmd run dev`, ATAU
> 2. Buka PowerShell dan jalankan:  
>    `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

Aplikasi akan otomatis terbuka di browser Anda pada:  
`http://localhost:3000`

---

## 📦 Build untuk Produksi

Untuk menghasilkan file siap online (tersimpan di folder `dist/`):

```bash
npm run build
```

Untuk menguji hasil build sebelum di-deploy:

```bash
npm run preview
```

---

## 🌐 Cara Mengonlinekan (Deploy ke Internet)

Pilih salah satu cara gratis & termudah berikut:

### Opsi 1: Netlify Drop (Paling Cepat — Tanpa Coding / Git)
1. Jalankan `npm run build` di terminal.
2. Buka [app.netlify.com/drop](https://app.netlify.com/drop) di browser.
3. Seret (drag & drop) folder **`dist`** dari folder project ini ke halaman tersebut.
4. Web langsung online dengan URL publik gratis (contoh: `https://kobra-hitam.netlify.app`).

### Opsi 2: Vercel (Otomatis & Sangat Cepat)
1. Jalankan perintah di terminal:
   ```bash
   npx vercel
   ```
2. Ikuti instruksi di layar (login/daftar akun Vercel gratis).
3. Vercel akan otomatis mendeteksi Vite dan men-deploy situs Anda dalam hitungan detik.

### Opsi 3: GitHub + Vercel / Netlify / Cloudflare Pages (Rekomendasi untuk Jangka Panjang)
1. Buat repository baru di GitHub (misal: `kobrahitam`).
2. Hubungkan dan upload kode:
   ```bash
   git add .
   git commit -m "Initial commit - Kobra Hitam Vite Project"
   git branch -M main
   git remote add origin https://github.com/USERNAME/kobrahitam.git
   git push -u origin main
   ```
3. Buka [vercel.com](https://vercel.com) atau [netlify.com](https://netlify.com), klik **Add New Project**, dan pilih repository GitHub Anda.
4. Framework Preset akan otomatis terdeteksi sebagai **Vite**. Klik **Deploy**.
5. Setiap kali Anda push pembaruan ke GitHub, website otomatis terupdate!

---

## 📁 Struktur Folder

```text
Kobrahitam/
├── dist/                  # Folder hasil build siap online
├── node_modules/          # Library dependencies
├── .gitignore             # File yang diabaikan Git
├── index.html             # Halaman utama aplikasi (Vite entry point)
├── package.json           # Konfigurasi project & script NPM
├── Sistemkobrahitam.html   # Backup file asli
├── vite.config.js         # Konfigurasi Vite (base path & port)
└── README.md              # Panduan project
```
