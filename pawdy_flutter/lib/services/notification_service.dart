import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. Android 초기화 설정 (앱 기본 아이콘 사용)
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    
    // 2. iOS/macOS 초기화 설정
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    // 3. 플러그인 초기화
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // 알림 클릭 시 추가 작업이 필요한 경우 여기에 작성
      },
    );

    // 4. Android 13+ 알림 권한 선제 요청
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    // Android용 세부 알림 채널 정의 (헤드업 알림 팝업 활성화 중요 설정)
    const androidDetails = AndroidNotificationDetails(
      'pawdy_notif_channel', // 채널 ID
      'Pawdy 알림', // 채널 이름
      channelDescription: 'Pawdy 서비스 실시간 알림 채널입니다.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
    );

    // 알림 ID는 밀리초 타임스탬프를 이용해 고유값 부여
    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _plugin.show(id, title, body, details);
  }
}
