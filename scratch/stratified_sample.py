import os
import csv
import json
import random

# Paths
master_test_path = r"D:\dompetai\test\test_cases_master.json"
corrected_labels_path = r"C:\Users\Administrator\.gemini\antigravity-ide\brain\cb87cb72-c72b-4c01-9c05-4f50df894473\corrected_labels.csv"

def load_master_cases():
    with open(master_test_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def main():
    master_cases = load_master_cases()
    # Build mapping from input_text to category (notes)
    text_to_cat = {}
    for case in master_cases:
        text_to_cat[case['input_text']] = case['notes']
        
    print(f"Loaded {len(text_to_cat)} unique texts from master test cases.")
    
    # Load corrections
    corrections = []
    with open(corrected_labels_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter='|')
        header = next(reader)
        for row in reader:
            if len(row) >= 4:
                teks_asli = row[0]
                old_exp = row[1]
                new_exp = row[2]
                reason = row[3]
                cat = text_to_cat.get(teks_asli, "unknown")
                corrections.append({
                    'teks_asli': teks_asli,
                    'old_expected': old_exp,
                    'new_expected': new_exp,
                    'short_reason': reason,
                    'category': cat
                })
                
    print(f"Loaded {len(corrections)} corrections from corrected_labels.csv.")
    
    # Group by category
    by_cat = {}
    for corr in corrections:
        cat = corr['category']
        by_cat.setdefault(cat, []).append(corr)
        
    print("Corrections count per category:")
    for cat, items in by_cat.items():
        print(f"- {cat}: {len(items)}")
        
    # Stratified sampling: 5 per category (or all if less than 5).
    # We want a total of 50 items.
    sampled = []
    # Seed for reproducibility
    random.seed(42)
    
    # First, take 5 from each category
    for cat in sorted(by_cat.keys()):
        items = by_cat[cat]
        sample_size = min(len(items), 5)
        cat_samples = random.sample(items, sample_size)
        sampled.extend(cat_samples)
        # Remove selected items from pool
        by_cat[cat] = [item for item in items if item not in cat_samples]
        
    print(f"Initial stratified sample (5 per category): {len(sampled)}")
    
    # Fill up to 50 if needed
    needed = 50 - len(sampled)
    if needed > 0:
        # Collect remaining pool sorted by category to ensure deterministic ordering before random selection
        pool = []
        for cat in sorted(by_cat.keys()):
            pool.extend(by_cat[cat])
        if len(pool) >= needed:
            sampled.extend(random.sample(pool, needed))
        else:
            sampled.extend(pool)
            
    print(f"Final sampled count: {len(sampled)}")
    
    # Let's count by category again in the final sample
    sample_by_cat = {}
    for item in sampled:
        sample_by_cat[item['category']] = sample_by_cat.get(item['category'], 0) + 1
    print("Sample count by category:")
    for cat in sorted(sample_by_cat.keys()):
        print(f"- {cat}: {sample_by_cat[cat]}")
        
    # Write to a CSV/text file or print
    output_path = r"D:\dompetai\scratch\audit_sample.csv"
    with open(output_path, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f, delimiter='|')
        writer.writerow(['teks_asli', 'category', 'label_lama', 'label_baru', 'justifikasi_tertulis'])
        for item in sampled:
            writer.writerow([
                item['teks_asli'],
                item['category'],
                item['old_expected'],
                item['new_expected'],
                item['short_reason']
            ])
    print(f"Sample written to {output_path}")

if __name__ == '__main__':
    main()
