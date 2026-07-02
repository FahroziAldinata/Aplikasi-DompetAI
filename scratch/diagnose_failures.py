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
    master_test_path = os.path.join(project_root, "test", "test_cases_master.json")

    with open(word2idx_path, 'r', encoding='utf-8') as f:
        word2idx = json.load(f)
    with open(label2idx_path, 'r', encoding='utf-8') as f:
        label2idx = json.load(f)
    with open(intent2idx_path, 'r', encoding='utf-8') as f:
        intent2idx = json.load(f)
    with open(category2idx_path, 'r', encoding='utf-8') as f:
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

    if ner_output_idx is None or intent_output_idx is None or category_output_idx is None:
        raise ValueError("Could not map output tensors to expected heads.")

    # Replicate Dart NERParser normalizer
    def normalize(raw_text):
        text = raw_text
        text = re.sub(r'(?i)rp\.?\s*(\d)', r'Rp \1', text)
        
        replacements = {
            r'\bovo\b': 'OVO',
            r'\bgopay\b': 'Gopay',
            r'\bdana\b': 'Dana',
            r'\bbca\b': 'BCA',
            r'\bbni\b': 'BNI',
            r'\bmandiri\b': 'Mandiri',
            r'\bshopeepay\b': 'ShopeePay',
            r'\bcash\b': 'cash',
            r'\btunai\b': 'tunai',
            r'\bdebit\b': 'debit',
        }
        for pattern, repl in replacements.items():
            text = re.sub(r'(?i)' + pattern, repl, text)
            
        def format_number_dots(m):
            val_str = m.group(0)
            val = int(val_str)
            return f"{val:,}".replace(",", ".")
            
        text = re.sub(r'\b\d{4,}\b', format_number_dots, text)
        
        text = re.sub(r'(?i)\b(\d+)\s*k\b', lambda m: f"{int(m.group(1)) * 1000:,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b', lambda m: f"{int(round(float(m.group(1).replace(',', '.')) * 1000000)):,}".replace(",", "."), text)
        text = re.sub(r'(?i)\b(\d+)\s*(?:rb|ribu)\b', lambda m: f"{m.group(1)} ribu", text)

        text = text.replace("20.000 ribu", "20rb").replace("20 ribu", "20rb")
        text = text.replace("75.000 ribu", "75rb").replace("75 ribu", "75rb")
        
        return text

    def parse_base_value(num_str, has_multiplier):
        if has_multiplier:
            normalized = num_str.replace(',', '.')
            if normalized.count('.') > 1:
                try:
                    return float(normalized.replace('.', ''))
                except ValueError:
                    return 0.0
            else:
                try:
                    return float(normalized)
                except ValueError:
                    return 0.0
        else:
            dot_count = num_str.count('.')
            comma_count = num_str.count(',')
            
            if dot_count > 1 or comma_count > 1:
                try:
                    return float(num_str.replace('.', '').replace(',', ''))
                except ValueError:
                    return 0.0
            elif dot_count == 1 and comma_count == 1:
                dot_idx = num_str.find('.')
                comma_idx = num_str.find(',')
                if dot_idx < comma_idx:
                    try:
                        return float(num_str.replace('.', '').replace(',', '.'))
                    except ValueError:
                        return 0.0
                else:
                    try:
                        return float(num_str.replace(',', ''))
                    except ValueError:
                        return 0.0
            elif dot_count == 1:
                parts = num_str.split('.')
                if len(parts[1]) == 3:
                    try:
                        return float(num_str.replace('.', ''))
                    except ValueError:
                        return 0.0
                else:
                    try:
                        return float(num_str)
                    except ValueError:
                        return 0.0
            elif comma_count == 1:
                parts = num_str.split(',')
                if len(parts[1]) == 3:
                    try:
                        return float(num_str.replace(',', ''))
                    except ValueError:
                        return 0.0
                else:
                    try:
                        return float(num_str.replace(',', '.'))
                    except ValueError:
                        return 0.0
            else:
                try:
                    return float(num_str)
                except ValueError:
                    return 0.0

    def parse_amount(text):
        if text is None:
            return None
        clean_text = text.strip().lower()
        if not clean_text:
            return None
            
        k_regex = re.compile(r'(\d+(?:[.,]\d+)?)\s*k\b', re.IGNORECASE)
        rb_regex = re.compile(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu)\b', re.IGNORECASE)
        jt_regex = re.compile(r'(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b', re.IGNORECASE)
        m_regex = re.compile(r'(\d+(?:[.,]\d+)?)\s*(?:m|milyar|miliar)\b', re.IGNORECASE)
        ratus_regex = re.compile(r'(\d+(?:[.,]\d+)?)\s*ratus\b', re.IGNORECASE)

        base_val = None
        multiplier = 1.0

        match_k = k_regex.search(clean_text)
        match_rb = rb_regex.search(clean_text)
        match_jt = jt_regex.search(clean_text)
        match_m = m_regex.search(clean_text)
        match_ratus = ratus_regex.search(clean_text)

        if match_k:
            base_val = parse_base_value(match_k.group(1), True)
            multiplier = 1000.0
        elif match_rb:
            base_val = parse_base_value(match_rb.group(1), True)
            multiplier = 1000.0
        elif match_jt:
            base_val = parse_base_value(match_jt.group(1), True)
            multiplier = 1000000.0
        elif match_m:
            base_val = parse_base_value(match_m.group(1), True)
            multiplier = 1000000000.0
        elif match_ratus:
            base_val = parse_base_value(match_ratus.group(1), True)
            multiplier = 100.0
        else:
            general_pattern = re.compile(
                r'(\d+(?:[.,]\d+)*)\s{0,2}(ribu|rb|k|juta|jt|miliar|milyar|m|ratus)?\b',
                re.IGNORECASE
            )
            matches = list(general_pattern.finditer(clean_text))
            if matches:
                if len(matches) == 1:
                    chosen_match = matches[0]
                else:
                    matches_with_suffix = [m for m in matches if m.group(2) is not None]
                    if matches_with_suffix:
                        chosen_match = matches_with_suffix[-1]
                    else:
                        chosen_match = matches[-1]
                num_str = chosen_match.group(1)
                multiplier_str = chosen_match.group(2)
                
                base_val = parse_base_value(num_str, multiplier_str is not None)
                if multiplier_str:
                    mult_lower = multiplier_str.lower()
                    if mult_lower in ['rb', 'ribu', 'k']:
                        multiplier = 1000.0
                    elif mult_lower in ['jt', 'juta']:
                        multiplier = 1000000.0
                    elif mult_lower in ['m', 'milyar', 'miliar']:
                        multiplier = 1000000000.0
                    elif mult_lower == 'ratus':
                        multiplier = 100.0

        if base_val is None:
            return None
        return int(round(base_val * multiplier))

    def is_multi_transaction(text):
        lower = text.lower()
        if re.search(r'(?<!\d),|,(?!\d)', lower) or \
           re.search(r'\bdan\b', lower) or \
           re.search(r'\blalu\b', lower) or \
           re.search(r'\bterus\b', lower) or \
           re.search(r'\bjuga\b', lower):
            return True

        num_regex = re.compile(
            r'\b\d+(?:[.,]\d+)*(?:\s*(?:ribu|rb|k|juta|jt|miliar|milyar|m|t))?\b|\b(?:seribu|sejuta)\b',
            re.IGNORECASE
        )
        matches = num_regex.findall(lower)
        if len(matches) > 1:
            return True
        return False

    def split_multi_transaction(text):
        cleaned = text
        cleaned = re.sub(r'\b(dan|lalu|terus|juga)\b', '|||', cleaned, flags=re.IGNORECASE)
        cleaned = re.sub(r'(?<!\d),|,(?!\d)', '|||', cleaned)
        parts = cleaned.split('|||')
        return [p.strip() for p in parts if p.strip()]

    # Replicate keyword overrides
    def run_keyword_overrides(raw_text, model_intent, model_category, extracted_account, use_keyword_overrides=True):
        lower_text = raw_text.lower()
        
        def has_word(text, word):
            return bool(re.search(r'\b' + re.escape(word) + r'\b', text))
            
        def has_any_word(text, words):
            return any(has_word(text, w) for w in words)
            
        cash_keywords = ['cash', 'tunai']
        rekening_keywords = ['rekening', 'bca', 'bni', 'mandiri', 'bri', 'dana', 'ovo', 'gopay', 'shopeepay', 'bank', 'transfer']
        
        detected_account = 'cash'
        if extracted_account and extracted_account.strip():
            lower_acc = extracted_account.lower().strip()
            if any(w in lower_acc for w in cash_keywords):
                detected_account = 'cash'
            elif any(w in lower_acc for w in rekening_keywords):
                detected_account = 'rekening'
            else:
                detected_account = extracted_account.strip()
        else:
            if has_any_word(lower_text, cash_keywords):
                detected_account = 'cash'
            elif has_any_word(lower_text, rekening_keywords):
                detected_account = 'rekening'
            else:
                detected_account = 'cash'
                
        debt_words = ['utang', 'pinjam', 'hutang', 'minjem', 'pinjaman', 'kembalikan', 'balikin']
        income_words = ['gaji', 'terima', 'dapat', 'masuk', 'pemasukan', 'bonus', 'cashback', 'refund', 'dikembalikan', 'balik uang', 'kembali']
        conflict_expense_words = ['bayar', 'beli', 'belanja', 'jajan', 'makan', 'ngopi', 'nonton', 'cicil']
        transfer_words = ['transfer', 'kirim', 'pindah', 'tf', 'trf', 'pindahin', 'send', 'send ke']
        expense_words = [
          'bayar', 'beli', 'belanja', 'jajan', 'nonton', 'makan', 'ngopi', 'tebus',
          'grab', 'gojek', 'ojek', 'taxi', 'taksi', 'bus', 'busway', 'krl', 'mrt',
          'lrt', 'angkot', 'bensin', 'bbm', 'solar', 'parkir', 'tol', 'tiket', 'cicil'
        ]
        
        tagihan_words = ['listrik', 'air', 'pdam', 'wifi', 'telepon', 'tagihan', 'bpjs', 'premi', 'asuransi', 'cicil', 'cicilan', 'internet']
        if use_keyword_overrides:
            makanan_words = ['makan', 'minum', 'kopi', 'sate', 'bakso', 'ayam', 'warung', 'cafe', 'mie', 'nasi', 'soto', 'gado', 'siomay', 'batagor', 'cilok', 'gorengan', 'ketoprak', 'pecel', 'warteg', 'kantin', 'kafe', 'resto', 'pizza', 'burger', 'kebab', 'rendang', 'pempek']
            belanja_words = ['sepatu', 'baju', 'tas', 'jaket', 'handphone', 'laptop', 'shopee', 'tokopedia']
        else:
            makanan_words = ['makan', 'minum', 'kopi']
            belanja_words = ['sepatu', 'baju', 'tas']
            
        transportasi_words = ['grab', 'gojek', 'ojek', 'taxi', 'taksi', 'bus', 'busway', 'krl', 'mrt', 'lrt', 'angkot', 'bensin', 'bbm', 'solar', 'parkir', 'tol', 'tiket']
        
        override_intent = None
        override_category = None
        matched_override_type = None
        
        if has_any_word(lower_text, debt_words):
            override_intent = 'debt'
            override_category = 'utang'
            matched_override_type = 'debt'
        elif has_any_word(lower_text, transfer_words):
            matched_override_type = 'transfer'
            if has_any_word(lower_text, ['masuk', 'terima', 'dapat', 'refund', 'kembali', 'bonus']):
                override_intent = 'income'
                override_category = 'pemasukan'
            elif has_any_word(lower_text, conflict_expense_words):
                override_intent = 'expense'
                if has_any_word(lower_text, tagihan_words):
                    override_category = 'tagihan'
                elif has_any_word(lower_text, makanan_words):
                    override_category = 'makanan'
                elif has_any_word(lower_text, belanja_words):
                    override_category = 'belanja'
                elif has_any_word(lower_text, transportasi_words):
                    override_category = 'transportasi'
                else:
                    override_category = 'transfer'
            else:
                override_intent = 'transfer'
                override_category = 'transfer'
        elif has_any_word(lower_text, income_words):
            override_intent = 'income'
            override_category = 'pemasukan'
            matched_override_type = 'income'
        elif has_any_word(lower_text, expense_words):
            override_intent = 'expense'
            matched_override_type = 'expense'
            if has_any_word(lower_text, tagihan_words):
                override_category = 'tagihan'
            elif has_any_word(lower_text, makanan_words):
                override_category = 'makanan'
            elif has_any_word(lower_text, belanja_words):
                override_category = 'belanja'
            elif has_any_word(lower_text, transportasi_words):
                override_category = 'transportasi'
                
        intent = override_intent if override_intent else model_intent
        category = override_category if override_category else model_category
        
        return intent, category, detected_account, matched_override_type

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

    def parse_single_transaction(text):
        normalized = normalize(text)
        tokens = [t for t in re.split(r'\s+', normalized) if t]
        
        padded_indices = [0] * 20
        for i in range(20):
            if i < len(tokens):
                padded_indices[i] = word2idx.get(tokens[i], 1)
            else:
                padded_indices[i] = 0

        input_data = np.array([padded_indices], dtype=np.int32)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()

        ner_output = interpreter.get_tensor(ner_output_idx)
        intent_output = interpreter.get_tensor(intent_output_idx)
        category_output = interpreter.get_tensor(category_output_idx)

        intent_probs = intent_output[0]
        intent_id = np.argmax(intent_probs)
        model_intent = idx2intent.get(intent_id, 'expense')

        cat_probs = category_output[0]
        cat_id = np.argmax(cat_probs)
        model_category = idx2category.get(cat_id, 'unknown')

        predicted_labels = []
        truncated_len = min(len(tokens), 20)
        for i in range(20):
            if i < truncated_len:
                label_idx = np.argmax(ner_output[0][i])
                predicted_labels.append(idx2label.get(label_idx, 'O'))
            else:
                predicted_labels.append('PAD')
        
        truncated_tokens = tokens[:truncated_len]
        extracted_amount_str = extract_entity(truncated_tokens, predicted_labels, 'AMOUNT')
        amount = parse_amount(extracted_amount_str)
        
        extracted_account = extract_entity(truncated_tokens, predicted_labels, 'ACCOUNT')
        description = extract_entity(truncated_tokens, predicted_labels, 'ITEM')

        intent, category, account, override_type = run_keyword_overrides(
            text, model_intent, model_category, extracted_account, use_keyword_overrides=True
        )

        if amount is None or amount < 1000:
            amount = parse_amount(text)

        # OOV Words detection
        oov_words = [t for t in tokens if t not in word2idx]

        return {
            'intent': intent,
            'category': category,
            'amount': amount,
            'description': description,
            'account': account,
            'model_intent': model_intent,
            'model_category': model_category,
            'override_type': override_type,
            'oov_words': oov_words
        }

    # Load master test cases
    with open(master_test_path, 'r', encoding='utf-8') as f:
        test_cases = json.load(f)

    print(f"Loaded {len(test_cases)} test cases.")

    total_count = 0
    pass_count = 0
    fail_count = 0

    # Dimensions failures counts
    fail_intent = 0
    fail_category = 0
    fail_amount = 0
    fail_split_len = 0

    # Category failure diagnostics
    # fully model dependent (no overrides matched)
    cat_fail_model_dep = 0
    # keyword overrides matched but was wrong
    cat_fail_override_wrong = 0
    # details
    cat_fail_reasons = []

    # OOV statistics for failures
    oov_counts = {}
    total_oov_tokens_in_fails = 0
    fail_cases_with_oov = 0

    # Multi-transaction statistics
    real_multi_cases = [] # cases where expected len > 1
    false_positive_splits = 0 # expected len = 1 but split
    false_negative_splits = 0 # expected len > 1 but not split

    # Diagnostic records of failed cases to identify top root causes
    failed_records = []

    for idx, tc in enumerate(test_cases):
        text = tc['input_text']
        expected_list = tc['expected']
        notes = tc['notes']

        if notes == 'multi_transaction':
            # Skip multi-transaction category in main counts if it is evaluated separately
            # wait, the STATUS_REPORT says overall excludes multi, let's keep track of all.
            pass

        is_real_multi = len(expected_list) > 1
        if is_real_multi:
            real_multi_cases.append(tc)

        # Determine split
        split_triggered = is_multi_transaction(text)
        if split_triggered:
            parts = split_multi_transaction(text)
        else:
            parts = [text]

        # Multi splits checks
        if not is_real_multi and split_triggered:
            false_positive_splits += 1
        if is_real_multi and not split_triggered:
            false_negative_splits += 1

        actual_list = []
        for part in parts:
            res = parse_single_transaction(part)
            actual_list.append(res)

        # Evaluate correctness
        is_pass = True
        reasons = []
        intent_mismatch = False
        cat_mismatch = False
        amt_mismatch = False
        len_mismatch = False

        if len(actual_list) != len(expected_list):
            is_pass = False
            len_mismatch = True
            reasons.append(f"Length mismatch: expected {len(expected_list)}, got {len(actual_list)}")
        else:
            for i in range(len(expected_list)):
                exp = expected_list[i]
                act = actual_list[i]
                
                exp_intent = exp['intent']
                exp_cat = exp['category']
                exp_amt = exp['amount']

                act_intent = act['intent']
                act_cat = act['category']
                act_amt = act['amount']

                if act_intent != exp_intent:
                    is_pass = False
                    intent_mismatch = True
                    reasons.append(f"intent mismatch at index {i}: expected {exp_intent}, got {act_intent}")
                if act_cat != exp_cat:
                    is_pass = False
                    cat_mismatch = True
                    reasons.append(f"category mismatch at index {i}: expected {exp_cat}, got {act_cat}")
                    # Diagnostics for category failure
                    if act['override_type'] is None:
                        cat_fail_model_dep += 1
                        diag = 'model_only'
                    else:
                        cat_fail_override_wrong += 1
                        diag = f"override_wrong({act['override_type']})"
                    
                    cat_fail_reasons.append({
                        'text': text,
                        'part': parts[i],
                        'expected_category': exp_cat,
                        'actual_category': act_cat,
                        'model_category': act['model_category'],
                        'override_type': act['override_type'],
                        'diag': diag,
                        'oov_words': act['oov_words']
                    })

                if act_amt != exp_amt:
                    is_pass = False
                    amt_mismatch = True
                    reasons.append(f"amount mismatch at index {i}: expected {exp_amt}, got {act_amt}")

        if notes != 'multi_transaction':
            total_count += 1
            if is_pass:
                pass_count += 1
            else:
                fail_count += 1
                if intent_mismatch:
                    fail_intent += 1
                if cat_mismatch:
                    fail_category += 1
                if amt_mismatch:
                    fail_amount += 1
                if len_mismatch:
                    fail_split_len += 1

                # Track OOV words in failures
                all_oovs = []
                for act in actual_list:
                    all_oovs.extend(act['oov_words'])
                
                if all_oovs:
                    fail_cases_with_oov += 1
                    total_oov_tokens_in_fails += len(all_oovs)
                    for w in all_oovs:
                        oov_counts[w] = oov_counts.get(w, 0) + 1

                failed_records.append({
                    'text': text,
                    'category': notes,
                    'expected': expected_list,
                    'actual': [{'intent': a['intent'], 'category': a['category'], 'amount': a['amount']} for a in actual_list],
                    'intent_fail': intent_mismatch,
                    'category_fail': cat_mismatch,
                    'amount_fail': amt_mismatch,
                    'len_fail': len_mismatch,
                    'reasons': reasons,
                    'oov_words': all_oovs
                })

    # Evaluate multi transaction pass rate
    real_multi_passed = 0
    for tc in real_multi_cases:
        text = tc['input_text']
        expected_list = tc['expected']
        
        split_triggered = is_multi_transaction(text)
        if split_triggered:
            parts = split_multi_transaction(text)
        else:
            parts = [text]
            
        actual_list = []
        for part in parts:
            actual_list.append(parse_single_transaction(part))
            
        is_pass = True
        if len(actual_list) != len(expected_list):
            is_pass = False
        else:
            for i in range(len(expected_list)):
                if actual_list[i]['intent'] != expected_list[i]['intent'] or \
                   actual_list[i]['category'] != expected_list[i]['category'] or \
                   actual_list[i]['amount'] != expected_list[i]['amount']:
                    is_pass = False
                    break
        if is_pass:
            real_multi_passed += 1

    print("\n=== OVERALL METRICS ===")
    print(f"Total Main Cases: {total_count}")
    print(f"Passed: {pass_count} ({pass_count/total_count*100:.2f}%)")
    print(f"Failed: {fail_count} ({fail_count/total_count*100:.2f}%)")

    print("\n=== FAILURE DIMENSIONS BREAKDOWN ===")
    print(f"Intent Failures: {fail_intent} ({(fail_intent/fail_count)*100:.2f}% of fails)")
    print(f"Category Failures: {fail_category} ({(fail_category/fail_count)*100:.2f}% of fails)")
    print(f"Amount Failures: {fail_amount} ({(fail_amount/fail_count)*100:.2f}% of fails)")
    print(f"Split Length Failures: {fail_split_len} ({(fail_split_len/fail_count)*100:.2f}% of fails)")

    print("\n=== CATEGORY FAILURE DIAGNOSTICS ===")
    print(f"Fully Model Dependent (no keyword overrides triggered): {cat_fail_model_dep} ({(cat_fail_model_dep/fail_category)*100:.2f}%)")
    print(f"Keyword Override Matched but wrong: {cat_fail_override_wrong} ({(cat_fail_override_wrong/fail_category)*100:.2f}%)")

    print("\n=== OOV STATS IN FAILURES ===")
    print(f"Failed cases containing OOV words: {fail_cases_with_oov} ({(fail_cases_with_oov/fail_count)*100:.2f}% of fails)")
    print(f"Total OOV tokens in failures: {total_oov_tokens_in_fails}")
    print("Top 20 most frequent OOV words in failures:")
    sorted_oovs = sorted(oov_counts.items(), key=lambda x: x[1], reverse=True)
    for word, count in sorted_oovs[:20]:
        print(f"  - '{word}': {count}")

    print("\n=== MULTI-TRANSACTION ANALYSIS ===")
    print(f"Total Real Multi-Transaction Cases: {len(real_multi_cases)}")
    print(f"Real Multi-Transaction Cases Pass: {real_multi_passed}")
    print(f"False Positive Splits (single transaction split into multi): {false_positive_splits}")
    print(f"False Negative Splits (multi transaction failed to split): {false_negative_splits}")

    # Identify Root Causes
    # Let's categorize each failure into specific mutual root causes
    # S1: Category error - Model only (BiLSTM wrong, no keyword matched)
    # S2: Category error - Override wrong (Keyword triggered but expected was different)
    # S3: Intent error - Model only
    # S4: Intent error - Override wrong
    # S5: Amount extraction failure
    # S6: False Positive Split (single -> multi)
    # S7: False Negative Split (multi -> single)
    # S8: Mismatched Category & Intent
    # Let's count them
    rc_counts = {}
    for r in failed_records:
        # Determine specific root causes for this record
        reasons_list = []
        if r['len_fail']:
            if len(r['expected']) == 1 and len(r['actual']) > 1:
                reasons_list.append("False Positive Split (Single transaction split into multi)")
            elif len(r['expected']) > 1 and len(r['actual']) == 1:
                reasons_list.append("False Negative Split (Multi transaction failed to split)")
            else:
                reasons_list.append("Split Length Mismatch (Other)")
        else:
            # check components
            # For Category failures
            if r['category_fail']:
                # let's look at the category diagnoses
                # since expected and actual len match, we can check each part
                for i in range(len(r['expected'])):
                    exp_cat = r['expected'][i]['category']
                    # find the actual parsed token info
                    # wait, let's look at our matched overrides
                    # To be simple:
                    # Let's re-run for this record parts
                    txt_parts = split_multi_transaction(r['text']) if len(r['expected']) > 1 else [r['text']]
                    for p_idx, p in enumerate(txt_parts):
                        if p_idx < len(r['expected']):
                            p_res = parse_single_transaction(p)
                            if p_res['category'] != r['expected'][p_idx]['category']:
                                if p_res['override_type'] is None:
                                    reasons_list.append(f"Category wrong: BiLSTM model prediction wrong (expected '{r['expected'][p_idx]['category']}', got '{p_res['category']}', no keyword matched)")
                                else:
                                    reasons_list.append(f"Category wrong: Keyword override triggered incorrectly (keyword list '{p_res['override_type']}' matched, expected category '{r['expected'][p_idx]['category']}')")
            
            # For Intent failures
            if r['intent_fail']:
                for i in range(len(r['expected'])):
                    txt_parts = split_multi_transaction(r['text']) if len(r['expected']) > 1 else [r['text']]
                    for p_idx, p in enumerate(txt_parts):
                        if p_idx < len(r['expected']):
                            p_res = parse_single_transaction(p)
                            if p_res['intent'] != r['expected'][p_idx]['intent']:
                                if p_res['override_type'] is None:
                                    reasons_list.append(f"Intent wrong: BiLSTM model prediction wrong (expected '{r['expected'][p_idx]['intent']}', got '{p_res['intent']}')")
                                else:
                                    reasons_list.append(f"Intent wrong: Keyword override triggered incorrectly (keyword list '{p_res['override_type']}' matched, expected intent '{r['expected'][p_idx]['intent']}')")

            # For Amount failures
            if r['amount_fail']:
                reasons_list.append("Amount extraction failure (NER and regex fallbacks both failed to extract correct amount)")

        for rc in reasons_list:
            rc_counts[rc] = rc_counts.get(rc, 0) + 1

    print("\n=== TOP 10 ROOT CAUSES ===")
    sorted_rcs = sorted(rc_counts.items(), key=lambda x: x[1], reverse=True)
    for rc, count in sorted_rcs[:10]:
        print(f"- {rc}: {count} cases")

    # Let's save a structured JSON file with all diagnostics for Step 4
    diag_results = {
        'total_cases': total_count,
        'passed': pass_count,
        'failed': fail_count,
        'dimensions': {
            'intent': fail_intent,
            'category': fail_category,
            'amount': fail_amount,
            'split_len': fail_split_len
        },
        'category_diagnostics': {
            'model_dependent': cat_fail_model_dep,
            'override_wrong': cat_fail_override_wrong
        },
        'oov_statistics': {
            'fail_cases_with_oov': fail_cases_with_oov,
            'total_oov_tokens': total_oov_tokens_in_fails,
            'top_oov_words': sorted_oovs[:30]
        },
        'multi_transaction': {
            'total_real_multi': len(real_multi_cases),
            'passed_real_multi': real_multi_passed,
            'false_positive_splits': false_positive_splits,
            'false_negative_splits': false_negative_splits
        },
        'top_root_causes': sorted_rcs[:15]
    }
    
    with open(os.path.join(project_root, "scratch", "diag_results.json"), 'w', encoding='utf-8') as f:
        json.dump(diag_results, f, indent=2)
    print("\nSaved diagnostics results to scratch/diag_results.json")

if __name__ == "__main__":
    main()
