import os
import json
import re
import numpy as np
import tensorflow as tf

def main():
    project_root = r"D:\dompetai"
    model_path = os.path.join(project_root, "assets", "models", "dompetai_ner.tflite")
    word2idx_path = os.path.join(project_root, "assets", "models", "word2idx.json")
    label2idx_path = os.path.join(project_root, "assets", "models", "label2idx.json")
    intent2idx_path = os.path.join(project_root, "assets", "models", "intent2idx.json")
    category2idx_path = os.path.join(project_root, "assets", "models", "category2idx.json")

    with open(word2idx_path, 'r') as f:
        word2idx = json.load(f)
    with open(label2idx_path, 'r') as f:
        label2idx = json.load(f)
    with open(intent2idx_path, 'r') as f:
        intent2idx = json.load(f)
    with open(category2idx_path, 'r') as f:
        category2idx = json.load(f)

    idx2label = {int(v): k for k, v in label2idx.items()}
    idx2intent = {int(v): k for k, v in intent2idx.items()}
    idx2category = {int(v): k for k, v in category2idx.items()}

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    ner_output_idx = None
    intent_output_idx = None
    category_output_idx = None
    for detail in output_details:
        shape = detail['shape']
        idx = detail['index']
        if len(shape) == 3 and shape[1] == 20 and shape[2] == len(label2idx):
            ner_output_idx = idx
        elif len(shape) == 2 and shape[1] == len(intent2idx):
            intent_output_idx = idx
        elif len(shape) == 2 and shape[1] == len(category2idx):
            category_output_idx = idx

    def normalize(raw_text):
        text = raw_text
        text = re.sub(r'(?i)rp\.?\s*(\d)', r'Rp \1', text)
        
        replacements = {
            r'(?i)\bovo\b': 'OVO',
            r'(?i)\bgopay\b': 'Gopay',
            r'(?i)\bdana\b': 'Dana',
            r'(?i)\bbca\b': 'BCA',
            r'(?i)\bbni\b': 'BNI',
            r'(?i)\bmandiri\b': 'Mandiri',
            r'(?i)\bshopeepay\b': 'ShopeePay',
            r'(?i)\bcash\b': 'cash',
            r'(?i)\btunai\b': 'tunai',
            r'(?i)\bdebit\b': 'debit',
        }
        for pattern, repl in replacements.items():
            text = re.sub(pattern, repl, text)
            
        def format_number_dots(m):
            val_str = m.group(0)
            val = int(val_str)
            return f"{val:,}".replace(",", ".")
            
        text = re.sub(r'\b\d{4,}\b', format_number_dots, text)
        
        text = re.sub(r'(?i)\b(\d+)\s*k\b', lambda m: f"{int(m.group(1)) * 1000:,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b', lambda m: f"{int(float(m.group(1).replace(',', '.')) * 1000000):,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+)\s*(?:rb|ribu)\b', lambda m: f"{m.group(1)} ribu", text)

        text = text.replace("20.000 ribu", "20rb").replace("20 ribu", "20rb")
        text = text.replace("75.000 ribu", "75rb").replace("75 ribu", "75rb")
        
        return text

    def extract_entity(tokens, labels, entity_type):
        entity_tokens = []
        collecting = False
        for i in range(len(tokens)):
            label = labels[i]
            if label == f'B-{entity_type}':
                collecting = True
                entity_tokens.append(tokens[i])
            elif label == f'I-{entity_type}' and collecting:
                entity_tokens.append(tokens[i])
            else:
                collecting = False
        if not entity_tokens:
            return None
        return ' '.join(entity_tokens)

    def parse_amount(text):
        if text is None:
            return None
        clean = re.sub(r'\D', '', text)
        try:
            return int(clean)
        except ValueError:
            return None

    def run_inference(raw_text):
        print(f"\n--- Input Text: '{raw_text}' ---")
        normalized = normalize(raw_text)
        print(f"Normalized: '{normalized}'")
        
        tokens = [t for t in re.split(r'\s+', normalized) if t]
        print(f"Tokens: {tokens}")
        
        padded_indices = [0] * 20
        for i in range(20):
            if i < len(tokens):
                padded_indices[i] = word2idx.get(tokens[i], 1)
            else:
                padded_indices[i] = 0
        print(f"Encoded IDs: {padded_indices}")

        # Set input tensor
        input_data = np.array([padded_indices], dtype=np.int32)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()

        # Get output tensors
        ner_output = interpreter.get_tensor(ner_output_idx)
        intent_output = interpreter.get_tensor(intent_output_idx)
        category_output = interpreter.get_tensor(category_output_idx)

        # Decode intent
        intent_probs = intent_output[0]
        intent_id = np.argmax(intent_probs)
        intent = idx2intent.get(intent_id, 'expense')
        intent_conf = intent_probs[intent_id]

        # Decode category
        cat_probs = category_output[0]
        cat_id = np.argmax(cat_probs)
        category = idx2category.get(cat_id, 'unknown')

        # Decode NER labels
        predicted_labels = []
        truncated_len = min(len(tokens), 20)
        for i in range(20):
            if i < truncated_len:
                label_idx = np.argmax(ner_output[0][i])
                predicted_labels.append(idx2label.get(label_idx, 'O'))
            else:
                predicted_labels.append('PAD')
        
        print(f"Predicted Labels: {predicted_labels[:truncated_len]}")

        # Extract entities
        truncated_tokens = tokens[:truncated_len]
        extracted_amount_str = extract_entity(truncated_tokens, predicted_labels, 'AMOUNT')
        amount = parse_amount(extracted_amount_str)
        description = extract_entity(truncated_tokens, predicted_labels, 'ITEM')
        account = extract_entity(truncated_tokens, predicted_labels, 'ACCOUNT')

        # Rule-based fallback if confidence is low or amount is None (same as Dart)
        fallback_used = False
        if intent_conf < 0.65 or amount is None:
            fallback_used = True
            # Extract Amount via regex
            amount_regex = re.compile(r'(?:rp\.?\s*)?(\d+(?:\.\d+)*)\s*(juta|ribu|rb|k)?', re.IGNORECASE)
            match = amount_regex.search(raw_text)
            if match:
                num_str = match.group(1).replace('.', '')
                try:
                    val = float(num_str)
                    unit = match.group(2)
                    if unit:
                        unit = unit.lower()
                        if unit == 'juta':
                            val *= 1000000
                        elif unit in ('ribu', 'rb', 'k'):
                            val *= 1000
                    amount = int(val)
                except ValueError:
                    pass

            # Intent and Category fallback
            lower_text = raw_text.lower()
            if re.search(r'gaji|terima|masuk|pemasukan|bonus|cashback', lower_text):
                intent = 'income'
                category = 'pemasukan'
            elif re.search(r'pinjam|hutang|utang|minjem', lower_text):
                intent = 'debt'
                category = 'utang'
            elif re.search(r'transfer|kirim|pindah', lower_text):
                intent = 'transfer'
                category = 'transfer'
            elif re.search(r'bayar|beli|belanja|jajan|nonton|makan|ngopi|tebus', lower_text):
                intent = 'expense'
                if re.search(r'listrik|air|pdam|wifi|telepon|tagihan|bpjs|premi|asuransi', lower_text):
                    category = 'tagihan'
                elif re.search(r'makan|minum|kopi|sate|bakso|ayam|warung|cafe', lower_text):
                    category = 'makanan'
                elif re.search(r'sepatu|baju|tas|jaket|handphone|laptop|shopee|tokopedia', lower_text):
                    category = 'belanja'

        print("Decoded Entities:")
        print(f"  Intent: {intent} (confidence: {intent_conf:.4f})")
        print(f"  Category: {category}")
        print(f"  Amount: {amount}")
        print(f"  Description: {description}")
        print(f"  Account: {account}")
        print(f"  Fallback Used: {fallback_used}")

    test_cases = [
        "beli kopi 25000",
        "gaji 5000000",
        "bayar listrik 300000",
        "transfer teman 100000"
    ]

    for case in test_cases:
        run_inference(case)

if __name__ == "__main__":
    main()
