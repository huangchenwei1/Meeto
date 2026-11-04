/// Centralized UI copy for the whole app (currently Simplified Chinese).
///
/// Keeping every user-facing string here makes future localization
/// (e.g. switching to `flutter_localizations` / ARB files) a mechanical task.
/// Keys, scene tags and other identifiers stay English; only display
/// values are translated.
abstract final class AppStrings {
  // App
  static const String appName = 'Meeto';

  // Scene tags are server-side identifiers (pricing, validation); the UI
  // renders them through this display map.
  static const Map<String, String> _sceneLabels = <String, String>{
    'Coffee': '咖啡',
    'Dinner': '晚餐',
    'Bar': '酒吧',
    'Movie': '电影',
    'Tea': '茶饮',
  };
  static String sceneLabel(String tag) => _sceneLabels[tag] ?? tag;

  // Login
  static const String loginTagline = 'MEET \u00b7 PLAN \u00b7 EARN';
  static const String loginSignInTitle = '用手机号登录';
  static String loginCodeSentTo(String phone) => '验证码已发送至 $phone';
  static const String loginCodeHint = '6 位验证码';
  static const String loginChangeNumber = '更换号码';
  static String loginDevCodeNote(String code) => '演示版 · 你的验证码是 $code';
  static const String loginContinueCta = '继续';
  static const String loginVerifyCta = '验证';
  static const String loginPhoneRequiredHint = '请输入手机号';

  // Shared errors
  static const String errorGeneric = '出错了，请重试';
  static const String errorNetwork = '网络异常，请重试';
  static const String errorMessageNotSent = '消息发送失败，请重试';

  // Tabs
  static const String tabMessages = '消息';
  static const String tabMe = '我的';

  // Feed (community activity wall)
  static const String emptyFeed = '还没有动态';
  static const String verifiedLabel = '实名';
  // Escrow payment page
  static const String paymentTitle = '确认支付';
  static const String paymentFeeLabel = '服务费';
  static const String paymentMethodDemo = '演示支付（GCash 接入中）';
  static const String paymentEscrowNote =
      '你的钱不会直接到对方手里。Meeto 全程托管，活动完成后才结算；'
      '计划取消则全额退款。支付后解锁聊天和电话。';
  static String paymentPayCta(String fee) => '支付 $fee 进入托管';
  static const String paymentPaying = '支付中...';
  static const String paymentDoneSnack = '服务费已进入托管';
  static const String paymentFailedSnack = '支付失败，请重试';
  static const String paymentCancelOrderCta = '不约了，取消订单';
  static const String unpaidCancelledSnack = '已取消';
  static const String paymentLaterSnack = '订单保留在「我的订单」，超时未支付将自动取消';
  static const String myOrdersTitle = '我的订单';
  static const String myOrderPayCta = '去支付';
  static const String myOrderCancelCta = '取消订单';
  static const String myOrderChatCta = '进入聊天';
  static const String myOrderDetailCta = '查看详情';
  static const String myOrderWaitingPeerPay = '等待对方支付';
  static String myOrderTotal(String fee) => '合计 $fee';
  static String myOrderHostLine(String name) => '$name · 主持人';
  static String myOrderGuestLine(String name) => '$name · 发起人';
  static String myOrderCreatedAt(String time) => '下单时间 $time';
  static const String myOrdersEmpty = '还没有订单';
  static const String chatLockedNote = '服务费托管后解锁聊天';
  static const String deletePostCta = '删除帖子';
  static const String deletePostConfirmTitle = '删除这条帖子？';
  static const String deletePostConfirmBody = '已报名的候选人会被释放，操作不可撤销。';
  static const String deletePostYes = '删除';
  static const String deletePostNo = '保留';
  static const String deletePostDone = '帖子已删除';
  static String appliedCount(int count) => '$count 人已报名';
  static const String tipLabel = '服务费';

