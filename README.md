# 👛 DompetAI

AI Personal Finance Assistant untuk Indonesia.
Catat keuangan cukup dengan chat — offline, gratis, privat.

## ✨ Fitur
- **Chat Natural** — ketik "beli kopi 20rb" langsung tercatat
- **AI On-Device** — model BiLSTM TFLite, tanpa internet
- **Multi Akun** — Cash, BCA, GoPay, OVO, dll
- **Target Tabungan** — progress bar + kalkulasi bulanan
- **Kelola Utang** — catat, bayar, lunas
- **Dashboard** — statistik, grafik, pie chart kategori
- **Dark Mode** — desain Bento Box glassmorphic

## 📱 Download APK
Lihat [README_APK.md](docs/README_APK.md)

## 🧠 Model AI
Lihat [README_MODEL.md](docs/README_MODEL.md)

## 🛠 Tech Stack
| Layer | Tech |
|---|---|
| Mobile | Flutter 3.44.4 |
| State | Riverpod |
| Database | Drift + SQLite |
| AI Engine | BiLSTM TFLite (0.47MB) |
| Training | Python 3.10 + TensorFlow 2.x |

## 📂 Struktur Project
lib/
├── core/          # tema, konstanta, utils
├── data/          # AI parser, database, repository
├── domain/        # entities, use cases
└── presentation/  # screens, widgets, providers

## 🚀 Jalankan Lokal
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Prasyarat: Flutter 3.44.4, JDK 21, Android device/emulator

## 📊 Akurasi Model
| Metric | Validation | Test |
|---|---|---|
| Intent | 98.74% | 99.12% |
| Kategori | 93.08% | 87.95% |
| NER | 96.13% | 82.19% |

## 🏗 Arsitektur
Clean Architecture: Presentation → Domain → Data

## 📄 Lisensi
MIT License — gratis untuk semua.
