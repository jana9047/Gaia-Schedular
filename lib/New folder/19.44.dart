import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

class FileViewerPage extends StatefulWidget {
  final String downloadUrl;
  final String fileName;
  final int? fileType;
  final String guid;
  final String userId;
  final String compId;
  final String? fileid;

  const FileViewerPage(
      {Key? key,
      required this.downloadUrl,
      required this.fileName,
      this.fileType,
      required this.guid,
      required this.userId,
      required this.compId,
      required this.fileid})
      : super(key: key);

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage> {
  String? localFilePath;
  bool isLoading = true;
  String? fileExtension;
  bool _useFallbackViewer = false;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    try {
      final response = await http.get(Uri.parse(widget.downloadUrl));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        String extension = _determineFileExtension(bytes, response.headers);

        print("guid ${widget.guid}");
        print("userId ${widget.userId}");
        print("compId ${widget.compId}");
        print("extension ${extension.toLowerCase()}");
        if (extension.toLowerCase() == 'bmf' ||
            extension.toLowerCase() == 'a3ddasm' ||
            extension.toLowerCase() == 'a3dprt') {
          print("Opening BMF file directly");
          setState(() {
            fileExtension = 'bmf';
            isLoading = false;
          });

          _openBmfFile();
          return;
        }
        // Save the file
        final dir = await getTemporaryDirectory();
        final safeFileName =
            widget.fileName.replaceAll(RegExp(r'[^\w\d.]+'), '_');
        final file = File('${dir.path}/$safeFileName.$extension');

        setState(() {
          localFilePath = file.path;
          isLoading = false;
          fileExtension = extension;
        });
        switch (extension) {
          case 'pdf':
          case 'PDF':
          case 'dwg':
          case 'DWG':
          case 'dxf':
          case 'DXF':
          case 'pptx':
          case 'PPTX':
          case 'docx':
          case 'DOCX':
          case 'xlsx':
          case 'ppt':
          case 'PPT':
          case 'XLSX':
          case 'csv':
          case 'CSV':
            return PdfViewerScreen(filePath: filePath, fileName: fileName);
          case 'jpg':
          case 'JPG':
          case 'jpeg':
          case 'JPEG':
          case 'png':
          case 'PNG':
          case 'gif':
          case 'GIF':
            return ImageViewerScreen(filePath: filePath, fileName: fileName);

          // return PptViewerScreen(filePath: filePath);
          case 'tif':
          case 'tiff':
          case 'TIFF':
          case 'TIF':
            return TifViewerScreen(filePath: filePath, fileName: fileName);
          default:
            return Scaffold(
              body: Center(child: Text('Unsupported file format')),
            );
        }
      } else {
        throw Exception('Failed to download file: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        localFilePath = null;
      });
    }
  }

  void _openBmfFile() async {
    print("Attempting to open BMF file");
    try {
      // Extract GUID from the download URL or filename
      // This assumes the GUID is part of the URL or filename
      final guid = widget.guid;

      // Generate timestamp and auth token
      String timestamp = DateFormat("yyyy/MM/dd HH:mm").format(DateTime.now());
      String auth = base64Encode(
          utf8.encode("${widget.compId}-${widget.userId}-$timestamp"));

      print("Generated Timestamp: $timestamp");
      print("Generated Auth Token: $auth");

      // Construct the A3D viewer URL
      String viewerUrl =
          "https://www.alfadock-pack.com/a3dviewer/#/viewer/${widget.fileid}?userid=${widget.userId}&device=ios&auth=$auth";

      print("Opening A3D Viewer: $viewerUrl");

      // Launch the A3D viewer (you'll need to implement this based on your app's navigation)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WebViewScreen(url: viewerUrl),
        ),
      );
    } catch (e) {
      print("Error opening BMF file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open BMF file: $e')),
      );
    }
  }

  String _determineFileExtension(Uint8List bytes, Map<String, String> headers) {
    // Get extension from filename first
    final fileName = widget.fileName.toLowerCase();
    final nameParts = fileName.split('.');
    print("nameParts $nameParts");
    if (nameParts.length > 1) {
      final ext = nameParts.last;
      if (_isSupportedExtension(ext)) {
        return ext;
      }
    }

    // Check magic numbers for file type detection
    // PDF magic number (%PDF)
    if (bytes.length >= 4 &&
        bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'pdf';
    }

    // JPEG magic number
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }

    // PNG magic number
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }

    // Check content-type header
    final contentType = headers['content-type']?.toLowerCase();
    if (contentType != null) {
      if (contentType.contains('pdf')) return 'pdf';
      if (contentType.contains('image/jpeg')) return 'jpg';
      if (contentType.contains('image/png')) return 'png';
      if (contentType.contains('image/tiff') ||
          contentType.contains('image/tif')) return 'tif';
    }

    // Default to pdf if uncertain
    return 'pdf';
  }

  bool _isSupportedExtension(String ext) {
    final supportedExtensions = [
      'pdf',
      'PDF',
      'dwg',
      'DWG',
      'dxf',
      'DXF',
      'pptx',
      'PPTX',
      'docx',
      'DOCX',
      'xlsx',
      'ppt',
      'PPT',
      'XLSX',
      'csv',
      'CSV',
      'jpg',
      'JPG',
      'jpeg',
      'JPEG',
      'png',
      'PNG',
      'gif',
      'GIF',
      'tif',
      'tiff',
      'TIFF',
      'TIF',
      'a3dasm',
      'a3dprt'
    ];
    return supportedExtensions.contains(ext);
  }

  bool _isImageFile(String extension) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'tif', 'tiff'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  bool _isPdfLikeFile(String extension) {
    final pdfLikeExtensions = [
      'pdf',
      'dwg',
      'dxf',
      'pptx',
      'docx',
      'xlsx',
      'ppt',
      'csv'
    ];
    return pdfLikeExtensions.contains(extension.toLowerCase());
  }

  void _onSyncfusionLoadFailed(PdfDocumentLoadFailedDetails details) {
    setState(() {
      _useFallbackViewer = true;
    });
  }

  Widget _buildFallbackPdfViewer() {
    return PDFView(
      filePath: localFilePath!,
      enableSwipe: true,
      swipeHorizontal: true,
      autoSpacing: false,
      pageFling: true,
      pageSnap: true,
      defaultPage: 0,
      fitPolicy: FitPolicy.BOTH,
      onRender: (pages) {
        setState(() {
          _totalPages = pages!;
        });
      },
      onViewCreated: (PDFViewController controller) {
        _pdfViewController = controller;
      },
      onPageChanged: (int? page, int? total) {
        if (page != null) {
          setState(() {
            _currentPage = page;
          });
        }
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load file: $error')),
        );
      },
    );
  }

  Widget _buildPdfViewer() {
    if (_useFallbackViewer) {
      return _buildFallbackPdfViewer();
    } else {
      return SfPdfViewer.file(
        File(localFilePath!),
        enableTextSelection: true,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        onDocumentLoaded: (PdfDocumentLoadedDetails details) {
          print("PDF document loaded successfully");
        },
        onDocumentLoadFailed: _onSyncfusionLoadFailed,
      );
    }
  }

  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: FileImage(File(localFilePath!)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
    );
  }

  Widget _buildPageIndicator() {
    if (!_useFallbackViewer || _totalPages <= 1) return SizedBox();

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Page ${_currentPage + 1} of $_totalPages',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName, style: TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 85, 161, 236),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : localFilePath == null
              ? Center(child: Text("Error loading file"))
              : Stack(
                  children: [
                    if (_isImageFile(fileExtension!))
                      _buildImageViewer()
                    else if (_isPdfLikeFile(fileExtension!))
                      _buildPdfViewer()
                    else
                      Center(child: Text('Unsupported file format')),
                    _buildPageIndicator(),
                  ],
                ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final String url;
  const WebViewScreen({super.key, required this.url});

  @override
  _WebViewScreenState createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFD8CAB8),
        title: Text('Default Title'),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.black),
            onPressed: () {
              // Navigator.pushAndRemoveUntil(
              //   context,
              //   MaterialPageRoute(
              //       builder: (context) =>
              //           HomeScreen(compId: '$CompanyId', userID: '$UserID1')),
              //   (route) => false,
              // );
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  //  final int totalPages;

  const PdfViewerScreen(
      {super.key, required this.filePath, required this.fileName});

  @override
  _PdfViewerScreenState createState() => _PdfViewerScreenState();
}