  // Community guidelines banner + page
  static const String bannerEyebrow = '社区';
  static const String bannerTitle = '真实见面，安全第一';
  static const String bannerSub = '每位 Meeto 用户都同意遵守的规则';
  static const String bannerCta = '查看规则';
  static const String guidelinesTitle = '社区公约';
  static const String guidelinesIntro =
      'Meeto 是为真实活动预约真实陪伴的地方。这些规则让每次见面都安全、'
      '真诚、值得赴约。';
  static const List<(String, String)> guidelinesRules = <(String, String)>[
    (
      '真实做自己',
      '头像必须是本人。每个账号都要通过真人认证，冒充他人将被封号。',
    ),
    (
      '尊重彼此',
      '无论在应用里还是见面时，都不允许任何骚扰、侮辱或施压。一次举报'
      '就可能导致封号。',
    ),
    (
      '公共场所见面',
      '选择咖啡馆、餐厅、商场等公共场所。首次见面绝不要转移到私密场所。',
    ),
    (
      '仅限陪伴',
      'Meeto 只提供真实活动中的陪伴。严禁任何性服务、性暗示或相关提议，'
      '一经发现将上报有关部门。',
    ),
    (
      '资金留在平台',
      '服务费由 Meeto 托管至活动完成。不要在平台外支付或收款，场外交易'
      '不受保护。',
    ),
    (
      '准时赴约',
      '计划匹配后双方都要履约。爽约和临时放鸽子会影响账号信用。',
    ),
    (
      '有问题就举报',
      '感觉不对劲？在订单里使用举报功能。审核期间结算会被冻结，违规者'
      '将失去账号。',
    ),
  ];
  static const String guidelinesFooter = '违反规则可能导致结算冻结或永久封号。';

  // Post detail
  static const String safetyNotice =
      'Meeto 保护你：双方都经过实名认证，从匹配到见面的整个活动都在平台'
      '监督下进行。';
  static const String tipPayLabel = '你将支付的服务费';
  static const String signUpCta = '报名';
  static const String signedUpCta = '已报名 · 等待选择';
  static const String candidateSignedUpSnack = '报名成功 — 发帖人会从候选人中选一位';

  // Candidate flow (poster side)
  static const String candidatesTitle = '候选人';
  static const String candidatesEmpty = '还没有人报名 — 通常几分钟内就会有人来';
  static const String approveCta = '选 TA';
  // Escrow / settlement
  static const String escrowSub = 'Meeto 托管至活动完成 · 取消全额退款';

  // Publish
  static const String publishTitle = '发布活动';
  static const String composerSceneLabel = '活动类型';
  static const String composerCoverLabel = '活动封面';
  static const String activityBudgetLabel = '活动预算';
  static String postAuthorLine(String name) => '$name 发起';
  static const String postTakenCta = '已有主持人接单';
  static const String postHostSignupsTitle = '已报名的主持人';
  static const String hostAnonymousLabel = '主持人';
  static const String postFinishedCta = '活动已结束';
  // The activity-budget rules shown on the demand post detail page.
  static const String budgetRuleQuality = '预算包含全部活动开销，优先用于保证活动安排质量';
  static const String budgetRuleAdvance = '活动开销由主持人先行垫付，Meeto 托管全款，取消全额退款';
  static const String budgetRuleRelease = '活动结束后自动发放给主持人，其中服务费不超过活动费的 50%';
  static const String budgetCoversNoteUser = '预算包含全部活动开销，由主持人安排这场活动';
  static const String budgetCoversNoteHost = '预算包含活动开销，安排得当，结余就是你的收入';
  static const String publishFieldTitle = '标题';
  static const String publishFieldDesc = '描述';
  static const String publishFieldDescHint = '说说你想做什么、期待什么样的同伴';
  static const String publishPhTitle = '例如：去新开的咖啡馆坐坐';
  static const String publishPhDesc = '例如：城里新开了家咖啡馆，想找个轻松愉快的伴一起去……';
  static const String publishTipPayNote = '选定主持人时支付的服务费 · 由 Meeto 托管';
  static const String publishSubmit = '发布';
  static const String publishSuccess = '发布成功！等待报名';

  // User profile
  static const String profileTitle = '个人主页';
  static const String profileReviews = '评价';
  static const String profileActivityPosts = '发布的活动';
  static const String profileDatesCompleted = '完成的活动';
  static const String profileAboutTitle = '关于我';
  static const String profileBasicsTitle = '基本资料';
  static const String profileInterestsTitle = '兴趣';
  static const String profileJobLabel = '职业';
  static const String profileEducationLabel = '学历';
  static const String profileHeightLabel = '身高';
  static const String profileWeightLabel = '体重';
  static const String profileLivesInLabel = '所在地';

