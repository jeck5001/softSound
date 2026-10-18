import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 聆阅双书源体系（2026-10-16 字节码深挖：SourceSwitchBadge #21193 /
/// ExploreScreen #21184 / `tingshu_active_source` 持久化键）。
///
/// 源1 = 酷我（kuwo，经聆阅 Edge 的 kuwo-* 契约）
/// 源2 = 懒人听书（lrts，经 lrts-category / lrts-search / lrts-play）
/// 全局 activeSource 决定：分类树、搜索上下文、书籍跳转前缀。
enum LySource {
  kuwo('kuwo', '源1', '酷我'),
  lrts('lrts', '源2', '懒人听书');

  final String id;
  final String badge;
  final String label;

  const LySource(this.id, this.badge, this.label);

  /// 书籍 id 前缀（与 typedSourceRegistry 的 sourceId 对齐）。
  String get bookPrefix => this == LySource.kuwo ? 'xiaoKu' : 'lrts';

  static LySource of(String? id) =>
      values.firstWhere((s) => s.id == id, orElse: () => kuwo);
}

/// 聆阅持久化键（字节码逐字）。
const String kActiveSourceKey = 'tingshu_active_source';

/// 全局源切换控制器（持久化，聆阅行为）。
class ActiveSourceController extends StateNotifier<LySource> {
  ActiveSourceController() : super(LySource.kuwo) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LySource.of(prefs.getString(kActiveSourceKey));
  }

  Future<void> set(LySource source) async {
    state = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kActiveSourceKey, source.id);
  }
}

final activeSourceProvider =
    StateNotifierProvider<ActiveSourceController, LySource>(
        (ref) => ActiveSourceController());

/// 大类（聆阅 SOURCE*_CATEGORIES 的 parent）。
class LyCategory {
  final String name;

  /// 酷我源：edge categoryId；懒人源：null。
  final String? categoryId;

  /// 懒人源：lrts 分类 id（用于 lrts-category?categoryId=）。
  final int? rootId;
  final String desc;
  final String icon;
  final int accent;
  final List<LySubCategory> children;

  const LyCategory({
    required this.name,
    this.categoryId,
    this.rootId,
    required this.desc,
    required this.icon,
    required this.accent,
    required this.children,
  });

  /// 懒人类目跳转用的分类 id（rootId 或子项 id 的字符串形态）。
  String get lrtsId => '$rootId';
}

/// 子类目。
class LySubCategory {
  /// 懒人源为 lrts 分类 id；酷我源为内部 id。
  final String id;
  final String name;

  /// 酷我源：albums 接口的 classifyId。
  final String? classifyId;

  const LySubCategory({required this.id, required this.name, this.classifyId});
}

// 聆阅双源分类树（2026-10-16 字节码 #21189 内联字面量逐字导出，脚本生成勿手改）。

