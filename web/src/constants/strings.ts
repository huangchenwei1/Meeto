/**
 * Centralized UI copy (Filipino). Keys, scene tags and other identifiers
 * stay English; only display values are localized.
 */

/** Indexed by Date.getDay(): Sunday first. */
const WEEKDAY_LABELS = ['Lin', 'Lun', 'Mar', 'Miy', 'Huw', 'Biy', 'Sab'];

/** Display names for host-pitch availability windows. */
const PROPOSAL_SLOT_LABELS: Record<string, string> = {
  ANYTIME: 'Kahit kailan',
  NOON: 'Tanghali',
  EVENING: 'Gabi',
};

const SCENE_LABELS: Record<string, string> = {
  Coffee: 'Kape',
  Dinner: 'Hapunan',
  Bar: 'Bar',
  Movie: 'Sine',
  Tea: 'Tsaa',
};

export const strings = {
  sceneLabel: (tag: string) => SCENE_LABELS[tag] ?? tag,

  // Splash
  splashBrand: 'MEETO',
  splashLines: [
    'May mga gabing hindi dapat mag-isa.',
    'May upuang nakalaan sa harap mo.',
    'Sine, hapunan, o lakad sa siyudad.',
    'Hindi mo kailangang ipaliwanag kung bakit.',
    'May maglalaan ng oras na ito para sa iyo.',
  ],
  splashEnterCta: 'Pumasok sa gabing ito',
  splashEntering: 'Binubuksan ang pinto',
  splashEnterFailed: 'Hindi nakapasok, subukan ulit',

  // Login
  loginTagline: 'MEET · PLAN · EARN',
  loginSignInTitle: 'Mag-login gamit ang numero mo',
  loginCodeSentTo: (phone: string) => `Naipadala ang code sa ${phone}`,
  loginCodeHint: '6-digit na code',
  loginChangeNumber: 'Palitan ang numero',
  loginDevCodeNote: (code: string) => `Demo · Ang code mo ay ${code}`,
  loginContinueCta: 'Magpatuloy',
  loginVerifyCta: 'I-verify',
  loginPhoneRequiredHint: 'Ilagay ang numero mo',
  loginInvalidCode: 'Maling code, subukan ulit',

  // Shared errors
  errorGeneric: 'May nangyaring mali, subukan ulit',
  errorNetwork: 'Problema sa network, subukan ulit',
  errorMessageNotSent: 'Hindi naipadala, subukan ulit',

  // Dead ends: unknown routes and rooms the viewer cannot open
  notFoundTitle: 'Nawawala ang page',
  notFoundBody: 'Wala o hindi na available ang page na ito',
  backToHallCta: 'Balik sa hall',
  orderUnavailableNote: 'Wala ang room na ito o wala kang access dito',

  // Tabs (used as page titles; the tab bar itself is icons-only)
  tabChats: 'Mga mensahe',
  tabMyActivities: 'Mga activity ko',
  tabMe: 'Ako',
  chatsEmpty: 'Wala pang kasama — lalabas sila dito kapag nag-match kayo',
  chatsHint: 'Mananatili dito ang chat ninyo ng kasama pagkatapos mag-match',
  msgPreviewPlan: '[Plano]',
  msgPreviewRequest: '[Imbitasyon]',
  chatLiveBadge: 'Ongoing ang activity',

  // Escrow payment page
  paymentTitle: 'Kumpirmahin ang bayad',
  paymentFeeLabel: 'Service fee ng kasama',
  paymentMethodDemo: 'Demo na bayad (paparating ang GCash)',
  paymentEscrowNote:
    'Hindi direktang mapupunta sa kabila ang pera mo. Hawak ito ng Meeto hanggang matapos ang activity; full refund kapag nakansela. Mabubuksan ang chat at tawag pagkabayad.',
  paymentPayCta: (fee: string) => `Bayaran ang ${fee}`,
  paymentPaying: 'Binabayaran...',
  paymentDoneSnack: 'Hawak na ng escrow ang bayad',
  paymentFailedSnack: 'Hindi natuloy ang bayad, subukan ulit',
  paymentCancelOrderCta: 'Hindi na, kanselahin ang plano',
  unpaidCancelledSnack: 'Nakansela',
  paymentLaterSnack: 'Awtomatikong makakansela ang planong hindi nabayaran',
  myOrderDetailCta: 'Tingnan ang detalye',
  myOrderTotal: (fee: string) => `Kabuuan ${fee}`,
  myOrderHostLine: (name: string) => `${name} · Kasama`,
  myOrderGuestLine: (name: string) => `${name} · Nag-aya`,
  myOrderCreatedAt: (time: string) => `Nag-match ${time}`,
  chatLockedNote: 'Mabubuksan ang chat kapag nasa escrow na ang bayad',
  deletePostConfirmTitle: 'Burahin ang post na ito?',
  deletePostConfirmBody:
    'Mare-release ang mga nag-apply. Hindi na ito maibabalik.',
  deletePostYes: 'Burahin',
  deletePostNo: 'Huwag',
  deletePostDone: 'Nabura ang post',
  appliedCount: (count: number) => `${count} ang nag-apply`,
  signupNoticePill: (count: number) => `${count} bagong aplikante`,
  dealNoticePay: 'May kasama ka na · Magbayad para ma-lock',
  dealNoticeGreet: 'Ready na ang kasama · Kumustahin mo',
  dealNoticeOngoing: 'Ongoing ang activity · Balik sa room',
  dealNoticeActive: 'Ready na ang kasama · Pasok sa room',
  dealNoticeMore: (count: number) => `+${count} pa`,

  // Community guidelines
  bannerTitle: 'Totoong meetup, ligtas lagi',
  bannerSub: 'Mga patakarang sinusunod ng bawat Meeto user',
  guidelinesTitle: 'Alituntunin ng komunidad',
  guidelinesIntro:
    'Ang Meeto ay para sa totoong kasama sa totoong activity. Pinapanatili ng mga patakarang ito na ligtas at tapat ang bawat meetup.',
  guidelinesRules: [
    [
      'Maging totoo',
      'Ikaw mismo ang dapat nasa photo. Ban ang pagpapanggap.',
    ],
    [
      'Magrespetuhan',
      'Bawal ang panggigipit, pang-iinsulto o pamimilit — sa app man o sa personal. Isang report lang ay puwede ka nang ma-ban.',
    ],
    [
      'Sa pampublikong lugar',
      'Pumili ng cafe, restaurant o mall. Huwag lumipat sa pribadong lugar sa unang meetup.',
    ],
    [
      'Kasama lang, wala nang iba',
      'Companionship sa totoong activity lang ang Meeto. Mahigpit na bawal ang anumang sexual na alok; isusumbong ito sa awtoridad.',
    ],
    [
      'Pera sa platform lang',
      'Hawak ng Meeto ang bayad hanggang matapos ang activity. Huwag magbayad o tumanggap sa labas — walang proteksyon doon.',
    ],
    [
      'Dumating sa oras',
      'Kapag nag-match, tuparin ang usapan. Nakakasira sa credit ng account ang no-show at biglaang pag-atras.',
    ],
    [
      'Mag-report agad',
      'May mali bang naramdaman? Gamitin ang report sa activity room. Naka-freeze ang settlement habang nirere-view, at mawawalan ng account ang lumabag.',
    ],
  ] as Array<[string, string]>,
  guidelinesFooter:
    'Ang paglabag ay puwedeng mauwi sa frozen settlement o permanenteng ban.',

  // Post detail
  budgetRuleUserService:
    'Bayad ito sa serbisyo ng kasama: pagdating sa oras at pagsama sa buong activity',
  budgetRuleUserExpenses:
    'Hindi kasama rito ang pagkain at iba pang gastos sa lugar — ikaw ang taya',
  budgetRuleUserEscrow:
    'Hawak ng Meeto ang bayad hanggang matapos ang activity; full refund kapag nakansela',
  signUpCta: 'Mag-apply',
  signedUpCta: 'Naka-apply na · Hinihintay ang pili',
  candidateSignedUpSnack:
    'Naka-apply ka na — pipili ang nag-post mula sa mga kandidato',

  // Candidate flow (poster side)
  candidatesTitle: 'Mga kandidato',
  candidatesEmpty:
    'Wala pang nag-a-apply — kadalasan may dumarating sa loob ng ilang minuto',
  approveCta: 'Piliin',

  // Publish
  publishTitle: 'Mag-post ng activity',
  hostingFeeLabel: 'Service fee ng kasama',
  expenseLabel: 'Gastos sa activity',
  expenseTreat: 'Ako ang taya',
  expenseAA: 'KKB',
  expenseNoteTreat:
    'Sagot mo ang pagkain at gastos sa lugar; relax lang ang kasama',
  budgetRuleExpensesTreat:
    'Sagot ng nag-post ang gastos sa lugar; hindi ito kasama sa fee',
  postAuthorLine: (name: string) => `Post ni ${name}`,
  postTakenCta: 'May kasama na',
  detailTimeLabel: 'Oras ng meetup',
  detailAreaLabel: 'Lugar',
  detailDurationLabel: 'Tagal',
  detailInvitesLabel: 'Mga imbitasyon',
  postFinishedCta: 'Tapos na ang activity',
  budgetRuleService:
    'Bayad ito sa serbisyo ng kasama: pagdating sa oras at pagsama sa buong activity',
  budgetRuleExpenses:
    'Hindi kasama ang gastos sa lugar; KKB ang mga kasali sa activity',
  budgetRuleRelease:
    'Hawak ng Meeto ang buong bayad at ibibigay sa kasama pagkatapos ng activity; full refund kapag nakansela',
  serviceFeeNoteUser:
    'Service fee ito ng kasama; hindi kasama ang gastos sa lugar',
  publishFieldTitle: 'Pamagat',
  publishFieldDesc: 'Detalye',
  publishFieldDescHint:
    'Ikuwento kung ano ang gusto mong gawin at anong kasama ang hanap mo',
  publishPhTitle: 'Hal.: Tara sa bagong cafe',
  publishPhDesc:
    'Hal.: May bagong cafe sa city, hanap ko ay chill na kasama para pasyalan ito…',
  publishSubmit: 'I-post',
  hotActivitiesTab: 'Sikat na activities',
  templateLaunchCta: 'Simulan',
  publishTemplateQuoteLabel: 'Activity na sisimulan',
  templatesEmpty: 'Inihahanda pa ang mga activity, balikan mo mamaya',
  publishPickTemplateSub:
    'Pumili mula sa mga piling activity ng platform; lahat ay sa partner venues',
  publishSuccess: 'Na-post! Hintayin ang mga aplikante',
  publishFieldsRequiredHint: 'Lagyan muna ng pamagat at detalye',

  // User profile
  profileTitle: 'Profile',
  profileActivityPosts: 'Mga na-post na activity',
  profileDatesCompleted: 'Natapos na activity',
  profileAboutTitle: 'Tungkol sa akin',
  profileBasicsTitle: 'Basic info',
  profileInterestsTitle: 'Mga hilig',
  profileJobLabel: 'Trabaho',
  profileEducationLabel: 'Pinag-aralan',
  profileHeightLabel: 'Taas',
  profileWeightLabel: 'Timbang',
  profileLivesInLabel: 'Lokasyon',
  joinedLine: (time: string) => `Sumali ${time}`,

  // Chats / order room
  statusCompleted: 'Tapos na',
  messageInputHint: 'Mag-type ng mensahe...',
  phoneCopied: 'Na-copy ang numero',
  meetCodeLabel: 'Meet code',
  meetCodeHintPayer:
    'Sabihin ang code sa kasama pagkikita; pag-enter nila, magsisimula ang activity',
  meetCodeInputHint: 'Ilagay ang 4-digit meet code ng kabila',
  startMeetCta: 'Simulan ang activity',
  wrongMeetCodeSnack: 'Maling code, i-double check sa kasama',
  startedBadge: 'Ongoing',
  serviceRemainingNote: (remaining: string) =>
    `Ongoing ang activity · ${remaining} na lang`,
  settlingNote: 'Tapos na ang oras · Sine-settle…',
  remainingShortLabel: (minutes: number) =>
    minutes >= 60
      ? `${Math.floor(minutes / 60)} oras ${minutes % 60} min`
      : `${minutes} min`,
  cancelCtaPayer: 'Kanselahin ang activity',
  cancelCtaHost: 'Umatras sa activity',
  cancelConfirmTitle: 'Sigurado ka bang ikakansela?',
  cancelConfirmBody:
    'Mare-refund nang buo ang bayad at maaabisuhan ang kabila. Hindi na puwedeng magkansela 30 minuto matapos mag-match.',
  cancelConfirmYes: 'Oo, ikansela',
  cancelConfirmNo: 'Bumalik',
  cancelledSnack: 'Nakansela, na-refund nang buo ang bayad',
  forfeitedNote: 'Walang nagsimula ng activity; hindi na ito matutuloy',
  planCardTitle: 'Plano',
  planConfirmedBadge: 'Kumpirmado',
  forfeitedBadge: 'Na-forfeit',
  chatEndedBadge: 'Tapos na',
  chatReadOnlyNote: 'Sarado na ang chat, basa na lang',

  // Rebooking card (REQUEST message) in the order room
  rebookCta: 'Ayain ulit',
  rebookSheetTitle: (name: string) => `Ayain ulit si ${name}`,
  rebookPickTemplateLabel: 'Pumili ng activity',
  requestCardTitle: 'Imbitasyon',
  requestWaitingNote: 'Hinihintay ang sagot',
  requestAcceptCta: 'Tanggapin',
  requestDeclineCta: 'Tanggihan',
  requestAcceptedPayerNote:
    'Tinanggap na — magbayad para matuloy ang plano',
  requestGoPayCta: 'Magbayad',
  requestAcceptedEarnerNote: 'Tinanggap · Hinihintay ang bayad',
  requestDeclinedNote: 'Tinanggihan',
  requestSentSnack: 'Naipadala ang imbitasyon, hintayin ang sagot',
  requestAlreadyPendingSnack:
    'May nakabinbing imbitasyon pa, hintayin muna ang sagot',

  // Live orders / my activities
  myActivitiesEmpty: 'Wala ka pang activity — mag-post o mag-apply',
  myOrderChatCta: 'Buksan ang chat',
  activityPostedAt: (time: string) => `Na-post ${time}`,
  activityInvites: (count: number) => `${count} imbitasyon`,
  statusAwaitingPayment: 'Hintay sa bayad',
  myOrderPayCta: 'Magbayad',
  statusActive: 'Ongoing',
  statusCancelled: 'Nakansela',
  settledEarnerNote: (net: string) =>
    `Tapos na ang activity · ${net} naipasok sa wallet mo`,
  settledPayerNote: (fee: string) =>
    `Tapos na ang activity · ${fee} na-settle mula sa escrow`,
  cancelledNote: 'Nakansela ang plano · Na-refund nang buo',

  // Profile setup wizard
  setupStepRoleTitle: 'Paano mo gagamitin ang Meeto?',
  setupStepRoleSub: 'Pumili ng role; hindi na ito mapapalitan.',
  roleUserLabel: 'Mag-book ng activity',
  roleUserSub:
    'Mag-post ng gusto mong gawin o mag-aya ng kasama, at magbayad ng service fee',
  roleHostLabel: 'Kumita bilang kasama',
  roleHostSub:
    'Maging kasama: mag-apply sa mga activity at kumita ng service fee',
  roleRequiredHint: 'Pumili muna ng role',
  setupStepGenderTitle: 'Ako ay...',
  setupStepGenderSub:
    'Lalabas sa profile mo at gagamitin sa filtering; hindi na mapapalitan.',
  genderFemaleLabel: 'Babae',
  genderMaleLabel: 'Lalaki',
  genderRequiredHint: 'Pumili para magpatuloy',
  setupStepNameTitle: 'Ang pangalan ko ay...',
  setupStepNameSub: 'Ito ang display name mo sa Meeto',
  setupNameHint: 'Pangalan mo',
  nameRequiredHint: 'Ilagay ang pangalan para magpatuloy',
  setupNext: 'Susunod',
  setupFinish: 'Tapusin',
  setupStepSkip: 'Laktawan',
  setupStepBirthTitle: 'Kailan ka ipinanganak?',
  setupStepBirthSub: 'Dapat 18+ ka. Edad mo lang ang makikita ng iba.',
  setupBirthYearLabel: 'Taon',
  setupBirthMonthLabel: 'Buwan',
  setupStepBodyTitle: 'Taas at timbang',
  setupStepBodySub: 'Para may ideya agad ang iba',
  setupStepLocationTitle: 'Saang lungsod ka?',
  setupStepLocationSub: 'Para mairekomenda ang mga activity na malapit sa iyo',
  setupStepWorkTitle: 'Ano ang trabaho mo?',
  setupStepWorkSub: 'Malaking plus ang kaunting background',
  setupStepTagsTitle: 'Mga hilig mo',
  setupStepTagsSub: 'Pumili ng ilang gusto mo',
  setupStepBioTitle: 'Magpakilala ka',
  setupStepBioSub: 'Malaking tulong sa match ang maikling intro',
  setupStepPhotosTitle: 'Mag-upload ng photos',
  setupStepPhotosSub:
    'Isang main photo at hanggang 3 pa.',
  setupMainPhotoBadge: 'Main',
  setupCountryLabel: 'Bansa',
  setupCityLabel: 'Lungsod',
  setupJobLabel: 'Trabaho',
  setupEducationLabel: 'Pinag-aralan',
  setupHeightLabel: 'Taas',
  setupWeightLabel: 'Timbang',
  setupTagsLabel: 'Mga hilig',
  setupBioLabel: 'Tungkol sa akin',
  setupBioHint:
    'Maikling intro: ano ang gusto mo, ano ang masayang lakad para sa iyo…',
  setupSave: 'I-save',
  editPhotosLabel: 'Mga photo',
  editNameLabel: 'Pangalan',
  editLocationLabel: 'Lokasyon',
  editNotSet: 'Wala pa',
  setupUploadFailed: 'Hindi na-upload, subukan ulit',
  setupAvatarRequired: 'Maglagay muna ng main photo',

  countryCities: [
    [
      'Pilipinas',
      [
        'Manila', 'Quezon City', 'Makati', 'Taguig', 'Pasig', 'Pasay',
        'Parañaque', 'Caloocan', 'Cebu', 'Davao', 'Baguio', 'Iloilo',
        'Bacolod', 'Cagayan de Oro',
      ],
    ],
    [
      'Indonesia',
      [
        'Jakarta', 'Surabaya', 'Bandung', 'Medan', 'Semarang', 'Makassar',
        'Palembang', 'Tangerang', 'Bekasi', 'Depok', 'Denpasar', 'Yogyakarta',
      ],
    ],
    [
      'Vietnam',
      [
        'Ho Chi Minh', 'Hanoi', 'Da Nang', 'Hai Phong', 'Can Tho',
        'Bien Hoa', 'Hue', 'Nha Trang', 'Vung Tau', 'Da Lat',
      ],
    ],
  ] as Array<[string, string[]]>,

  educationOptions: [
    'High school', 'Vocational', 'College', "Master's", 'Doctorate',
  ],
  jobOptions: [
    'Estudyante', 'IT / Engineering', 'Design / Creative', 'Guro',
    'Healthcare', 'Sales / Marketing', 'Finance', 'Service crew',
    'Negosyante', 'Freelance', 'Content creator', 'Iba pa',
  ],
  setupTagOptions: [
    'Kape', 'Food trip', 'Sine', 'Musika', 'Videoke', 'Sining', 'Travel',
    'Gym', 'Hiking', 'Games', 'Photography', 'Pagbabasa', 'Nightlife',
    'Shopping',
  ],

  // Gig hall (host-side actions on demand posts)
  gigAppliedBadge: 'Naka-apply',
  gigPitchCta: 'Mag-apply',

  // Hall
  hallTitle: 'Activity hall',
  hallEmpty: 'Wala pang activity sa hall — magsimula ka',
  publishMeetTimeLabel: 'Oras ng meetup',
  publishMeetTimeHint:
    'Available ang kasama 9:00–22:00; mga 2 oras ang activity at 20:00 ang pinakahuling simula. Hindi na mapapalitan ang oras pagkatapos.',
  publishMeetTimeRequiredHint: 'Pumili muna ng oras ng meetup',
  meetingPointLabel: 'Tagpuan',
  todayLabel: 'Ngayon',
  tomorrowLabel: 'Bukas',
  weekdayLabel: (day: number) => WEEKDAY_LABELS[day] ?? '',

  // Proposal composer (host side)
  proposalComposerTitle: 'Mag-post ng alok',
  proposalTitleHint:
    'Saan mo gustong may samahan? Hal.: Manood ng live gig',
  proposalDescHint:
    'Hal.: Tahimik ang lugar at masarap ang kape, bagay sa chill na kuwentuhan…',
  proposalTimeSlotLabel: 'Available na oras',
  proposalTimeSlotName: (slot: string) =>
    PROPOSAL_SLOT_LABELS[slot] ?? PROPOSAL_SLOT_LABELS.ANYTIME,
  proposalTimeSlotHint:
    'Tinatayang oras lang ang pipiliin; ang eksaktong oras at presyo ay sa mag-aaya',

  hostCompletedLabel: (count: number) => `${count}x nakasama`,
  hostNewLabel: 'Bagong kasama',
  hostInviteCta: 'Ayain',
  inviteSheetTitle: (name: string) => `Ayain si ${name}`,
  inviteNoteHint: 'Sabihin ang plano mo (optional)',
  inviteFeeNote: (fee: string) =>
    `Kapag tinanggap, magbabayad ka ng ${fee} para simulan ang plano`,
  inviteSendCta: 'Ipadala',
  inviteSentSnack: 'Naipadala — maaabisuhan ka kapag tinanggap',
  inviteAlreadyPendingSnack:
    'Naka-aya ka na sa alok na ito, hintayin ang sagot',
  proposalNotOpenSnack: 'Nakuha na ang alok na ito',
  invitedBadge: 'Naka-aya na',
  proposalInviteCount: (count: number) => `${count} ang nag-aya`,
  proposalFeePickNote: 'Ikaw ang pipili ng halaga sa pag-aya',
  proposalInvitesTitle: 'Mga natanggap na aya',
  proposalInvitesEmpty: 'Wala pang nag-aaya, maghintay lang',
  selectInviterDoneSnack:
    'Napili na — magsisimula ang plano kapag nagbayad sila',

  durationLabel: (minutes: number) =>
    minutes % 60 === 0
      ? `${minutes / 60} oras`
      : `${(minutes / 60).toFixed(1)} oras`,
  durationAbout: (minutes: number) => `mga ${strings.durationLabel(minutes)}`,

  // Me page
  walletLabel: 'Kita ngayong buwan',
  walletWithdrawable: (amount: string) =>
    `Puwedeng i-withdraw ${amount} · T+1`,
  withdraw: 'Mag-withdraw',
  withdrawSubmitted: 'Naisumite ang withdrawal',
  menuMyPosts: 'Mga post ko',
  menuLogout: 'Mag-logout',
  menuEditProfile: 'I-edit ang profile',
  myPostsEmpty: 'Wala pang post',
  postStatusOpen: 'Bukas pa',
  postStatusMatched: 'May kasama na',
  walletTitle: 'Wallet',
  withdrawSheetTitle: 'I-withdraw sa GCash',
  withdrawSheetSub: (amount: string) =>
    `Hanggang ${amount} · T+1 · Ise-setup ang account kapag live na ang GCash`,
  withdrawHistoryTitle: 'Mga withdrawal',
  withdrawHistoryEmpty: 'Wala pang withdrawal',
  withdrawFailed: 'Hindi natuloy, subukan ulit',
  withdrawalPending: 'Pinoproseso',
  withdrawalPaid: 'Naipadala na',

  // In-room safety report
  reportCta: 'I-report',
  reportSheetTitle: 'I-report ang activity na ito',
  reportSheetSub:
    'Mafi-freeze ang settlement habang nirere-view; aaksyunan agad ng platform',
  reportReasonHint: 'Ikuwento kung ano ang nangyari…',
  reportSubmitCta: 'Isumite',
  reportSentSnack:
    'Natanggap ang report; naka-freeze ang settlement habang nirere-view',
  reportReasonRequiredHint: 'Ilagay ang dahilan ng report',

  // Relative time
  justNow: 'Ngayon lang',
  minutesAgo: (minutes: number) => `${minutes} min ang nakalipas`,
  hoursAgo: (hours: number) => `${hours} oras ang nakalipas`,
  daysAgo: (days: number) => `${days} araw ang nakalipas`,
};
