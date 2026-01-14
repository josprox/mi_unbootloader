import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/time_service.dart';

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
      importance: Importance.low, // importance must be at low or higher level
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
    // Only available for flutter 3.0.0 and later
    DartPluginRegistrant.ensureInitialized();

    final apiService = XiaomiApiService();
    final timeService = TimeService();

    // Load data from preferences
    final prefs = await SharedPreferences.getInstance();
    final token1 = prefs.getString('token');
    final token2 = prefs.getString('poprun_token');
    final deviceId = prefs.getString('device_id');
    final timeShift = prefs.getDouble('timeshift') ?? 0.0;

    if (token1 == null || deviceId == null) {
      service.stopSelf();
      return;
    }

    Timer? timer;

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('stopService').listen((event) {
        timer?.cancel();
        service.stopSelf();
      });
    }

    if (service is AndroidServiceInstance) {
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
      DateTime nowBeijing = beijingTime;
      DateTime nextDay = nowBeijing.add(const Duration(days: 1));
      DateTime targetTime = DateTime(
        nextDay.year,
        nextDay.month,
        nextDay.day,
        0,
        0,
        0,
      ).subtract(Duration(milliseconds: timeShift.toInt()));

      print("Target Time (Beijing): $targetTime");

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

          // Launch 4 concurrent workers as requested
          List<Future> workers = [];

          // Worker 1: Token 1
          workers.add(_startWorker(1, token1, deviceId, apiService));

          // Worker 2: Token 2 (or Token 1 if T2 missing)
          workers.add(
            _startWorker(
              2,
              token2?.isNotEmpty == true ? token2! : token1,
              deviceId,
              apiService,
            ),
          );

          // Worker 3: Token 1
          workers.add(_startWorker(3, token1, deviceId, apiService));

          // Worker 4: Token 2 (or Token 1 if T2 missing)
          workers.add(
            _startWorker(
              4,
              token2?.isNotEmpty == true ? token2! : token1,
              deviceId,
              apiService,
            ),
          );

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
