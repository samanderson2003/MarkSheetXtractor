import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import flutter_dotenv
import 'display_page.dart';

class ImageScanningPage extends StatefulWidget {
  const ImageScanningPage({super.key});

  @override
  _ImageScanningPageState createState() => _ImageScanningPageState();
}

class _ImageScanningPageState extends State<ImageScanningPage> {
  final ImagePicker _picker = ImagePicker();
  final DataManager _dataManager = DataManager();
  List<XFile> _selectedImages = [];
  List<XFile> _pendingImages = [];
  bool _isScanning = false;
  int _currentImageIndex = 0;
  int _totalImages = 0;

  // OpenAI API configuration
  late final String _openAIApiKey; // Make it a late variable
  static const String _openAIEndpoint = 'https://api.openai.com/v1/chat/completions';

  @override
  void initState() {
    super.initState();
    // Load the API key from .env
    _openAIApiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (_openAIApiKey.isEmpty) {
      print('Error: OPENAI_API_KEY not found in .env file');
    }
    _dataManager.loadData().then((_) {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marksheet Scanner', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.deepPurple.shade400,
              Colors.deepPurple.shade800,
              Colors.indigo.shade900,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    Text(
                      'Scan Marksheets',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture or select marksheet images to extract marks',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            if (_selectedImages.isEmpty)
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300, width: 2),
                                ),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_outlined, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No images selected',
                                        style: TextStyle(color: Colors.grey, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _selectedImages.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      width: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        image: DecorationImage(
                                          image: FileImage(File(_selectedImages[index].path)),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),

                            const SizedBox(height: 24),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImages(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt),
                                    label: const Text('Camera'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple.shade100,
                                      foregroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _pickImages(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library),
                                    label: const Text('Gallery'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.deepPurple.shade100,
                                      foregroundColor: Colors.deepPurple,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_selectedImages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Text(
                                '${_selectedImages.length} image(s) selected',
                                style: TextStyle(color: Colors.grey.shade600),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _selectedImages.isEmpty || _isScanning ? null : _scanImages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isScanning
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                            : const Text(
                          'Scan Marksheets',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),

                if (_isScanning && _totalImages > 0)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Processing ($_currentImageIndex/$_totalImages)',
                              style: const TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImages(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (!cameraStatus.isGranted) {
          _showSnackBar('Camera permission is required', Colors.red);
          return;
        }
      } else {
        final storageStatus = await Permission.storage.request();
        if (!storageStatus.isGranted) {
          _showSnackBar('Storage permission is required', Colors.red);
          return;
        }
      }

      if (source == ImageSource.camera) {
        final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
        if (image != null) {
          setState(() {
            _selectedImages = [image];
          });
        }
      } else {
        final List<XFile> images = await _picker.pickMultiImage(imageQuality: 80);
        if (images.isNotEmpty) {
          setState(() {
            _selectedImages = images;
          });
        }
      }
    } catch (e) {
      _showSnackBar('Error selecting images: $e', Colors.red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _scanImages() async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isScanning = true;
      _pendingImages = List.from(_selectedImages);
      _selectedImages.clear();
      _currentImageIndex = 0;
      _totalImages = _pendingImages.length;
    });

    int successfulScans = 0;

    while (_pendingImages.isNotEmpty) {
      final image = _pendingImages.first;
      setState(() {
        _currentImageIndex++;
      });

      try {
        final result = await _processImageWithOpenAI(image);
        if (result != null) {
          _dataManager.addMarksheetData(result);
          successfulScans++;
        } else {
          _showSnackBar('Failed to process image ${_currentImageIndex}', Colors.red);
        }
      } catch (e) {
        _showSnackBar('Error processing image ${_currentImageIndex}: $e', Colors.red);
      }

      setState(() {
        _pendingImages.removeAt(0);
      });
    }

    setState(() {
      _isScanning = false;
      _currentImageIndex = 0;
      _totalImages = 0;
    });

    if (successfulScans > 0) {
      _showSnackBar('Successfully scanned $successfulScans marksheet(s)', Colors.green);
      if (successfulScans < _totalImages) {
        _showSnackBar('${_totalImages - successfulScans} image(s) failed to process', Colors.orange);
      }
    } else {
      _showSnackBar('No images were processed successfully', Colors.red);
    }
  }

  Future<MarksheetData?> _processImageWithOpenAI(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      final response = await http.post(
        Uri.parse(_openAIEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAIApiKey', // Use the loaded API key
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                  'Extract the registration number, each mark of Part A (10 questions, 2 marks each), '
                      'each mark of Part B (4 questions, 10 marks each, where students answer any 3 out of 4), '
                      'Part A total, Part B total, final total, and percentage from the provided mark sheet image. '
                      'For Part B, include all 4 marks, setting the unanswered question to 0 or null if not provided. '
                      'Format the response as a clean JSON object with keys: regNo, partA (array of 10 numbers), '
                      'partB (array of 4 numbers), finalTotal, and percentage. '
                      'Return ONLY the JSON object without any markdown formatting, code blocks, or additional text.',
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,$base64Image',
                  },
                },
              ],
            },
          ],
          'max_tokens': 1000,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final content = responseData['choices'][0]['message']['content'];

        try {
          final extractedData = jsonDecode(content);
          if (_isValidData(extractedData)) {
            return MarksheetData.fromJson({
              ...extractedData,
              'imageSource': image.path,
            });
          } else {
            throw Exception('Invalid data format');
          }
        } catch (e) {
          print('Error parsing JSON: $e');
          return null;
        }
      } else {
        throw Exception('OpenAI API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  bool _isValidData(Map<String, dynamic> data) {
    return data['regNo'] != null &&
        data['regNo'].isNotEmpty &&
        data['partA'] is List &&
        (data['partA'] as List).length == 10 &&
        (data['partA'] as List).every((mark) => mark is int) &&
        data['partB'] is List &&
        (data['partB'] as List).length == 4 &&
        (data['partB'] as List).every((mark) => mark == null || mark is int) &&
        (data['partB'] as List).where((mark) => mark != null && mark > 0).length <= 4 &&
        data['finalTotal'] is int &&
        data['percentage'] is num;
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}