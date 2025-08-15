import 'package:vibration/vibration.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TimerPage(),
    );
  }
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;
  // bool _notificationsInitialized = false;
  // final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
  super.initState();
  _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _localNotifications.initialize(initSettings);
    setState(() {
      _notificationsInitialized = true;
    });
  // const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  // const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
  // await _localNotifications.initialize(initSettings);
  // setState(() {
  //   _notificationsInitialized = true;
  // });
  }
  DateTime? _endTime;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ピッカー（タイマー動作中は非表示）
            if (!_isRunning) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildPicker(
                    itemCount: 24,
                    selected: _hours,
                    onSelected: (val) {
                      setState(() {
                        _hours = val;
                      });
                    },
                    label: '時',
                    enabled: !_isRunning,
                  ),
                  const SizedBox(width: 10),
                  _buildPicker(
                    itemCount: 60,
                    selected: _minutes,
                    onSelected: (val) {
                      setState(() {
                        _minutes = val;
                      });
                    },
                    label: '分',
                    enabled: !_isRunning,
                  ),
                  const SizedBox(width: 10),
                  _buildPicker(
                    itemCount: 60,
                    selected: _seconds,
                    onSelected: (val) {
                      setState(() {
                        _seconds = val;
                      });
                    },
                    label: '秒',
                    enabled: !_isRunning,
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
            // タイマー表示（タイマー動作中のみ表示）
            if (_isRunning) ...[
              Text(
                _formatTime(_remainingSeconds),
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.bold, color: Colors.cyan),
              ),
              const SizedBox(height: 30),
            ],
            // ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRunning) ...[
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.cyan, size: 36),
                    onPressed: (_hours + _minutes + _seconds) > 0 ? _startTimer : null,
                    tooltip: 'スタート',
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.stop, color: Colors.cyan, size: 36),
                    onPressed: _stopTimer,
                    tooltip: 'ストップ',
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.cyan, size: 36),
                    onPressed: _resetTimer,
                    tooltip: 'リセット',
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
  int _hours = 0;
  int _minutes = 0;
  int _seconds = 0;
  int _remainingSeconds = 0;
  Timer? _timer;
  bool _isRunning = false;

  void _startTimer() {
  // タイマー開始時に画面消灯を無効化
  WakelockPlus.enable();
    if (_isRunning || (_hours + _minutes + _seconds) == 0) return;
    setState(() {
      _isRunning = true;
      _remainingSeconds = _hours * 3600 + _minutes * 60 + _seconds;
      _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds + 1));
    });
    _updateRemainingTime(); // ← 直後に1回呼び出し
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemainingTime();
      if (_remainingSeconds <= 0) {
        _stopTimer();
        _showAlert();
      }
    });
  _scheduleNotification(_remainingSeconds);
  }

  void _updateRemainingTime() {
    if (_endTime != null) {
      final now = DateTime.now();
      final diff = _endTime!.difference(now).inSeconds;
      setState(() {
        _remainingSeconds = diff > 0 ? diff : 0;
      });
    }
  }

  Future<void> _scheduleNotification(int seconds) async {
    if (!_notificationsInitialized) return;
    await _localNotifications.zonedSchedule(
      0,
      'タイマー終了',
      '時間になりました',
      tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'timer_channel',
          'Timer',
          channelDescription: 'タイマー通知',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _stopTimer() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() {
        _isRunning = false;
      });
  // タイマー停止時に画面消灯を有効化
  WakelockPlus.disable();
    }
  }

  void _resetTimer() {
    _stopTimer();
    setState(() {
      _remainingSeconds = 0;
      _isRunning = false;
    });
  // 念のためリセット時にも画面消灯を有効化
  WakelockPlus.disable();
  }

  void _showAlert() async {
    // バイブレーション（5回繰り返し）
    if (await Vibration.hasVibrator()) {
      for (int i = 0; i < 2; i++) {
        Vibration.vibrate(duration: 100);
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    // 時間入力画面に戻す
    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
      _endTime = null;
    });
  // タイマー終了時にも画面消灯を有効化
  WakelockPlus.disable();
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int min = (totalSeconds % 3600) ~/ 60;
    int sec = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildPicker({required int itemCount, required int selected, required ValueChanged<int> onSelected, required String label, required bool enabled}) {
    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            child: AbsorbPointer(
              absorbing: !enabled,
              child: CupertinoPicker(
                itemExtent: 40,
                backgroundColor: Colors.transparent,
                scrollController: FixedExtentScrollController(initialItem: selected),
                onSelectedItemChanged: enabled ? onSelected : null,
                children: List.generate(
                  itemCount,
                  (i) => Center(
                    child: Text(
                      i.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.cyan.withOpacity(i == selected ? 1.0 : 0.15),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: const TextStyle(color: Colors.cyan, fontSize: 18)),
          ),
        ],
      ),
    );
  }
}
