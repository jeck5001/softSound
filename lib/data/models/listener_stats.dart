/// 听众等级体系 —— 对应聆阅的「依据累计收听分钟数晋级」。
///
/// 聆阅的等级称号（从提取的文案中可见）：
/// `🌱 初级听众`、`📖 初学书友`、`活跃听众 · 阶级`、`🎉 已达成最高等级！`
///
/// 本项目按累计收听时长划分等级；阈值可在后续按实际运营调整。
class ListenerLevel {
  /// 等级序号（从 1 开始）。
  final int level;

  /// 称号。
  final String title;

  /// 达到该等级所需的累计分钟数。
  final int requiredMinutes;

  const ListenerLevel({
    required this.level,
    required this.title,
    required this.requiredMinutes,
  });
}

/// 听众统计快照。
class ListenerStats {
  /// 累计收听时长。
  final Duration totalListening;

  /// 书架书籍数。
  final int bookCount;

  /// 收藏数（当前与书架一致，预留独立字段）。
  final int favoriteCount;

  /// 已听章节数。
  final int listenedChapters;

  const ListenerStats({
    this.totalListening = Duration.zero,
    this.bookCount = 0,
    this.favoriteCount = 0,
    this.listenedChapters = 0,
  });

  /// 累计分钟数。
  int get totalMinutes => totalListening.inMinutes;

  /// 当前等级。
  ListenerLevel get currentLevel => ListenerLevels.forMinutes(totalMinutes);

  /// 下一等级；已满级返回 null。
  ListenerLevel? get nextLevel => ListenerLevels.next(totalMinutes);

  /// 距离下一等级还需的分钟数；已满级返回 0。
  int get minutesToNextLevel {
    final next = nextLevel;
    if (next == null) return 0;
    final remain = next.requiredMinutes - totalMinutes;
    return remain > 0 ? remain : 0;
  }

  /// 当前等级内的进度 0.0–1.0；已满级返回 1.0。
  double get levelProgress {
    final current = currentLevel;
    final next = nextLevel;
    if (next == null) return 1.0;
    final span = next.requiredMinutes - current.requiredMinutes;
    if (span <= 0) return 1.0;
    final done = totalMinutes - current.requiredMinutes;
    return (done / span).clamp(0.0, 1.0);
  }

  /// 是否已达最高等级。
  bool get isMaxLevel => nextLevel == null;

  /// 累计时长的可读文案，如「3 小时 25 分钟」。
  String get formattedListening {
    final d = totalListening;
    if (d.inMinutes < 1) return '${d.inSeconds} 秒';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '$m 分钟';
    if (m == 0) return '$h 小时';
    return '$h 小时 $m 分钟';
  }

  ListenerStats copyWith({
    Duration? totalListening,
    int? bookCount,
    int? favoriteCount,
    int? listenedChapters,
  }) =>
      ListenerStats(
        totalListening: totalListening ?? this.totalListening,
        bookCount: bookCount ?? this.bookCount,
        favoriteCount: favoriteCount ?? this.favoriteCount,
        listenedChapters: listenedChapters ?? this.listenedChapters,
      );
}

/// 等级定义表。
class ListenerLevels {
  const ListenerLevels._();

  /// 全部等级（按累计分钟递增）。
  static const List<ListenerLevel> all = [
    ListenerLevel(level: 1, title: '🌱 初级听众', requiredMinutes: 0),
    ListenerLevel(level: 2, title: '📖 初学书友', requiredMinutes: 60),
    ListenerLevel(level: 3, title: '🎧 常客听众', requiredMinutes: 300),
    ListenerLevel(level: 4, title: '📚 资深书友', requiredMinutes: 900),
    ListenerLevel(level: 5, title: '🌟 活跃听众', requiredMinutes: 1800),
    ListenerLevel(level: 6, title: '🏆 听书达人', requiredMinutes: 3600),
    ListenerLevel(level: 7, title: '👑 声音旅行者', requiredMinutes: 7200),
  ];

  /// 按累计分钟数取当前等级。
  ///
  /// 负值按 0 处理，避免越界。
  static ListenerLevel forMinutes(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    var result = all.first;
    for (final lv in all) {
      if (m >= lv.requiredMinutes) {
        result = lv;
      } else {
        break;
      }
    }
    return result;
  }

  /// 下一等级；已满级返回 null。
  static ListenerLevel? next(int minutes) {
    final current = forMinutes(minutes);
    final idx = all.indexOf(current);
    if (idx < 0 || idx >= all.length - 1) return null;
    return all[idx + 1];
  }

  /// 最高等级。
  static ListenerLevel get max => all.last;
}
