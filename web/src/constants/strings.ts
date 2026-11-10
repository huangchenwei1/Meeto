/**
 * Centralized UI copy (Simplified Chinese), ported from the Flutter app.
 * Keys, scene tags and other identifiers stay English; only display
 * values are translated.
 */

/** Indexed by Date.getDay(): Sunday first. */
const WEEKDAY_LABELS = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];

/** Display names for host-pitch availability windows. */
const PROPOSAL_SLOT_LABELS: Record<string, string> = {
  ANYTIME: '随时',
  NOON: '中午',
  EVENING: '晚上',
};

const SCENE_LABELS: Record<string, string> = {
  Coffee: '咖啡',
  Dinner: '晚餐',
  Bar: '酒吧',
  Movie: '电影',
  Tea: '茶饮',
};

export const strings = {
  sceneLabel: (tag: string) => SCENE_LABELS[tag] ?? tag,

  // Login
  loginTagline: 'MEET · PLAN · EARN',
  loginSignInTitle: '用手机号登录',
  loginCodeSentTo: (phone: string) => `验证码已发送至 ${phone}`,
  loginCodeHint: '6 位验证码',
  loginChangeNumber: '更换号码',
  loginDevCodeNote: (code: string) => `演示版 · 你的验证码是 ${code}`,
  loginContinueCta: '继续',
  loginVerifyCta: '验证',
  loginPhoneRequiredHint: '请输入手机号',
  loginInvalidCode: '验证码不对，请重试',

  // Shared errors
  errorGeneric: '出错了，请重试',
  errorNetwork: '网络异常，请重试',
  errorMessageNotSent: '消息发送失败，请重试',

  // Dead ends: unknown routes and rooms the viewer cannot open
  notFoundTitle: '页面不见了',
  notFoundBody: '这个页面不存在或已失效',
  backToHallCta: '回到大厅',
  orderUnavailableNote: '这个活动房间不存在，或你没有权限查看',

  // Tabs
  tabHall: '大厅',
  tabChats: '消息',
  tabMyActivities: '我的活动',
  tabMe: '我的',
  chatsEmpty: '还没有搭子，结伴成功后会出现在这里',
  chatsHint: '结成活动后，和搭子的会话会一直留在这里',
  msgPreviewPlan: '[活动计划]',
  msgPreviewRequest: '[活动邀约]',
  chatLiveBadge: '活动进行中',

  verifiedLabel: '实名',

  // Escrow payment page
  paymentTitle: '确认支付',
  paymentFeeLabel: '陪伴服务费',
  paymentMethodDemo: '演示支付（GCash 接入中）',
  paymentEscrowNote:
    '你的钱不会直接到对方手里。Meeto 全程托管，活动完成后才结算；计划取消则全额退款。支付后解锁聊天和电话。',
  paymentPayCta: (fee: string) => `支付 ${fee} 进入托管`,
  paymentPaying: '支付中...',
  paymentDoneSnack: '服务费已进入托管',
  paymentFailedSnack: '支付失败，请重试',
  paymentCancelOrderCta: '不约了，取消这次约定',
  unpaidCancelledSnack: '已取消',
  paymentLaterSnack: '未支付的约定超时将自动取消',
  myOrderDetailCta: '查看详情',
  myOrderTotal: (fee: string) => `合计 ${fee}`,
  myOrderHostLine: (name: string) => `${name} · 陪伴搭子`,
  myOrderGuestLine: (name: string) => `${name} · 发起人`,
  myOrderCreatedAt: (time: string) => `结伴时间 ${time}`,
  chatLockedNote: '服务费托管后解锁聊天',
  deletePostConfirmTitle: '删除这条帖子？',
  deletePostConfirmBody: '已报名的候选人会被释放，操作不可撤销。',
  deletePostYes: '删除',
  deletePostNo: '保留',
  deletePostDone: '帖子已删除',
  appliedCount: (count: number) => `${count} 人已报名`,
  signupNoticePill: (count: number) => `${count} 条新报名`,
  dealNoticePay: '已结成搭子 · 去支付锁定活动',
  dealNoticeGreet: '搭子已就位 · 去打个招呼',
  dealNoticeOngoing: '活动进行中 · 回到房间',
  dealNoticeActive: '搭子已就位 · 进入房间',
  dealNoticeMore: (count: number) => `还有 ${count} 件`,

  // Community guidelines
  bannerTitle: '真实见面，安全第一',
  bannerSub: '每位 Meeto 用户都同意遵守的规则',
  guidelinesTitle: '社区公约',
  guidelinesIntro:
    'Meeto 是为真实活动预约真实陪伴的地方。这些规则让每次见面都安全、真诚、值得赴约。',
  guidelinesRules: [
    ['真实做自己', '头像必须是本人。每个账号都要通过真人认证，冒充他人将被封号。'],
    [
      '尊重彼此',
      '无论在应用里还是见面时，都不允许任何骚扰、侮辱或施压。一次举报就可能导致封号。',
    ],
    [
      '公共场所见面',
      '选择咖啡馆、餐厅、商场等公共场所。首次见面绝不要转移到私密场所。',
    ],
    [
      '仅限陪伴',
      'Meeto 只提供真实活动中的陪伴。严禁任何性服务、性暗示或相关提议，一经发现将上报有关部门。',
    ],
    [
      '资金留在平台',
      '服务费由 Meeto 托管至活动完成。不要在平台外支付或收款，否则不受平台保护。',
    ],
    ['准时赴约', '计划匹配后双方都要履约。爽约和临时放鸽子会影响账号信用。'],
    [
      '有问题就举报',
      '感觉不对劲？在活动房间里使用举报功能。审核期间结算会被冻结，违规者将失去账号。',
    ],
  ] as Array<[string, string]>,
  guidelinesFooter: '违反规则可能导致结算冻结或永久封号。',

  // Post detail
  budgetRuleUserService: '这笔费用是陪伴搭子的服务报酬：准时赴约、全程陪伴',
  budgetRuleUserExpenses: '现场餐饮等消费不含在这笔费用内，默认由你请客',
  budgetRuleUserEscrow: '付款后由 Meeto 托管，活动结束才发放给搭子；取消全额退款',
  signUpCta: '报名',
  signedUpCta: '已报名 · 等待选择',
  candidateSignedUpSnack: '报名成功 — 发帖人会从候选人中选一位',

  // Candidate flow (poster side)
  candidatesTitle: '候选人',
  candidatesEmpty: '还没有人报名 — 通常几分钟内就会有人来',
  approveCta: '选 TA',

  // Publish
  publishTitle: '发布活动',
  hostingFeeLabel: '陪伴服务费',
  expenseLabel: '活动经费',
  expenseTreat: '我请客',
  expenseAA: '现场 AA',
  expenseNoteTreat: '现场餐饮等消费由你承担，搭子轻松赴约',
  budgetRuleExpensesTreat: '现场餐饮等消费由发布者请客，不含在这笔费用内',
  postAuthorLine: (name: string) => `${name} 发起`,
  postTakenCta: '已结成搭子',
  detailTimeLabel: '见面时间',
  detailAreaLabel: '区域',
  detailDurationLabel: '活动时长',
  detailInvitesLabel: '邀约',
  postFinishedCta: '活动已结束',
  budgetRuleService: '这笔费用是陪伴搭子的服务报酬：准时赴约、全程陪伴',
  budgetRuleExpenses: '现场餐饮等消费不包含在内，活动时参与者各自支付',
  budgetRuleRelease: '全款由 Meeto 托管，活动结束后发放给搭子；取消全额退款',
  serviceFeeNoteUser: '这笔费用是陪伴搭子的服务费，不含现场消费',
  publishFieldTitle: '标题',
  publishFieldDesc: '描述',
  publishFieldDescHint: '说说你想做什么、期待什么样的同伴',
  publishPhTitle: '例如：去新开的咖啡馆坐坐',
  publishPhDesc: '例如：城里新开了家咖啡馆，想找个轻松愉快的伴一起去……',
  publishSubmit: '发布',
  hotActivitiesTab: '热门活动',
  templateLaunchCta: '发起',
  publishTemplateQuoteLabel: '发起的活动',
  templatesEmpty: '活动上架中，稍后再来看看',
  publishPickTemplateSub: '从平台精选活动中选一个发起，地点都在合作场所内',
  publishSuccess: '发布成功！等待报名',
  publishFieldsRequiredHint: '先填好标题和描述',

  // User profile
  profileTitle: '个人主页',
  profileActivityPosts: '发布的活动',
  profileDatesCompleted: '完成的活动',
  profileAboutTitle: '关于我',
  profileBasicsTitle: '基本资料',
  profileInterestsTitle: '兴趣',
  profileJobLabel: '职业',
  profileEducationLabel: '学历',
  profileHeightLabel: '身高',
  profileWeightLabel: '体重',
  profileLivesInLabel: '所在地',
  joinedLine: (time: string) => `${time}加入`,

  // Chats / order room
  statusCompleted: '已完成',
  messageInputHint: '输入消息...',
  phoneCopied: '电话号码已复制',
  meetCodeLabel: '见面密码',
  meetCodeHintPayer: '见面时把密码告诉搭子，对方输入后活动开始',
  meetCodeInputHint: '输入对方的 4 位见面密码',
  startMeetCta: '开始活动',
  wrongMeetCodeSnack: '密码不对，再和对方核对一下',
  startedBadge: '进行中',
  serviceRemainingNote: (remaining: string) => `活动进行中 · 剩余 ${remaining}`,
  settlingNote: '活动时间到 · 结算中…',
  remainingShortLabel: (minutes: number) =>
    minutes >= 60
      ? `${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分`
      : `${minutes} 分钟`,
  cancelCtaPayer: '取消活动',
  cancelCtaHost: '放弃活动',
  cancelConfirmTitle: '确定要取消吗？',
  cancelConfirmBody:
    '费用将全额原路退回，对方会收到通知。成单 30 分钟后将无法取消。',
  cancelConfirmYes: '确定取消',
  cancelConfirmNo: '返回',
  cancelledSnack: '已取消，费用全额原路退回',
  forfeitedNote: '无人开始活动，这次约定已作废',
  planCardTitle: '活动计划',
  planConfirmedBadge: '已确认',
  forfeitedBadge: '已作废',
  chatEndedBadge: '已结束',
  chatReadOnlyNote: '会话已关闭，仅可读',

  // Rebooking card (REQUEST message) in the order room
  rebookCta: '再约',
  rebookSheetTitle: (name: string) => `再约 ${name} 一次`,
  rebookPickTemplateLabel: '选择活动',
  requestCardTitle: '活动邀约',
  requestWaitingNote: '等待对方确认',
  requestAcceptCta: '接受',
  requestDeclineCta: '谢绝',
  requestAcceptedPayerNote: '对方已接受，支付后计划生效',
  requestGoPayCta: '去支付',
  requestAcceptedEarnerNote: '已接受 · 等待对方支付',
  requestDeclinedNote: '已谢绝',
  requestSentSnack: '邀约已发出，等对方确认',
  requestAlreadyPendingSnack: '已有一个待确认的邀约，等对方回应吧',

  // Live orders / my activities
  myActivitiesEmpty: '还没有活动 — 去发布或报名一个吧',
  myOrderChatCta: '进入聊天',
  activityPostedAt: (time: string) => `发布时间 ${time}`,
  activityInvites: (count: number) => `收到 ${count} 个邀约`,
  statusAwaitingPayment: '待支付',
  myOrderPayCta: '去支付',
  statusActive: '进行中',
  statusCancelled: '已取消',
  settledEarnerNote: (net: string) => `活动完成 · ${net} 已结算到你的钱包`,
  settledPayerNote: (fee: string) => `活动完成 · ${fee} 已从托管结算`,
  cancelledNote: '计划已取消 · 已全额退款',

  // Profile setup wizard
  setupStepRoleTitle: '你想怎么使用 Meeto？',
  setupStepRoleSub: '选择适合你的身份，之后不可更改。',
  roleUserLabel: '预约活动',
  roleUserSub: '发布想做的活动或邀请陪伴搭子，并支付服务费',
  roleHostLabel: '陪伴赚钱',
  roleHostSub: '成为陪伴搭子，报名活动赚取服务费',
  roleRequiredHint: '先选择你的使用方式',
  setupStepGenderTitle: '我是...',
  setupStepGenderSub: '展示在你的主页上并用于偏好筛选，之后不可更改。',
  genderFemaleLabel: '女生',
  genderMaleLabel: '男生',
  genderRequiredHint: '选择一项后继续',
  setupStepNameTitle: '我的名字是...',
  setupStepNameSub: '这是你在 Meeto 上的展示名',
  setupNameHint: '你的名字',
  nameRequiredHint: '输入名字后继续',
  setupNext: '下一步',
  setupFinish: '完成',
  setupStepSkip: '跳过',
  setupStepBirthTitle: '你的生日是？',
  setupStepBirthSub: '须年满 18 岁。其他人只会看到你的年龄。',
  setupBirthYearLabel: '年',
  setupBirthMonthLabel: '月',
  setupStepBodyTitle: '身高体重',
  setupStepBodySub: '让大家对你有个直观印象',
  setupStepLocationTitle: '你在哪个城市？',
  setupStepLocationSub: '方便为你推荐附近的活动',
  setupStepWorkTitle: '你是做什么的？',
  setupStepWorkSub: '一点背景介绍很加分',
  setupStepTagsTitle: '你的兴趣',
  setupStepTagsSub: '选几个你喜欢的',
  setupStepBioTitle: '介绍一下自己',
  setupStepBioSub: '简短的自我介绍能大大提高匹配率',
  setupStepPhotosTitle: '上传照片',
  setupStepPhotosSub: '一张主照加最多 3 张照片。主照也是真人认证的比对依据。',
  setupMainPhotoBadge: '主照',
  setupCountryLabel: '国家',
  setupCityLabel: '城市',
  setupJobLabel: '职业',
  setupEducationLabel: '学历',
  setupHeightLabel: '身高',
  setupWeightLabel: '体重',
  setupTagsLabel: '兴趣',
  setupBioLabel: '自我介绍',
  setupBioHint: '简单介绍一下：你喜欢什么，怎样算一次开心的出行……',
  setupSave: '保存',
  editPhotosLabel: '照片',
  editNameLabel: '昵称',
  editLocationLabel: '所在地',
  editNotSet: '未设置',
  setupUploadFailed: '上传失败，请重试',
  setupAvatarRequired: '请先添加主页照片',
  verifyGoSetAvatar: '去设置照片',

  countryCities: [
    ['中国', ['武汉']],
    [
      '菲律宾',
      [
        '马尼拉', '奎松城', '马卡蒂', '塔吉格', '帕西格', '帕赛', '帕拉纳克',
        '卡卢坎', '宿务', '达沃', '碧瑶', '伊洛伊洛', '巴科洛德', '卡加延德奥罗',
      ],
    ],
    [
      '印度尼西亚',
      [
        '雅加达', '泗水', '万隆', '棉兰', '三宝垄', '望加锡', '巨港',
        '坦格朗', '勿加泗', '德波', '登巴萨', '日惹',
      ],
    ],
    [
      '越南',
      [
        '胡志明市', '河内', '岘港', '海防', '芹苴', '边和', '顺化',
        '芽庄', '头顿', '大叻',
      ],
    ],
  ] as Array<[string, string[]]>,

  educationOptions: ['高中', '专科', '本科', '硕士', '博士'],
  jobOptions: [
    '学生', 'IT / 工程', '设计 / 创意', '教师', '医疗健康', '销售 / 市场',
    '金融', '服务业', '创业者', '自由职业', '内容创作者', '其他',
  ],
  setupTagOptions: [
    '咖啡', '美食探店', '电影', '音乐', 'K歌', '艺术', '旅行', '健身',
    '徒步', '游戏', '摄影', '阅读', '夜生活', '逛街',
  ],

  // Real-person verification
  verifyTitle: '真人认证',
  verifySub:
    '快速自拍一张，与你的主页照片比对，确认是你本人。认证让见面更安全，并解锁发布、报名和支付。',
  verifyYourPhoto: '你的主页照片',
  verifyStart: '开始认证',
  verifySuccess: '认证通过',
  verifyNoAvatar: '请先设置主页照片，自拍将与它进行比对',
  verifyDialogTitle: '需要真人认证',
  verifyDialogBody: '此操作需要真人认证，只需一分钟。',
  verifyNow: '立即认证',
  verifyLater: '稍后',
  livenessWarnTitle: '闪光提醒',
  livenessWarnBody: '检测过程中屏幕会闪烁不同颜色，对光敏感请谨慎使用。',
  livenessGuide: '把脸正对椭圆框内，然后开始',
  livenessStart: '开始检测',
  livenessStepHold: '保持面部在框内',
  livenessStepBlink: '请眨眨眼',
  livenessStepTurn: '请缓慢左右转头',
  livenessUploading: '正在比对…',
  livenessCameraError: '无法打开摄像头，已切换为拍照上传',
  verifiedStatus: '已认证',
  notVerifiedStatus: '未认证',

  // Gig hall (host-side actions on demand posts)
  gigAppliedBadge: '已报名',
  gigPitchCta: '去报名',

  // Hall
  hallTitle: '活动大厅',
  hallEmpty: '大厅还没有活动，发起一个吧',
  publishMeetTimeLabel: '见面时间',
  publishMeetTimeHint:
    '陪伴搭子服务时间 9:00–22:00，活动约 2 小时，最晚 20:00 开始；报名后不再另约时间',
  publishMeetTimeRequiredHint: '先选好见面时间',
  meetingPointLabel: '见面地点',
  todayLabel: '今天',
  tomorrowLabel: '明天',
  weekdayLabel: (day: number) => WEEKDAY_LABELS[day] ?? '',

  // Proposal composer (host side)
  proposalComposerTitle: '发布活动提案',
  proposalTitleHint: '想陪大家去做什么？比如：去听一场 live',
  proposalDescHint: '例如：店里安静、豆子好，适合慢慢聊……',
  proposalTimeSlotLabel: '可约时段',
  proposalTimeSlotName: (slot: string) =>
    PROPOSAL_SLOT_LABELS[slot] ?? PROPOSAL_SLOT_LABELS.ANYTIME,
  proposalTimeSlotHint:
    '只需选一个大致时段，具体见面时间和价格档由报名的用户选择',

  hostCompletedLabel: (count: number) => `${count} 次陪伴`,
  hostNewLabel: '新人搭子',
  hostInviteCta: '邀请',
  inviteSheetTitle: (name: string) => `邀请 ${name} 来陪伴`,
  inviteNoteHint: '说说你的想法（选填）',
  inviteFeeNote: (fee: string) => `对方接受后，你需支付 ${fee} 服务费以开启计划`,
  inviteSendCta: '发送邀请',
  inviteSentSnack: '邀请已发送 — 对方接受后会通知你',
  inviteAlreadyPendingSnack: '你已邀请过这个提案，等对方回应吧',
  proposalNotOpenSnack: '这个提案已被约走',
  invitedBadge: '已邀请',
  proposalInviteCount: (count: number) => `${count} 人想约`,
  proposalFeePickNote: '金额由你在邀请时选定',
  proposalInvitesTitle: '收到的邀请',
  proposalInvitesEmpty: '还没有人邀请，再等等',
  selectInviterDoneSnack: '已选定 — 对方支付后计划生效',

  durationLabel: (minutes: number) =>
    minutes % 60 === 0
      ? `${minutes / 60} 小时`
      : `${(minutes / 60).toFixed(1)} 小时`,
  durationAbout: (minutes: number) => `约 ${strings.durationLabel(minutes)}`,

  // Me page
  walletLabel: '本月收入',
  walletWithdrawable: (amount: string) => `可提现 ${amount} · T+1 到账`,
  withdraw: '提现',
  withdrawSubmitted: '提现申请已提交',
  menuMyPosts: '我的帖子',
  menuVerification: '认证中心',
  menuLogout: '退出登录',
  menuEditProfile: '编辑资料',
  myPostsEmpty: '还没有帖子',
  postStatusOpen: '招募中',
  postStatusMatched: '已匹配',
  walletTitle: '钱包',
  withdrawSheetTitle: '提现到 GCash',
  withdrawSheetSub: (amount: string) =>
    `最多 ${amount} · T+1 到账 · 收款账户设置随 GCash 接入上线`,
  withdrawHistoryTitle: '提现记录',
  withdrawHistoryEmpty: '还没有提现记录',
  withdrawFailed: '提现失败，请重试',
  withdrawalPending: '处理中',
  withdrawalPaid: '已到账',

  // In-room safety report
  reportCta: '举报',
  reportSheetTitle: '举报这次活动',
  reportSheetSub: '审核期间结算会被冻结，平台会尽快处理',
  reportReasonHint: '说说发生了什么…',
  reportSubmitCta: '提交举报',
  reportSentSnack: '已收到举报，审核期间结算冻结',
  reportReasonRequiredHint: '请填写举报原因',

  // Relative time
  justNow: '刚刚',
  minutesAgo: (minutes: number) => `${minutes} 分钟前`,
  hoursAgo: (hours: number) => `${hours} 小时前`,
  daysAgo: (days: number) => `${days} 天前`,
};
