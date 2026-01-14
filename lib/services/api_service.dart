import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/app_log.dart';
import '../services/db_service.dart';
import '../core/constants.dart';

class XiaomiApiService {
  final DatabaseService _dbService = DatabaseService();

  // Helper to log actions
  Future<void> _log(String message, String type) async {
    await _dbService.insertLog(
      AppLog(timestamp: DateTime.now(), message: message, type: type),
    );
    print("[$type] $message");
  }

  // Generate unique device ID
  String generateDeviceId() {
    // var uuid = const Uuid();
    String randomData =
        "${Random().nextDouble()}-${DateTime.now().millisecondsSinceEpoch}";
    var bytes = utf8.encode(randomData);
    var digest = sha1.convert(bytes);
    return digest.toString().toUpperCase();
  }

  // Check unlock status
  Future<bool> checkUnlockStatus(String token, String deviceId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/user/bl-switch/state");
    final headers = {
      "Cookie":
          "new_bbs_serviceToken=$token;versionCode=500411;versionName=5.4.11;deviceId=$deviceId;",
      "Content-Type": "application/json; charset=utf-8",
      "User-Agent": "okhttp/4.12.0",
      "Connection": "keep-alive",
    };

    try {
      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 100004) {
          await _log("Token expired", "ERROR");
          return false;
        }

        final responseData = data['data'];
        int isPass = responseData['is_pass'];
        int buttonState = responseData['button_state'];
        String deadlineFormat = responseData['deadline_format'] ?? "";

        if (isPass == 4) {
          if (buttonState == 1) {
            await _log("Account status: Ready to apply", "INFO");
            return true;
          } else if (buttonState == 2) {
            await _log(
              "Account status: Blocked until $deadlineFormat",
              "WARNING",
            );
            // In Python script it asks to continue, here we can just return true to let user decide or false
            // For automation, we likely want to try anyway if the user wants.
            return true;
          } else if (buttonState == 3) {
            await _log("Account status: Account too new (<30 days)", "WARNING");
            return true;
          }
        } else if (isPass == 1) {
          await _log(
            "Account status: Already approved until $deadlineFormat",
            "SUCCESS",
          );
          return false; // No need to apply
        }
        await _log("Account status: Unknown state", "ERROR");
        return false;
      } else {
        await _log("API Error: ${response.statusCode}", "ERROR");
        return false;
      }
    } catch (e) {
      await _log("Network Error: $e", "ERROR");
      return false;
    }
  }

  // Apply for unlock
  Future<void> applyForUnlock(String token, String deviceId) async {
    final url = Uri.parse("${AppConstants.baseUrl}/apply/bl-auth");
    final headers = {
      "Cookie":
          "new_bbs_serviceToken=$token;versionCode=500411;versionName=5.4.11;deviceId=$deviceId;",
      "Content-Type": "application/json; charset=utf-8",
      "User-Agent": "okhttp/4.12.0",
      "Connection": "keep-alive",
      "Accept-Encoding": "gzip, deflate, br",
    };

    // Body from python script seems to be just retry flag usually or empty
    final body = json.encode({"is_retry": true});

    try {
      final response = await http.post(url, headers: headers, body: body);
      final responseTime =
          DateTime.now(); // Should ideally use synchronized time logic here
      await _log("Response received at $responseTime", "INFO");

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        int code = jsonResponse['code'];
        final data = jsonResponse['data'] ?? {};

        if (code == 0) {
          int applyResult = data['apply_result'];
          if (applyResult == 1) {
            await _log("Application APPROVED! Verifying...", "SUCCESS");
          } else if (applyResult == 3) {
            String deadline = data['deadline_format'] ?? "Unknown";
            await _log(
              "Application exceeded limit. Try after $deadline",
              "WARNING",
            );
          } else if (applyResult == 4) {
            String deadline = data['deadline_format'] ?? "Unknown";
            await _log("Application blocked until $deadline", "WARNING");
          }
        } else {
          await _log(
            "Application failed. Code: $code. Msg: ${jsonResponse['message']}",
            "ERROR",
          );
        }
      } else {
        await _log("Apply API Error: ${response.statusCode}", "ERROR");
      }
    } catch (e) {
      await _log("Apply Network Error: $e", "ERROR");
    }
  }
}
