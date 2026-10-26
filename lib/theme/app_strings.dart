/// 应用文案中心 —— 移植自「聆阅 FM」。
///
/// 全部文案提取自聆阅 APK 的 Hermes 字节码字符串表（共 464 条中文文案），
/// 按功能域归类，替换项目中原先散落在各页面的硬编码提示语。
///
/// 命名约定：
/// - 空状态以 `empty*` 开头
/// - 错误提示以 `error*` 开头
/// - 加载中文案以 `loading*` 开头
/// - 确认弹窗以 `confirm*` 开头
/// - 时间/单位以 `unit*` 开头
class AppStrings {
  const AppStrings._();

  // ---------------------------------------------------------------- 应用信息

  static const appName = '轻听';
  static const appNameFull = '轻 听';
  static const slogan = '轻 听 有 声   ·   悦 享 纯 粹';
  static const tagline = '专注高品质有声阅读';
  static const heroTitle = '沉浸声音宇宙 · 听见世间百态';
  static const heroSubtitle = '海量有声小说 · 精选分类 · 点击即听';
  static const libraryHint = '随时随地  ·  听见好书';
  static const libraryHeadline = '轻听 FM · 随身携带的声音图书馆';

  /// 「我的」页社区抬头（原先硬编码在 profile_page，收进文案中心防止再漂移）。
  static const communityLabel = '轻听 · 听友';

  // ---------------------------------------------------------------- 导航

  static const navHome = '首页';
  static const navExplore = '发现';
  static const navShelf = '书架';
  static const navProfile = '我的';
  static const navLibrary = '书库';
  static const navRanking = '排行榜';
  static const navCategory = '分类';
  static const navDownloads = '下载管理';
  static const navSettings = '设置';

  // ---------------------------------------------------------------- 搜索

  static const searchHint = '搜索你想听的书';
  static const searchHintLong = '搜索书名、作者...';
  static const searchHintFull = '搜索书名、作者、分类…';
  static const searchAction = '搜索';
  static const searchHistory = '搜索历史';
  static const searchHot = '热门搜索';
  static const searching = '正在全网高速搜索匹配的有声书籍';
  static const searchUpdating = '正在为您更新搜索结果列表';
  static const searchEnd = '— 已显示全部搜索结果 —';
  static const searchNoResult = '没有找到相关书籍';
  static const searchRetryHint = '换个关键词试试';
  static const searchFailed = '搜索失败，请重试';
  static const searchFailedPrefix = '搜索失败: ';
  static const searchNoSource = '请先添加并启用书源';
  static const searchAddSource = '添加书源';
  static const searchIdleTitle = '输入书名搜索有声书';
  static const searchIdleHint = '支持多个书源同时搜索，结果按书源分组';
  static const searchKeywordEmpty = '请输入搜索关键词';
  static const searchNetworkRetry = '网络不太顺畅，点击下方按钮重新搜索';
  static const searchAgain = '重新搜索';
  static const loadMore = '加载更多...';
  static const loadingMoreBooks = '正在加载更多书籍...';
  static const loadingBookList = '正在加载书籍列表中，请稍候...';
  static const pullToLoadMore = '滑动或点击加载下一页';

  // ---------------------------------------------------------------- 书籍

  static const bookDetail = '书籍详情';
  static const bookIntro = '简介';
  static const bookCatalog = '目录';
  static const bookAuthor = '作者';
  static const bookNarrator = '演播';
  static const bookOriginal = '原著: ';
  static const bookNarratorPrefix = '演播: ';
  static const bookAnchorPrefix = '主播: ';
  static const bookSpeakPrefix = '· 播讲: ';
  static const durationPrefix = '· 时长 ';
  static const unknownBook = '未知书名';
  static const unknownAuthor = '未知作者';
  static const unknownNarrator = '未知播音';
  static const unknownAnchor = '未知主播';
  static const anonymous = '佚名';
  static const bookNotExist = '书籍不存在';
  static const bookNotExistShort = '不存在';
  static const bookDetailError = '书籍详情加载异常';
  static const bookInfoUnavailable = '当前书籍信息暂时无法加载，请检查网络或稍后重试';
  static const bookInfoUnavailableRetry = '书籍信息暂时无法获取，请检查网络或稍后重试';
  static const loadingBookInfo = '加载书籍信息…';
  static const bookInfoReady = '作品基础信息已就绪，正在高速拉取章节列表';
  static const bookNotFoundTitle = '书籍不存在';