  // Chats
  static const String statusCompleted = '已完成';
  static const String messageInputHint = '输入消息...';

  // Live orders (API mode: both sides act from their own devices)
  static const String ordersEmpty = '还没有计划 — 去报名或发布一个活动吧';
  static const String statusAwaitingPayment = '待支付';
  static const String statusPendingDate = '计划待定';
  static const String statusActive = '进行中';
  static const String statusCancelled = '已取消';
  static const String waitingForPayment = '等待对方支付服务费';
  static String settledEarnerNote(String net) => '活动完成 · $net 已结算到你的钱包';
  static String settledPayerNote(String fee) => '活动完成 · $fee 已从托管结算';
  static const String cancelledNote = '计划已取消 · 已全额退款';
  static String escrowHeldNote(String amount) => '$amount 由 Meeto 托管中';

  // Profile setup wizard (registration onboarding)
  static const String setupStepRoleTitle = '你想怎么使用 Meeto？';
  static const String setupStepRoleSub = '选择适合你的身份，之后不可更改。';
  static const String roleUserLabel = '预约活动';
  static const String roleUserSub = '发布想做的活动或邀请主持人，并支付服务费';
  static const String roleHostLabel = '主持赚钱';
  static const String roleHostSub = '提交方案、主持精彩活动，赚取服务费';
  static const String roleRequiredHint = '先选择你的使用方式';
  static const String setupStepGenderTitle = '我是...';
  static const String setupStepGenderSub = '展示在你的主页上并用于偏好筛选，之后不可更改。';
  static const String genderFemaleLabel = '女生';
  static const String genderMaleLabel = '男生';
  static const String genderRequiredHint = '选择一项后继续';
  static const String setupStepNameTitle = '我的名字是...';
  static const String setupStepNameSub = '这是你在 Meeto 上的展示名';
  static const String setupNameHint = '你的名字';
  static const String nameRequiredHint = '输入名字后继续';
  static const String setupStepBirthTitle = '你的生日是？';
  static const String setupStepBirthSub = '须年满 18 岁。其他人只会看到你的年龄。';
  static const String setupBirthYearLabel = '年';
  static const String setupBirthMonthLabel = '月';
  static const String setupStepBodyTitle = '身高体重';
  static const String setupStepBodySub = '让大家对你有个直观印象';
  static const String setupStepLocationTitle = '你在哪个城市？';
  static const String setupStepLocationSub = '方便为你推荐附近的活动';
  static const String setupStepWorkTitle = '你是做什么的？';
  static const String setupStepWorkSub = '一点背景介绍很加分';
  static const String setupStepTagsTitle = '你的兴趣';
  static const String setupStepTagsSub = '选几个你喜欢的';
  static const String setupStepBioTitle = '介绍一下自己';
  static const String setupStepBioSub = '简短的自我介绍能大大提高匹配率';
  static const String setupStepPhotosTitle = '上传照片';
  static const String setupStepPhotosSub =
      '一张主照加最多 3 张照片。主照也是真人认证的比对依据。';
  static const String setupMainPhotoBadge = '主照';
  static const String setupNext = '下一步';
  static const String setupFinish = '完成';
  static const String setupStepSkip = '跳过';
  static const String setupCountryLabel = '国家';
  static const String setupCityLabel = '城市';

  /// Launch markets and their selectable cities. Stored as display values;
  /// the server treats them as plain strings.
  static const List<(String, List<String>)> countryCities =
      <(String, List<String>)>[
    (
      '中国',
      <String>[
        '武汉',
      ],
    ),
    (
      '菲律宾',
      <String>[
        '马尼拉',
        '奎松城',
        '马卡蒂',
        '塔吉格',
        '帕西格',
        '帕赛',
        '帕拉纳克',
        '卡卢坎',
        '宿务',
        '达沃',
        '碧瑶',
        '伊洛伊洛',
        '巴科洛德',
        '卡加延德奥罗',
      ]
    ),
    (
      '印度尼西亚',
      <String>[
        '雅加达',
        '泗水',
        '万隆',
        '棉兰',
        '三宝垄',
        '望加锡',
        '巨港',
        '坦格朗',
        '勿加泗',
        '德波',
        '登巴萨',
        '日惹',
      ]
    ),
    (
      '越南',
      <String>[
        '胡志明市',
        '河内',
        '岘港',
        '海防',
        '芹苴',
        '边和',
        '顺化',
        '芽庄',
        '头顿',
        '大叻',
      ]
    ),
  ];
  static const String setupJobLabel = '职业';
  static const String setupEducationLabel = '学历';
  static const String setupHeightLabel = '身高';
  static const String setupWeightLabel = '体重';

