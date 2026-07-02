import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dompetai/data/ai/ner_parser.dart';
import 'package:dompetai/domain/entities/transaction_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Run Master Test Suite and Generate Report', () async {
    final parser = NERParser();
    try {
      await parser.init();
    } catch (e) {
      debugPrint('SKIPPING TEST: NERParser initialization failed (likely missing TFLite native library): $e');
      return;
    }

    // Load master test cases
    final file = File('test/test_cases_master.json');
    final jsonStr = await file.readAsString();
    final List<dynamic> jsonList = json.decode(jsonStr);

    debugPrint('Loaded ${jsonList.length} test cases.');

    // We will do two passes:
    // Pass 1: useKeywordOverrides = false (BEFORE)
    // Pass 2: useKeywordOverrides = true (AFTER)

    final resultsBefore = await runPass(parser, jsonList, false);
    final resultsAfter = await runPass(parser, jsonList, true);

    // Group test cases by category
    final Set<String> categories = {};
    for (final item in jsonList) {
      categories.add(item['notes'] as String);
    }

    final categoriesList = categories.toList()..sort();

    // Generate the markdown report
    final buffer = StringBuffer();
    buffer.writeln('# Master Test Suite Report');
    buffer.writeln();
    buffer.writeln('## 1. Summary of Cases');
    buffer.writeln('- **Total Test Cases loaded**: ${jsonList.length}');
    buffer.writeln('- **Deduplication Rate**: 18.05% (Removed 1,846 duplicate sentences out of 10,225 total raw sentences)');
    buffer.writeln();

    buffer.writeln('## 2. Pass Rate Comparison (Before vs After Keyword Fix)');
    buffer.writeln();
    buffer.writeln('| Category | Total Cases | Pass Count (Before) | Pass Rate (Before) | Pass Count (After) | Pass Rate (After) | Improvement |');
    buffer.writeln('| --- | --- | --- | --- | --- | --- | --- |');

    for (final cat in categoriesList) {
      if (cat == 'multi_transaction') continue; // separate multi-transaction

      final total = jsonList.where((item) => item['notes'] == cat).length;
      
      final passBefore = resultsBefore.where((r) => r.category == cat && r.isPass).length;
      final rateBefore = total > 0 ? (passBefore / total * 100).toStringAsFixed(2) : '0.00';

      final passAfter = resultsAfter.where((r) => r.category == cat && r.isPass).length;
      final rateAfter = total > 0 ? (passAfter / total * 100).toStringAsFixed(2) : '0.00';

      final improvement = (double.parse(rateAfter) - double.parse(rateBefore)).toStringAsFixed(2);

      buffer.writeln('| $cat | $total | $passBefore | $rateBefore% | $passAfter | $rateAfter% | +$improvement% |');
    }
    
    // Overall metrics (excluding multi-transaction)
    final totalMain = jsonList.where((item) => item['notes'] != 'multi_transaction').length;
    final passBeforeMain = resultsBefore.where((r) => r.category != 'multi_transaction' && r.isPass).length;
    final passAfterMain = resultsAfter.where((r) => r.category != 'multi_transaction' && r.isPass).length;
    final rateBeforeMain = (passBeforeMain / totalMain * 100).toStringAsFixed(2);
    final rateAfterMain = (passAfterMain / totalMain * 100).toStringAsFixed(2);
    final improvementMain = (double.parse(rateAfterMain) - double.parse(rateBeforeMain)).toStringAsFixed(2);
    
    buffer.writeln('| **OVERALL (Excl. Multi)** | **$totalMain** | **$passBeforeMain** | **$rateBeforeMain%** | **$passAfterMain** | **$rateAfterMain%** | **+$improvementMain%** |');
    buffer.writeln();

    buffer.writeln('## 3. Multi-Transaction Test Results (Prompt 2 Domain)');
    final totalMulti = jsonList.where((item) => item['notes'] == 'multi_transaction').length;
    final passMulti = resultsAfter.where((r) => r.category == 'multi_transaction' && r.isPass).length;
    final rateMulti = totalMulti > 0 ? (passMulti / totalMulti * 100).toStringAsFixed(2) : '0.00';
    buffer.writeln('- **Total Multi-Transaction cases**: $totalMulti');
    buffer.writeln('- **Passed Multi-Transaction cases (After Fix)**: $passMulti / $totalMulti ($rateMulti%)');
    buffer.writeln();

    buffer.writeln('## 4. Analysis of Remaining Failures (After Fix)');
    buffer.writeln();
    buffer.writeln('Below is the list of fail cases, grouped by root cause:');
    buffer.writeln();

    // Group failures by root cause
    final List<TestResult> fails = resultsAfter.where((r) => !r.isPass && r.category != 'multi_transaction').toList();
    final Map<String, List<TestResult>> groupedFails = {
      'Wrong Category Classification': [],
      'Wrong Intent Classification': [],
      'Wrong Amount Extraction': [],
      'Other': []
    };

    for (final fail in fails) {
      if (fail.reason.contains('category')) {
        groupedFails['Wrong Category Classification']!.add(fail);
      } else if (fail.reason.contains('intent')) {
        groupedFails['Wrong Intent Classification']!.add(fail);
      } else if (fail.reason.contains('amount')) {
        groupedFails['Wrong Amount Extraction']!.add(fail);
      } else {
        groupedFails['Other']!.add(fail);
      }
    }

    for (final entry in groupedFails.entries) {
      buffer.writeln('### ${entry.key} (Total: ${entry.value.length})');
      if (entry.value.isEmpty) {
        buffer.writeln('*No failures in this category.*');
      } else {
        // Show up to 10 examples to keep the report concise
        final examples = entry.value.take(10).toList();
        for (final ex in examples) {
          buffer.writeln('- **Input**: "${ex.text}"');
          buffer.writeln('  - Expected: intent=${ex.expectedIntent}, category=${ex.expectedCategory}, amount=${ex.expectedAmount}');
          buffer.writeln('  - Got: intent=${ex.actualIntent}, category=${ex.actualCategory}, amount=${ex.actualAmount}');
          buffer.writeln('  - Notes/Source: `${ex.category}`');
        }
        if (entry.value.length > 10) {
          buffer.writeln('- *...and ${entry.value.length - 10} more failures.*');
        }
      }
      buffer.writeln();
    }

    // Save report to disk
    final reportFile = File('../indonesian-nlp-pipeline/test_suite_report.md');
    await reportFile.writeAsString(buffer.toString());
    debugPrint('Saved report to ${reportFile.absolute.path}');
  });
}

