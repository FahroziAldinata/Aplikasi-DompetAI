# 🧠 DompetAI NLP Model

Model AI untuk parsing transaksi keuangan 
Bahasa Indonesia informal.

## Arsitektur
Input (max 20 token)
↓
Embedding (64 dim)
↓
Bidirectional LSTM (64 units)
↓
┌─────────────┬──────────────┬───────────────┐
NER Tags    Intent Class  Category Class
(per token)  (per kalimat)  (per kalimat)

## Spesifikasi
| Property | Value |
|---|---|
| Format | TFLite (quantized) |
| Ukuran | 0.47 MB |
| Input | [1, 20] token indices |
| Vocab | 2.573 tokens |
| Output 1 | NER tags [1, 20, 8] |
| Output 2 | Intent [1, 4] |
| Output 3 | Kategori [1, 10] |

## Label Schema
**NER Tags:** O, B-AMOUNT, I-AMOUNT, B-ITEM, 
I-ITEM, B-ACCOUNT, B-PERSON

**Intent:** expense, income, transfer, debt

**Kategori:** makanan, transportasi, belanja, 
tagihan, hiburan, kesehatan, pendidikan, 
pemasukan, transfer, utang

## Dataset
- **Total:** 3.973 labeled records
- **Sumber:** Bahasa Indonesia informal
- **Format:** JSONL (CoNLL-style BIO)
- **Split:** 80% train / 20% test

## Akurasi
| Metric | Val | Test |
|---|---|---|
| NER | 96.13% | 82.19% |
| Intent | 98.74% | 99.12% |
| Kategori | 93.08% | 87.95% |

## Hybrid Pipeline
Input teks
↓
Keyword Override (menang mutlak)
↓ jika tidak ada keyword
BiLSTM inference
↓ jika confidence < 0.65
Regex fallback
↓
TransactionEntity

## Retrain Model
```bash
cd D:\indonesian-nlp-pipeline

# Build vocab
python train/build_vocab.py

# Train
python train/train.py

# Export TFLite
python train/convert_tflite.py

# Copy ke Flutter
copy models\dompetai_ner.tflite 
     D:\dompetai\assets\models\
```

## Keyword Override
Parser menggunakan keyword list sebagai 
"menang mutlak" sebelum model:
- **Debt:** utang, pinjam, hutang, minjem
- **Income:** gaji, refund, cashback, bonus
- **Transfer:** tf, kirim, transfer, pindah
- **Expense:** beli, bayar, jajan, makan
