# 🏠 WARO — Warung Obrolan
> *Dari bahasa Jawa: waro = warung / tempat nongkrong sederhana*

---

## 📌 Ringkasan Eksekutif

**WARO** adalah aplikasi chat pertama di dunia yang **sengaja tidak instan** — kebalikan dari WhatsApp, Telegram, atau semua sosmed yang berlomba-lomba semakin cepat dan real-time.

> **Filosofi:** *"Tidak semua obrolan perlu dibalas sekarang. Tidak semua orang perlu tahu lokasi exact kamu. Tapi pertemanan perlu dirawat dengan ritme manusia, bukan ritme notifikasi."*

---

## 🎯 Masalah yang Diselesaikan

| Aplikasi Saat Ini | Masalah |
|---|---|
| WhatsApp | Harus cepat balas, grup bising, lokasi real-time menyalahgunakan privasi |
| Telegram | Fitur terlalu banyak, bingung untuk orang awam |
| Facebook/Meta | Berat, banyak iklan, algoritma bikin FOMO |
| TikTok/IG | Bikin stres sosial & konsumsi konten berlebihan |
| MiChat | Sering jadi sarana penipuan & prostitusi terselubung |

---

## ✨ Fitur Unggulan (Unik di Dunia)

| Fitur | Cara Kerja | Kebaruan |
|---|---|---|
| **Pesan Jeda (Pause Chat)** | Pause chat tanpa blokir. Lawan tahu kamu istirahat. Pesan tertunda otomatis terkirim kembali setelah pause berakhir. | Tidak ada di aplikasi manapun |
| **Warung Virtual** | Grup kecil maks 5 orang, otomatis bubar setelah 24 jam | Mengurangi drama grup permanen |
| **Pulsa Chat** | 20 pulsa/hari. Kalau habis, tunggu besok atau minta ke teman | Membatasi spam & obrolan tidak penting |
| **Mode Jalan-Jalan** | Lokasi hanya muncul sebagai nama kecamatan, update 3x/hari | Privasi tinggi, tetap bisa ketemuan |
| **Suara Lingkungan (Soundscape)** | Rekaman 10 detik suara sekitar (motor, adzan, hujan) tanpa kata-kata | Bentuk komunikasi baru yang lebih hangat |

---

## 📱 UI — 5 Layar Utama

```
[Layar 1]   [Layar 2]   [Layar 3]   [Layar 4]   [Layar 5]
 Warung       Chat        Pulsa       Jalan2      Warungku
(beranda)   (pesan)     (dompet)    (lokasi)     (profil)
```

### Layar 1 · Warung (Beranda)
- Daftar warung aktif hari ini dengan progress bar sisa waktu (mis. `██████░░ 58%`)
- Tombol **Buat Warung Baru**
- Daftar warung kemarin yang sudah bubar + tombol Arsipkan

### Layar 2 · Chat (Pesan)
- Indikator **PAUSE MODE AKTIF** (kontak yang sedang di-pause)
- Chat aktif per warung & per orang
- Preview tipe pesan: teks, suara lingkungan, permintaan pulsa

### Layar 3 · Pulsa (Dompet Chat)
- Sisa pulsa hari ini (mis. ⚡ 12), reset jam 00:00
- Tombol Minta Pulsa ke Teman
- Beli pulsa ekstra via QRIS / OVO / ShopeePay

### Layar 4 · Jalan-Jalan (Lokasi Santai)
- Lokasi berupa nama kecamatan saja (bukan koordinat GPS)
- Update 3x/hari: 06:00, 12:00, 18:00
- Daftar teman di sekitar + tombol sapaan anonim

### Layar 5 · Warungku (Profil & Pengaturan)
- Manajemen kontak yang di-pause
- Jadwal update lokasi (3x/6x/manual)
- Penyimpanan lokal & backup Google Drive
- Tema (Terang/Gelap/Otomatis)

---

## 🔧 Arsitektur Teknis

### Prinsip Desain
- **Offline-First** — data di SQLite lokal, sync saat buka app
- **APK < 15 MB**, Android 8+ (2016 ke atas)
- **No cloud AI, no ML** → hemat baterai & kuota
- **Enkripsi end-to-end** — server tidak menyimpan pesan setelah terkirim