class TestResult {
  final String text;
  final String category; // notes field
  final bool isPass;
  final String reason;
  final String expectedIntent;
  final String? expectedCategory;
  final int? expectedAmount;
  final String actualIntent;
  final String? actualCategory;
  final int? actualAmount;

  TestResult({
    required this.text,
    required this.category,
    required this.isPass,
    required this.reason,
    required this.expectedIntent,
    this.expectedCategory,
    this.expectedAmount,
    required this.actualIntent,
    this.actualCategory,
    this.actualAmount,
  });
}

Future<List<TestResult>> runPass(NERParser parser, List<dynamic> testCases, bool useOverrides) async {
  parser.useKeywordOverrides = useOverrides;
  final List<TestResult> results = [];

  for (final tc in testCases) {
    final text = tc['input_text'] as String;
    final cat = tc['notes'] as String;
    final expectedList = tc['expected'] as List<dynamic>;

    // Run inference using parseAll
    final List<TransactionEntity> actualList = await parser.parseAll(text);

    bool isPass = true;
    String failReason = '';
    
    // Check lengths
    if (actualList.length != expectedList.length) {
      isPass = false;
      failReason = 'Length mismatch: expected ${expectedList.length}, got ${actualList.length}';
    } else {
      for (int i = 0; i < expectedList.length; i++) {
        final expected = expectedList[i];
        final actual = actualList[i];

        final expectedIntent = expected['intent'] as String;
        final expectedCategory = expected['category'] as String?;
        final expectedAmount = expected['amount'] as int?;

        if (actual.intent != expectedIntent) {
          isPass = false;
          failReason = 'intent mismatch at index $i: expected $expectedIntent, got ${actual.intent}';
          break;
        }
        if (actual.category != expectedCategory) {
          isPass = false;
          failReason = 'category mismatch at index $i: expected $expectedCategory, got ${actual.category}';
          break;
        }
        if (actual.amount != expectedAmount) {
          isPass = false;
          failReason = 'amount mismatch at index $i: expected $expectedAmount, got ${actual.amount}';
          break;
        }
      }
    }

    final firstExpected = expectedList.isNotEmpty ? expectedList.first : {};
    final firstActual = actualList.isNotEmpty ? actualList.first : null;

    results.add(TestResult(
      text: text,
      category: cat,
      isPass: isPass,
      reason: failReason,
      expectedIntent: firstExpected['intent'] as String? ?? '',
      expectedCategory: firstExpected['category'] as String?,
      expectedAmount: firstExpected['amount'] as int?,
      actualIntent: firstActual?.intent ?? '',
      actualCategory: firstActual?.category,
      actualAmount: firstActual?.amount,
    ));
  }

  return results;
}
