import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'scanning_page.dart'; // Import ImageScanningPage to navigate for rescanning

// Data Models
class MarksheetData {
  final String regNo;
  final List<int> partA; // 10 questions, 2 marks each
  final List<int?> partB; // 4 questions, 10 marks each, 3 answered
  final int partATotal;
  final int partBTotal;
  final int finalTotal;
  final double percentage;
  final String? imageSource;
  final DateTime scannedAt;

  MarksheetData({
    required this.regNo,
    required this.partA,
    required this.partB,
    required this.partATotal,
    required this.partBTotal,
    required this.finalTotal,
    required this.percentage,
    this.imageSource,
    required this.scannedAt,
  });

  factory MarksheetData.fromJson(Map<String, dynamic> json) {
    return MarksheetData(
      regNo: json['regNo'] ?? '',
      partA: List<int>.from(json['partA'] ?? []),
      partB: (json['partB'] as List<dynamic>?)?.map((e) => e != null ? e as int : null).toList() ?? [null, null, null, null],
      partATotal: (json['partA'] as List<dynamic>?)?.fold<int>(0, (sum, mark) => sum + (mark as int)) ?? 0,
      partBTotal: (json['partB'] as List<dynamic>?)?.fold<int>(0, (sum, mark) => sum + (mark as int? ?? 0)) ?? 0,
      finalTotal: json['finalTotal'] ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      imageSource: json['imageSource'],
      scannedAt: json['scanned_at'] != null ? DateTime.parse(json['scanned_at']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regNo': regNo,
      'partA': partA,
      'partB': partB,
      'partATotal': partATotal,
      'partBTotal': partBTotal,
      'finalTotal': finalTotal,
      'percentage': percentage,
      'imageSource': imageSource,
      'scanned_at': scannedAt.toIso8601String(),
    };
  }
}

// Data Manager for temporary storage and persistence
class DataManager {
  // ignore: invalid_use_of_private_type_in_public_api
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final List<MarksheetData> _marksheetData = [];
  static const String _storageKey = 'scannedData';

  List<MarksheetData> get marksheetData => List.unmodifiable(_marksheetData);

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString(_storageKey);
    if (storedData != null) {
      final List<dynamic> jsonData = jsonDecode(storedData);
      _marksheetData.clear();
      _marksheetData.addAll(jsonData.map((json) => MarksheetData.fromJson(json)).toList());
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_marksheetData.map((data) => data.toJson()).toList()));
  }

  void addMarksheetData(MarksheetData data) {
    _marksheetData.add(data);
    saveData();
  }

  void updateMarksheetData(int index, MarksheetData data) {
    _marksheetData[index] = data;
    saveData();
  }

  void deleteMarksheetData(int index) {
    _marksheetData.removeAt(index);
    saveData();
  }

  void clearData() {
    _marksheetData.clear();
    saveData();
  }

  bool get hasData => _marksheetData.isNotEmpty;
}

// Data Display and Export Page
class DataDisplayPage extends StatefulWidget {
  const DataDisplayPage({super.key});

