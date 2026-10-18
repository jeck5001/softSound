import 'package:flutter_test/flutter_test.dart';
import 'package:soft_sound/theme/app_strings.dart';

void main() {
  group('AppStrings 文案体系', () {
    test('导航文案取自聆阅', () {
      expect(AppStrings.navHome, '首页');
      expect(AppStrings.navExplore, '发现');
      expect(AppStrings.navShelf, '书架');
      expect(AppStrings.navProfile, '我的');
    });

    test('空状态文案取自聆阅', () {
      expect(AppStrings.shelfEmpty, '书架空空如也');
      expect(AppStrings.historyEmpty, '暂无听书记录');
      expect(AppStrings.downloadedEmpty, '暂无已下载章节');
      expect(AppStrings.noPlayContent, '暂无播放内容');
    });

    test('错误/重试文案取自聆阅', () {
      expect(AppStrings.loadFailedNetwork, '加载失败，请检查网络');
      expect(AppStrings.reload, '重新加载');
      expect(AppStrings.retryLater, '操作失败，请稍后重试');
      expect(AppStrings.networkError, '网络异常，请稍后重试');
    });

    test('播放相关文案取自聆阅', () {
      expect(AppStrings.sleepTimerChapterEnd, '本章结束后停止');
      expect(AppStrings.skipIntro, '略过片头');
      expect(AppStrings.skipOutro, '略过片尾');
      expect(AppStrings.volumeBoostNote, '采用 Android 原生 LoudnessEnhancer（无ROOT）');
      expect(AppStrings.bluetoothDisconnected, '蓝牙/耳机已断开，已暂停播放');
    });

    test('字幕文案取自聆阅', () {
      expect(AppStrings.subtitleNoText, '本集暂无字幕');
      expect(AppStrings.subtitleLoading, '字幕加载中…');
    });

    test('设置分组文案取自聆阅', () {
      expect(AppStrings.settingsAppearance, '🎨 个性化与主题');
      expect(AppStrings.settingsAudio, '🔊 播放与音频');
      expect(AppStrings.settingsData, '🔄 数据与存储');
    });

    test('主题模式与分类文案', () {
      expect(AppStrings.themeLight, '亮色模式');
      expect(AppStrings.themeDark, '暗夜模式');
      expect(AppStrings.categoryHorror, '恐怖专区');
      expect(AppStrings.categoryKids, '亲子儿童');
    });
  });

  group('AppStrings 复数/拼接辅助', () {
    test('bookCount', () {
      expect(AppStrings.bookCount(3), '3本');
    });

    test('episodeCount', () {
      expect(AppStrings.episodeCount(12), '12集');
    });

    test('listenedChapters', () {
      expect(AppStrings.listenedChapters(5), '章 5');
    });

    test('episodeIndex', () {
      expect(AppStrings.episodeIndex(7), '集 7');
    });

    test('favoriteCountText', () {
      expect(AppStrings.favoriteCountText(2), '2本收藏');
    });

    test('cachedChapters', () {
      expect(AppStrings.cachedChapters(9), '9个音频章节');
    });

    test('historyCountText', () {
      expect(AppStrings.historyCountText(4), '4条收听记录（左滑可删除）');
    });
  });

  group('常量非空校验', () {
    test('关键 UI 文案均非空', () {
      final samples = <String>[
        AppStrings.appName,
        AppStrings.slogan,
        AppStrings.searchHint,
        AppStrings.loading,
        AppStrings.confirm,
        AppStrings.cancel,
        AppStrings.gotIt,
        AppStrings.downloadManage,
        AppStrings.syncTitle,
        AppStrings.about,
      ];
      for (final s in samples) {
        expect(s.trim(), isNotEmpty, reason: '文案不应为空');
      }
    });
  });
}
