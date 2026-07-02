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

    print("=== LOADING VOCABULARY AND MODEL ===")
    
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

    print(f"Vocab size: {len(word2idx)}")
    print(f"Labels: {label2idx}")
    print(f"Intents: {intent2idx}")
    print(f"Categories: {category2idx}")

    print("\n=== INITIALIZING TFLITE INTERPRETER ===")
    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    print("--- Model Inputs ---")
    for i, detail in enumerate(input_details):
        print(f"Input {i}: name={detail['name']}, shape={detail['shape']}, dtype={detail['dtype']}")

    print("--- Model Outputs ---")
    for i, detail in enumerate(output_details):
        print(f"Output {i}: name={detail['name']}, shape={detail['shape']}, dtype={detail['dtype']}")

    # Dynamic indices mapping
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

    print("\n--- Dynamically Mapped Output Indices ---")
    print(f"  NER head index: {ner_output_idx}")
    print(f"  Intent head index: {intent_output_idx}")
    print(f"  Category head index: {category_output_idx}")

    if ner_output_idx is None or intent_output_idx is None or category_output_idx is None:
        raise ValueError("Could not map output tensors to expected heads.")

    # Validation logic mirroring Dart NERParser
    def normalize(raw_text):
        text = raw_text
        
        # 1. Normalize Rp prefix to "Rp " (capitalized with space)
        text = re.sub(r'(?i)rp\.?\s*(\d)', r'Rp \1', text)
        
        # 2. Capitalize key wallets and banks if they are lowercase
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
            
        # 3. Handle raw numbers without dot separators.
        # If there is a sequence of 4 or more digits (like 25000), format it with dots (like 25.000).
        def format_number_dots(m):
            val_str = m.group(0)
            val = int(val_str)
            return f"{val:,}".replace(",", ".")
            
        text = re.sub(r'\b\d{4,}\b', format_number_dots, text)
        
        # 4. Multipliers: e.g. 20k -> 20.000, 1.5 juta -> 1.500.000
        # If there's 20rb or 75rb, they are in vocabulary, so keep them!
        # If there is 20k, replace it with 20.000.
        # If there is 1,5juta, let's keep it? Or replace it? 
        # Let's convert text multipliers that are not directly in vocab (like k or juta/ribu with raw digits) 
        # into dotted numbers, or format them cleanly.
        # For example, "20k" -> "20.000"
        # "1,5juta" -> "1.500.000" (since 1.500.000 is in vocab!)
        # "10ribu" -> "10 ribu" (with space, since "10" and "ribu" are in vocab!)
        text = re.sub(r'(?i)\b(\d+)\s*k\b', lambda m: f"{int(m.group(1)) * 1000:,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b', lambda m: f"{int(float(m.group(1).replace(',', '.')) * 1000000):,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+)\s*(?:rb|ribu)\b', lambda m: f"{m.group(1)} ribu", text)

        # Restore 20/75rb to vocab formats if they got converted
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
        print(f"\n--- Processing Text: '{raw_text}' ---")
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

        print(f"Raw Intent Output: {intent_output[0]}")
        print(f"Raw Category Output: {category_output[0]}")

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

        print("Decoded Entities:")
        print(f"  Intent: {intent} (confidence: {intent_conf:.4f})")
        print(f"  Category: {category}")
        print(f"  Amount: {amount}")
        print(f"  Description: {description}")
        print(f"  Account: {account}")

    test_cases = [
        "Beli kopi susu habis Rp 25.000 bayar pakai tunai",
        "Ngopi di cafe pesen nasi goreng seharga Rp25.000 bayar cash",
        "Ada uang masuk Rp1.500.000 dari Budi",
        "Bayar listrik seharga 300.000 lewat Gopay",
        "Transfer 100.000 lewat OVO"
    ]

    for case in test_cases:
        run_inference(case)

if __name__ == "__main__":
    main()
