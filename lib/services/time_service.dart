import 'package:ntp/ntp.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/constants.dart';

class TimeService {
  static final TimeService _instance = TimeService._internal();

  factory TimeService() {
    return _instance;
  }

  TimeService._internal() {
    tz.initializeTimeZones();
  }

  Future<DateTime> getBeijingTime() async {
    try {
      // Get current NTP time
      DateTime ntpTime = await NTP.now(
        lookUpAddress: AppConstants.ntpServers[0],
      ); // Simple check, better to iterate

      // Convert to Beijing Time (UTC+8)
      final beijingLocation = tz.getLocation('Asia/Shanghai');
      final beijingTime = tz.TZDateTime.from(ntpTime, beijingLocation);

      return beijingTime;
    } catch (e) {
      // Fallback to simpler method or other servers if needed
      print("Error getting NTP time: $e");
      // Fallback to system time converted if NTP fails, though risky for this specific app
      final beijingLocation = tz.getLocation('Asia/Shanghai');
      return tz.TZDateTime.from(DateTime.now(), beijingLocation);
    }
  }

  // Iterate through servers like the python script
  Future<DateTime?> getReliableBeijingTime() async {
    final beijingLocation = tz.getLocation('Asia/Shanghai');

    for (String server in AppConstants.ntpServers) {
      try {
        DateTime ntpTime = await NTP.now(
          lookUpAddress: server,
          timeout: const Duration(seconds: 2),
        );
        return tz.TZDateTime.from(ntpTime, beijingLocation);
      } catch (e) {
        continue;
      }
    }
    return null;
  }
}