  // ---------------------------------------------------------------- 章节

  static const chapterLoading = '章节加载中…';
  static const chapterError = '章节加载遇到问题';
  static const chapterEmpty = '暂无章节内容';
  static const loadingChapters = '正在加载章节选集中，请稍候…';
  static const chaptersReady = '集（可即点即播），后台正在同步全量 ';
  static const episodeEmpty = '本集暂无字幕';
  static const subtitleAi = '本字幕由轻听 AI 技术生成';
  static const subtitleAiTme = '本字幕由TME AI 技术生成';
  static const subtitleLoading = '字幕加载中…';
  static const subtitleUnavailable = '该章节尚未提供可解析的字幕文本，可返回继续收听';
  static const swipeNextChapter = '继续滑动进入下一集';
  static const releaseToLoadSubtitle = '松开即自动加载下一章节字幕';

  // ---------------------------------------------------------------- 播放

  static const play = '播放';
  static const pause = '暂停';
  static const playNow = '立即播放';
  static const continuePlay = '继续收听';
  static const playing = '正在播放';
  static const noPlayContent = '暂无播放内容';
  static const replayLast = '上次收听的有声书';
  static const speed = '倍速';
  static const speedSetting = '语速设置';
  static const speedReset = '1.0x 还原';
  static const audioQuality = '音质';
  static const selectQuality = '选择音质';
  static const volumeBoost = '音量增强';
  static const volumeBoostSwitch = '音量增强开关';
  static const volumeBoostGain = '增强增益';
  static const volumeBoostNote = '采用 Android 原生 LoudnessEnhancer（无ROOT）';
  static const volumeBoostHint = '建议将设备系统媒体音量调至最高；退出播放或销毁页面时将自动释放音效资源。';
  static const audioMix = '与其他App同时播放';
  static const audioMixHint = '可与音乐、导航等App同时发声';
  static const audioLimited = '部分手机、蓝牙耳机音效受限';
  static const bluetoothDisconnected = '蓝牙/耳机已断开，已暂停播放';
  static const playApiNoResponse = '播放接口无响应，请检查网络后重试';
  static const playFailed = '播放失败，请联系作者修复';
  static const audioUrlMissing = '未获取到播放地址';
  static const audioUrlUnavailable = '无法获取播放地址';
  static const resolvingAudio = '取址中…';
  static const resolveFailed = '取址失败:';
  static const resolveRetry = '取址失败，自动重连(';
  static const reconnect = '点击重连';
  static const subtitleNoText = '本集暂无字幕';
  static const sleepTimer = '定时';
  static const sleepTimerChapterEnd = '本章结束后停止';
  static const sleepTimerCountdown = '还有 30 秒，即将停止播放';
  static const listenAgain = '⏱ 再听 ';
  static const listeningSuffix = '分钟';
  static const stopAfter = '后停止';
  static const skipIntro = '略过片头';
  static const skipOutro = '略过片尾';
  static const introOutro = '片头尾';
  static const skipIntroNote = '全局生效 · 每章自动执行';
  static const startEpisode = '起始集';
  static const endEpisode = '结束集';
  static const episodeInvalid = '请输入有效的集数';
  static const episodeStartGtEnd = '起始集不能大于结束集';
  static const episodeMaxExceeded = '集数不能超过 ';
  static const chapterOrderPlay = '章节顺序播放';
  static const ascending = '正序';
  static const descending = '倒序';
  static const readingModePaused = '阅读模式下播放已暂停，点击「朗读」可继续播放';
  static const readingMode = '阅读';
  static const readAloud = '朗读';