  /// Fixed education levels; stored as-is.
  static const List<String> educationOptions = <String>[
    '高中',
    '专科',
    '本科',
    '硕士',
    '博士',
  ];

  /// Fixed occupation categories; stored as-is.
  static const List<String> jobOptions = <String>[
    '学生',
    'IT / 工程',
    '设计 / 创意',
    '教师',
    '医疗健康',
    '销售 / 市场',
    '金融',
    '服务业',
    '创业者',
    '自由职业',
    '内容创作者',
    '其他',
  ];
  static const String setupTagsLabel = '兴趣';

  /// Predefined interest tags shown as multi-select chips on profile setup.
  static const List<String> setupTagOptions = <String>[
    '咖啡',
    '美食探店',
    '电影',
    '音乐',
    'K歌',
    '艺术',
    '旅行',
    '健身',
    '徒步',
    '游戏',
    '摄影',
    '阅读',
    '夜生活',
    '逛街',
  ];
  static const String setupBioLabel = '自我介绍';
  static const String setupBioHint = '简单介绍一下：你喜欢什么，怎样算一次开心的出行……';
  static const String setupSave = '保存';
  static const String menuEditProfile = '编辑资料';
  static const String editPhotosLabel = '照片';
  static const String editLocationLabel = '所在地';
  static const String editNotSet = '未设置';
  static const String sheetDone = '完成';

  // Real-person verification
  static const String verifyTitle = '真人认证';
  static const String verifySub =
      '快速自拍一张，与你的主页照片比对，确认是你本人。认证让见面更安全，'
      '并解锁发布、报名和支付。';
  static const String verifyYourPhoto = '你的主页照片';
  static const String verifyStart = '开始认证';
  static const String verifySuccess = '认证通过';
  static const String verifyNoAvatar = '请先设置主页照片，自拍将与它进行比对';
  static const String verifyGoSetAvatar = '去设置照片';
  static const String verifyDialogTitle = '需要真人认证';
  static const String verifyDialogBody = '此操作需要真人认证，只需一分钟。';
  static const String verifyNow = '立即认证';
  static const String verifyLater = '稍后';
  static const String verifiedStatus = '已认证';
  static const String notVerifiedStatus = '未认证';
  static const String setupUploadFailed = '上传失败，请重试';
  static const String setupAvatarRequired = '请先添加主页照片';
  static String joinedLine(String time) => '$time加入';

  // Publish: structured time and place pickers
  static const String publishPickTime = '选择日期和时间';

  // Order room (API mode)
  static const String peerPhoneLabel = '电话';
  static const String phoneCopied = '电话号码已复制';
  static const String orderDetailsCta = '详情';
  static const String orderFeeLabel = '服务费';
  static const String orderPayoutLabel = '主持人所得';
  static const String meetCodeLabel = '见面密码';
  static const String meetCodeHintPayer = '见面时把密码告诉主持人，对方输入后服务开始';
  static const String meetCodeInputHint = '输入对方的 4 位见面密码';
  static const String startMeetCta = '开始服务';
  static const String wrongMeetCodeSnack = '密码不对，再和对方核对一下';
  static const String startedBadge = '进行中';
  static String settlesAtNote(String time) => '服务进行中 · $time 自动结算';
  static const String cancelCtaPayer = '取消活动';
  static const String cancelCtaHost = '放弃活动';
  static const String cancelConfirmTitle = '确定要取消吗？';
  static const String cancelConfirmBody = '费用将全额原路退回，对方会收到通知。成单 30 分钟后将无法取消。';
  static const String cancelConfirmYes = '确定取消';
  static const String cancelConfirmNo = '返回';
  static const String cancelledSnack = '已取消，费用全额原路退回';
  static const String forfeitedNote = '无人开始服务，订单已作废';
  static const String statusForfeited = '已作废';

