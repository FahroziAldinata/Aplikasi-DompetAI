# DompetAI — Project Context for AI Assistant

## Project Overview
- **App**: DompetAI — AI Personal Finance Assistant untuk Indonesia
- **Platform**: Flutter (Android)
- **Developer**: Solo developer
- **Filosofi**: Zero cost, offline-first, gratis untuk user

## Tech Stack
- **Flutter**: 3.44.4
- **Dart**: 3.12.2
- **Python**: 3.10 (training pipeline)
- **TensorFlow**: 2.x (BiLSTM training)
- **JAVA_HOME**: C:\Program Files\Java\jdk-21

## Architecture
- **Clean Architecture**: presentation → domain → data
- **State management**: Riverpod
- **Database**: Drift + SQLite (offline-first)
- **AI Parser**: BiLSTM TFLite on-device + regex fallback (Opsi C)

## AI Parser Details
- **Model**: BiLSTM multi-output (Sequence Tagger + Classifiers)
- **Size**: 0.47MB (quantized TFLite, Non-Flex, static input signature `[1, 20]`)
- **Vocab**: 2,573 tokens (case-sensitive)
- **Outputs**: NER tags + Intent + Category
- **Dataset**: 3,973 labeled records (Bahasa Indonesia informal)
- **Validation Metrics**:
  - Val NER Accuracy: **96.13%**
  - Val Intent Accuracy: **98.74%**
  - Val Category Accuracy: **93.08%**
- **Held-out Test Metrics**:
  - Test NER Accuracy: **82.19%**
  - Test Intent Accuracy: **99.12%**
  - Test Category Accuracy: **87.95%**
- **Fallback**: Hybrid regex rule-based jika model confidence < 0.65 atau nominal amount gagal terekstrak model.

## Fallback Keywords Expansion
- **Makanan (24 kata)**: bakso, mie, ayam, nasi, soto, gado, siomay, batagor, cilok, gorengan, ketoprak, pecel, warteg, warung, kantin, cafe, kafe, resto, pizza, burger, kebab, sate, rendang, pempek.
- **Transportasi (17 kata)**: grab, gojek, ojek, taxi, taksi, bus, busway, krl, mrt, lrt, angkot, bensin, bbm, solar, parkir, tol, tiket.

## Validation Results (Python Simulation & Test Harness)
- `"beli kopi 25000"`       → Fallback ✅ (Amount: 25000, Intent: expense, Category: makanan)
- `"gaji 5000000"`          → Fallback ✅ (Amount: 5000000, Intent: income, Category: pemasukan)
- `"bayar listrik 300000"`  → Model    ✅ (Amount: 300000, Intent: expense, Category: tagihan, Confidence: 98.68%)
- `"transfer teman 100000"` → Fallback ✅ (Amount: 100000, Intent: transfer, Category: transfer)
- **dart analyze**: No issues found (Clean compilation)
 
## Parser Validation
All 5 critical cases passed on physical Android device:
- grab ke stasiun 18rb → expense/transportasi ✅
- refund tiket acara 250rb → income/pemasukan ✅
- transfer ke mama buat bayar listrik → expense/tagihan ✅
- ngopi 25k → expense/makanan/Rp25000 ✅
- kirim ke budi buat beli kopi → expense/makanan ✅

## Android Build Config
- **JVM Target**: 21 (untuk Java dan Kotlin)
- **android/build.gradle.kts**: konfigurasi `jvmToolchain(21)` di level `subprojects`
- **android/app/build.gradle.kts**: konfigurasi `compileOptions` ke `VERSION_21`
- **tflite_flutter**: `^0.12.1` (kompatibel dengan Flutter 3.44.4)

## Known Issues (Resolved)
- **Bad State / Failed Precondition di HP fisik**:
  - *Root Cause*: NERParser.init() belum di-await sebelum model parse() dipanggil.
  - *Fix*: Diimplementasikan asinkron await inisialisasi via Riverpod `FutureProvider` di `providers.dart` dan di-await sebelum parse() dipanggil.
- **Flex Delegate Dependency pada TFLite**:
  - *Root Cause*: Export model default menghasilkan `tf.TensorListReserve` yang butuh Flex delegate.
  - *Fix*: Menggunakan concrete function tracing dengan static input signature `[1, 20]` di `convert_tflite.py` sehingga model 100% menggunakan native TFLite built-in ops.