  // ---------------------------------------------------------------- 书架 / 收藏

  static const myShelf = '我的书架';
  static const myFavorites = '我的收藏';
  static const shelfEmpty = '书架空空如也';
  static const shelfEmptyHint = '去书库发现好书，点击收藏按钮加入书架';
  static const shelfDiscover = '去书库发现好书';
  static const shelfExplore = '去探索书库';
  static const shelfPickBook = '去挑选书籍';
  static const favoritesEmpty = '暂无收藏书籍';
  static const favoriteAddHint = '遇到喜欢的作品，点击红心即可加入书架';
  static const favoriteRemoveHint = '本好书（左滑可移出收藏）';
  static const favoriteCount = '本收藏';
  static const favoriteCountSuffix = '本收藏）';
  static const removeFromShelf = '》移出书架吗？收藏将被取消，收听进度不受影响。';
  static const removeFromFavorite = '》移出收藏吗？收听进度不受影响。';
  static const shelfSort = '排序';
  static const shelfViewGrid = '网格';
  static const shelfViewList = '列表';
  static const viewHorizontal = '横向';
  static const filterAll = '全部';
  static const filterNewest = '最新';
  static const filterHottest = '最热';

  // ---------------------------------------------------------------- 历史

  static const listenHistory = '听书记录';
  static const historyEmpty = '暂无听书记录';
  static const historyCount = '条听书记录吗？此操作不可恢复。';
  static const historyRecord = '条收听记录（左滑可删除）';
  static const historyDeleteTitle = '删除收听记录';
  static const historyDeleteConfirm = '》的收听记录吗？';
  static const confirmClearPrefix = '确定清空全部 ';
  static const listeningTotal = '累计收听总计';
  static const listeningDetail = '⏱️ 累计听书时间详情';
  static const listeningLevel = '累计听书';
  static const levelUpByMinutes = '依据累计收听分钟数晋级';
  static const levelUpByBooks = '依据完播书籍数量晋级';
  static const currentLevel = '当前等级';
  static const levelDetail = '等级详情';
  static const currentTitle = '当前活跃称号';
  static const maxLevelReached = '🎉 已达成最高等级！';
  static const listeningBeginner = '🌱 初级听众';
  static const listeningBookworm = '📖 初学书友';
  static const listenerLevelPrefix = '活跃听众 · 阶级';
  static const levelDistancePrefix = '距离下级【';
  static const levelDistanceSuffix = '】还需收听 ';
  static const listenedAlready = '已听 ';
  static const chapterListenedTo = '章 · 听到 ';

  // ---------------------------------------------------------------- 下载 / 缓存

