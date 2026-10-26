import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soft_sound/features/home/announcement_gate.dart';
import 'package:soft_sound/features/settings/update_dialogs.dart';
import 'package:soft_sound/services/remote_config_api.dart';

/// 远程配置 UI 行为测试：更新弹窗、公告弹窗、公告「不再显示」持久化。
///
/// 契约依据：字节码 #21402（更新弹窗文案/按钮）、#20382（公告指纹）、
/// `rc_ann_dismiss_v1`（公告已读键）。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('更新对话框', () {
    const version = AppVersionInfo(
      versionName: '1.2.0',
      updateDescription: '修复了若干问题',
      downloadUrl: 'https://example.com/app.apk',
      hasUpdate: true,
    );

    testWidgets('展示版本号与更新说明，点「暂不更新」不打开链接', (tester) async {
      var opened = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUpdateDialog(
                context,
                version: version,
                opener: (url) async {
                  opened.add(url);
                  return true;
                },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining('发现新版本'), findsOneWidget);
      expect(find.textContaining('修复了若干问题'), findsOneWidget);
      expect(find.text('更新内容'), findsOneWidget);

      await tester.tap(find.text('暂不更新'));
      await tester.pumpAndSettle();
      expect(opened, isEmpty);
    });

    testWidgets('点「立即更新」用 download_url 打开浏览器', (tester) async {
      final opened = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUpdateDialog(
                context,
                version: version,
                opener: (url) async {
                  opened.add(url);
                  return true;
                },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('立即更新'));
      await tester.pumpAndSettle();

      expect(opened, ['https://example.com/app.apk']);
    });

    testWidgets('无下载地址时「立即更新」不可点', (tester) async {
      const noUrl = AppVersionInfo(versionName: '1.2.0', hasUpdate: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUpdateDialog(context, version: noUrl),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '立即更新'),
      );
      expect(button.onPressed, isNull);
      expect(find.text('该版本未提供下载地址'), findsOneWidget);
    });

    testWidgets('update_description 为空时用默认文案', (tester) async {
      const noDesc = AppVersionInfo(versionName: '1.2.0', hasUpdate: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showUpdateDialog(context, version: noDesc),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('修复已知问题，优化使用体验'), findsOneWidget);
    });
  });

  group('公告对话框', () {
    const ann = Announcement(
      title: '公告',
      content: '这是一条真实公告',
      hasLink: true,
      linkUrl: 'https://example.com/more',
      linkText: '去看看',
    );

    testWidgets('展示标题/内容/链接文案', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showAnnouncementDialog(context, announcement: ann),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('公告'), findsOneWidget);
      expect(find.text('这是一条真实公告'), findsOneWidget);
      expect(find.text('去看看'), findsOneWidget);
      expect(find.text('不再显示'), findsOneWidget);
    });

    testWidgets('点链接文案会打开 link_url', (tester) async {
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAnnouncementDialog(
                context,
                announcement: ann,
                opener: (url) async {
                  opened.add(url);
                  return true;
                },
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去看看'));
      await tester.pumpAndSettle();

      expect(opened, ['https://example.com/more']);
    });

    testWidgets('点「不再显示」返回 true（供调用方写指纹）', (tester) async {
      var muted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                muted = await showAnnouncementDialog(
                  context,
                  announcement: ann,
                );
              },
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('不再显示'));
      await tester.pumpAndSettle();

      expect(muted, isTrue);
    });
  });

  group('公告「不再显示」持久化（rc_ann_dismiss_v1）', () {
    test('按内容指纹记录；内容变化后重新提示', () async {
      final store = AnnouncementDismissStore();
      const a1 = Announcement(title: '公告', content: 'A');
      const a2 = Announcement(title: '公告', content: 'B');

      expect(await store.isDismissed(a1), isFalse);
      await store.dismiss(a1);
      expect(await store.isDismissed(a1), isTrue);
      // 内容变化 → 指纹变化 → 应重新提示
      expect(await store.isDismissed(a2), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(RemoteConfigApi.dismissKey), a1.hash);
      expect(RemoteConfigApi.dismissKey, 'rc_ann_dismiss_v1');
    });

    test('reset 后重新变为未读', () async {
      final store = AnnouncementDismissStore();
      const a = Announcement(title: 't', content: 'c');
      await store.dismiss(a);
      expect(await store.isDismissed(a), isTrue);
      await store.reset();
      expect(await store.isDismissed(a), isFalse);
    });
  });

  group('AnnouncementGate', () {
    testWidgets('无公告时不弹任何对话框', (tester) async {
      resetAnnouncementGateForTest();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            remoteConfigProvider.overrideWith(
              (ref) async => RemoteConfig.fallback,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: AnnouncementGate(child: Text('页面'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('页面'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('有公告且未读时弹出', (tester) async {
      resetAnnouncementGateForTest();
      const cfg = RemoteConfig(
        announcement: Announcement(title: '公告', content: '看到我了吗'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [remoteConfigProvider.overrideWith((ref) async => cfg)],
          child: const MaterialApp(
            home: Scaffold(body: AnnouncementGate(child: Text('页面'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('看到我了吗'), findsOneWidget);
    });

    testWidgets('已读（指纹一致）时不再弹', (tester) async {
      resetAnnouncementGateForTest();
      const ann = Announcement(title: '公告', content: '看到我了吗');
      await AnnouncementDismissStore().dismiss(ann);
      const cfg = RemoteConfig(announcement: ann);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [remoteConfigProvider.overrideWith((ref) async => cfg)],
          child: const MaterialApp(
            home: Scaffold(body: AnnouncementGate(child: Text('页面'))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