  // Gig hall (host-side work surface)
  static const String tabGigs = '需求';
  static const String gigsTitle = '需求大厅';
  static const String gigsSubtitle = '提交方案，赚取服务费';
  static const String gigsEmpty = '暂时没有新需求 — 稍后再来看看';
  static const String gigsRequestsHeader = '开放需求';
  static const String gigAppliedBadge = '已报名';
  static const String gigPitchCta = '提交方案';

  // Host directory + direct invitations
  static const String tabHosts = '首页';
  static const String tabCommunity = '社区';
  static const String hostsTitle = '发现活动';
  static const String hostsEmpty = '还没有活动提案';

  // --- Activity community (tab 1): templates shelf + sharing wall ---
  static const String tabActivityCommunity = '社区';
  static const String hotActivitiesTab = '热门活动';
  static const String activitySharesTab = '活动分享';
  static const String templateLaunchCta = '发起';
  static const String templatesEmpty = '活动上架中，稍后再来看看';

  // --- Dating hall (tab 2): the unified board ---
  static const String tabHall = '大厅';
  static const String hallTitle = '约会大厅';
  static const String hallEmpty = '大厅还没有活动，去社区发起一个吧';
  static const String hallFilterAll = '全部';
  static const String hallFilterRequests = '找人主持';
  static const String hallFilterProposals = '主持人提案';

  // Fuzzy availability windows: identifiers stay English on the wire,
  // display labels live here. The exact schedule comes later via the
  // order plan flow.
  static const List<String> timeSlots = <String>[
    'TODAY_AFTERNOON',
    'TONIGHT',
    'TOMORROW',
    'WEEKEND',
    'ANYTIME',
  ];
  static const Map<String, String> _timeSlotLabels = <String, String>{
    'TODAY_AFTERNOON': '今天下午',
    'TONIGHT': '今晚',
    'TOMORROW': '明天',
    'WEEKEND': '周末',
    'ANYTIME': '时间灵活',
  };
  static String timeSlotLabel(String tag) => _timeSlotLabels[tag] ?? tag;
  static const String publishTimeSlotLabel = '活动时间（选填）';

  // Proposal composer (host side)
  static const String proposalComposerTitle = '发布活动提案';
  static const String proposalTitleHint = '想带大家去做什么？比如：去听一场 live';
  static const String proposalDescHint = '例如：店里安静、豆子好，适合慢慢聊……';
  static const String proposalAreaLabel = '活动区域（选填）';
  static const String proposalPublishCta = '发布';
  static const String proposalPostedSnack = '提案已发布';

  /// Rough Metro Manila areas a pitch can point at; proper nouns stay in
  /// their local form. The exact venue comes via the order plan flow.
  static const List<String> manilaAreas = <String>[
    'Makati',
    'BGC',
    'Poblacion',
    'Ortigas',
    'Quezon City',
    'Ermita',
    'Salcedo Village',
    'Legazpi Village',
    'Rockwell',
  ];
  static String hostCompletedLabel(int count) => '$count 次主持';
  static const String hostNewLabel = '新人主持';
  static const String hostRecentPlanLabel = '近期方案';
  static const String hostInviteCta = '邀请';
  static String inviteSheetTitle(String name) => '邀请 $name 来主持';
  static const String inviteNoteHint = '说说你的想法（选填）';
  static String inviteFeeNote(String fee) => '对方接受后，你需支付 $fee 服务费以开启计划';
  static const String inviteSendCta = '发送邀请';
  static const String inviteSentSnack = '邀请已发送 — 对方选中你后会通知你';
  static const String inviteAlreadyPendingSnack = '你已邀请过这个提案，等对方回应吧';
  static const String proposalNotOpenSnack = '这个提案已被约走';
  static const String invitedBadge = '已邀请';
  static String proposalInviteCount(int count) => '$count 人想约';
  static const String proposalInvitesTitle = '收到的邀请';
  static const String proposalInvitesEmpty = '还没有人邀请，再等等';
  static const String selectInviterDoneSnack = '已选定 — 对方支付后计划生效';
  static const String selectPlanTitle = '敲定活动计划';
  static const String selectPlanSub = '选定 TA 之前先把地点和时间定好，对方支付后计划立即生效。';
  static const String selectPlanNoteLabel = '补充说明（可选）';
  static const String selectPlanCta = '选定并锁定计划';