  static const download = '下载';
  static const downloadNow = '立即下载';
  static const downloadNowPrefix = '立即下载 (';
  static const startDownload = '开始下载';
  static const stopDownload = '停止下载';
  static const downloading = '正在下载';
  static const downloadingCount = '集 · 下载中 ';
  static const downloadQueued = '排队';
  static const downloadFailed = '下载失败';
  static const downloadStarted = '下载任务已开始，可在下载页查看进度';
  static const downloadSelectChapters = '请勾选需要下载的章节';
  static const downloadCustom = '自定义下载';
  static const downloadSelectAll = '全选未下载';
  static const downloadCancelAll = '全部取消';
  static const downloadCancelSelectAll = '取消全选';
  static const downloadConcurrent = '同时下载';
  static const downloadConcurrency = '并发';
  static const offlineDownload = '离线下载';
  static const downloaded = '已下载';
  static const downloadedCount = '集 · 已下载 ';
  static const downloadedEmpty = '暂无已下载章节';
  static const cachedEmpty = '暂无已缓存章节';
  static const cached = '已缓存';
  static const caching = '正在缓存…';
  static const offlineReady = '已离线';
  static const cacheAudioChapters = '个音频章节';
  static const cacheDeleteConfirm = '个已缓存章节吗？此操作不可恢复。';
  static const cacheDeleteReload = '个已缓存章节吗？删除后需重新下载。';
  static const cacheDeleteOfBook = '》的缓存文件吗？删除后需重新下载。';
  static const cacheDeleteOfBookShort = '」的缓存文件吗？删除后需重新下载才能离线收听。';
  static const cacheClearTitle = '清除应用缓存';
  static const cacheClearConfirm = '确定清除全部缓存数据吗？当前占用 ';
  static const cacheCleared = '缓存已成功清理';
  static const cacheOccupied = '当前占用 ';
  static const cacheNote = '，清除后可释放空间，下次进入页面将重新加载。';
  static const clearAllDownloads = '确定清空全部 ';
  static const cancelAllDownloads = '确定取消全部 ';
  static const cancelDownloadOf = '确定取消下载《';
  static const deleteCacheOf = '确定删除《';
  static const downloadTaskCount = '个下载任务吗？排队中的任务将被移出队列，下载中的任务完成后的文件将被丢弃。';
  static const noNetworkOffline = '无网，已切换到已下载章节';
  static const offlineHint1 = '在书库找到感兴趣的有声书，开启声音之旅吧';
  static const offlineHint2 = '在书籍详情页点击「下载」，即可离线随时随地畅听';
  static const offlineHint3 = '在播放页或书籍详情页可下载离线收听';
  static const downloadManage = '下载管理';
  static const downloadList = '下载列表';

  // ---------------------------------------------------------------- 设置

  static const settings = '设置';
  static const settingsAppearance = '🎨 个性化与主题';
  static const settingsAudio = '🔊 播放与音频';
  static const settingsData = '🔄 数据与存储';
  static const appearanceTheme = '外观主题';
  static const themeLight = '亮色模式';
  static const themeDark = '暗夜模式';
  static const themeSelectColor = '选择主题配色';
  static const personalization = '个性化与主题';
  static const globalAnimations = '全局动效开关';
  static const globalAnimationsHint = '页面过渡与元素动效呈现';
  static const tapEffect = '点击粒子特效';
  static const tapEffectHint = '点击屏幕时触发炫彩微粒动效';
  static const festivalMusic = '开启节日音乐';
  static const festivalEffect = '关闭节日特效';
  static const festivalEffectOn = '关闭节日特效';
  static const backgroundKeepAlive = '后台保活设置';
  static const enableBackground = '开启后台常驻';
  static const bgKeepAliveNote = '为避免锁屏或切后台几分钟后被系统省电策略杀掉播放，请把本应用加入「电池优化白名单」，让音频可以长时间持续播放。';
  static const bgKeepAliveStep1 = '1. 开启通知栏权限';
  static const bgKeepAliveStep2 = '2. 关闭电池优化（白名单）';
  static const bgKeepAliveNote2 = '开启通知栏能大大提高软件后台运行能力，锁屏后依然可以看到播放控制。';
  static const bgKeepAliveNote3 = '加入系统电池白名单，锁屏后台稳定播放';
  static const bgKeepAliveNote4 = '如果还是不能长时间后台播放，需要把本软件的电池优化关闭（即加入电池白名单）。';
  static const enableNow = '立即去开启';
  static const about = '关于轻听 FM';
  static const version = '版本';
  static const checkUpdate = '检查更新';

  /// 本应用版本号 —— 必须与 `pubspec.yaml` 的 `version:` 一致。
  ///
  /// 由 `test/theme/app_version_test.dart` 静态校验，防止再次出现
  /// 「设置页硬编码 v1.1.7（那是聆阅的版本号）」这类漂移。
  static const appVersion = '0.1.0';

