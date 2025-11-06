// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:intl/intl.dart'; // For date formatting

// class CameraPage extends StatefulWidget {
//   final String compId;
//   final String userId;
//   final String? folderId;

//   const CameraPage(
//       {super.key, required this.compId, required this.userId, this.folderId});

//   @override
//   _CameraPageState createState() => _CameraPageState();
// }

// class _CameraPageState extends State<CameraPage> {
//   @override
//   void initState() {
//     super.initState();
//     _openCamera();
//   }

//   Future<void> _openCamera() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.camera);

//     if (pickedFile != null) {
//       final _image = File(pickedFile.path);
//       await _uploadImage(_image);
//     } else {
//       Navigator.pop(context); // Go back if camera is cancelled
//     }
//   }

//   Future<String?> _uploadImage(File image) async {
//     print('Uploading image: ${image.path}');
//     final today = DateTime.now();
//     final fileName = '${DateFormat('yyyyMMdd_HHmmss').format(today)}.jpg';
//     final fileLength = await image.length();

//     var request = http.MultipartRequest(
//       'POST',
//       Uri.parse('https://www.alfadock-pack.com/api/file/UploadFile'),
//     );

//     request.files.add(await http.MultipartFile.fromPath(
//       'file',
//       image.path,
//       filename: fileName,
//     ));

//     request.fields['userid'] = widget.userId;
//     request.fields['Filename'] = fileName;
//     request.fields['replace'] = 'false';
//     request.fields['compid'] = widget.compId;
//     request.fields['shared'] = 'false';
//     request.fields['source'] = 'camera';
//     request.fields['fileLength'] = fileLength.toString();
//     request.fields['parentid'] =
//         widget.folderId ?? '0'; // Adjust with API if needed
//     request.fields['ownerCompid'] = widget.compId;