- **Silent Bug Multi-transaksi (Digit Concatenation)**:
  - *Root Cause*: Kalimat dengan lebih dari satu angka (misal "beli jus jeruk 10 ribu, bayar parkir 2k") digabungkan secara salah oleh regex parser menjadi satu transaksi sebesar Rp102.000 karena digit digabung secara string-concatenation ("10" + "2" = "102") lalu dikali pengali.
  - *Fix (Opsi A)*: Implementasi deteksi (`isMultiTransaction`) dan pemisahan sub-kalimat (`splitMultiTransaction`) di client. Sub-kalimat diproses terpisah oleh parser dan dikembalikan sebagai list draf transaksi di UI agar user bisa mengonfirmasi, mengedit, atau menghapus per transaksi sebelum disimpan ke Drift SQLite.
- **Arsitektur Keyword Override Lama (Confidence-Gated)**:
  - *Root Cause*: Keyword check dibungkus di dalam block fallback reaktif `if (confidence < 0.65 || amount == null)` di skrip Python, sehingga tidak terpicu jika model percaya diri tinggi.
  - *Fix*: Diubah menjadi "menang mutlak" (precedence mutlak), dievaluasi terlebih dahulu sebelum output model dibaca.
- **Bug Ekstraksi Suffix Amount & Comma Splitting**:
  - *Root Cause*: `_parseAmount` lama melakukan pembersihan dengan regex `\D` (non-digit) sehingga huruf pengali seperti `rb`/`k`/`jt` terbuang. Detektor multi-transaksi juga salah membelah angka berkoma (seperti `2,000` menjadi `2` dan `000`).
  - *Fix*: Implementasi adjacent multiplier matching regex `(\d+(?:[.,]\d+)*)\s{0,2}(ribu|rb|k|juta|jt|miliar|milyar|m|ratus)?\b` serta lookaround `(?<!\d),|,(?!\d)` agar koma nominal desimal/ribuan tidak dibelah sebagai batas multi-transaksi.
- **Draft Review untuk Incomplete Amount**:
  - *Fix*: Jika amount bernilai null/0 (atau < 1000 pada fallback), transaksi tidak akan disimpan otomatis melainkan dijadikan draft di Chat UI agar pengguna mereview terlebih dahulu.
- **Static Analysis & Deprecation warnings (Flutter 3.19+)**:
  - *Root Cause*: 176 issues terdeteksi (deprecated `withOpacity`, `ColorScheme.background`, `DropdownButtonFormField.value`, `pw.Table.fromTextArray`, missing `if (!mounted) return;` safety checks on context, print statements, and legacy constructors).
  - *Fix*: Seluruh warning diselesaikan dengan migrasi API modern (`withValues`, `surface`, `initialValue`, `TableHelper`), integrasi mounted checks, standardisasi `super.key`, pembersihan dead code, dan transisi `print` ke `debugPrint`.
- **Onboarding Name Entry & Color Cleanup (Round 2)**:
  - *Onboarding*: Memperbaiki alur fresh install untuk mengarahkan pengguna baru ke `NameInputScreen` setelah onboarding selesai. Status `user_name_entered` disimpan di `SharedPreferences`.
  * *Color Cleanup*: Menghilangkan seluruh aksen ungu (`#C0C1FF`) di `AppTheme` dan komponen UI dengan monokromatik hitam/putih/abu-abu premium. Tombol statistik beralih ke layout side-by-side ("Mingguan"/"Bulanan") dengan warna normal/active dinamis.
  * *Account History Sync*: Mengatasi kegagalan sinkronisasi transaksi AI ke riwayat rekening (BCA, GoPay, Dana, OVO) dengan memperbarui override pendeteksi akun di `NERParser.parse()` dan dynamic metadata mapping (`accountName` & `accountType`) di mapper `toCompanion()` dan `toEntity()`.