  /// 更新检查说明：下载地址来自上游发布渠道（聆阅），不是本应用的商店包。
  static const updateUpstreamNote = '更新信息来自上游发布渠道；下载后将安装该渠道的安装包。';
  static const updateNoLink = '该版本未提供下载地址';
  static const announcementFallbackTitle = '公告';
  static const checkingUpdate = '正在检查新版本…';
  static const alreadyLatest = '当前已是最新版本 (v';
  static const newVersionFound = '发现新版本 v';
  static const updateContent = '更新内容';
  static const updateNow = '立即更新';
  static const updateLater = '暂不更新';
  static const updateBrowserHint = '检测新版本并跳转浏览器下载';
  static const updateBrowserConfirm = '\n\n是否立即前往系统默认浏览器下载更新？';
  static const updateDownloadHint = '点击立即前往浏览器下载最新安装包';
  static const updateFixNote = '修复已知问题，优化使用体验';

  // ---------------------------------------------------------------- 多设备同步

  static const syncTitle = '多设备数据同步';
  static const syncCode = '设置同步码';
  static const syncCodeInput = '请输入同步码';
  static const syncCodeCurrent = '当前同步码：';
  static const syncCodeInvalid = '同步码需为 4-20 位字母或数字';
  static const syncCodeExample = '例如：mybook2024';
  static const syncCodeHint = '自定义一个专属同步码（4-20 位字母或数字），用于在其他设备同步本设备的播放记录与收藏。';
  static const syncCodeInputHint = '输入对方的同步码，将对方的播放记录与收藏合并到本设备。';
  static const syncCodeHelp = '同步码使用说明';
  static const syncCodeStep1 = '① 在「设备A」点击「设置同步码」，自定义一个专属同步码（4-20 位字母或数字）。';
  static const syncCodeStep2 = '② 在「设备B」点击「输入同步码」输入该码（或直接设置相同同步码）。';
  static const syncCodeStep3 = '③ 双方即刻完成双向实时合并，无需重启软件，换设备听书进度自动衔接。';
  static const syncCodeWarning = '⚠️ 特别注意';
  static const syncCodeTip = '提示：相同同步码的设备会自动组成同步组，新设备加入时会自动双向补齐，不会清空原有进度。';
  static const syncCodeNote = '同步码用于在多台手机或平板间双向实时同步播放进度与书架收藏。';
  static const syncSuccess = '同步成功：已双向合并 ';
  static const syncSuccessBound = '同步码设置成功，多端使用相同同步码即可实时互通';
  static const syncSuccessMerged = '同步码设置成功（已双向合并 ';
  static const syncFailed = '同步失败，请稍后重试';
  static const syncMergeFailed = '数据合并未成功，请稍后重试';
  static const syncCodeSetFailed = '设置同步码失败，请稍后重试';
  static const syncCodeBindSuccess = '同步码设置/绑定成功';
  static const syncCodeNotSet = '同步码设置未成功，请稍后重试';
  static const syncBound = '已绑定';
  static const syncInUse = '已被使用';
  static const syncDeviceInitFailed = '设备标识初始化失败，请稍后重试';
  static const syncProgress = '同步';

  // ---------------------------------------------------------------- 书源

  static const sourceLabel1 = '源1';
  static const sourceLabel2 = '源2';
  static const loadingSource2 = '正在获取源2有声大作…';
  static const kuwoAlbumFailed = '获取酷我专辑信息失败';
  static const kuwoAlbumInvalid = '未获取到有效专辑信息';
  static const sourceManagerTitle = '书源管理';
  static const sourceEmptyTitle = '暂无书源';
  static const sourceEmptyHint = '添加书源后即可搜索有声书';
  static const sourceLoadBuiltIn = '加载内置书源';
  static const sourceAddManual = '手动添加书源';
  static const sourceDeleteTitle = '删除书源';
  static const sourceDeleteConfirmPrefix = '确定要删除 ';
  static const sourceDeleteConfirmSuffix = ' 吗？';
  static const sourceAddTitle = '添加书源';
  static const sourceAddAction = '添加';
  static const sourcePasteHint = '粘贴书源JSON...';
  static const sourceAddSuccessPrefix = '已添加书源: ';
  static const sourceLoadFailedPrefix = '加载书源失败: ';
  static const sourceInvalidFormatPrefix = '无效的书源格式: ';