const List<LyCategory> source1Categories = [
  LyCategory(
    name: '有声小说',
    categoryId: '2',
    rootId: 3,
    desc: '玄幻修真 · 都市爽文 · 悬疑惊悚',
    icon: '📚',
    accent: 0xFFA855F7,
    children: [
      LySubCategory(id: '10', name: '玄幻奇幻', classifyId: '1548'),
      LySubCategory(id: '12', name: '现代言情', classifyId: '1561'),
      LySubCategory(id: '14', name: '穿越架空', classifyId: '1553'),
      LySubCategory(id: '9', name: '都市传说', classifyId: '1546'),
      LySubCategory(id: '15', name: '古代言情', classifyId: '1556'),
      LySubCategory(id: '11', name: '悬疑推理', classifyId: '1550'),
      LySubCategory(id: '18', name: '青春校园', classifyId: '1554'),
      LySubCategory(id: '13', name: '武侠仙侠', classifyId: '1549'),
      LySubCategory(id: '16', name: '科幻竞技', classifyId: '1555'),
      LySubCategory(id: '19', name: '历史军事', classifyId: '1551'),
      LySubCategory(id: '22', name: '文学名著', classifyId: '1547'),
      LySubCategory(id: '193', name: '广播剧', classifyId: '1659'),
      LySubCategory(id: '194', name: '畅销书', classifyId: '1680'),
      LySubCategory(id: '195', name: '影视原声', classifyId: '1681'),
    ],
  ),
  LyCategory(
    name: '相声曲艺',
    categoryId: '8',
    rootId: 7,
    desc: '大师经典 · 评书相声 · 戏曲荟萃',
    icon: '🎙️',
    accent: 0xFFFFB800,
    children: [
      LySubCategory(id: '35', name: '评书', classifyId: '1219'),
      LySubCategory(id: '33', name: '相声', classifyId: '1217'),
      LySubCategory(id: '36', name: '小品', classifyId: '1223'),
      LySubCategory(id: '41', name: '戏曲荟萃', classifyId: '1224'),
      LySubCategory(id: '40', name: '曲艺', classifyId: '1319'),
      LySubCategory(id: '148', name: '京剧', classifyId: '1637'),
      LySubCategory(id: '149', name: '豫剧', classifyId: '1641'),
      LySubCategory(id: '150', name: '黄梅戏', classifyId: '1639'),
      LySubCategory(id: '145', name: '二人转', classifyId: '1647'),
    ],
  ),
  LyCategory(
    name: '儿童亲子',
    categoryId: '1',
    rootId: 6,
    desc: '睡前故事 · 国学启蒙 · 少儿名著',
    icon: '🧸',
    accent: 0xFF00FF87,
    children: [
      LySubCategory(id: '209', name: '益智故事', classifyId: '209'),
      LySubCategory(id: '2', name: '国学经典', classifyId: '2'),
      LySubCategory(id: '4', name: '儿童教育', classifyId: '4'),
      LySubCategory(id: '12', name: '英语启蒙', classifyId: '12'),
      LySubCategory(id: '20', name: '儿歌童谣', classifyId: '20'),
      LySubCategory(id: '83', name: '科普知识', classifyId: '83'),
      LySubCategory(id: '210', name: '轻松哄睡', classifyId: '210'),
      LySubCategory(id: '282', name: '卡通动画', classifyId: '282'),
      LySubCategory(id: '385', name: '早教启蒙', classifyId: '385'),
    ],
  ),
  LyCategory(
    name: '历史人文',
    categoryId: '45',
    rootId: 12,
    desc: '百家讲坛 · 人物传记 · 哲学思考',
    icon: '🏯',
    accent: 0xFF38BDF8,
    children: [
      LySubCategory(id: '71', name: '百家讲坛', classifyId: '1252'),
      LySubCategory(id: '75', name: '名家传记', classifyId: '1253'),
      LySubCategory(id: '69', name: '军事历史', classifyId: '1251'),
      LySubCategory(id: '73', name: '悬案秘闻', classifyId: '1254'),
      LySubCategory(id: '70', name: '读书思考', classifyId: '1303'),
      LySubCategory(id: '72', name: '国学经典', classifyId: '1304'),
      LySubCategory(id: '79', name: '诗词歌赋', classifyId: '1354'),
      LySubCategory(id: '81', name: '艺术美学', classifyId: '1356'),
      LySubCategory(id: '83', name: '博闻杂谈', classifyId: '1358'),
      LySubCategory(id: '84', name: '档案纪实', classifyId: '1357'),
      LySubCategory(id: '85', name: '商业财经', classifyId: '1386'),
      LySubCategory(id: '176', name: '宗教哲学', classifyId: '1682'),
      LySubCategory(id: '177', name: '历史通识', classifyId: '1683'),
      LySubCategory(id: '179', name: 'IT科技', classifyId: '1709'),
    ],
  ),
  LyCategory(
    name: '两性情感',
    categoryId: '7',
    rootId: 8,
    desc: '情感夜话 · 治愈美文 · 睡前暖心',
    icon: '💗',
    accent: 0xFFFF2D78,
    children: [
      LySubCategory(id: '51', name: '哄睡', classifyId: '1618'),
      LySubCategory(id: '162', name: '治愈', classifyId: '1619'),
      LySubCategory(id: '53', name: '美文', classifyId: '1620'),
      LySubCategory(id: '55', name: '心理', classifyId: '1622'),
      LySubCategory(id: '163', name: '婚姻', classifyId: '1623'),
      LySubCategory(id: '50', name: '脱单', classifyId: '1452'),
      LySubCategory(id: '58', name: '星座', classifyId: '1626'),
      LySubCategory(id: '56', name: '故事', classifyId: '1628'),
      LySubCategory(id: '165', name: '时尚生活', classifyId: '1629'),
    ],
  ),
  LyCategory(
    name: '助眠解压',
    categoryId: '81',
    rootId: 40,
    desc: '白噪音 · 自然之声 · 催眠冥想',
    icon: '🌙',
    accent: 0xFF00E5FF,
    children: [
      LySubCategory(id: '156', name: '白噪音', classifyId: '1662'),
      LySubCategory(id: '154', name: '功能音乐', classifyId: '1660'),
      LySubCategory(id: '155', name: '禅音', classifyId: '1661'),
      LySubCategory(id: '157', name: 'ASMR', classifyId: '1663'),
      LySubCategory(id: '158', name: '情绪疗愈', classifyId: '1664'),
      LySubCategory(id: '159', name: '助眠故事', classifyId: '1665'),
    ],
  ),
  LyCategory(
    name: '音乐娱乐',
    categoryId: '42',
    rootId: 13,
    desc: '热歌神曲 · 影视原声 · 经典流行',
    icon: '🎵',
    accent: 0xFFFFD60A,
    children: [
      LySubCategory(id: '152', name: '八卦综艺', classifyId: '1374'),
      LySubCategory(id: '151', name: '趣闻', classifyId: '1232'),
      LySubCategory(id: '153', name: '明星集锦', classifyId: '1376'),
      LySubCategory(id: '197', name: '播客', classifyId: '197'),
    ],
  ),
];