  // Community moments (activity recaps)
  static const String momentBadge = '动态';
  static const String momentComposerTitle = '分享动态';
  static const String momentTextHint = '活动怎么样？给你的主持人一个好评吧';
  static const String momentTextRequiredHint = '先写点什么吧';
  static const String momentVenueLabel = '活动地点';
  static const String momentVenueHint = '店名或地标，让大家也能找到这里';
  static const String momentVenueRequiredHint = '填一下活动地点，这是分享的精华';
  static const String momentPostCta = '发布';
  static const String momentPhotoFailed = '照片上传失败，请重试';

  // Sign-up proposal (the candidate's plan pitch)
  static const String proposalSheetTitle = '提交你的方案';
  static const String proposalSheetSub = '说说你想带 TA 去哪、什么时候去。发帖人会根据方案选人。';
  static const String proposalHint = '例如：马卡蒂 Single Origin，周六下午 3 点';
  static const String proposalRequiredHint = '写一个简短方案来报名';

  // Plan (host proposes, poster confirms)
  static const String planCardTitle = '活动计划';
  static const String planConfirmedBadge = '已确认';
  static const String planPlaceHint = '具体在哪？例如：Greenbelt 3 的 Single Origin';
  static const String planRequiredHint = '先填好地点、时间和流程安排';
  static const String forfeitedBadge = '已作废';
  static const String chatEndedBadge = '已结束';
  static const String chatReadOnlyNote = '活动已结束，会话仅可读';
  static const String planDurationLabel = '游玩时长';
  static const String proposalPitchLabel = '方案介绍';
  static const String proposalPlaceLabel = '地点';
  static const String proposalTimeLabel = '时间';
  static const String publishTemplateQuoteLabel = '发起的活动';
  static const String publishFieldsRequiredHint = '先填好标题和描述';

  /// '2 小时' / '2.5 小时' from minutes.
  static String durationLabel(int minutes) {
    return minutes % 60 == 0
        ? '${minutes ~/ 60} 小时'
        : '${(minutes / 60).toStringAsFixed(1)} 小时';
  }

  /// '约 2 小时' for plan cards and candidate rows.
  static String durationAbout(int minutes) => '约 ${durationLabel(minutes)}';

  // Notifications
  static const String notificationsEmpty = '这里还没有内容';
  static const String timeJustNow = '刚刚';
  static String timeMinutesAgo(int m) => '$m 分钟前';
  static String timeHoursAgo(int h) => '$h 小时前';
  static String timeDaysAgo(int d) => '$d 天前';

  // Me page
  static const String walletLabel = '本月收入';
  static String walletWithdrawable(String amount) => '可提现 $amount · T+1 到账';
  static const String withdraw = '提现';
  static const String withdrawSubmitted = '提现申请已提交';
  static const String menuMyPosts = '我的帖子';
  static const String menuVerification = '认证中心';
  static const String menuSettings = '设置';
  static const String menuLogout = '退出登录';
  static const String myPostsEmpty = '还没有帖子';
  static const String postStatusOpen = '招募中';
  static const String postStatusMatched = '已匹配';
  static const String walletTitle = '钱包';
  static const String withdrawSheetTitle = '提现到 GCash';
  static String withdrawSheetSub(String amount) =>
      '最多 $amount · T+1 到账 · 收款账户设置随 GCash 接入上线';
  static const String withdrawHistoryTitle = '提现记录';
  static const String withdrawHistoryEmpty = '还没有提现记录';
  static const String withdrawFailed = '提现失败，请重试';
  static const String withdrawalPending = '处理中';
  static const String withdrawalPaid = '已到账';

  // Relative time
  static const String justNow = '刚刚';
  static String minutesAgo(int minutes) => '$minutes 分钟前';
  static String hoursAgo(int hours) => '$hours 小时前';
  static String daysAgo(int days) => '$days 天前';
}
