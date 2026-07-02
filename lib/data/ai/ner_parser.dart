import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/transaction_entity.dart';

class NERParser {
  Interpreter? _interpreter;
  Map<String, int> _word2idx = {};
  Map<int, String> _idx2label = {};
  Map<int, String> _idx2intent = {};
  Map<int, String> _idx2category = {};
  bool useKeywordOverrides = true;

  int? _nerOutputIndex;
  int? _intentOutputIndex;
  int? _categoryOutputIndex;

  Future<void> init() async {
    try {
      // 1. Load interpreter from assets
      _interpreter = await Interpreter.fromAsset(
        AppConstants.modelPath,
        options: InterpreterOptions()..threads = 1,
      );

      // 2. Load and decode vocabulary maps
      final word2idxStr = await rootBundle.loadString(AppConstants.word2idxPath);
      _word2idx = Map<String, int>.from(json.decode(word2idxStr));

      final label2idxStr = await rootBundle.loadString(AppConstants.label2idxPath);
      final label2idx = Map<String, dynamic>.from(json.decode(label2idxStr));
      _idx2label = label2idx.map((k, v) => MapEntry(v as int, k));

      final intent2idxStr = await rootBundle.loadString(AppConstants.intent2idxPath);
      final intent2idx = Map<String, dynamic>.from(json.decode(intent2idxStr));
      _idx2intent = intent2idx.map((k, v) => MapEntry(v as int, k));

      final category2idxStr = await rootBundle.loadString(AppConstants.category2idxPath);
      final category2idx = Map<String, dynamic>.from(json.decode(category2idxStr));
      _idx2category = category2idx.map((k, v) => MapEntry(v as int, k));

      // 3. Dynamically map output indexes by checking shapes of output details
      debugPrint('--- NERParser TFLite Model Inputs ---');
      final inputTensors = _interpreter!.getInputTensors();
      for (int i = 0; i < inputTensors.length; i++) {
        debugPrint('Input $i: shape=${inputTensors[i].shape}');
      }

      debugPrint('--- NERParser TFLite Model Outputs ---');
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < outputTensors.length; i++) {
        debugPrint('Output $i: shape=${outputTensors[i].shape}');
      }

      for (int i = 0; i < outputTensors.length; i++) {
        final shape = outputTensors[i].shape;
        // We expect shapes:
        // NER: [1, 20, 8] -> 3D shape where shape[1] == maxTokenLen (20) and shape[2] == label classes (8)
        // Intent: [1, 4] -> 2D shape where shape[1] == intent classes (4)
        // Category: [1, 10] -> 2D shape where shape[1] == category classes (10)
        if (shape.length == 3 && shape[1] == AppConstants.maxTokenLen && shape[2] == label2idx.length) {
          _nerOutputIndex = i;
        } else if (shape.length == 2 && shape[1] == intent2idx.length) {
          _intentOutputIndex = i;
        } else if (shape.length == 2 && shape[1] == category2idx.length) {
          _categoryOutputIndex = i;
        }
      }

      if (_nerOutputIndex == null || _intentOutputIndex == null || _categoryOutputIndex == null) {
        throw Exception('Failed to map TFLite outputs to appropriate heads.');
      }
      debugPrint('SUCCESS: TFLite model loaded successfully from assets.');
    } catch (e) {
      throw Exception('NERParser init failed: $e');
    }
  }

  String _normalize(String rawText) {
    String text = rawText.toLowerCase();

    // Handle text multipliers: e.g. 20k -> 20000, 1.5 juta -> 1500000
    text = text.replaceAllMapped(RegExp(r'\b(\d+)\s*k\b'), (m) {
      final val = int.parse(m[1]!) * 1000;
      return val.toString();
    });
    
    text = text.replaceAllMapped(RegExp(r'\b(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b'), (m) {
      final numStr = m[1]!.replaceAll(',', '.');
      final val = double.parse(numStr) * 1000000;
      return val.round().toString();
    });

    text = text.replaceAllMapped(RegExp(r'\b(\d+)\s*(?:rb|ribu)\b'), (m) {
      final val = int.parse(m[1]!) * 1000;
      return val.toString();
    });

    return text;
  }


  bool isMultiTransaction(String text) {
    final lower = text.toLowerCase();
    
    // Check delimiters first (ignoring commas inside numbers like 2,000)
    if (lower.contains(RegExp(r'(?<!\d),|,(?!\d)')) ||
        lower.contains(RegExp(r'\bdan\b')) ||
        lower.contains(RegExp(r'\blalu\b')) ||
        lower.contains(RegExp(r'\bterus\b')) ||
        lower.contains(RegExp(r'\bjuga\b'))) {
      return true;
    }

    // Match numeric sequences or common word-based amounts
    final numRegex = RegExp(
      r'\b\d+(?:[.,]\d+)*(?:\s*(?:ribu|rb|k|juta|jt|miliar|milyar|m|t))?\b|\b(?:seribu|sejuta)\b',
      caseSensitive: false,
    );
    final matches = numRegex.allMatches(lower);
    if (matches.length > 1) {
      return true;
    }
    
    return false;
  }

  List<String> splitMultiTransaction(String text) {
    String cleaned = text;
    // Replace word delimiters with a unique separator
    cleaned = cleaned.replaceAllMapped(RegExp(r'\b(dan|lalu|terus|juga)\b', caseSensitive: false), (m) => '|||');
    cleaned = cleaned.replaceAll(RegExp(r'(?<!\d),|,(?!\d)'), '|||');
    
    final parts = cleaned.split('|||');
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
  }

  Future<List<TransactionEntity>> parseAll(String text) async {
    if (isMultiTransaction(text)) {
      final parts = splitMultiTransaction(text);
      final List<TransactionEntity> results = [];
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final tx = await parse(part);
        
        // Generate a unique ID for each transaction using microsecond and index + random suffix
        final uniqueId = '${DateTime.now().microsecondsSinceEpoch}_${i}_${100 + (part.hashCode % 900)}';
        
        results.add(TransactionEntity(
          id: uniqueId,
          rawText: part,
          intent: tx.intent,
          category: tx.category,
          amount: tx.amount,
          account: tx.account,
          description: tx.description,
          createdAt: tx.createdAt,
          confidence: tx.confidence,
        ));
      }
      return results;
    } else {
      final tx = await parse(text);
      return [tx];
    }
  }

  Future<TransactionEntity> parse(String rawText) async {
    if (_interpreter == null) {
      throw Exception('NERParser is not initialized. Call init() first.');
    }

    debugPrint('--- NERParser parsing start ---');
    debugPrint('Input text: $rawText');

    // 1. Normalize
    final normalized = _normalize(rawText);
    debugPrint('Normalized text: $normalized');

    // 2. Tokenize by whitespace
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    debugPrint('Tokenized words: $tokens');

    // 3. Convert tokens to indices using word2idx (UNK=1 for unknown)
    // 4. Pad/truncate to maxTokenLen=20
    final paddedIndices = List<int>.filled(AppConstants.maxTokenLen, 0);
    for (int i = 0; i < AppConstants.maxTokenLen; i++) {
      if (i < tokens.length) {
        paddedIndices[i] = _word2idx[tokens[i]] ?? 1; // 1 is UNK
      } else {
        paddedIndices[i] = 0; // 0 is PAD
      }
    }

    debugPrint('Encoded token ids: $paddedIndices');

    // 5. Run TFLite inference
    final input = [paddedIndices];

    // Initialize output buffers corresponding to the classifier shapes
    final intentOutput = List.generate(1, (_) => List<double>.filled(4, 0.0));
    final nerOutput = List.generate(1, (_) => List.generate(20, (_) => List<double>.filled(8, 0.0)));
    final categoryOutput = List.generate(1, (_) => List<double>.filled(10, 0.0));

    final outputs = {
      _intentOutputIndex!: intentOutput,
      _nerOutputIndex!: nerOutput,
      _categoryOutputIndex!: categoryOutput,
    };

    _interpreter!.runForMultipleInputs([input], outputs);
    debugPrint('Raw intent output tensor: $intentOutput');
    debugPrint('Raw NER output tensor: $nerOutput');
    debugPrint('Raw category output tensor: $categoryOutput');

    // 6. Decode outputs
    // 6.1. Decode intent
    final intentProbs = intentOutput[0];
    final intentIdx = _argmax(intentProbs);
    final modelIntent = _idx2intent[intentIdx] ?? 'expense';
    final confidence = intentProbs[intentIdx];

    // 6.2. Decode category
    final catProbs = categoryOutput[0];
    final catIdx = _argmax(catProbs);
    final modelCategory = _idx2category[catIdx];

    // 6.3. Decode NER labels
    final List<String> predictedLabels = [];
    final int truncatedLen = tokens.length < AppConstants.maxTokenLen ? tokens.length : AppConstants.maxTokenLen;
    final List<String> truncatedTokens = tokens.take(truncatedLen).toList();

    for (int i = 0; i < AppConstants.maxTokenLen; i++) {
      if (i < truncatedLen) {
        final labelIdx = _argmax(nerOutput[0][i]);
        predictedLabels.add(_idx2label[labelIdx] ?? 'O');
      } else {
        predictedLabels.add('PAD');
      }
    }

    // 7. Extract amount from B-AMOUNT tokens
    final amountStr = _extractEntity(truncatedTokens, predictedLabels, 'AMOUNT');
    var amount = _parseAmount(amountStr);

    // 8. Extract description from B-ITEM tokens
    var description = _extractEntity(truncatedTokens, predictedLabels, 'ITEM');

    // 9. Extract account from B-ACCOUNT tokens
    var account = _extractEntity(truncatedTokens, predictedLabels, 'ACCOUNT');

    // Keyword Override Layer (Menang Mutlak)
    final lowerText = rawText.toLowerCase();
    String? overrideIntent;
    String? overrideCategory;

    bool hasWord(String text, String word) {
      return RegExp(r'\b' + word + r'\b', caseSensitive: false).hasMatch(text);
    }

    bool hasAnyWord(String text, List<String> words) {
      return words.any((w) => hasWord(text, w));
    }

    // Account Detection Override
    String detectedAccount = 'cash';
    final cashKeywords = ['cash', 'tunai', 'dompet utama'];
    final bcaKeywords = ['bca', 'bank bca'];
    final gopayKeywords = ['gopay', 'go-pay'];
    final danaKeywords = ['dana'];
    final ovoKeywords = ['ovo'];
    final generalRekeningKeywords = ['rekening', 'bni', 'mandiri', 'bri', 'shopeepay', 'bank', 'transfer'];
    
    final textToCheck = (account != null && account.trim().isNotEmpty) ? account.toLowerCase().trim() : lowerText;
    
    if (cashKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'cash';
    } else if (bcaKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'bca';
    } else if (gopayKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'gopay';
    } else if (danaKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'dana';
    } else if (ovoKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'ovo';
    } else if (generalRekeningKeywords.any((w) => textToCheck.contains(w))) {
      detectedAccount = 'bca';
    } else {
      detectedAccount = 'cash';
    }
    account = detectedAccount;


    final debtWords = ['utang', 'pinjam', 'hutang', 'minjem', 'pinjaman', 'kembalikan', 'balikin'];
    final incomeWords = ['gaji', 'terima', 'dapat', 'masuk', 'pemasukan', 'bonus', 'cashback', 'refund', 'dikembalikan', 'balik uang', 'kembali'];
    final conflictExpenseWords = ['bayar', 'beli', 'belanja', 'jajan', 'makan', 'ngopi', 'nonton', 'cicil'];
    final transferWords = ['transfer', 'kirim', 'pindah', 'tf', 'trf', 'pindahin', 'send', 'send ke'];
    final expenseWords = [
      'bayar', 'beli', 'belanja', 'jajan', 'nonton', 'makan', 'ngopi', 'tebus',
      'grab', 'gojek', 'ojek', 'taxi', 'taksi', 'bus', 'busway', 'krl', 'mrt',
      'lrt', 'angkot', 'bensin', 'bbm', 'solar', 'parkir', 'tol', 'tiket', 'cicil'
    ];

    // Override Category Lists
    final tagihanWords = ['listrik', 'air', 'pdam', 'wifi', 'telepon', 'tagihan', 'bpjs', 'premi', 'asuransi', 'cicil', 'cicilan', 'internet'];
    final makananWords = useKeywordOverrides
        ? ['makan', 'minum', 'kopi', 'sate', 'bakso', 'ayam', 'warung', 'cafe', 'mie', 'nasi', 'soto', 'gado', 'siomay', 'batagor', 'cilok', 'gorengan', 'ketoprak', 'pecel', 'warteg', 'kantin', 'kafe', 'resto', 'pizza', 'burger', 'kebab', 'rendang', 'pempek']
        : ['makan', 'minum', 'kopi'];
    final belanjaWords = useKeywordOverrides
        ? ['sepatu', 'baju', 'tas', 'jaket', 'handphone', 'laptop', 'shopee', 'tokopedia']
        : ['sepatu', 'baju', 'tas'];
    final transportasiWords = ['grab', 'gojek', 'ojek', 'taxi', 'taksi', 'bus', 'busway', 'krl', 'mrt', 'lrt', 'angkot', 'bensin', 'bbm', 'solar', 'parkir', 'tol', 'tiket'];

    // FIX 2 & FIX 3 Priority overrides
    if (hasAnyWord(lowerText, debtWords)) {
      overrideIntent = 'debt';
      overrideCategory = 'utang';
    } else if (hasAnyWord(lowerText, transferWords)) {
      // Cek dulu apakah ini transfer masuk (incoming transfer)
      if (hasAnyWord(lowerText, ['masuk', 'terima', 'dapat', 'refund', 'kembali', 'bonus'])) {
        overrideIntent = 'income';
        overrideCategory = 'pemasukan';
      } else if (hasAnyWord(lowerText, conflictExpenseWords)) {
        overrideIntent = 'expense';
        if (hasAnyWord(lowerText, tagihanWords)) {
          overrideCategory = 'tagihan';
        } else if (hasAnyWord(lowerText, makananWords)) {
          overrideCategory = 'makanan';
        } else if (hasAnyWord(lowerText, belanjaWords)) {
          overrideCategory = 'belanja';
        } else if (hasAnyWord(lowerText, transportasiWords)) {
          overrideCategory = 'transportasi';
        } else {
          overrideCategory = 'transfer';
        }
      } else {
        overrideIntent = 'transfer';
        overrideCategory = 'transfer';
      }
    } else if (hasAnyWord(lowerText, incomeWords)) {
      overrideIntent = 'income';
      overrideCategory = 'pemasukan';
    } else if (hasAnyWord(lowerText, expenseWords)) {
      overrideIntent = 'expense';
      if (hasAnyWord(lowerText, tagihanWords)) {
        overrideCategory = 'tagihan';
      } else if (hasAnyWord(lowerText, makananWords)) {
        overrideCategory = 'makanan';
      } else if (hasAnyWord(lowerText, belanjaWords)) {
        overrideCategory = 'belanja';
      } else if (hasAnyWord(lowerText, transportasiWords)) {
        overrideCategory = 'transportasi';
      }
    }

    final intent = overrideIntent ?? modelIntent;
    final category = overrideCategory ?? modelCategory;

    // Fallback amount extraction via robust adjacent multiplier match on raw sentence if it is still null or suspicious (< 1000)
    if (amount == null || amount < 1000) {
      amount = _parseAmount(rawText);
    }

    debugPrint('Final parsed entities: intent=$intent, category=$category, amount=$amount, description=$description, account=$account, confidence=$confidence');
    debugPrint('--- NERParser parsing end ---');

    // 11. Return TransactionEntity
    return TransactionEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      rawText: rawText,
      intent: intent,
      category: category,
      amount: amount,
      account: account,
      description: description,
      createdAt: DateTime.now(),
      confidence: confidence,
    );
  }

  int _argmax(List<double> probs) {
    if (probs.isEmpty) return -1;
    int maxIdx = 0;
    double maxVal = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxVal) {
        maxVal = probs[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  String? _extractEntity(List<String> tokens, List<String> labels, String entityType) {
    final List<String> entityTokens = [];
    bool collecting = false;
    for (int i = 0; i < tokens.length; i++) {
      final label = labels[i];
      if (label == 'B-$entityType') {
        collecting = true;
        entityTokens.add(tokens[i]);
      } else if (label == 'I-$entityType' && collecting) {
        entityTokens.add(tokens[i]);
      } else {
        collecting = false;
      }
    }
    if (entityTokens.isEmpty) return null;
    return entityTokens.join(' ');
  }

  int? parseAmount(String? text) => _parseAmount(text);

  int? _parseAmount(String? text) {
    if (text == null) return null;
    
    final cleanText = text.trim().toLowerCase();
    if (cleanText.isEmpty) return null;
    
    // Check specific suffix multiplier patterns
    final kRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*k\b', caseSensitive: false);
    final rbRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:rb|ribu)\b', caseSensitive: false);
    final jtRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:jt|juta)\b', caseSensitive: false);
    final mRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:m|milyar|miliar)\b', caseSensitive: false);
    final ratusRegex = RegExp(r'(\d+(?:[.,]\d+)?)\s*ratus\b', caseSensitive: false);

    double? baseVal;
    double multiplier = 1.0;

    final matchK = kRegex.firstMatch(cleanText);
    final matchRb = rbRegex.firstMatch(cleanText);
    final matchJt = jtRegex.firstMatch(cleanText);
    final matchM = mRegex.firstMatch(cleanText);
    final matchRatus = ratusRegex.firstMatch(cleanText);

    if (matchK != null) {
      baseVal = _parseBaseValue(matchK.group(1)!, hasMultiplier: true);
      multiplier = 1000.0;
    } else if (matchRb != null) {
      baseVal = _parseBaseValue(matchRb.group(1)!, hasMultiplier: true);
      multiplier = 1000.0;
    } else if (matchJt != null) {
      baseVal = _parseBaseValue(matchJt.group(1)!, hasMultiplier: true);
      multiplier = 1000000.0;
    } else if (matchM != null) {
      baseVal = _parseBaseValue(matchM.group(1)!, hasMultiplier: true);
      multiplier = 1000000000.0;
    } else if (matchRatus != null) {
      baseVal = _parseBaseValue(matchRatus.group(1)!, hasMultiplier: true);
      multiplier = 100.0;
    } else {
      // Fallback to general parsing without multiplier or general pattern
      final generalPattern = RegExp(
        r'(\d+(?:[.,]\d+)*)\s{0,2}(ribu|rb|k|juta|jt|miliar|milyar|m|ratus)?\b',
        caseSensitive: false,
      );
      final matches = generalPattern.allMatches(cleanText).toList();
      if (matches.isNotEmpty) {
        // Choose candidate match
        RegExpMatch chosenMatch;
        if (matches.length == 1) {
          chosenMatch = matches[0];
        } else {
          final matchesWithSuffix = matches.where((m) => m.group(2) != null).toList();
          if (matchesWithSuffix.isNotEmpty) {
            chosenMatch = matchesWithSuffix.last;
          } else {
            chosenMatch = matches.last;
          }
        }
        final numStr = chosenMatch.group(1)!;
        final multiplierStr = chosenMatch.group(2);
        
        baseVal = _parseBaseValue(numStr, hasMultiplier: multiplierStr != null);
        if (multiplierStr != null) {
          switch (multiplierStr.toLowerCase()) {
            case 'rb':
            case 'ribu':
            case 'k':
              multiplier = 1000.0;
              break;
            case 'jt':
            case 'juta':
              multiplier = 1000000.0;
              break;
            case 'm':
            case 'milyar':
            case 'miliar':
              multiplier = 1000000000.0;
              break;
            case 'ratus':
              multiplier = 100.0;
              break;
          }
        }
      }
    }

    if (baseVal == null) return null;
    return (baseVal * multiplier).round();
  }

  double _parseBaseValue(String numStr, {required bool hasMultiplier}) {
    if (hasMultiplier) {
      // If multiplier exists, single dot/comma is decimal separator
      final normalized = numStr.replaceAll(',', '.');
      if ('.'.allMatches(normalized).length > 1) {
        return double.tryParse(normalized.replaceAll('.', '')) ?? 0.0;
      } else {
        return double.tryParse(normalized) ?? 0.0;
      }
    } else {
      // No multiplier, determine separators
      final dotCount = '.'.allMatches(numStr).length;
      final commaCount = ','.allMatches(numStr).length;
      
      if (dotCount > 1 || commaCount > 1) {
        return double.tryParse(numStr.replaceAll('.', '').replaceAll(',', '')) ?? 0.0;
      } else if (dotCount == 1 && commaCount == 1) {
        final dotIdx = numStr.indexOf('.');
        final commaIdx = numStr.indexOf(',');
        if (dotIdx < commaIdx) { // e.g. 1.000,50
          return double.tryParse(numStr.replaceAll('.', '').replaceAll(',', '.')) ?? 0.0;
        } else { // e.g. 1,000.50
          return double.tryParse(numStr.replaceAll(',', '')) ?? 0.0;
        }
      } else if (dotCount == 1) {
        final parts = numStr.split('.');
        if (parts[1].length == 3) { // e.g. 1.000 -> thousand separator
          return double.tryParse(numStr.replaceAll('.', '')) ?? 0.0;
        } else { // e.g. 1.5 -> decimal separator
          return double.tryParse(numStr) ?? 0.0;
        }
      } else if (commaCount == 1) {
        final parts = numStr.split(',');
        if (parts[1].length == 3) { // e.g. 1,000 -> thousand separator
          return double.tryParse(numStr.replaceAll(',', '')) ?? 0.0;
        } else { // e.g. 1,5 -> decimal separator
          return double.tryParse(numStr.replaceAll(',', '.')) ?? 0.0;
        }
      } else {
        return double.tryParse(numStr) ?? 0.0;
      }
    }
  }
}