const List<LyCategory> source2Categories = [
  LyCategory(
    name: '有声小说',
    rootId: 1,
    desc: '玄幻奇幻 · 言情穿越 · 悬疑探险',
    icon: '⚔️',
    accent: 0xFFFF6B00,
    children: [
      LySubCategory(id: '11', name: '玄幻奇幻'),
      LySubCategory(id: '3020', name: '现代言情'),
      LySubCategory(id: '3109', name: '穿越架空'),
      LySubCategory(id: '9', name: '奇人怪谈'),
      LySubCategory(id: '10', name: '古代言情'),
      LySubCategory(id: '44', name: '官场商战'),
      LySubCategory(id: '15', name: '悬疑爱情'),
      LySubCategory(id: '3106', name: '青春校园'),
      LySubCategory(id: '3107', name: '悬疑推理'),
      LySubCategory(id: '14', name: '武侠仙侠'),
      LySubCategory(id: '12', name: '历史幻想'),
      LySubCategory(id: '3021', name: '科幻空间'),
      LySubCategory(id: '9041', name: '热血军事'),
    ],
  ),
  LyCategory(
    name: '名著文学',
    rootId: 78,
    desc: '名家名著 · 外国经典 · 影视文学',
    icon: '📖',
    accent: 0xFF3B82F6,
    children: [
      LySubCategory(id: '13', name: '名家名著'),
      LySubCategory(id: '82', name: '外国文学'),
      LySubCategory(id: '5241', name: '影视文学'),
      LySubCategory(id: '9039', name: '古典文学'),
      LySubCategory(id: '9139', name: '推理小说'),
      LySubCategory(id: '9140', name: '探险小说'),
      LySubCategory(id: '3022', name: '散文诗歌'),
      LySubCategory(id: '9262', name: '名著精读'),
    ],
  ),
  LyCategory(
    name: '儿童',
    rootId: 6,
    desc: '益智故事 · 儿童文学 · 国学启蒙',
    icon: '🧸',
    accent: 0xFF10B981,
    children: [
      LySubCategory(id: '63', name: '益智故事'),
      LySubCategory(id: '3027', name: '儿童文学'),
      LySubCategory(id: '9031', name: '国学启蒙'),
      LySubCategory(id: '65', name: '家教育儿'),
      LySubCategory(id: '9029', name: '卡通动画'),
      LySubCategory(id: '9245', name: '少儿名著'),
      LySubCategory(id: '59', name: '儿歌童谣'),
      LySubCategory(id: '64', name: '少儿科普'),
    ],
  ),
  LyCategory(
    name: '人文',
    rootId: 17,
    desc: '心理百科 · 科学科普 · 人物传记',
    icon: '🏛️',
    accent: 0xFF8B5CF6,
    children: [
      LySubCategory(id: '9045', name: '心理百科'),
      LySubCategory(id: '9046', name: '科学科普'),
      LySubCategory(id: '17', name: '人物传记'),
      LySubCategory(id: '3063', name: '纪实传奇'),
      LySubCategory(id: '1026', name: '哲学思想'),
      LySubCategory(id: '9044', name: '文艺文化'),
      LySubCategory(id: '109', name: '公开课'),
      LySubCategory(id: '85', name: '法律基础'),
    ],
  ),
  LyCategory(
    name: '财经',
    rootId: 16,
    desc: '投资理财 · 商业智慧 · 创业管理',
    icon: '📈',
    accent: 0xFFEAB308,
    children: [
      LySubCategory(id: '3059', name: '投资理财'),
      LySubCategory(id: '3058', name: '股市'),
      LySubCategory(id: '3057', name: '商业智慧'),
      LySubCategory(id: '16', name: '管理营销'),
      LySubCategory(id: '9048', name: '创业'),
      LySubCategory(id: '9253', name: '商业财经'),
    ],
  ),
  LyCategory(
    name: '曲艺戏曲',
    rootId: 4,
    desc: '戏曲名家 · 豫剧京剧 · 黄梅越剧',
    icon: '🎭',
    accent: 0xFFF97316,
    children: [
      LySubCategory(id: '9060', name: '戏曲名家'),
      LySubCategory(id: '95', name: '豫剧'),
      LySubCategory(id: '89', name: '京剧'),
      LySubCategory(id: '93', name: '黄梅戏'),
      LySubCategory(id: '1031', name: '曲剧'),
      LySubCategory(id: '90', name: '越剧'),
      LySubCategory(id: '58', name: '地方戏'),
    ],
  ),
  LyCategory(
    name: '相声评书',
    rootId: 3,
    desc: '单田芳 · 刘兰芳 · 袁阔成 · 连丽如',
    icon: '🪕',
    accent: 0xFF06B6D4,
    children: [
      LySubCategory(id: '19', name: '单田芳'),
      LySubCategory(id: '5247', name: '刘兰芳'),
      LySubCategory(id: '21', name: '袁阔成'),
      LySubCategory(id: '20', name: '连丽如'),
      LySubCategory(id: '74', name: '短打评书'),
      LySubCategory(id: '3083', name: '历史评书'),
      LySubCategory(id: '48', name: '文化评书'),
      LySubCategory(id: '61', name: '相声小品'),
    ],
  ),
  LyCategory(
    name: '健康',
    rootId: 66,
    desc: '中医养生 · 女性养生 · 疾病预防',
    icon: '🌿',
    accent: 0xFF14B8A6,
    children: [
      LySubCategory(id: '3069', name: '中医养生'),
      LySubCategory(id: '3070', name: '女性养生'),
      LySubCategory(id: '3072', name: '健康课堂'),
      LySubCategory(id: '3074', name: '疾病预防'),
      LySubCategory(id: '3073', name: '饮食药膳'),
      LySubCategory(id: '1030', name: '医学药典'),
      LySubCategory(id: '66', name: '母婴胎教'),
    ],
  ),
  LyCategory(
    name: '历史',
    rootId: 9068,
    desc: '历史小说 · 古代近代 · 野史逸闻',
    icon: '📜',
    accent: 0xFFA855F7,
    children: [
      LySubCategory(id: '9072', name: '历史小说'),
      LySubCategory(id: '9209', name: '中国古代史'),
      LySubCategory(id: '9210', name: '中国近代史'),
      LySubCategory(id: '9068', name: '世界史'),
      LySubCategory(id: '9070', name: '红色足迹'),
      LySubCategory(id: '9071', name: '野史逸闻'),
    ],
  ),
  LyCategory(
    name: '生活',
    rootId: 1022,
    desc: '时尚美容 · 情感杂谈 · 美食窍门',
    icon: '☕',
    accent: 0xFFF43F5E,
    children: [
      LySubCategory(id: '1022', name: '时尚美容'),
      LySubCategory(id: '3029', name: '情感杂谈'),
      LySubCategory(id: '1023', name: '生活窍门'),
      LySubCategory(id: '3028', name: '美食天地'),
      LySubCategory(id: '9106', name: '艺术欣赏'),
    ],
  ),
  LyCategory(
    name: '成功',
    rootId: 83,
    desc: '职场进阶 · 演讲口才 · 激励成长',
    icon: '🚀',
    accent: 0xFF6366F1,
    children: [
      LySubCategory(id: '83', name: '职场进阶'),
      LySubCategory(id: '9054', name: '演讲口才'),
      LySubCategory(id: '9056', name: '情商情绪'),
      LySubCategory(id: '9052', name: '就业指导'),
      LySubCategory(id: '9053', name: '礼仪交际'),
      LySubCategory(id: '9055', name: '激励成长'),
    ],
  ),
];