### Stack
| Layer | Teknologi |
|---|---|
| Mobile App | Flutter (Dart) |
| Database Lokal | SQLite via `sqflite` |
| Realtime | Firebase RTDB / MQTT |
| Backend API | Node.js + Express |
| Cloud Database | Supabase (PostgreSQL) |
| Background Jobs | WorkManager (Android) |
| Push Notification | Firebase Cloud Messaging |
| Backup | Google Drive API (AES-256) |

### Estimasi Performa
| Komponen | Ukuran/Konsumsi |
|---|---|
| APK | ~12–15 MB |
| Per 1.000 pesan | ~2 MB |
| Per 100 rekaman suara | ~8 MB |
| Baterai (background sync) | ~2–3%/hari |
| Kuota harian | ~5–10 MB |

---

## 🗄️ Database Lokal (SQLite)

```
waro_local.db
├── users              → Data diri sendiri (1 baris)
├── contacts           → Daftar teman + status pause
├── warungs            → Grup sementara (24 jam)
├── warung_members     → Anggota tiap warung
├── messages           → Semua pesan (termasuk offline)
├── pulsa_transactions → Riwayat transaksi pulsa
├── location_history   → Riwayat update lokasi lokal
├── paused_contacts    → Kontak yang di-pause
├── pending_messages   → Pesan tertahan selama pause
└── sync_queue         → Antrian operasi belum terkirim
```

## 🗄️ Database Server (Supabase PostgreSQL)

```
waro_server
├── users              → Akun (phone, name, password_hash, pulsa_balance)
├── contacts           → Relasi pertemanan & status pause
├── warungs            → Grup sementara + expires_at
├── warung_members     → Anggota warung
├── messages           → Semua pesan (text/soundscape/system/urgent)
├── pulsa_transactions → Transaksi pulsa (daily/gift/purchase)
├── pending_messages   → Pesan dari kontak yang dipause
├── sync_queue         → Antrian sync offline device
└── device_tokens      → FCM token push notification
```

---

## 📦 Struktur Folder Project

```
waro_app/                         (Flutter)
├── lib/
│   ├── main.dart
│   ├── database/
│   │   ├── database_helper.dart
│   │   └── dao/ (message, warung, contact, pulsa)
│   ├── sync/
│   │   ├── sync_queue.dart
│   │   └── background_sync.dart
│   ├── services/
│   │   ├── sound_recorder_service.dart
│   │   ├── pause_chat_service.dart
│   │   ├── warung_service.dart
│   │   └── backup_service.dart
│   ├── screens/
│   │   ├── home_screen.dart
│   │   ├── chat_screen.dart
│   │   ├── pulsa_screen.dart
│   │   ├── location_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── pause_chat_screen.dart
│   │   ├── create_warung_screen.dart
│   │   └── backup_screen.dart
│   └── widgets/
│       ├── soundscape_widget.dart
│       ├── warung_card_widget.dart
│       └── sync_status_indicator.dart
└── pubspec.yaml

backend-waro/                     (Node.js)
├── supabase/migrations/001_initial_schema.sql
├── src/
│   ├── index.js
│   ├── config/supabase.js
│   ├── middleware/auth.js
│   └── routes/
│       ├── auth.js
│       ├── messages.js
│       ├── warungs.js
│       ├── pause.js
│       ├── pulsa.js
│       └── sync.js
└── package.json
```

---

## 🚀 Roadmap Implementasi (9 Bagian)

### ✅ Bag. 1 — Konsep & Wireframe
Filosofi produk, diferensiasi, wireframe 5 layar utama

### ✅ Bag. 2 — Database Lokal + Sinkronisasi Offline
Skema SQLite 10 tabel, arsitektur offline-first, algoritma sync

### ✅ Bag. 3 — Soundscape (Suara Lingkungan)
- Rekam 2–10 detik, format AAC 22kHz 64kbps Mono
- Long-press untuk rekam, preview & hapus sebelum kirim