  // ---------------------------------------------------------------- 分类

  static const categoryAll = '全部分类';
  static const categorySub = '个子类';
  static const categoryEmpty = '该分类暂无书籍';
  static const categoryUrban = '都市';
  static const categoryFantasy = '玄幻';
  static const categoryHistory = '历史人文';
  static const categoryHorror = '恐怖专区';
  static const categoryComedy = '相声曲艺';
  static const categoryKids = '亲子儿童';
  static const categorySleep = '助眠解压';
  static const categoryMusic = '音乐娱乐';
  static const categoryFeatured = '精品有声';
  static const categoryEditorPick = '编辑推荐';
  static const categoryHot = '热播精选';
  static const categoryFree = '限免';
  static const categoryExclusive = '畅听爆款';
  static const categoryOriginal = '精选原声';
  static const categoryFocus = '精选焦点';
  static const categoryPopular = '全网精选热门好书';
  static const categoryFriendsPick = '听友推荐';
  static const categoryNewest = '最新书单';
  static const categoryHottest = '最热书单';
  static const categoryRecommend = '推荐书单';
  static const categoryPlayerList = '书目列表';
  static const categoryPodcast = '播客';
  static const categoryAudiobook = '有声书';
  static const categoryNovel = '有声小说';
  static const categoryBooks = '有声书籍';
  static const loadingCategory = '正在为您拉取最新热播榜单数据';
  static const loadingCategoryBooks = '正在为您高速拉取精选好书';
  static const loadingRanking = '加载榜单…';
  /// 发现页排行榜入口：取不到预览数据时的兜底（不能显示「加载中」骗人一直转）。
  static const rankEntryHint = '点击查看榜单';
  /// 榜单页：服务端配额被占满（429 projectConcurrencyLimitExceeded）时的说明。
  static const rankBusy = '榜单服务正忙（请求排队中），请稍后重试';
  /// 榜单页：请求成功但该榜确实没有数据。
  static const rankEmpty = '这个榜单暂时没有内容';

  // ---------------------------------------------------------------- 通用状态

  static const loading = '加载中…';
  static const loadingShort = '加载中..';
  static const loadingPlease = '正在加载中，请稍候…';
  static const loadingAll = '正在加载中，请稍候…';
  static const loadFailed = '加载失败';
  static const loadFailedNetwork = '加载失败，请检查网络';
  static const loadError = '加载遇到问题';
  static const reload = '重新加载';
  static const retryLater = '操作失败，请稍后重试';
  static const networkError = '网络异常，请稍后重试';
  static const serviceBusy = '服务繁忙，请稍后重试';
  static const cloudBusy = '云端服务繁忙，正在自动重试，请稍候再试';
  static const noData = '暂无数据';
  static const noContent = '暂无内容';
  static const noMoreContent = '已加载全部内容';
  static const loadingBook = '正在加载书籍...';
  static const listLoading = '正在加载书籍列表中，请稍候...';
  static const preparing = '准备中…';
  static const back = '返回';
  static const backPrev = '返回上一页';
  static const backToLibrary = '← 返回书库';
  static const backArrow = '← 返回';
  static const backHome = '回到首页';
  static const close = '关闭';
  static const confirm = '确定';
  static const cancel = '取消';
  static const save = '保存';
  static const saveSettings = '保存设置';
  static const edit = '修改';
  static const reset = '重置';
  static const clear = '清空';
  static const clean = '清理';
  static const delete = '删除';
  static const done = '完成';
  static const all = '全部';
  static const expandAll = '全部展开';
  static const collapseAll = '全部折叠';
  static const viewDetail = '查看详情';
  static const gotIt = '我知道了';
  static const understoodClose = '我已了解，关闭';
  static const dontShowAgain = '不再显示';
  static const skip = '跳过';
  static const share = '分享给好友';
  static const shareCopied = '分享链接已复制，快发给小伙伴去吧！';
  static const shareText = '一款宝藏级免费听书软件分享给你下载地址：';
  static const shareInvite = '把宝藏免费听书软件推荐给身边好友';
  static const inputPlaceholder = '请输入';
  static const openInBrowser = '点击任意处关闭';