- **Final UI/UX Revisions & Theme Consistency (Round 3 - Juli 2026)**:
  - *Dashboard & Header*: Membungkus nama pengguna dalam `Expanded` dan `TextOverflow.ellipsis` untuk mencegah RenderFlex overflow saat input nama panjang. Menghapus warna ungu/indigo yang tersisa dari `TOTAL SALDO` di Dashboard.
  - *Global Nominal Color Standardization*: Menyeragamkan warna nominal transaksi di seluruh layar (Dashboard, Cash History, Account Detail, Transaction List, dan Transaction Tile) dengan skema: Hijau untuk Pemasukan, Merah untuk Pengeluaran/Utang, Biru Muda untuk Transfer/Piutang.
  - *Cash History & Account Detail*: Mengubah latar belakang kartu transaksi pada riwayat Cash dan Detail Akun menjadi warna netral (`surfaceContainerHigh`) dan seragam, serta mengganti FloatingActionButton di Cash Detail menjadi warna putih dengan border hitam.
  - *Theme Toggle Integration*: Menambahkan `ThemeToggleButton` pada seluruh screen sekunder (Cash Detail, Account Detail, dan Transaction List) untuk navigasi mode gelap/terang yang merata.
- **Global Theme Cleanup & Release Build (Final Round - Juli 2026)**:
  - *Form Fields Neutralization*: Mengubah semua input field, label, hint, border, dan prefix icon pada form "Tambah Target", "Tambah Rekening", dan "Tambah Utang/Piutang" dari aksen ungu default ke warna putih/abu-abu netral agar selaras dengan tema monokromatik.
  - *Category Color Standardisation*: Mengganti warna ungu/indigo di `TransactionTile` kategori "hiburan" dan "tagihan" dengan `Colors.tealAccent.shade700` dan `Colors.blueGrey`.
  - *Release Build & Quality Assurance*: Berhasil melakukan build APK rilis (`app-release.apk`) secara 100% bersih tanpa warning static analysis maupun kegagalan test suite.


## Status
### Phase 1 MVP — SELESAI ✅
- [x] Dataset pipeline (3.973 records)
- [x] BiLSTM TFLite model (0.11MB, offline)
- [x] Hybrid parser (model + regex fallback)
- [x] Clean Architecture Flutter
- [x] Drift SQLite offline-first
- [x] Chat screen dengan AI parser
- [x] Dashboard Bento Box glassmorphic
- [x] Balance cards realtime (Cash + Rekening)
- [x] Line chart statistik dengan tanggal
- [x] Transaksi terakhir + Lihat Semua
- [x] Saving Goals screen (CRUD lengkap)
- [x] Bottom navigation 4 tab
- [x] Dark/light mode toggle
- [x] Format nominal otomatis (Rp X.XXX)
- [x] Tested on Android 14 physical device

### Phase 2 — SELESAI ✅
- [x] Bento UI Redesign Migration (Dashboard, Cash, Rekening, Debt)
- [x] Debt management screen
- [x] Advanced statistics (pie chart kategori)
- [x] Export PDF/Excel
- [x] Notifikasi pengingat utang (simulasi & push local)
- [x] Onboarding screen
- [x] App icon + splash screen custom
- [x] Release APK (signed)
- [x] Debug APK (`app-debug.apk`)
- [x] 100% Static Analysis Clean (0 issues)
- [x] 100% Test Suite Verification (23 tests passed)

## Design System
- Primary: Colors.white (neutral text/accents cleanup) / #6366F1 (indigo container base)
- Glow: #818CF8
- Dark surface: #131316 (background) / #1F1F22 (zinc-900 surface-container)
- Border radius: 20px (dashboard cards) / 32px (bank cards) / 12px (sub-cards & icons)
- Style: Bento Box, glassmorphic, theme-aware dark/light mode
- Chart: fl_chart LineChart with gradient fill


## File Locations
- **Model**: `D:\dompetai\assets\models\dompetai_ner.tflite`
- **Vocab**: `D:\dompetai\assets\models\*.json`
- **Training pipeline**: `D:\indonesian-nlp-pipeline\`
- **Master Test Cases**: `D:\dompetai\test\test_cases_master.json`
- **Python Test Runner**: `D:\indonesian-nlp-pipeline\tools\run_master_test_suite.py`
- **Test Suite Report**: `D:\indonesian-nlp-pipeline\test_suite_report.md`