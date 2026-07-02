import 'package:flutter/material.dart';
import 'package:dompetai/data/ai/ner_parser.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  debugPrint('=== STARTING RUNTIME VALIDATION TEST ===');
  
  final parser = NERParser();
  try {
    await parser.init();
    debugPrint('SUCCESS: NERParser initialized successfully!');
    
    final testCases = [
      "beli kopi 25000",
      "gaji 5000000",
      "bayar listrik 300000",
      "transfer teman 100000",
    ];

    for (final text in testCases) {
      debugPrint('=== RUNNING TEST CASE: "$text" ===');
      final result = await parser.parse(text);
      debugPrint('Parsed Result:');
      debugPrint('  Intent: ${result.intent}');
      debugPrint('  Category: ${result.category}');
      debugPrint('  Amount: ${result.amount}');
      debugPrint('  Description: ${result.description}');
      debugPrint('  Account: ${result.account}');
      debugPrint('  Confidence: ${result.confidence}');
      debugPrint('==================================');
    }
    
    debugPrint('=== ALL RUNTIME VALIDATION TESTS COMPLETED SUCCESSFULLY ===');
  } catch (e, stack) {
    debugPrint('ERROR: Runtime test failed with exception: $e');
    debugPrint(stack.toString());
  }
}