  // ---------------------------------------------------------------- 单位

  static const unitEpisode = '集';
  static const unitChapter = '章';
  static const unitBook = '本';
  static const unitMinute = '分钟';
  static const unitHour = '小时';
  static const unitSecond = '秒';
  static const unitItem = '条';
  static const unitTimes = '次';
  static const unitWanPlay = '万播放';
  static const unitYiPlay = '亿播放';
  static const unitPlus100k = '10万+';

  // ---------------------------------------------------------------- 增强 / 音效

  static const soundPlus = '音+';
  static const soundBoost = '强';
  static const permanentListen = '永久畅听';
  static const immersiveHint = '精彩有声剧情，戴上耳机沉浸收听…';
  static const premiumListen = '精品有声';
  static const tailoredHint = '精选大作 · 随时随地沉浸收听';
  static const anniversary = '辞旧迎新';
  static const easterEgg = '发现彩蛋！';
  static const nationalDay = '勿忘国耻';
  static const blessing = '福';
  static const legend = '榜';
  static const lantern = '灯';


  // ---------------------------------------------------------------- 书架/详情补充

  static const recommendSources = '推荐书源';
  static const noSources = '暂无书源';
  static const addSource = '添加书源';
  static const chapterNotFound = '未找到章节';
  static const noIntro = '暂无简介';
  static const cancelTimer = '取消定时';
  static const resetStatsConfirm = '确定清空累计收听统计吗？此操作不可恢复。';
  static const statsReset = '收听统计已清空';
  static const addedToShelf = '已加入书架';
  static const loadFailedPrefix = '加载失败: ';
  static const removedFromShelfPrefix = '已将「';
  static const removedFromShelfSuffix = '」移出书架';
  static const removeFromShelfTitle = '移出书架';
  static const removeFromShelfConfirmPrefix = '确定要将「';
  static const removeFromShelfConfirmSuffix = '」移出书架吗？';
  static const moveOut = '移出';
  static const chapterIndexPrefix = '第';
  static const chapterIndexSuffix = '章';
  static const playSpeedPrefix = '播放速度: ';
  static const minuteSuffix = '分钟';
  static const categoryUrbanFantasy = '都市';
  static const categoryFantasyShort = '玄幻';

  // ---------------------------------------------------------------- 辅助

  /// 生成「共 N 本」文案。
  static String bookCount(int n) => '$n$unitBook';

  /// 生成「共 N 集」文案。
  static String episodeCount(int n) => '$n$unitEpisode';

  /// 生成「已听 N 章」文案。
  static String listenedChapters(int n) => '$unitChapter $n';

  /// 生成「第 N 集」文案。
  static String episodeIndex(int n) => '$unitEpisode $n';

  /// 生成「N 条听书记录」文案。
  static String historyCountText(int n) => '$n$historyRecord';

  /// 生成「N 本收藏」文案。
  static String favoriteCountText(int n) => '$n$favoriteCount';

  /// 生成「N 个音频章节」文案。
  static String cachedChapters(int n) => '$n$cacheAudioChapters';
}
