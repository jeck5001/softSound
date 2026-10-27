import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/data/models/book.dart';
import 'package:soft_sound/data/models/chapter.dart';
import 'package:soft_sound/services/media_metadata.dart';

/// 媒体通知元数据测试。
///
/// 背景（用户反馈）：播放时下拉菜单没有媒体卡片、小米灵动岛也不显示。
/// 根因是整条链没接：没 `JustAudioBackground.init`、清单没声明
/// `AudioService`、`AudioSource` 没带 `MediaItem`、也没申请通知权限。
/// 这里锁住"元数据这一环"，其余几环由 `media_notification_wiring_test` 静态守卫。
void main() {
  Book book({
    String? author,
    String? narrator,
    String? coverUrl,
    String name = '大唐明月',
  }) =>
      Book(
        bookId: 'lrts_1',
        sourceId: 'lrts',
        name: name,
        author: author,
        narrator: narrator,
        coverUrl: coverUrl,
        detailUrl: '1',
      );

  Chapter chapter({String name = '第09集_故人相见', int? duration}) => Chapter(
        chapterId: 'c1',
        bookId: 'lrts_1',
        index: 8,
        name: name,
        url: 'https://cdn.example/a.mp3',
        duration: duration,
      );

  group('forChapter', () {
    test('标题取章节名、专辑取书名、正文取「播音 演播」', () {
      final item = MediaMetadata.forChapter(
        book: book(narrator: '夙染白', coverUrl: 'https://cdn.example/c.jpg'),
        chapter: chapter(),
        audioUrl: 'https://cdn.example/a.mp3',
      );
      expect(item.title, '第09集_故人相见');
      expect(item.album, '大唐明月');
      expect(item.artist, '夙染白 演播');
      expect(item.id, 'https://cdn.example/a.mp3');
      expect(item.artUri.toString(), 'https://cdn.example/c.jpg');
    });

    test('没有演播时回落到作者', () {
      final item = MediaMetadata.forChapter(
        book: book(author: '林语堂'),
        chapter: chapter(),
        audioUrl: 'u',
      );
      expect(item.artist, '林语堂');
    });

    test('演播与作者都空 → 应用名（避免通知显示空行）', () {
      final item = MediaMetadata.forChapter(
        book: book(author: '   ', narrator: ''),
        chapter: chapter(),
        audioUrl: 'u',
      );
      expect(item.artist, isNotEmpty);
      expect(item.album, '大唐明月');
    });

    test('书为空也不崩（降级到应用名）', () {
      final item = MediaMetadata.forChapter(
        book: null,
        chapter: chapter(),
        audioUrl: 'u',
      );
      expect(item.album, isNotEmpty);
      expect(item.artist, isNotEmpty);
      expect(item.artUri, isNull);
    });

    test('章节时长带入 MediaItem', () {
      final item = MediaMetadata.forChapter(
        book: book(),
        chapter: chapter(duration: 1079),
        audioUrl: 'u',
      );
      expect(item.duration, const Duration(seconds: 1079));
    });

    test('无时长 → duration 为 null（交给播放器探测）', () {
      final item = MediaMetadata.forChapter(
        book: book(),
        chapter: chapter(),
        audioUrl: 'u',
      );
      expect(item.duration, isNull);
    });
  });

  group('coverUri 只接受 http(s)', () {
    test('https / http 通过', () {
      expect(MediaMetadata.coverUri('https://a/b.png')?.scheme, 'https');
      expect(MediaMetadata.coverUri('http://a/b.png')?.scheme, 'http');
    });

    test('空 / 非法 / file:// → null', () {
      expect(MediaMetadata.coverUri(null), isNull);
      expect(MediaMetadata.coverUri('   '), isNull);
      expect(MediaMetadata.coverUri('file:///data/a.png'), isNull);
      expect(MediaMetadata.coverUri('data:image/png;base64,xxx'), isNull);
    });
  });

  group('通知链路接线守卫（静态扫描）', () {
    String read(String path) => File(path).readAsStringSync();

    test('main.dart 初始化 JustAudioBackground', () {
      final src = read('lib/main.dart');
      expect(src.contains('JustAudioBackground.init('), isTrue,
          reason: '未初始化就没有 MediaSession，通知栏/灵动岛都不会出现');
      expect(src.contains('androidNotificationOngoing: true'), isTrue,
          reason: '进行中通知是常驻媒体卡/灵动岛的前提');
    });

    test('AndroidManifest 声明媒体服务、按键接收器与所需权限', () {
      final xml = read('android/app/src/main/AndroidManifest.xml');
      expect(xml.contains('com.ryanheise.audioservice.AudioService'), isTrue);
      expect(xml.contains('foregroundServiceType="mediaPlayback"'), isTrue);
      expect(xml.contains('com.ryanheise.audioservice.MediaButtonReceiver'),
          isTrue);
      expect(xml.contains('android.permission.FOREGROUND_SERVICE'), isTrue);
      expect(
          xml.contains('android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK'),
          isTrue);
      expect(xml.contains('android.permission.POST_NOTIFICATIONS'), isTrue,
          reason: 'Android 13+ 没有通知权限就不会显示媒体通知');
      expect(xml.contains('android.permission.WAKE_LOCK'), isTrue);
    });

    test('MainActivity 继承 AudioServiceActivity（否则初始化报错）', () {
      final src = read(
        'android/app/src/main/kotlin/com/softSound/soft_sound/MainActivity.kt',
      );
      expect(src.contains('AudioServiceActivity'), isTrue);
      expect(src.contains('class MainActivity : AudioServiceActivity()'), isTrue);
    });

    test('播放时给 AudioSource 带上 MediaItem（否则通知显示“未知”）', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('MediaMetadata.forChapter('), isTrue);
      expect(src.contains('tag: mediaItem'), isTrue);
    });

    test('首次播放前申请通知权限', () {
      final src = read('lib/services/player_service.dart');
      expect(src.contains('ensureNotificationPermission()'), isTrue);
    });
  });
}