//     try {
//       final response = await request.send();
//       if (response.statusCode == 200) {
//         print(response.statusCode);
//         final responseData = await response.stream.bytesToString();
//         final jsonResponse = jsonDecode(responseData);
//         if (jsonResponse['status'] == 'success') {
//           Navigator.pop(context, 'Uploaded: $fileName');
//           return fileName;
//         } else {
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(
//                 content: Text('Upload failed: ${jsonResponse['message']}')),
//           );
//           Navigator.pop(context);
//           return null;
//         }
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//               content:
//                   Text('Upload failed with status: ${response.statusCode}')),
//         );
//         Navigator.pop(context);
//         return null;
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error uploading file: $e')),
//       );
//       Navigator.pop(context);
//       return null;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     // Show a loading indicator while camera is active
//     return const Scaffold(
//       body: Center(
//         child: CircularProgressIndicator(),
//       ),
//     );
//   }
// }

// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_camera/flutter_camera.dart';

// class CameraPage extends StatefulWidget {
//   const CameraPage({Key? key}) : super(key: key);

//   @override
//   _CameraPageState createState() => _CameraPageState();
// }

// class _CameraPageState extends State<CameraPage> {
//   String? _capturedImagePath;

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Take Photo'),
//         backgroundColor: Colors.amber,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back),
//           onPressed: () {
//             Navigator.of(context).pop(); // Return without image
//           },
//         ),
//       ),
//       body: FlutterCamera(
//         color: Colors.amber,
//         onImageCaptured: (value) {
//           final path = value.path;
//           print("Image captured at path: $path");

//           setState(() {
//             _capturedImagePath = path;
//           });

//           if (path.isNotEmpty && File(path).existsSync()) {
//             // Show preview dialog with options
//             _showPreviewDialog(path);
//           } else {
//             // Handle case where image capture failed
//             ScaffoldMessenger.of(context).showSnackBar(
//               const SnackBar(
//                 content: Text('Failed to capture image. Please try again.'),
//                 backgroundColor: Colors.red,
//               ),
//             );
//           }
//         },
//         onVideoRecorded: (value) {
//           final path = value.path;
//           print('Video recorded at path: $path');
//         },
//       ),
//     );
//   }

//   void _showPreviewDialog(String imagePath) {
//     showDialog(
//       context: context,
//       barrierDismissible: false, // Prevent dismissing by tapping outside
//       builder: (dialogContext) {
//         return AlertDialog(
//           title: const Text('Photo Preview'),
//           content: SingleChildScrollView(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Container(
//                   constraints: const BoxConstraints(
//                     maxHeight: 300,
//                     maxWidth: 300,
//                   ),
//                   child: Image.file(
//                     File(imagePath),
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         // Dismiss dialog and go back to camera
//                         Navigator.of(dialogContext).pop();
//                       },
//                       child: const Text('Retake'),
//                     ),
//                     ElevatedButton(
//                       onPressed: () {
//                         print("Using photo: $imagePath");
//                         // Close dialog first
//                         Navigator.of(dialogContext).pop();
//                         // Then return to the calling screen with the image path
//                         Navigator.of(context).pop(imagePath);
//                       },
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green,
//                         foregroundColor: Colors.white,
//                       ),
//                       child: const Text('Use Photo'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// // Example usage of IconButton with isLoading state inside a StatefulWidget
// class CameraIconButton extends StatefulWidget {
//   final Future<void> Function(File file) uploadImage;

//   const CameraIconButton({Key? key, required this.uploadImage})
//       : super(key: key);

//   @override
//   State<CameraIconButton> createState() => _CameraIconButtonState();
// }

// class _CameraIconButtonState extends State<CameraIconButton> {
//   bool isLoading = false;

//   @override
//   Widget build(BuildContext context) {
//     return IconButton(
//       icon: isLoading
//           ? const SizedBox(
//               width: 20,
//               height: 20,
//               child: CircularProgressIndicator(strokeWidth: 2),
//             )
//           : const Icon(Icons.camera_alt, color: Colors.blue),
//       onPressed: isLoading
//           ? null
//           : () async {
//               setState(() {
//                 isLoading = true;
//               });
//               try {
//                 print("Opening camera...");
//                 final result = await Navigator.push<String>(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => const CameraPage(),
//                   ),
//                 );
//                 print("Camera result received: $result");
//                 if (result != null && result.isNotEmpty) {
//                   final file = File(result);
//                   if (await file.exists()) {
//                     final fileSize = await file.length();
//                     print(
//                         "File verified - Path: ${file.path}, Size: $fileSize bytes");
//                     print("Starting upload...");
//                     await widget.uploadImage(file);
//                   } else {
//                     print("ERROR: File does not exist at path: ${file.path}");
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(
//                         content:
//                             Text('Image file not found. Please try again.'),
//                         backgroundColor: Colors.red,
//                       ),
//                     );
//                   }
//                 } else {
//                   print("No image path returned from camera");
//                 }
//               } catch (e) {
//                 print("ERROR in camera flow: $e");
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(
//                     content: Text('Camera error: $e'),
//                     backgroundColor: Colors.red,
//                   ),
//                 );
//               } finally {
//                 setState(() {
//                   isLoading = false;
//                 });
//               }
//             },
//     );
//   }
// }

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_camera/flutter_camera.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({Key? key}) : super(key: key);

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  String? _capturedImagePath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Take Photo'),
        backgroundColor: Colors.amber,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, null), // cancel
        ),
      ),
      body: FlutterCamera(
        color: Colors.amber,
        onImageCaptured: (value) {
          final path = value.path;
          print("Image captured at path: $path");

          if (path.isNotEmpty && File(path).existsSync()) {
            setState(() => _capturedImagePath = path);
            _showPreviewDialog(path);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to capture image. Please try again.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onVideoRecorded: (value) {
          print('Video recorded at path: ${value.path}');
        },
      ),
    );
  }

  void _showPreviewDialog(String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Photo Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints:
                    const BoxConstraints(maxHeight: 300, maxWidth: 300),
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // close preview
                      // Just go back to camera without returning a path
                    },
                    child: const Text('Retake'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(); // close preview
                      Navigator.pop(context, imagePath); // return to caller
                    },
                    child: const Text('Use Photo'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
