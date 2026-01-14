import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'; // Added for CookieManager
import 'package:permission_handler/permission_handler.dart'; // Added for Battery Optimization
import '../services/api_service.dart';
import 'logs_screen.dart';
import 'login_screen.dart';

import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _popRunTokenController = TextEditingController();
  final TextEditingController _timeShiftController = TextEditingController();

  final XiaomiApiService _apiService = XiaomiApiService();

  String _status = "Ready";
  String? _userId;
  bool _isRunning = false;
  Timer? _statusTimer;
  double _concurrentRequests = 4.0; // Default

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkServiceStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkServiceStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tokenController.dispose();
    _popRunTokenController.dispose();
    _timeShiftController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tokenController.text = prefs.getString('token') ?? '';
      _popRunTokenController.text = prefs.getString('poprun_token') ?? '';
      _userId = prefs.getString('user_id');
      _concurrentRequests = (prefs.getInt('concurrent_requests') ?? 4)
          .toDouble();

      _timeShiftController.text = (prefs.getDouble('timeshift') ?? 0.0)
          .toString();

      if (prefs.getString('device_id') == null) {
        String devId = _apiService.generateDeviceId();
        prefs.setString('device_id', devId);
      }
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _tokenController.text);
    await prefs.setString('poprun_token', _popRunTokenController.text);
    if (_userId != null) {
      await prefs.setString('user_id', _userId!);
    }
    await prefs.setInt('concurrent_requests', _concurrentRequests.round());
    await prefs.setDouble(
      'timeshift',
      double.tryParse(_timeShiftController.text) ?? 0.0,
    );
  }

  Future<void> _checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    if (mounted && _isRunning != isRunning) {
      setState(() {
        _isRunning = isRunning;
      });
    }
  }

  Future<void> _toggleService() async {
    await _savePreferences();
    final service = FlutterBackgroundService();
    var isRunning = await service.isRunning();
    debugPrint(
      "HomeScreen: _toggleService called. Currently running: $isRunning",
    );

    if (isRunning) {
      debugPrint("HomeScreen: Invoking stopService");
      service.invoke("stopService");
    } else {
      // Check notification permission (Android 13+)
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        status = await Permission.notification.request();
      }

      if (status.isGranted) {
        // Request to ignore battery optimizations for persistent service
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }
        await service.startService();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permission denied. Cannot start service.'),
            ),
          );
        }
      }
    }
    setState(() {
      _isRunning = !isRunning;
    });
  }

  Future<void> _checkAccountStatus() async {
    await _savePreferences();
    final prefs = await SharedPreferences.getInstance();
    final deviceId =
        prefs.getString('device_id') ?? _apiService.generateDeviceId();

    setState(() => _status = "Checking...");
    bool canUnlock = await _apiService.checkUnlockStatus(
      _tokenController.text,
      deviceId,
    );
    setState(
      () => _status = canUnlock
          ? "Account Ready for Unlock!"
          : "Account not authorized or Token invalid",
    );
  }

  Future<void> _openLoginScreen(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );

    if (result != null && result is Map) {
      if (mounted) {
        setState(() {
          if (result['token'] != null) {
            _tokenController.text = result['token'];
          }
          if (result['popRunToken'] != null) {
            _popRunTokenController.text = result['popRunToken'];
          }
          if (result['userId'] != null) {
            _userId = result['userId'];
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful! Tokens updated.')),
        );

        _savePreferences();
        // optionally auto-check status
        _checkAccountStatus();
      }
    }
  }

  void _clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('poprun_token');
    await prefs.remove('user_id');

    // Also clear WebView cookies to allow account switching
    try {
      await CookieManager.instance().deleteAllCookies();
      debugPrint("WebView cookies cleared.");
    } catch (e) {
      debugPrint("Error clearing cookies: $e");
    }

    setState(() {
      _tokenController.clear();
      _popRunTokenController.clear();
      _userId = null;
      _status = "Idle";
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Mi UnBootloader'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.history_edu),
                tooltip: 'View Logs',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogsScreen()),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatusOverview(colorScheme, textTheme),
                  const SizedBox(height: 16),
                  _buildConnectionCard(colorScheme, textTheme),
                  const SizedBox(height: 16),
                  _buildAdvancedSection(colorScheme),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleService,
        icon: Icon(
          _isRunning ? Icons.stop_circle_outlined : Icons.play_circle_fill,
        ),
        label: Text(_isRunning ? "STOP SERVICE" : "START SERVICE"),
        backgroundColor: _isRunning ? colorScheme.error : colorScheme.primary,
        foregroundColor: _isRunning
            ? colorScheme.onError
            : colorScheme.onPrimary,
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildStatusOverview(ColorScheme colorScheme, TextTheme textTheme) {
    bool isReady = _status.contains("Ready");
    // M3: Use proper containers, not hardcoded green backgrounds
    final containerColor = _isRunning
        ? colorScheme.primaryContainer
        : (isReady
              ? colorScheme
                    .tertiaryContainer // Use tertiary for "success-like" states if possible, or just secondary
              : colorScheme.surfaceContainerHighest);

    final contentColor = _isRunning
        ? colorScheme.onPrimaryContainer
        : (isReady
              ? colorScheme.onTertiaryContainer
              : colorScheme.onSurfaceVariant);

    final iconColor = _isRunning
        ? colorScheme.onPrimaryContainer
        : (isReady
              ? Colors
                    .green // Keep custom green icon for semantic clarity
              : colorScheme.onSurfaceVariant);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      color: containerColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Icon(
              _isRunning
                  ? Icons.timer
                  : (isReady ? Icons.check_circle : Icons.info),
              size: 48,
              color: iconColor,
            ),
            const SizedBox(height: 12),
            Text(
              _isRunning ? "Service Running" : _status,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: contentColor,
              ),
            ),
            if (_isRunning)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Waiting for 00:00 Beijing Time...",
                  style: textTheme.bodyMedium?.copyWith(color: contentColor),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(ColorScheme colorScheme, TextTheme textTheme) {
    final bool isLoggedIn = _tokenController.text.isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_circle, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  "Xiaomi Account",
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (isLoggedIn)
                  Chip(
                    label: Text(_userId ?? 'User'),
                    avatar: const Icon(Icons.check, size: 16),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (!isLoggedIn)
              FilledButton.icon(
                onPressed: () => _openLoginScreen(context),
                icon: const Icon(Icons.login),
                label: const Text("CONNECT ACCOUNT"),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _checkAccountStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Refresh Status"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _clearLogin,
                    icon: const Icon(Icons.logout),
                    tooltip: "Logout",
                    style: IconButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      backgroundColor: colorScheme.errorContainer.withOpacity(
                        0.2,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: const Text("Advanced Configuration"),
        leading: const Icon(Icons.settings),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _tokenController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: "Service Token",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.key),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _popRunTokenController,
            readOnly: true, // Auto-filled now
            decoration: const InputDecoration(
              labelText: "PopRun Token",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          TextField(
            controller: _timeShiftController,
            decoration: const InputDecoration(
              labelText: "Time Shift (ms)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.timelapse),
              helperText: "Adjustment for network latency",
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.rocket_launch, color: Colors.orange),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Concurrent Requests: ${_concurrentRequests.toInt()}",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      "Increase for higher success chance (CPU intensive)",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Slider(
            value: _concurrentRequests,
            min: 1,
            max: 50,
            divisions: 49,
            label: _concurrentRequests.round().toString(),
            activeColor: Colors.orange,
            onChanged: (double value) {
              setState(() {
                _concurrentRequests = value;
              });
            },
          ),
          const SizedBox(height: 8),
          if (_concurrentRequests > 10)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "High concurrency may cause network throttling or device lag.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