### ✅ Bag. 4 — Queue Sync dengan Retry Logic
- Retry otomatis 5x: 30s → 1m → 2m → 5m → 10m
- Batch 20 item/siklus, background sync tiap 1 jam

### ✅ Bag. 5 — Main App Integration
Init WorkManager + SQLite + SyncQueueManager saat app start

### ✅ Bag. 6 — Pause Chat (Tanpa Blokir)
- Pause 1–7 hari, transparan (lawan tahu alasan & durasi)
- Pesan tertunda tersimpan & terkirim otomatis setelah selesai
- Pesan URGENT bisa tembus pause
- Pause massal: digital detox (pause semua kontak)
- Auto-resume saat waktu habis

### ✅ Bag. 7 — Warung Expired Auto-Delete
- Auto-expire 24 jam sejak dibuat
- Progress bar merah jika < 20% waktu tersisa
- Notifikasi sistem ke semua anggota saat bubar
- Arsip otomatis, cleanup DB setelah 30 hari
- Premium: perpanjang +24 jam = Rp1.000

### ✅ Bag. 8 — Backup & Restore Google Drive
- Enkripsi AES-256 sebelum upload
- Backup otomatis jam 02:00 setiap hari
- Restore selektif (pilih data yang dikembalikan)
- Simpan max 10 backup terakhir

### ✅ Bag. 9 — API Server (Node.js + Supabase)
- JWT Auth + bcrypt + Socket.io realtime
- Cron: expire warung tiap jam, reset pulsa tiap 00:00 WIB

---

## 📡 API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| POST | `/auth/register` | Daftar akun baru |
| POST | `/auth/login` | Login → JWT |
| GET | `/auth/verify` | Verifikasi token |
| POST | `/messages/send` | Kirim pesan (pribadi/warung) |
| GET | `/messages/:userId` | Ambil pesan (sync) |
| GET | `/warungs/:userId` | Ambil warung aktif |
| POST | `/warungs` | Buat warung baru |
| POST | `/pause/:contactId` | Pause chat |
| DELETE | `/pause/:contactId` | Unpause chat |
| GET | `/pulsa/balance` | Cek saldo pulsa |
| POST | `/pulsa/buy` | Beli pulsa ekstra |
| POST | `/pulsa/gift` | Kirim pulsa ke teman |

---

## 💰 Monetisasi (Tanpa Iklan, Tanpa Jual Data)

| Model | Detail |
|---|---|
| Pulsa Ekstra | 10 pulsa = Rp5.000 / 25 = Rp10.000 / 60 = Rp20.000 |
| Stiker Suara Lokal | Paket suara lokal = Rp2.000/paket |
| Warung Perpanjang | +24 jam = Rp1.000 |

Pembayaran: QRIS, OVO, ShopeePay

---

## 👥 Target Pengguna

| Segmen | Alasan |
|---|---|
| Anak kos / mahasiswa | Capek dengan grup keluarga & dosen di WA |
| Orang tua 50+ | Tidak perlu fitur ribet |
| Daerah 3T | Offline-first, tidak butuh sinyal kenceng |
| Pekerja kantoran | Digital detox tapi tetap bisa dihubungi darurat |

---

## ✅ Status Implementasi

| # | Komponen | Status | File Utama |
|---|---|---|---|
| 1 | Konsep & Wireframe | ✅ | — |
| 2 | Database SQLite | ✅ | `database_helper.dart` |
| 3 | Soundscape Recorder | ✅ | `sound_recorder_service.dart` |
| 4 | Queue Sync + Retry | ✅ | `sync_queue.dart` |
| 5 | Background Sync | ✅ | `background_sync.dart` |
| 6 | Pause Chat | ✅ | `pause_chat_service.dart` |
| 7 | Warung Auto-Delete | ✅ | `warung_service.dart` |
| 8 | Backup Google Drive | ✅ | `backup_service.dart` |
| 9 | API Server Backend | ✅ | `src/routes/*.js` |

---

> **WARO** — Kebaruannya bukan dari teknologi canggih, tapi dari **desain sosial yang melambatkan komunikasi** — sesuatu yang belum pernah dibuat sebagai produk digital mainstream, baik di Indonesia maupun di luar negeri.
