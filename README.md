# 👛 DompetAI

AI Personal Finance Assistant untuk Indonesia.
Catat keuangan cukup dengan chat — offline, gratis, privat.

---

## ✨ Fitur Utama
- **Chat Natural** — ketik "beli kopi 20rb" langsung tercatat
- **AI On-Device** — model BiLSTM TFLite, tanpa internet
- **Multi Akun** — Cash, BCA, GoPay, OVO, dll
- **Target Tabungan** — progress bar + kalkulasi bulanan
- **Kelola Utang** — catat, bayar, lunas
- **Dashboard** — statistik, grafik, pie chart kategori
- **Dark Mode** — desain Bento Box glassmorphic

---

## 📱 Panduan Install APK

### Download
| Versi | Link | Ukuran |
|---|---|---|
| Release v1.0.0 | [app-release.apk](build/app/outputs/flutter-apk/app-release.apk) | ~70MB |

### Cara Install
1. Download file APK
2. Buka **Pengaturan → Keamanan**
3. Aktifkan **"Izinkan sumber tidak dikenal"**
4. Buka file APK yang didownload
5. Tap **Install**

### Persyaratan
- Android 6.0 (API 23) ke atas
- RAM minimal 2GB
- Storage 70MB

---

## 🧠 Model AI (NLP Parser)

Model AI untuk parsing transaksi keuangan Bahasa Indonesia informal secara on-device.

### Arsitektur Model
Input (max 20 token)
↓
Embedding (64 dim)
↓
Bidirectional LSTM (64 units)
↓
┌─────────────┬──────────────┬───────────────┐
NER Tags    Intent Class  Category Class
(per token)  (per kalimat)  (per kalimat)

### Spesifikasi
| Property | Value |
|---|---|
| Format | TFLite (quantized) |
| Ukuran | 0.47 MB |
| Input | [1, 20] token indices |
| Vocab | 2.573 tokens |
| Output 1 | NER tags [1, 20, 8] |
| Output 2 | Intent [1, 4] |
| Output 3 | Kategori [1, 10] |

### Akurasi Model
| Metric | Validation | Test |
|---|---|---|
| Named Entity Recognition (NER) | 96.13% | 82.19% |
| Intent Classification | 98.74% | 99.12% |
| Kategori Classification | 93.08% | 87.95% |

---

## 🛠 Tech Stack
| Layer | Tech |
|---|---|
| Mobile | Flutter 3.44.4 |
| State Management | Riverpod |
| Database | Drift + SQLite |
| AI Engine | BiLSTM TFLite (0.47MB) |
| Training | Python 3.10 + TensorFlow 2.x |

---

## 📂 Struktur Project
```text
lib/
├── core/          # tema, konstanta, utils
├── data/          # AI parser, database, repository
├── domain/        # entities, use cases
└── presentation/  # screens, widgets, providers
```

---

## 🚀 Jalankan Lokal
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Prasyarat: Flutter 3.44.4, JDK 21, Android device/emulator

## 📄 Lisensi
MIT License — gratis untuk semua.
