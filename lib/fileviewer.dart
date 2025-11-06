import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:photo_view/photo_view.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import 'l10n/app_localizations.dart';

class FileViewerPage extends StatefulWidget {
  final String downloadUrl;
  final String fileName;
  final int? fileType;
  final String guid;
  final String userId;
  final String compId;
  final String? fileid;

  const FileViewerPage({
    Key? key,
    required this.downloadUrl,
    required this.fileName,
    this.fileType,
    required this.guid,
    required this.userId,
    required this.compId,
    required this.fileid,
  }) : super(key: key);

  @override
  State<FileViewerPage> createState() => _FileViewerPageState();
}

class _FileViewerPageState extends State<FileViewerPage>
    with WidgetsBindingObserver {
  String? localFilePath;
  bool isLoading = true;
  String? fileExtension;
  bool _useFallbackViewer = false;
  int _totalPages = 0;
  int _currentPage = 0;
  PDFViewController? _pdfViewController;
  double _downloadProgress = 0.0;
  late final WebViewController _webViewController;
  bool _isWebView = false;
  String? _webViewUrl;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // For image handling
  img.Image? _tiffImage;
  bool _isTiffLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadFile();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoController();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_videoController != null) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        _videoController!.pause();
      } else if (state == AppLifecycleState.resumed) {
        // Resume video if it was playing
        if (_videoController!.value.isInitialized) {
          _videoController!.play();
        }
      }
    }
  }

  Future<void> _loadFile() async {
    try {
      print("Starting file load for: ${widget.fileName}");
      localFilePath = await _downloadFile(widget.downloadUrl, widget.fileName);
      final extension = widget.fileName.split('.').last.toLowerCase();

      print("guid ${widget.guid}");
      print("userId ${widget.userId}");
      print("compId ${widget.compId}");
      print("extension $extension");

      if (extension == 'bmf' ||
          extension == 'a3dasm' ||
          extension == 'a3dprt') {
        print("Opening BMF file directly");
        _openBmfFile();
        return;
      }

      if (extension == 'tif' || extension == 'tiff') {
        await _loadTiffImage();
        return;
      }

      if (extension == 'mp4') {
        print("Detected MP4 file, validating...");

        // Validate file before initializing video player
        final isValid = await _validateVideoFile(localFilePath!);
        if (!isValid) {
          throw Exception('Invalid or corrupted MP4 file');
        }

        print("MP4 validation passed, initializing video player");
        await _initializeVideoPlayerSafely();
        return;
      }

      if (await File(localFilePath!).exists()) {
        setState(() {
          fileExtension = extension;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to save file to temporary directory');
      }
    } catch (e) {
      print("CRITICAL ERROR in _loadFile: $e");
      print("Stack trace: ${StackTrace.current}");
      if (mounted) {
        setState(() {
          isLoading = false;
          localFilePath = null;
        });

        // Show user-friendly error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load video: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<bool> _validateVideoFile(String filePath) async {
    try {
      final file = File(filePath);

      // Check if file exists and has content
      if (!await file.exists()) {
        print("Video file does not exist");
        return false;
      }

      final fileSize = await file.length();
      print("Video file size: $fileSize bytes");

      if (fileSize < 1024) {
        // Less than 1KB is suspicious for a video
        print("Video file too small, likely corrupted");
        return false;
      }

      // Read first few bytes to check MP4 signature
      final bytes = await file.openRead(0, 32).toList();
      final allBytes = bytes.expand((list) => list).toList();

      if (allBytes.length >= 8) {
        // Check for MP4 file signature (ftyp box)
        bool hasValidSignature = false;
        for (int i = 0; i < allBytes.length - 4; i++) {
          if (allBytes[i] == 0x66 && // 'f'
              allBytes[i + 1] == 0x74 && // 't'
              allBytes[i + 2] == 0x79 && // 'y'
              allBytes[i + 3] == 0x70) {
            // 'p'
            hasValidSignature = true;
            break;
          }
        }

        if (!hasValidSignature) {
          print("Invalid MP4 signature detected");
          return false;
        }
      }

      print("Video file validation passed");
      return true;
    } catch (e) {
      print("Error validating video file: $e");
      return false;
    }
  }

  Future<void> _initializeVideoPlayerSafely() async {
    try {
      await _disposeVideoController();
      final file = File(localFilePath!);
      _videoController = VideoPlayerController.file(
        file,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _videoController!.addListener(_videoPlayerListener);
      await _videoController!.initialize().timeout(Duration(seconds: 15));
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          fileExtension = 'mp4';
          isLoading = false;
        });
        await _videoController!.setVolume(0.2); // Lower to reduce load
        await _videoController!.setLooping(false);
        // Delay play to avoid immediate rendering
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted && _videoController != null) {
            _videoController!.play();
          }
        });
      }
    } catch (e) {
      print("Video init error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video failed: $e')),
        );
        setState(() {
          isLoading = false;
          _isVideoInitialized = false;
        });
      }
    }
  }

  void _videoPlayerListener() {
    if (_videoController?.value.hasError == true) {
      print("Video player error: ${_videoController!.value.errorDescription}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Video playback error: ${_videoController!.value.errorDescription}'),
            duration: const Duration(seconds: 5),
          ),
        );
        setState(() {
          _isVideoInitialized = false;
          isLoading = false;
        });
      }
    }
  }

  Future<void> _disposeVideoController() async {
    if (_videoController != null) {
      print("Disposing video controller");
      try {
        _videoController!.removeListener(_videoPlayerListener);
        await _videoController!.pause();
        await _videoController!.dispose();
      } catch (e) {
        print("Error disposing video controller: $e");
      }
      _videoController = null;
      _isVideoInitialized = false;
    }
  }

  Future<void> _loadTiffImage() async {
    try {
      final bytes = await File(localFilePath!).readAsBytes();
      final decodedImage = img.decodeTiff(bytes);

      if (decodedImage != null) {
        if (mounted) {
          setState(() {
            _tiffImage = decodedImage;
            _isTiffLoading = false;
            isLoading = false;
            fileExtension = 'tiff';
          });
        }
      } else {
        print("Failed to decode TIFF, trying regular image viewer");
        if (mounted) {
          setState(() {
            isLoading = false;
            fileExtension = widget.fileName.split('.').last.toLowerCase();
          });
        }
      }
    } catch (e) {
      print("Error loading TIFF image: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          fileExtension = widget.fileName.split('.').last.toLowerCase();
        });
      }
    }
  }

  Future<String> _downloadFile(String url, String filename) async {
    try {
      // final directory = Directory('/storage/emulated/0/Download');
      final directory = await getApplicationDocumentsDirectory();
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final safeFileName = filename.replaceAll(RegExp(r'[^\w\d.]+'), '_');
      final filePath = '${directory.path}/$safeFileName';
      print("filePath download $filePath");

      final dio = Dio();
      dio.options.receiveTimeout = const Duration(minutes: 5);

      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            if (mounted) {
              setState(() {
                _downloadProgress = received / total;
              });
            }
            print(
                'Download progress: ${(_downloadProgress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      final file = File(filePath);
      final fileSize = await file.length();
      if (fileSize == 0) {
        throw Exception('Downloaded file is empty');
      }

      return filePath;
    } on DioException catch (e) {
      throw Exception('Download failed: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected download error: $e');
    }
  }

  void _openBmfFile() async {
    final loc = AppLocalizations.of(context);
    print("Attempting to open BMF file");
    try {
      final guid = widget.guid;

      String timestamp = DateFormat("yyyy/MM/dd HH:mm").format(DateTime.now());
      String auth = base64Encode(
          utf8.encode("${widget.compId}-${widget.userId}-$timestamp"));

      print("Generated Timestamp: $timestamp");
      print("Generated Auth Token: $auth");

      String viewerUrl =
          "https://www.alfadock-pack.com/a3dviewer/#/viewer/${widget.fileid}?userid=${widget.userId}&device='ios'&auth=$auth";

      print("Opening A3D Viewer: $viewerUrl");

      setState(() {
        _isWebView = true;
        _webViewUrl = viewerUrl;
        isLoading = false;
      });

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(viewerUrl));
    } catch (e) {
      print("Error opening BMF file: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.failedto} $e')),
        );
      }
    }
  }

  bool _isSupportedExtension(String ext) {
    final supportedExtensions = [
      'pdf',
      'dwg',
      'dxf',
      'pptx',
      'docx',
      'xlsx',
      'ppt',
      'csv',
      'jpg',
      'jpeg',
      'png',
      'gif',
      'tif',
      'tiff',
      'bmf',
      'a3dasm',
      'a3dprt',
      'mp4',
    ];
    return supportedExtensions.contains(ext.toLowerCase());
  }

  bool _isImageFile(String extension) {
    final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'tif', 'tiff'];
    return imageExtensions.contains(extension.toLowerCase());
  }

  bool _isVideoFile(String extension) {
    return extension.toLowerCase() == 'mp4';
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

  Widget _buildFallbackPdfViewer() {
    final loc = AppLocalizations.of(context);
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
        if (mounted) {
          setState(() {
            _totalPages = pages!;
          });
        }
      },
      onViewCreated: (PDFViewController controller) {
        _pdfViewController = controller;
      },
      onPageChanged: (int? page, int? total) {
        if (page != null && mounted) {
          setState(() {
            _currentPage = page;
          });
        }
      },
      onError: (error) {
        print('error $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${loc.failedtoload}: $error')),
          );
        }
      },
    );
  }

  Widget _buildPdfViewer() {
    if (_useFallbackViewer) {
      print("Using fallback PDF viewer");
      return _buildFallbackPdfViewer();
    } else {
      return _buildFallbackPdfViewer();
    }
  }

  Widget _buildImageViewer() {
    return PhotoView(
      imageProvider: FileImage(File(localFilePath!)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 2,
    );
  }

  Widget _buildTiffViewer() {
    if (_isTiffLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tiffImage == null) {
      return const Center(child: Text('Failed to load TIFF image'));
    }

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.memory(
          Uint8List.fromList(img.encodePng(_tiffImage!)),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildVideoViewer() {
    if (_videoController == null || !_isVideoInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing video player...'),
          ],
        ),
      );
    }

    if (!_videoController!.value.isInitialized) {
      return const Center(child: Text('Video failed to initialize'));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio.isFinite
            ? _videoController!.value.aspectRatio
            : 16 / 9,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_videoController!),
            Positioned(
              bottom: 50,
              left: 20,
              right: 20,
              child: VideoProgressIndicator(
                _videoController!,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.blue,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.black26,
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              //  tip: you can make this file public by clicking the share icon
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: ValueListenableBuilder(
                  valueListenable: _videoController!,
                  builder: (context, VideoPlayerValue value, child) {
                    return IconButton(
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () async {
                        if (_videoController != null &&
                            _videoController!.value.isInitialized) {
                          if (value.isPlaying) {
                            await _videoController!.pause();
                          } else {
                            await _videoController!.play();
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ValueListenableBuilder(
                  valueListenable: _videoController!,
                  builder: (context, value, child) {
                    final position = value.position;
                    final duration = value.duration;
                    return Text(
                      '${_formatDuration(position)} / ${_formatDuration(duration)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  Widget _buildPageIndicator() {
    final loc = AppLocalizations.of(context);
    if (!_useFallbackViewer || _totalPages <= 1) return const SizedBox();

    return Positioned(
      bottom: 16,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '${loc.page} ${_currentPage + 1} of $_totalPages',
          style: const TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.fileName, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color.fromARGB(255, 85, 161, 236),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '${loc.downloading}: ${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : _isWebView
              ? WebViewWidget(controller: _webViewController)
              : localFilePath == null
                  ? Center(child: Text(loc.failedtoload))
                  : Stack(
                      children: [
                        if (_isVideoFile(fileExtension!))
                          _buildVideoViewer()
                        else if (_isImageFile(fileExtension!))
                          (fileExtension == 'tif' || fileExtension == 'tiff')
                              ? _buildTiffViewer()
                              : _buildImageViewer()
                        else if (_isPdfLikeFile(fileExtension!))
                          _buildPdfViewer()
                        else
                          Center(child: Text(loc.unsupportfile)),
                        _buildPageIndicator(),
                      ],
                    ),
    );
  }
}
