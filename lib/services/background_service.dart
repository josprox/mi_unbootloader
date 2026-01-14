import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/time_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    /// OPTIONAL, using custom notification channel id
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'MY FOREGROUND SERVICE', // title
      description:
          'This channel is used for important notifications.', // description
      importance: Importance.high, // importance must be at low or higher level
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        // this will be executed when app is in foreground or background in separated isolate
        onStart: onStart,

        // auto start service
        autoStart: false,
        isForegroundMode: true,

        notificationChannelId: 'my_foreground',
        initialNotificationTitle: 'Mi Unlock Service',
        initialNotificationContent: 'Service is ready',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Ensure bindings are initialized
    WidgetsFlutterBinding.ensureInitialized();
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    // Initialize TimeZone for this isolate
    tz.initializeTimeZones();

    print("BackgroundService: onStart called");

    final apiService = XiaomiApiService();
    // Load data from preferences
    final timeService = TimeService();

    // Load data from preferences
    final prefs = await SharedPreferences.getInstance();
    final token1 = prefs.getString('token');
    final token2 = prefs.getString('poprun_token');
    final deviceId = prefs.getString('device_id');
    final timeShift = prefs.getDouble('timeshift') ?? 0.0;

    print(
      "BackgroundService: Loaded prefs. Token: ${token1 != null}, DeviceID: ${deviceId != null}",
    );

    if (token1 == null || deviceId == null) {
      print("BackgroundService: Missing token or deviceId, stopping.");
      service.stopSelf();
      return;
    }

    Timer? timer;

    if (service is AndroidServiceInstance) {
      print("BackgroundService: Service IS AndroidServiceInstance");
      service.on('setAsForeground').listen((event) {
        print("BackgroundService: Received setAsForeground");
        service.setAsForegroundService();
      });

      service.on('stopService').listen((event) {
        print("BackgroundService: Received stopService event");
        timer?.cancel();
        service.stopSelf();
        print("BackgroundService: Service stopped");
      });
    } else {
      print(
        "BackgroundService: Service is NOT AndroidServiceInstance: ${service.runtimeType}",
      );
    }

    if (service is AndroidServiceInstance) {
      print("BackgroundService: Setting initial notification");
      service.setForegroundNotificationInfo(
        title: "Mi Unlocker Running",
        content: "Waiting for target time...",
      );
    }

    // Initial NTP Sync
    DateTime? beijingTime = await timeService.getReliableBeijingTime();
    if (beijingTime == null) {
      print("Failed to get NTP time in background");
    }

    if (beijingTime != null) {
      // Explicitly get location
      final beijingLocation = tz.getLocation('Asia/Shanghai');

      // Convert DateTime to TZDateTime
      final now = tz.TZDateTime.from(beijingTime, beijingLocation);

      // Construct target for today 00:00 logic first
      tz.TZDateTime targetTime = tz.TZDateTime(
        beijingLocation,
        now.year,
        now.month,
        now.day,
        0,
        0,
        0,
      );

      // If target passed (e.g. it is 14:00, target was 00:00), aim for tomorrow 00:00
      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 1));
      }

      // Apply timeshift
      DateTime finalTarget = targetTime.subtract(
        Duration(milliseconds: timeShift.toInt()),
      );

      print("Target Time (Beijing): $finalTarget");
      print("Current Time (Beijing): $now");

      final startTimestamp = DateTime.now().millisecondsSinceEpoch;
      final startBeijingTime = beijingTime;

      timer = Timer.periodic(const Duration(milliseconds: 50), (t) async {
        int elapsed = DateTime.now().millisecondsSinceEpoch - startTimestamp;
        DateTime currentBeijingLogically = startBeijingTime.add(
          Duration(milliseconds: elapsed),
        );
        Duration timeDiff = targetTime.difference(currentBeijingLogically);

        if (timeDiff.inSeconds > 60) {
          if (timeDiff.inSeconds % 60 == 0) {
            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: "Mi Unlocker Waiting",
                content: "Time until unlock: ${timeDiff.inMinutes} minutes",
              );
            }
          }
        } else if (timeDiff.inMilliseconds <= 0) {
          t.cancel();
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Mi Unlocker EXECUTING",
              content: "Sending 4x concurrent requests!",
            );
          }

          // Launch concurrent workers based on preference
          int workerCount = prefs.getInt('concurrent_requests') ?? 4;
          // Safety cap if pref is corrupted, though UI limits to 50
          if (workerCount < 1) workerCount = 1;
          if (workerCount > 100) workerCount = 100;

          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: "Mi Unlocker EXECUTING",
              content: "Sending ${workerCount}x concurrent requests!",
            );
          }

          List<Future> workers = [];

          for (int i = 1; i <= workerCount; i++) {
            // Alternate tokens if token2 exists:
            // Worker 1 -> Token 1
            // Worker 2 -> Token 2
            // Worker 3 -> Token 1 ...
            String tokenToUse = token1;
            if (token2 != null && token2.isNotEmpty) {
              if (i % 2 == 0) {
                tokenToUse = token2;
              }
            }
            workers.add(_startWorker(i, tokenToUse, deviceId, apiService));
          }

          await Future.wait(workers);
          service.stopSelf();
        }
      });
    }
  }

  static Future<void> _startWorker(
    int id,
    String token,
    String deviceId,
    XiaomiApiService api,
  ) async {
    print("Worker $id started with token: ${token.substring(0, 5)}...");
    bool stop = false;
    while (!stop) {
      await api.applyForUnlock(token, deviceId);
      // Small delay to prevent complete UI freeze if strictly single threaded isolate
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }
}