  @override
  _DataDisplayPageState createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage> {
  final DataManager _dataManager = DataManager();
  bool _isExporting = false;
  static const String _excelFileName = 'marksheet_data.xlsx';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Scanned Data', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF007AFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [], // Removed the camera IconButton as per previous request
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Marksheet Data',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: const Color(0xFF333333),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_dataManager.marksheetData.length} marksheet(s) scanned',
                style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Data List
              Expanded(
                child: _dataManager.hasData
                    ? ListView.builder(
                  itemCount: _dataManager.marksheetData.length,
                  itemBuilder: (context, index) {
                    final data = _dataManager.marksheetData[index];
                    return _buildMarksheetCard(data, index);
                  },
                )
                    : const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Color(0xFF999999)),
                      SizedBox(height: 16),
                      Text(
                        'No data available',
                        style: TextStyle(
                          color: Color(0xFF999999),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Export Button
              ElevatedButton.icon(
                onPressed: _dataManager.hasData && !_isExporting ? _exportToExcel : null,
                icon: _isExporting
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Icon(Icons.file_download),
                label: Text(_isExporting ? 'Exporting...' : 'Export to Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),

              const SizedBox(height: 16),

              // Clear Data Button
              TextButton(
                onPressed: _dataManager.hasData ? _clearAllData : null,
                child: Text(
                  'Clear All Data',
                  style: TextStyle(
                    color: _dataManager.hasData ? const Color(0xFFFF3B30) : const Color(0xFF999999),
                    decoration: TextDecoration.underline,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMarksheetCard(MarksheetData data, int index) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Marksheet #${index + 1}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF007AFF)),
                      onPressed: () => _showEditDialog(data, index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Color(0xFFFF3B30)),
                      onPressed: () => _deleteMarksheet(index),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reg No: ${data.regNo}',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF666666),
              ),
            ),
            const SizedBox(height: 12),

            // Part A
            const Text(
              'Part A',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(10, (i) => Text(
                'Q${i + 1}: ${data.partA[i]}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
              )),
            ),
            const SizedBox(height: 12),

            // Part B
            const Text(
              'Part B',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: List.generate(4, (i) => Text(
                'Q${i + 1}: ${data.partB[i] ?? 0}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF555555)),
              )),
            ),
            const SizedBox(height: 12),

            // Totals
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Part A Total:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  '${data.partATotal}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Part B Total:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  '${data.partBTotal}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Final Total:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  '${data.finalTotal}',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Percentage:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF333333),
                  ),
                ),
                Text(
                  '${data.percentage.toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                ),
              ],
            ),

            // Image Preview
            if (data.imageSource != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(data.imageSource!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showEditDialog(MarksheetData data, int index) {
    final regNoController = TextEditingController(text: data.regNo);
    final List<TextEditingController> partAControllers = List.generate(
      10,
          (i) => TextEditingController(text: data.partA[i].toString()),
    );
    final List<TextEditingController> partBControllers = List.generate(
      4,
          (i) => TextEditingController(text: data.partB[i]?.toString() ?? '0'),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Edit Marksheet #${index + 1}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: regNoController,
                  decoration: const InputDecoration(labelText: 'Registration Number'),
                ),
                const SizedBox(height: 16),
                const Text('Part A', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(10, (i) {
                    return SizedBox(
                      width: 80,
                      child: TextField(
                        controller: partAControllers[i],
                        decoration: InputDecoration(labelText: 'Q${i + 1}'),
                        keyboardType: TextInputType.number,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text('Part B', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(4, (i) {
                    return SizedBox(
                      width: 80,
                      child: TextField(
                        controller: partBControllers[i],
                        decoration: InputDecoration(labelText: 'Q${i + 1}'),
                        keyboardType: TextInputType.number,
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF007AFF))),
            ),
            TextButton(
              onPressed: () {
                // Update the marksheet data
                final updatedPartA = partAControllers.map((controller) {
                  return int.tryParse(controller.text) ?? 0;
                }).toList();

                final updatedPartB = partBControllers.map((controller) {
                  final value = int.tryParse(controller.text);
                  return value != 0 ? value : null;
                }).toList();

                final partATotal = updatedPartA.fold<int>(0, (sum, mark) => sum + mark);
                final partBTotal = updatedPartB.fold<int>(0, (sum, mark) => sum + (mark ?? 0));
                final finalTotal = partATotal + partBTotal;
                final percentage = (finalTotal / 50) * 100;

                final updatedData = MarksheetData(
                  regNo: regNoController.text,
                  partA: updatedPartA,
                  partB: updatedPartB,
                  partATotal: partATotal,
                  partBTotal: partBTotal,
                  finalTotal: finalTotal,
                  percentage: percentage,
                  imageSource: data.imageSource,
                  scannedAt: data.scannedAt,
                );

                _dataManager.updateMarksheetData(index, updatedData);
                setState(() {});
                Navigator.of(context).pop();
                _showSnackBar('Marksheet updated successfully', const Color(0xFF4CD964));
              },
              child: const Text('Save', style: TextStyle(color: Color(0xFF007AFF))),
            ),
          ],
        );
      },
    );
  }

  void _deleteMarksheet(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Delete Marksheet #${index + 1}'),
          content: const Text('Are you sure you want to delete this marksheet? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF007AFF))),
            ),
            TextButton(
              onPressed: () {
                _dataManager.deleteMarksheetData(index);
                setState(() {});
                Navigator.of(context).pop();
                _showSnackBar('Marksheet deleted', const Color(0xFFFF9500));
                // Ask if the user wants to rescan
                _showRescanDialog();
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
            ),
          ],
        );
      },
    );
  }

  void _showRescanDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Rescan Image'),
          content: const Text('Would you like to capture a new image to replace the deleted marksheet?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('No', style: TextStyle(color: Color(0xFF007AFF))),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ImageScanningPage()),
                );
              },
              child: const Text('Yes', style: TextStyle(color: Color(0xFF007AFF))),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isExporting = true;
    });

    try {
      // Request storage permission
      final storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        _showSnackBar('Storage permission is required for export', const Color(0xFFFF3B30));
        return;
      }

      // Initialize Excel file
      final excel = Excel.createExcel();
      final sheet = excel['Marksheets'];

      // Define headers
      final headers = [
        'Registration Number',
        'Part A Q1', 'Part A Q2', 'Part A Q3', 'Part A Q4', 'Part A Q5',
        'Part A Q6', 'Part A Q7', 'Part A Q8', 'Part A Q9', 'Part A Q10',
        'Part B Q1', 'Part B Q2', 'Part B Q3', 'Part B Q4',
        'Part A Total', 'Part B Total', 'Final Total', 'Percentage'
      ];

      // Add headers
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).value = TextCellValue(headers[i]);
      }

      // Add data
      for (int rowIndex = 0; rowIndex < _dataManager.marksheetData.length; rowIndex++) {
        final data = _dataManager.marksheetData[rowIndex];
        int colIndex = 0;

        // Registration number
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = TextCellValue(data.regNo);

        // Part A marks
        for (int i = 0; i < 10; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = IntCellValue(data.partA[i]);
        }

        // Part B marks
        for (int i = 0; i < 4; i++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = IntCellValue(data.partB[i] ?? 0);
        }

        // Totals and percentage
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = IntCellValue(data.partATotal);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = IntCellValue(data.partBTotal);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = IntCellValue(data.finalTotal);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex + 1)).value = DoubleCellValue(data.percentage);
      }

      // Save file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_excelFileName';
      final file = File(filePath);
      await file.writeAsBytes(excel.encode()!);

      _showSnackBar('Excel file exported successfully', const Color(0xFF4CD964));

      // Open the file
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        _showSnackBar('Could not open file: ${result.message}', const Color(0xFFFF3B30));
      }
    } catch (e) {
      _showSnackBar('Error exporting to Excel: $e', const Color(0xFFFF3B30));
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _clearAllData() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Clear All Data'),
          content: const Text('Are you sure you want to clear all scanned data? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF007AFF))),
            ),
            TextButton(
              onPressed: () {
                _dataManager.clearData();
                setState(() {});
                Navigator.of(context).pop();
                _showSnackBar('All data cleared', const Color(0xFFFF9500));
              },
              child: const Text('Clear', style: TextStyle(color: Color(0xFFFF3B30))),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}