import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'api.dart';

class AudioRecordSvc {
  static final _record = AudioRecorder();

  static Future<void> startEmergencyRecording(String sessionId) async {
    // Prevent multiple concurrent recordings from crashing the app
    if (await _record.isRecording()) {
      print("Audio recording already in progress...");
      return;
    }

    if (await _record.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$sessionId.m4a';

      print("Starting emergency recording: $path");
      await _record.start(const RecordConfig(), path: path);

      // Record for 10 seconds, then stop and upload
      Timer(const Duration(seconds: 10), () async {
        try {
          final finalPath = await _record.stop();
          if (finalPath != null) {
            print("Recording stopped, uploading: $finalPath");
            await Api.uploadEvidence(sessionId, finalPath);
            print("✅ Audio evidence secured for $sessionId");
            
            final file = File(finalPath);
            if (await file.exists()) await file.delete();
          }
        } catch (e) {
          print("❌ Evidence upload failed: $e");
        }
      });
    }
  }
}