class PdfDimensions {
  final double width;
  final double height;
  final int totalPages; // Add this field

  PdfDimensions({
    required this.width,
    required this.height,
    required this.totalPages, // Initialize this field
  });

  int get numberOfPages => totalPages; // Add this getter
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  bool _isLoading = true;
  int _totalPages = 0;
  int _currentPage = 0;
  PdfDimensions? _pdfDimensions;

  @override
  void initState() {
    super.initState();
    _loadPdfDetails(); // Load PDF details on screen initialization
  }

  Future<void> _loadPdfDetails() async {
    print("usertype $usertype");
    print("hi");
    try {
      await Future.delayed(Duration(milliseconds: 500));
      final document = await pdfx.PdfDocument.openFile(widget.filePath);
      final page = await document.getPage(1);
      final totalPages = document.pagesCount;
      print("original dimensions height ${page.height} width ${page.width}");
      double height = page.height.toDouble();
      double width = page.width.toDouble();

      // Swap width & height if iOS detects it incorrectly
      // if (width > height) {
      //   double temp = width;
      //   width = height;
      //   height = temp;
      // }

      print("Final Height: $height Width: $width");

      setState(() {
        _pdfDimensions = PdfDimensions(
          width: width,
          height: height,
          totalPages: totalPages,
        );
        _totalPages = totalPages;
        _isLoading = false;
      });

      await page.close();
      await document.close();
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load PDF details: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFA7F8DD),
        title: Text(widget.fileName),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.black),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => HomeScreen(
                    compId: '$CompanyId',
                    userID: '$UserID1',
                  ),
                ),
                (route) => false,
              );
            },
          ),
          // Edit Icon with condition
          IgnorePointer(
            ignoring: usertype != 'Admin', // Disable if not admin
            child: Opacity(
              opacity: usertype == 'Admin' ? 1.0 : 0.4, // Dim if not admin
              child: IconButton(
                icon: const Icon(Icons.edit, color: Colors.black),
                onPressed: () {
                  if (_pdfDimensions != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DrawingScreen(
                          filePath: widget.filePath,
                          fileName: widget.fileName,
                          pdfDimensions: _pdfDimensions!,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PDF dimensions are not available.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            swipeHorizontal: true,
            autoSpacing: false,
            pageFling: true,
            pageSnap: true,
            defaultPage: 0,
            fitPolicy:
                FitPolicy.BOTH, // Adjusts width and height for better clarity
            preventLinkNavigation: false,
            onRender: (pages) {
              setState(() {
                _totalPages = pages!;
              });
            },
            onError: (error) {
              setState(() {
                _isLoading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${loc.failedto} $error'),
                ),
              );
            },
            onPageChanged: (int? page, int? total) {
              if (page != null) {
                setState(() {
                  _currentPage = page;
                });
              }
            },
          ),
          if (_isLoading) Center(child: CircularProgressIndicator()),
          if (!_isLoading)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Page ${_currentPage + 1} of $_totalPages',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
