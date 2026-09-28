/// 「猫生重开」模拟器（CatsKit 2.0） —— 静态数据表
///
/// 这里集中放所有**可调平衡数值**与文案：活动决策、档位阈值、奖励表、
/// 部件掉落权重、帮派库、成就定义。改平衡只需要改本文件。
library;

import 'dart:math';

import 'gang_league_roster.dart';
import 'life_sim_models.dart';

// =====================================================================
// 一、开局
// =====================================================================

/// 开局欢迎语（新游戏第 1 天弹窗 + 日志）
const String kWelcomeZh = '欢迎进入 C.A.T.S. 的世界！';
const String kWelcomeEn = 'Welcome to the world of C.A.T.S.!';

/// 开局发放的部件数量
const int kStarterBodyCount = 3;
const int kStarterWeaponCount = 3;
const int kStarterGadgetCount = 3;
const int kStarterWheelCount = 6;

/// 开局部件总数（= 3 + 3 + 3 + 6 = 15）
const int kStarterPartTotal =
    kStarterBodyCount +
    kStarterWeaponCount +
    kStarterGadgetCount +
    kStarterWheelCount;

/// 开局部件稀有度权重。
///
/// 下标 = `Rarity.index`（r1..r6）：以 R2 为主，少量 R1/R3，
/// 更少 R4，极少 R5，极极少 R6。
const List<int> kStarterRarityWeights = <int>[12, 50, 25, 9, 3, 1];

/// 开局保底稀有度下标（5 = R6）：15 个部件里至少有一个 R6
const int kStarterGuaranteedRarityIndex = 5;

// =====================================================================
// 二、活动决策
// =====================================================================

/// 一次活动决策（玩家在活动进行时做出的选择）
class ActivityChoice {
  final String id;
  final String nameZh;
  final String nameEn;
  final String descZh;
  final String descEn;

  /// 消耗精力
  final int energyCost;

  /// 进度系数（进度 = 车队战力分 × 系数）
  final double coef;

  /// 翻车概率（0~1）与翻车时的系数
  final double backfireChance;
  final double backfireCoef;

  /// 额外固定收益
  final int bonusCash;
  final int bonusToken;

  /// 帮派活跃度提升
  final int gangActivityGain;

  /// 给下个活动周期的进度加成（0.2 = +20%）
  final double nextActivityBonus;

  /// 系数在 0.8~2.0 之间随机（「王牌百搭」）
  final bool wildCard;

  /// 固定进度点数（废铁行动专用；非 null 时忽略 [coef]，与战力无关）
  final int? fixedPoints;

  /// GP 专用：一次决策消耗的汽油（0 = 不消耗）
  final int gasCost;

  /// GP 专用：旗帜随机变动区间（含两端，均匀分布）
  ///
  /// `flagMin >= 0` 表示「只增不减」的低风险档。
  final int flagMin;
  final int flagMax;

  /// GP 专用：基础分数（最终得分 = 基础分 × GP 分数乘数）
  final int baseScore;

  const ActivityChoice({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.descZh,
    required this.descEn,
    required this.energyCost,
    required this.coef,
    this.backfireChance = 0,
    this.backfireCoef = 0,
    this.bonusCash = 0,
    this.bonusToken = 0,
    this.gangActivityGain = 0,
    this.nextActivityBonus = 0,
    this.wildCard = false,
    this.fixedPoints,
    this.gasCost = 0,
    this.flagMin = 0,
    this.flagMax = 0,
    this.baseScore = 0,
  });
}

/// 所有活动通用的三个决策
const List<ActivityChoice> kCommonChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'steady',
    nameZh: '稳扎稳打',
    nameEn: 'Steady Run',
    descZh: '少花精力，收益稳定，不会翻车',
    descEn: 'Cheap and safe, never backfires',
    energyCost: 1,
    coef: 0.55,
  ),
  ActivityChoice(
    id: 'normal',
    nameZh: '常规出击',
    nameEn: 'Standard Run',
    descZh: '标准投入，标准收益',
    descEn: 'Standard input, standard reward',
    energyCost: 2,
    coef: 1.00,
  ),
  ActivityChoice(
    id: 'burst',
    nameZh: '全力冲刺',
    nameEn: 'All-Out Rush',
    descZh: '高投入高回报，但有 25% 概率翻车',
    descEn: 'Risky: 25% chance to backfire',
    energyCost: 4,
    coef: 1.70,
    backfireChance: 0.25,
    backfireCoef: 0.50,
  ),
];

/// 每个活动专属的决策（风味 + 差异化收益）
final Map<String, ActivityChoice> kSignatureChoices =
    <String, ActivityChoice>{
      'gp': const ActivityChoice(
        id: 'nip',
        nameZh: '氮气全开',
        nameEn: 'Nitro Overdrive',
        descZh: '额外获得 40 紫票',
        descEn: 'Also grants 40 Cash',
        energyCost: 3,
        coef: 1.35,
        bonusCash: 40,
      ),
      'space': const ActivityChoice(
        id: 'mega',
        nameZh: '模块拼装',
        nameEn: 'Module Assembly',
        descZh: '帮派活跃度 +3',
        descEn: 'Gang activity +3',
        energyCost: 3,
        coef: 1.30,
        gangActivityGain: 3,
      ),
      'scrap': const ActivityChoice(
        id: 'recycle',
        nameZh: '废铁回收',
        nameEn: 'Scrap Recycling',
        descZh: '额外获得 60 代币',
        descEn: 'Also grants 60 Tokens',
        energyCost: 3,
        coef: 1.25,
        bonusToken: 60,
      ),
      'allstar': const ActivityChoice(
        id: 'show',
        nameZh: '全明星秀',
        nameEn: 'All-Star Showcase',
        descZh: '消耗 5 精力，但收益极高',
        descEn: 'Costs 5 energy for a huge payoff',
        energyCost: 5,
        coef: 1.55,
        bonusCash: 80,
      ),
      'gear': const ActivityChoice(
        id: 'overdrive',
        nameZh: '齿轮超频',
        nameEn: 'Gear Overdrive',
        descZh: '20% 概率翻车',
        descEn: '20% chance to backfire',
        energyCost: 3,
        coef: 1.45,
        backfireChance: 0.20,
        backfireCoef: 0.60,
      ),
      'champ': const ActivityChoice(
        id: 'gamble',
        nameZh: '黑市豪赌',
        nameEn: 'Black Market Gamble',
        descZh: '额外获得 120 代币',
        descEn: 'Also grants 120 Tokens',
        energyCost: 4,
        coef: 1.60,
        bonusToken: 120,
      ),
      'tavern': const ActivityChoice(
        id: 'intel',
        nameZh: '酒馆情报',
        nameEn: 'Tavern Intel',
        descZh: '下个活动进度 +20%',
        descEn: 'Next activity +20% progress',
        energyCost: 2,
        coef: 1.10,
        nextActivityBonus: 0.20,
      ),
      'joker': const ActivityChoice(
        id: 'wild',
        nameZh: '王牌百搭',
        nameEn: 'Wild Card',
        descZh: '系数在 0.8~2.0 之间随机',
        descEn: 'Random multiplier 0.8~2.0',
        energyCost: 3,
        coef: 1.00,
        wildCard: true,
      ),
    };

// =====================================================================
// 三、档位阈值与奖励
// =====================================================================

/// 档位线（从高到低排；`min` 为达到该档所需的进度分）
class RankTier {
  final String rank;
  final int min;
  const RankTier(this.rank, this.min);
}

/// 大活动（4 天周期）档位线
const List<RankTier> kMajorTiers = <RankTier>[
  RankTier('S', 700000),
  RankTier('A', 120000),
  RankTier('B', 20000),
  RankTier('C', 3000),
  RankTier('D', 0),
];

/// 小活动（3 天周期）档位线
const List<RankTier> kMinorTiers = <RankTier>[
  RankTier('S', 350000),
  RankTier('A', 60000),
  RankTier('B', 10000),
  RankTier('C', 1500),
  RankTier('D', 0),
];

/// 档位奖励（大活动口径；小活动按 [kMinorRewardScale] 缩放）
class RankReward {
  final String rank;

  /// 紫票 / 代币
  final int cash;
  final int token;

  /// 保底部件数
  final int partCount;

  /// 额外多掉一个部件的概率（%）
  final int extraPartChancePct;

  const RankReward({
    required this.rank,
    required this.cash,
    required this.token,
    required this.partCount,
    this.extraPartChancePct = 0,
  });
}

/// 小活动的紫票 / 代币按此比例折算
const double kMinorRewardScale = 0.5;

/// 大活动档位奖励
const Map<String, RankReward> kRankRewards = <String, RankReward>{
  'S': RankReward(
    rank: 'S',
    cash: 1200,
    token: 500,
    partCount: 3,
  ),
  'A': RankReward(
    rank: 'A',
    cash: 500,
    token: 200,
    partCount: 2,
  ),
  'B': RankReward(
    rank: 'B',
    cash: 200,
    token: 80,
    partCount: 1,
    extraPartChancePct: 50,
  ),
  'C': RankReward(
    rank: 'C',
    cash: 80,
    token: 30,
    partCount: 1,
    extraPartChancePct: 20,
  ),
  'D': RankReward(
    rank: 'D',
    cash: 30,
    token: 10,
    partCount: 1,
  ),
};

/// 部件掉落稀有度权重。
///
/// 值的下标 = `Rarity.index`（r1..r6），共 6 项；权重为 0 表示不掉该稀有度。
const Map<String, List<int>> kDropWeights = <String, List<int>>{
  // 大活动
  'gp': <int>[0, 10, 25, 35, 25, 5],
  'space': <int>[0, 0, 15, 30, 40, 15],
  'scrap': <int>[0, 5, 30, 40, 22, 3],
  'allstar': <int>[0, 5, 25, 35, 28, 7],
  'gear': <int>[0, 0, 12, 28, 40, 20],
  // 小活动
  'champ': <int>[10, 30, 35, 20, 5, 0],
  'tavern': <int>[15, 32, 35, 15, 3, 0],
  'joker': <int>[10, 30, 35, 20, 5, 0],
};

// =====================================================================
// 三之二、废铁行动（特殊活动：总进度条 + 奖励节点）
// =====================================================================

/// 废铁行动的总进度
const int kScrapTotalProgress = 2000;

/// 齿轮奔袭的总进度
const int kGearTotalProgress = 12500;

/// 齿轮奔袭：按**单车最高战力**取「基础进度」的阶梯（从高到低匹配）
const List<({int power, int points})> kGearPowerTiers =
    <({int power, int points})>[
      (power: 2000000, points: 1000),
      (power: 1000000, points: 500),
      (power: 400000, points: 350),
      (power: 100000, points: 200),
    ];

/// 齿轮奔袭的最低战力要求：单车最高战力低于该值时进度 ×0（提示提升车辆战力）
const int kGearMinPower = 100000;

/// 齿轮奔袭：单车最高战力 → 基础进度
///
/// 低于 [kGearMinPower] 返回 0（即进度 ×0）。
int gearBasePoints(int maxCarPower) {
  if (maxCarPower < kGearMinPower) return 0;
  for (final t in kGearPowerTiers) {
    if (maxCarPower >= t.power) return t.points;
  }
  return kGearPowerTiers.last.points;
}

/// 齿轮奔袭 / 全明星：精力 → 倍数（两活动共用同一套阶梯）
const Map<int, double> kGearEnergyMultipliers = <int, double>{
  1: 0.25,
  2: 0.5,
  4: 0.75,
  8: 1.0,
};

/// 全明星沿用齿轮的精力倍数
const Map<int, double> kAllStarEnergyMultipliers = kGearEnergyMultipliers;

/// 齿轮奔袭的四档决策（进度 = 单车最高战力基础值 × 精力倍数）
const List<ActivityChoice> kGearChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'gear1',
    nameZh: '浅尝辄止',
    nameEn: 'A Taste',
    descZh: '投入最少，收益最少',
    descEn: 'Least effort, least reward',
    energyCost: 1,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear2',
    nameZh: '投入精力',
    nameEn: 'Put In Effort',
    descZh: '投入一般',
    descEn: 'Moderate effort',
    energyCost: 2,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear3',
    nameZh: '全神贯注',
    nameEn: 'Full Focus',
    descZh: '投入较多',
    descEn: 'High effort',
    energyCost: 4,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear4',
    nameZh: '我爱上班',
    nameEn: 'Love the Grind',
    descZh: '全力投入',
    descEn: 'All in',
    energyCost: 8,
    coef: 0,
  ),
];

/// 里程碑式活动（总进度条 + 奖励节点）的配置
class MilestoneConfig {
  final String id;

  /// 总进度
  final int total;

  /// 节点位置取整步长（节点位置都是该值的倍数）
  final int step;

  /// 看广告的进度档位（随机取一档；空 = 该活动看广告只给紫票）
  final List<int> adProgressTiers;

  /// 部件奖励是否为「随机 R6 部件」（齿轮奔袭 = true，废铁行动 = 指定 15 种）
  final bool randomR6Parts;

  /// 是否限制「带倍率的决策」每天只能用一次（齿轮奔袭 = true）
  ///
  /// 为 true 时，本活动的所有决策**合计每天只能选 1 次**（次日重置）。
  final bool oneChoicePerDay;

  const MilestoneConfig({
    required this.id,
    required this.total,
    required this.step,
    required this.adProgressTiers,
    this.randomR6Parts = false,
    this.oneChoicePerDay = false,
  });
}

const Map<String, MilestoneConfig> kMilestoneActivities =
    <String, MilestoneConfig>{
      'scrap': MilestoneConfig(
        id: 'scrap',
        total: kScrapTotalProgress,
        step: 5,
        adProgressTiers: <int>[3, 5, 10],
      ),
      'gear': MilestoneConfig(
        id: 'gear',
        total: kGearTotalProgress,
        step: 50,
        adProgressTiers: <int>[20, 50, 100],
        randomR6Parts: true,
        oneChoicePerDay: true,
      ),
    };

/// 24h锦标赛+黑市：本期不设活动，只保留「看广告」按钮（只给紫票）
const String kChampActivityId = 'champ';

// =====================================================================
// 三之三、全明星（打榜活动：随机榜单 + 名次奖励）
// =====================================================================

/// 全明星：单车最高战力 → 分数（阶梯，从高到低匹配；低于最低档取最低档）
const List<({int power, int score})> kAllStarScoreTiers =
    <({int power, int score})>[
      (power: 2500000, score: 60000),
      (power: 1500000, score: 40000),
      (power: 600000, score: 20000),
      (power: 150000, score: 10000),
    ];

int allStarScore(int maxCarPower) {
  for (final t in kAllStarScoreTiers) {
    if (maxCarPower >= t.power) return t.score;
  }
  return kAllStarScoreTiers.last.score;
}

/// 全明星的四档决策（分数 = 单车最高战力分数 × 精力倍数）
const List<ActivityChoice> kAllStarChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'allstar1',
    nameZh: '浅尝辄止',
    nameEn: 'A Taste',
    descZh: '投入最少，收益最少',
    descEn: 'Least effort, least reward',
    energyCost: 1,
    coef: 0,
  ),
  ActivityChoice(
    id: 'allstar2',
    nameZh: '投入精力',
    nameEn: 'Put In Effort',
    descZh: '投入一般',
    descEn: 'Moderate effort',
    energyCost: 2,
    coef: 0,
  ),
  ActivityChoice(
    id: 'allstar3',
    nameZh: '全神贯注',
    nameEn: 'Full Focus',
    descZh: '投入较多',
    descEn: 'High effort',
    energyCost: 4,
    coef: 0,
  ),
  ActivityChoice(
    id: 'allstar4',
    nameZh: '我爱上班',
    nameEn: 'Love the Grind',
    descZh: '全力投入',
    descEn: 'All in',
    energyCost: 8,
    coef: 0,
  ),
];

/// 全明星看广告的分数档位（随机取一档，再乘氪金倍率）
const List<int> kAllStarAdScoreTiers = <int>[200, 500, 1000];

/// 全明星榜单人数
const int kAllStarBoardSize = 400;

/// 榜单分数按名次幂律分布：score = A / rank^B（+ 每日抖动）
///
/// 实测标定（全明星周期 4 天，每次决策基础分见 [kAllStarScoreTiers]）：
/// - 15 万战力（10,000/次）×1 → 40,000 分 → 第 151-300 名档
/// - 60 万战力（20,000/次）×1 → 80,000 分 → 第 31-70 名档
/// - 60 万战力 ×3 → 240,000 分 → 第 4-10 名档
/// - 250 万战力（60,000/次）×1 → 240,000 分 → 第 4-10 名档
/// - 250 万战力 ×3（180,000/天）→ 720,000 分 → **第 1 名**
///
/// 即「车越大 + 投入越多 → 名次越前」，第 1 名需要顶级战车 + 全程氪金。
const double kAllStarBoardA = 600000.0;
const double kAllStarBoardB = 0.5405;

/// 每日榜单抖动幅度（±）
const double kAllStarBoardJitter = 0.15;

/// 全明星名次档位（8 档；名次越前奖励越多）
class AllStarTier {
  /// 该档覆盖到第几名（含）
  final int maxRank;
  final String labelZh;
  final String labelEn;

  /// 部件种类数 / 每种数量
  final int partKinds;
  final int partEach;

  /// 代币 / 紫票
  final int token;
  final int cash;

  const AllStarTier({
    required this.maxRank,
    required this.labelZh,
    required this.labelEn,
    required this.partKinds,
    required this.partEach,
    required this.token,
    required this.cash,
  });
}

const List<AllStarTier> kAllStarTiers = <AllStarTier>[
  AllStarTier(
    maxRank: 1,
    labelZh: '第 1 名',
    labelEn: 'Rank 1',
    partKinds: 12,
    partEach: 20,
    token: 225,
    cash: 3000000,
  ),
  AllStarTier(
    maxRank: 3,
    labelZh: '第 2-3 名',
    labelEn: 'Rank 2-3',
    partKinds: 11,
    partEach: 18,
    token: 200,
    cash: 2600000,
  ),
  AllStarTier(
    maxRank: 10,
    labelZh: '第 4-10 名',
    labelEn: 'Rank 4-10',
    partKinds: 10,
    partEach: 16,
    token: 175,
    cash: 2200000,
  ),
  AllStarTier(
    maxRank: 30,
    labelZh: '第 11-30 名',
    labelEn: 'Rank 11-30',
    partKinds: 9,
    partEach: 14,
    token: 150,
    cash: 1800000,
  ),
  AllStarTier(
    maxRank: 70,
    labelZh: '第 31-70 名',
    labelEn: 'Rank 31-70',
    partKinds: 8,
    partEach: 12,
    token: 125,
    cash: 1400000,
  ),
  AllStarTier(
    maxRank: 150,
    labelZh: '第 71-150 名',
    labelEn: 'Rank 71-150',
    partKinds: 7,
    partEach: 10,
    token: 100,
    cash: 1000000,
  ),
  AllStarTier(
    maxRank: 300,
    labelZh: '第 151-300 名',
    labelEn: 'Rank 151-300',
    partKinds: 6,
    partEach: 8,
    token: 75,
    cash: 600000,
  ),
  AllStarTier(
    maxRank: 1 << 30,
    labelZh: '第 301 名及以后',
    labelEn: 'Rank 301+',
    partKinds: 5,
    partEach: 6,
    token: 50,
    cash: 200000,
  ),
];

/// 名次 → 档位
AllStarTier allStarTierFor(int rank) {
  for (final t in kAllStarTiers) {
    if (rank <= t.maxRank) return t;
  }
  return kAllStarTiers.last;
}

/// 榜单上的一个玩家
class AllStarEntry {
  final String id;
  final int score;
  const AllStarEntry(this.id, this.score);
}

/// 生成某一天的全明星榜单（人数固定，分数按名次幂律分布 + 抖动）
///
/// 同一天同一服务器返回同一份榜单；换天/换周期会重新生成，
/// 因此可能出现「加了分名次反而后退」的情况。
List<AllStarEntry> buildAllStarBoard({required int seed}) {
  final rng = Random(seed);
  final entries = <AllStarEntry>[];
  for (var rank = 1; rank <= kAllStarBoardSize; rank++) {
    final base = kAllStarBoardA / pow(rank, kAllStarBoardB);
    final jitter =
        1 - kAllStarBoardJitter + rng.nextDouble() * kAllStarBoardJitter * 2;
    entries.add(
      AllStarEntry(
        '${100000 + rng.nextInt(8999999)}',
        (base * jitter).round(),
      ),
    );
  }
  entries.sort((a, b) => b.score.compareTo(a.score));
  return entries;
}

// =====================================================================
// 三之四、GP 大奖赛（高随机 / 高耗体的打榜活动）
// =====================================================================
// 与全明星的区别：**和战车大小完全无关**（分数只看决策与乘数，不看战力）。
// 特点：
// - 两种专用代币：汽油（gasoline）与旗帜（flags），二者均不可为负
// - 高随机：每次决策旗帜大幅波动，可能一路亏到 0
// - 非常耗体力：高风险一次 2 精力
// - 玩家可以氪乘数：每 10 钱 → 分数 +150%，上限 50 次

/// GP 开局给的旗帜（**整局只给一次**，之后不再补；归零当天全部禁选）
///
/// 数值定义在 [LifeSimSave.kGpInitialFlags]（存档默认值需要它）。
const int kGpInitialFlags = LifeSimSave.kGpInitialFlags;

/// GP 每天补充的汽油（会累积）
const int kGpDailyGasoline = 2000;

/// GP 一次决策消耗的汽油
const int kGpGasPerChoice = 200;

/// 每累计消耗这么多汽油，分数乘数 +[kGpGasBonusStepPct]%
const int kGpGasBonusStep = 1000;

/// 每 [kGpGasBonusStep] 汽油提供的乘数加成（百分比）
const int kGpGasBonusStepPct = 50;

/// 汽油部分的乘数加成上限（+450%）
const int kGpGasBonusMaxPct = 450;

/// GP 一次氪金消耗的钱
const int kGpTopUpMoney = 10;

/// GP 一次氪金提供的乘数加成（百分比）
const int kGpTopUpBonusPct = 150;

/// GP 氪金次数上限
const int kGpMaxTopUpCount = 50;

/// GP 分数乘数加成的**整体**上限（氪金 + 汽油 相加后封顶 +7650%）
const int kGpTotalBonusCapPct = 7650;

/// GP 的三档决策（与战车战力无关）
///
/// - 高风险：旗帜 -5000~+3000，200 汽油 + 2 精力，分数 +50000
/// - 中风险：旗帜 -2500~+2000，200 汽油 + 2 精力，分数 +20000
/// - 低风险：旗帜 0~+3000，200 汽油 + 1 精力，分数 +1000（唯一不亏旗帜的档）
const List<ActivityChoice> kGpChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'gpHigh',
    nameZh: '高风险',
    nameEn: 'High Risk',
    descZh: '旗帜 -5000~+3000 · 200 汽油 + 2 精力 · 分数 +50000',
    descEn: 'Flags -5000~+3000 · 200 gas + 2 energy · score +50000',
    energyCost: 2,
    coef: 0,
    gasCost: kGpGasPerChoice,
    flagMin: -5000,
    flagMax: 3000,
    baseScore: 50000,
  ),
  ActivityChoice(
    id: 'gpMid',
    nameZh: '中风险',
    nameEn: 'Medium Risk',
    descZh: '旗帜 -2500~+2000 · 200 汽油 + 2 精力 · 分数 +20000',
    descEn: 'Flags -2500~+2000 · 200 gas + 2 energy · score +20000',
    energyCost: 2,
    coef: 0,
    gasCost: kGpGasPerChoice,
    flagMin: -2500,
    flagMax: 2000,
    baseScore: 20000,
  ),
  ActivityChoice(
    id: 'gpLow',
    nameZh: '低风险',
    nameEn: 'Low Risk',
    descZh: '旗帜 0~+3000 · 200 汽油 + 1 精力 · 分数 +1000',
    descEn: 'Flags 0~+3000 · 200 gas + 1 energy · score +1000',
    energyCost: 1,
    coef: 0,
    gasCost: kGpGasPerChoice,
    flagMin: 0,
    flagMax: 3000,
    baseScore: 1000,
  ),
];

/// GP 汽油部分的乘数加成（百分比，上限 +450%）
int gpGasBonusPct(int gasConsumed) => min(
  kGpGasBonusMaxPct,
  (max(0, gasConsumed) ~/ kGpGasBonusStep) * kGpGasBonusStepPct,
);

/// GP 氪金部分的乘数加成（百分比，上限 +7500%）
int gpMoneyBonusPct(int topUpCount) =>
    min(max(0, topUpCount), kGpMaxTopUpCount) * kGpTopUpBonusPct;

/// GP 分数乘数的总加成（百分比；氪金 + 汽油 相加后整体封顶 +7650%）
int gpBonusPct({required int gasConsumed, required int topUpCount}) => min(
  kGpTotalBonusCapPct,
  gpGasBonusPct(gasConsumed) + gpMoneyBonusPct(topUpCount),
);

/// GP 分数乘数（从 1.0 起：`1 + 总加成% / 100`）
double gpMultiplierOf({required int gasConsumed, required int topUpCount}) =>
    1 + gpBonusPct(gasConsumed: gasConsumed, topUpCount: topUpCount) / 100;

/// GP 一次决策的实际得分（基础分 × 乘数）
int gpChoiceScore(ActivityChoice choice, double multiplier) =>
    (choice.baseScore * multiplier).round();

// ---- GP 榜单与名次奖励 ----

/// GP 榜单人数
const int kGpBoardSize = 400;

/// GP 榜单控制点（名次 → 分数），控制点之间按**对数线性**插值
///
/// 为什么不用幂律 `A / rank^B`：
/// 氪金乘数上限 +7500% 远大于汽油的 +450%，所以「200 氪」与「0 氪」的分数
/// 差接近 18 倍，但按需求两者只差 2-3 倍名次。幂律只能取一个指数：
/// - 要让 0 氪进 50-100 名 → 指数 ≈ 3.17 → 第 1 名需要 1.45 万亿分（永远拿不到）
/// - 要让 200 氪进 10-50 名 → 指数 ≈ 0.23 → 0 氪掉到第 400 名开外
/// 对数线性锚点可以做到「顶部平缓、中段陡峭」，同时满足两条需求。
///
/// 锚点取值（实测模拟：4 天周期、精力打满、全程高风险，41 个随机种子取中位数）：
/// - 第 1 名 ≈ 9500 万（重氪 + 旗帜运气好时的极限约 1.08 亿，所以第 1 名可达）
/// - 第 30 名 ≈ 3020 万（200 氪中位分）
/// - 第 75 名 ≈ 166 万（0 氪中位分）
/// - 第 400 名 ≈ 2 万
///
/// 实测名次分布（中位 / 最好 / 最差）：
/// - 0 氪（乘数只吃汽油，约 ×3.5）：75 / 67 / 175 → 落在 50-100 ✓
/// - 200 氪（20 次 ×+150% = +3000%，乘数约 ×33）：31 / 21 / 47 → 落在 10-50 ✓
/// - 500 氪（氪满 50 次，乘数封顶 ×77.5）：7 / 1 / 32 → 第 1 名可达 ✓
/// - 全程低风险（不亏旗帜，约 11 万分）：275 → 兜底档 ✓
const List<({int rank, int score})> kGpBoardAnchors =
    <({int rank, int score})>[
      (rank: 1, score: 95000000),
      (rank: 30, score: 30200000),
      (rank: 75, score: 1660000),
      (rank: 400, score: 20000),
    ];

/// GP 榜单每天的抖动幅度（±；比全明星小，因为顶部对分数很敏感）
const double kGpBoardJitter = 0.05;

/// 某个名次对应的榜单分数（控制点之间对数线性插值）
double gpBoardScore(int rank) {
  final anchors = kGpBoardAnchors;
  if (rank <= anchors.first.rank) return anchors.first.score.toDouble();
  for (var i = 1; i < anchors.length; i++) {
    final a = anchors[i - 1];
    final b = anchors[i];
    if (rank <= b.rank) {
      final t = (rank - a.rank) / (b.rank - a.rank);
      return (a.score * pow(b.score / a.score, t)).toDouble();
    }
  }
  return anchors.last.score.toDouble();
}

/// GP 名次奖励（8 档；名次越前奖励越多，档位与全明星同形）
const List<AllStarTier> kGpTiers = <AllStarTier>[
  AllStarTier(
    maxRank: 1,
    labelZh: '第 1 名',
    labelEn: 'Rank 1',
    partKinds: 12,
    partEach: 20,
    token: 225,
    cash: 3000000,
  ),
  AllStarTier(
    maxRank: 3,
    labelZh: '第 2-3 名',
    labelEn: 'Rank 2-3',
    partKinds: 11,
    partEach: 18,
    token: 200,
    cash: 2600000,
  ),
  AllStarTier(
    maxRank: 10,
    labelZh: '第 4-10 名',
    labelEn: 'Rank 4-10',
    partKinds: 10,
    partEach: 16,
    token: 175,
    cash: 2200000,
  ),
  AllStarTier(
    maxRank: 25,
    labelZh: '第 11-25 名',
    labelEn: 'Rank 11-25',
    partKinds: 9,
    partEach: 14,
    token: 150,
    cash: 1800000,
  ),
  AllStarTier(
    maxRank: 50,
    labelZh: '第 26-50 名',
    labelEn: 'Rank 26-50',
    partKinds: 8,
    partEach: 12,
    token: 125,
    cash: 1400000,
  ),
  AllStarTier(
    maxRank: 100,
    labelZh: '第 51-100 名',
    labelEn: 'Rank 51-100',
    partKinds: 7,
    partEach: 10,
    token: 100,
    cash: 1000000,
  ),
  AllStarTier(
    maxRank: 250,
    labelZh: '第 101-250 名',
    labelEn: 'Rank 101-250',
    partKinds: 6,
    partEach: 8,
    token: 75,
    cash: 600000,
  ),
  AllStarTier(
    maxRank: 1 << 30,
    labelZh: '第 251 名及以后',
    labelEn: 'Rank 251+',
    partKinds: 5,
    partEach: 6,
    token: 50,
    cash: 200000,
  ),
];

/// GP 名次 → 档位
AllStarTier gpTierFor(int rank) {
  for (final t in kGpTiers) {
    if (rank <= t.maxRank) return t;
  }
  return kGpTiers.last;
}

/// 生成某一天的 GP 榜单（人数固定，分数按 [kGpBoardAnchors] 插值 + 抖动）
List<AllStarEntry> buildGpBoard({required int seed}) {
  final rng = Random(seed);
  final entries = <AllStarEntry>[];
  for (var rank = 1; rank <= kGpBoardSize; rank++) {
    final jitter =
        1 - kGpBoardJitter + rng.nextDouble() * kGpBoardJitter * 2;
    entries.add(
      AllStarEntry(
        '${200000 + rng.nextInt(7999999)}',
        (gpBoardScore(rank) * jitter).round(),
      ),
    );
  }
  entries.sort((a, b) => b.score.compareTo(a.score));
  return entries;
}

// =====================================================================
// 三之五、城市之王：40 天一赛季（胜场里程碑 + 赛季结算分数）
// =====================================================================

/// 城市之王赛季长度（天）
const int kCitySeasonDays = 40;

/// 城市之王一场的分数上限
///
/// 一场的**胜场分 + 败场分恒等于这个值**：均势时各一半，差距越大越偏向一方。
const int kCityMaxScore = 145000;

/// 提升帮派活跃度：消耗的精力
const int kGangActivityEnergyCost = 2;

/// 提升帮派活跃度：一次随机提升的下限 / 上限（活跃度上限 100）
const int kGangActivityGainMin = 1;
const int kGangActivityGainMax = 5;

/// 一个胜场里程碑
class CityWinMilestone {
  /// 达到这个胜场数时触发
  final int wins;

  /// 宝箱数量（每个宝箱 = 随机一个该稀有度的部件）
  final int chestCount;

  /// 宝箱稀有度下标（4 = R5，5 = R6）
  final int chestRarityIndex;

  /// 附带代币
  final int token;

  /// 达到该胜场后，每场城市之王的结算分数倍率
  final int scoreMultiplier;

  const CityWinMilestone({
    required this.wins,
    required this.chestCount,
    required this.chestRarityIndex,
    required this.token,
    required this.scoreMultiplier,
  });

  /// 宝箱稀有度的可读名（R5 / R6）
  String get chestRarityName => 'R${chestRarityIndex + 1}';
}

/// 城市之王赛季胜场里程碑（按胜场升序）
///
/// 1/2/4/6/9 胜 → 5 × R5 宝箱；12/16/20/25/30 胜 → 3 × R6 宝箱；
/// 附带代币 1/1/2/2/3/3/4/4/5/5；结算分数倍率 ×2…×15。
const List<CityWinMilestone> kCityWinMilestones = <CityWinMilestone>[
  CityWinMilestone(
    wins: 1,
    chestCount: 5,
    chestRarityIndex: 4,
    token: 1,
    scoreMultiplier: 2,
  ),
  CityWinMilestone(
    wins: 2,
    chestCount: 5,
    chestRarityIndex: 4,
    token: 1,
    scoreMultiplier: 3,
  ),
  CityWinMilestone(
    wins: 4,
    chestCount: 5,
    chestRarityIndex: 4,
    token: 2,
    scoreMultiplier: 4,
  ),
  CityWinMilestone(
    wins: 6,
    chestCount: 5,
    chestRarityIndex: 4,
    token: 2,
    scoreMultiplier: 5,
  ),
  CityWinMilestone(
    wins: 9,
    chestCount: 5,
    chestRarityIndex: 4,
    token: 3,
    scoreMultiplier: 6,
  ),
  CityWinMilestone(
    wins: 12,
    chestCount: 3,
    chestRarityIndex: 5,
    token: 3,
    scoreMultiplier: 7,
  ),
  CityWinMilestone(
    wins: 16,
    chestCount: 3,
    chestRarityIndex: 5,
    token: 4,
    scoreMultiplier: 8,
  ),
  CityWinMilestone(
    wins: 20,
    chestCount: 3,
    chestRarityIndex: 5,
    token: 4,
    scoreMultiplier: 9,
  ),
  CityWinMilestone(
    wins: 25,
    chestCount: 3,
    chestRarityIndex: 5,
    token: 5,
    scoreMultiplier: 10,
  ),
  CityWinMilestone(
    wins: 30,
    chestCount: 3,
    chestRarityIndex: 5,
    token: 5,
    scoreMultiplier: 15,
  ),
];

/// 当前赛季胜场对应的结算分数倍率（未达到任何里程碑 = ×1）
int cityScoreMultiplier(int seasonWins) {
  var mul = 1;
  for (final m in kCityWinMilestones) {
    if (seasonWins >= m.wins) mul = m.scoreMultiplier;
  }
  return mul;
}

/// 帮派强度 = **帮派车辆大小**（车队总战力，含队友）× (1 + **帮派活跃度** / 100)
int gangStrengthOf({required int gangPower, required int gangActivity}) {
  final actMul = 1 + gangActivity.clamp(0, 100) / 100.0;
  return (max(0, gangPower) * actMul).round();
}

/// 城市之王一场的胜 / 败结算分数（未乘赛季倍率）
///
/// 双方强度：我方 = 我方帮派车辆大小 × 我方活跃度加成；
/// 对方 = 对手帮派战力 × 对手活跃度加成。
/// 强弱差 `d = (我方强度 - 对方强度) / (我方强度 + 对方强度)`（-1 ~ 1）：
/// - 胜场分 = [kCityMaxScore] × (1 + d) / 2
/// - 败场分 = [kCityMaxScore] × (1 - d) / 2
///
/// 两者相加恒为 [kCityMaxScore]；均势（d = 0）时胜负分相等（分差 0），
/// 双方差距越大分差越大；单场分数最高 [kCityMaxScore]。
({int win, int loss}) cityBattleScoresOf({
  required int myStrength,
  required int oppStrength,
}) {
  final sum = myStrength + oppStrength;
  final d = sum <= 0 ? 0.0 : (myStrength - oppStrength) / sum;
  final win = (kCityMaxScore * (1 + d) / 2)
      .round()
      .clamp(0, kCityMaxScore);
  return (win: win, loss: kCityMaxScore - win);
}

/// 废铁行动的四档决策：进度 +50/100/150/200，精力 1/2/4/8
///
/// 和齿轮奔袭 / 全明星用**同一套四档名与精力阶梯**（1/2/4/8 → 0.25/0.5/0.75/1）：
/// 50/100/150/200 正好是满档 200 的 0.25/0.5/0.75/1 倍。
const List<ActivityChoice> kScrapChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'scrap1',
    nameZh: '浅尝辄止',
    nameEn: 'A Taste',
    descZh: '投入最少，收益最少',
    descEn: 'Least effort, least reward',
    energyCost: 1,
    coef: 0,
    fixedPoints: 50,
  ),
  ActivityChoice(
    id: 'scrap2',
    nameZh: '投入精力',
    nameEn: 'Put In Effort',
    descZh: '投入一般',
    descEn: 'Moderate effort',
    energyCost: 2,
    coef: 0,
    fixedPoints: 100,
  ),
  ActivityChoice(
    id: 'scrap3',
    nameZh: '全神贯注',
    nameEn: 'Full Focus',
    descZh: '投入较多',
    descEn: 'High effort',
    energyCost: 4,
    coef: 0,
    fixedPoints: 150,
  ),
  ActivityChoice(
    id: 'scrap4',
    nameZh: '我爱上班',
    nameEn: 'Love the Grind',
    descZh: '全力投入',
    descEn: 'All in',
    energyCost: 8,
    coef: 0,
    fixedPoints: 200,
  ),
];

/// 看广告：消耗 1 精力，随机抽「紫票」和「进度」各一档
///
/// 进度档位按活动区分，见 [kMilestoneActivities] 的 `adProgressTiers`。
const int kAdEnergyCost = 1;
const List<int> kAdCashTiers = <int>[200, 500, 1000];

/// 氪金：消耗「钱」换取「本次废铁行动」的进度倍率
class TopUpTier {
  /// 消耗的钱（钱可以扣至负值）
  final int cost;

  /// 本次废铁行动的进度倍率
  final int multiplier;
  const TopUpTier(this.cost, this.multiplier);
}

const List<TopUpTier> kTopUpTiers = <TopUpTier>[
  TopUpTier(70, 2),
  TopUpTier(150, 3),
];

/// 全明星「买分」氪金项：消耗 1 精力 + 10 钱，获得 15000 分
///
/// 与 [kTopUpTiers] 的区别：这项**没有次数限制**（只受精力限制），
/// 且得到的分数会被当前的氪金倍率 [LifeSimSave.scrapMultiplier] 放大。
/// 只在全明星（打榜）周期可用。
const int kAllStarBuyEnergyCost = 1;
const int kAllStarBuyMoneyCost = 10;
const int kAllStarBuyScore = 15000;

/// 节点位置取整步长（节点位置都是 5 的倍数）
const int kScrapNodeStep = 5;

/// 齿轮奔袭节点位置取整步长（节点位置都是 50 的倍数）
const int kGearNodeStep = 50;

/// 废铁行动奖励类型
enum ScrapRewardKind {
  /// 指定的 R6 部件碎片
  r6Part,

  /// 随机 R6 部件碎片（齿轮奔袭用）
  randomR6Part,

  /// 随机部件宝箱（开出 1 个随机部件）
  randomPart,

  /// 代币
  token,

  /// 紫票
  cash,
}

class ScrapReward {
  final ScrapRewardKind kind;
  final int amount;

  /// [ScrapRewardKind.r6Part] 时指定的部件 id
  final String? partId;

  const ScrapReward(this.kind, this.amount, {this.partId});
}

/// 废铁行动的一个奖励节点
class ScrapNode {
  /// 达到该进度即可获得（5 的倍数，最后一个为 [kScrapTotalProgress]）
  final int progress;
  final List<ScrapReward> rewards;

  const ScrapNode(this.progress, this.rewards);
}

/// 废铁行动奖励的 R6 部件 id 列表（共 15 种）。
///
/// 留空时自动取当前服务器 R6 部件（按 id 排序）的前 15 个；
/// 想指定具体部件时，把 15 个 id 填进来即可（不足 15 个会自动补齐）。
const List<String> kScrapR6PartIds = <String>[];

/// 代币奖励序列（共 180 个，先少后多）
const List<int> kScrapTokenSeq = <int>[
  1,
  2,
  2,
  3,
  4,
  5,
  6,
  7,
  8,
  9,
  10,
  12,
  14,
  16,
  18,
  20,
  21,
  22,
];

/// 紫票奖励序列（共 1,500,000，先少后多）
const List<int> kScrapCashSeq = <int>[
  5000,
  10000,
  15000,
  20000,
  25000,
  40000,
  55000,
  75000,
  95000,
  120000,
  145000,
  175000,
  205000,
  235000,
  280000,
];

/// 随机部件宝箱序列（共 30 个，先少后多）
const List<int> kScrapChestSeq = <int>[1, 2, 2, 3, 3, 3, 4, 4, 4, 4];

/// 每个 R6 部件的碎片分两个节点发放（先 5 后 6）
const int kScrapR6FirstBatch = 5;
const int kScrapR6SecondBatch = 6;

/// 对数分布：第 [i]（0 起）个节点在进度条上的位置
///
/// `pos = step × (total/step)^(i/(n-1))`，四舍五入到 [step] 的倍数；
/// 先密后疏（前面的节点便宜、后面的贵），最后一个节点正好在 [total]。
int milestoneLogPosition(int i, int n, int total, int step) {
  if (n <= 1) return total;
  final raw = step * pow(total / step, i / (n - 1));
  final rounded = (raw / step).round() * step;
  return rounded.clamp(step, total);
}

/// 奖励的粗略价值分（只用于决定在进度条上的先后：小的在前、大的在后）
///
/// 不影响实际发放数量，纯粹是排序权重；想调整奖励出现的先后顺序改这里即可。
int scrapRewardValue(ScrapReward r) => switch (r.kind) {
  ScrapRewardKind.token => r.amount * 10,
  ScrapRewardKind.cash => r.amount ~/ 500,
  ScrapRewardKind.randomPart => r.amount * 40,
  ScrapRewardKind.r6Part || ScrapRewardKind.randomR6Part => r.amount * 30,
};

/// 生成里程碑活动（废铁行动 / 齿轮奔袭）的奖励节点表
///
/// 规则：
/// - **一个节点只给一种奖励**（不合并）；
/// - 部件碎片 30 个节点（15 组「先 5 后 6」）、代币 18、紫票 15、宝箱 10，共 73 个；
/// - 每个奖励族内部「先少后多」；
/// - 位置按**对数分布**（先密后疏），取整为 [step] 的倍数且互不重复，
///   最后一个节点正好在 [total]；
/// - 节点先后按 [scrapRewardValue] 从小到大排（小奖在前、大奖在后）。
List<ScrapNode> buildMilestoneNodes({
  required int total,
  required int step,
  required List<ScrapReward> partRewards,
}) {
  final families = <List<ScrapReward>>[
    <ScrapReward>[
      for (final c in kScrapChestSeq)
        ScrapReward(ScrapRewardKind.randomPart, c),
    ],
    <ScrapReward>[
      for (final t in kScrapTokenSeq) ScrapReward(ScrapRewardKind.token, t),
    ],
    partRewards,
    <ScrapReward>[
      for (final c in kScrapCashSeq) ScrapReward(ScrapRewardKind.cash, c),
    ],
  ];

  // 按价值从小到大铺开（同价值时按族与族内序号，保证各族内部先少后多）
  final entries = <({ScrapReward reward, int value, int family, int index})>[];
  for (var f = 0; f < families.length; f++) {
    final list = families[f];
    for (var i = 0; i < list.length; i++) {
      entries.add((
        reward: list[i],
        value: scrapRewardValue(list[i]),
        family: f,
        index: i,
      ));
    }
  }
  entries.sort((a, b) {
    final c = a.value.compareTo(b.value);
    if (c != 0) return c;
    final f = a.family.compareTo(b.family);
    return f != 0 ? f : a.index.compareTo(b.index);
  });

  final n = entries.length;
  final nodes = <ScrapNode>[];
  var prev = 0;
  for (var i = 0; i < n; i++) {
    // 对数分布 + 保证严格递增（位置互不重复）
    final raw = milestoneLogPosition(i, n, total, step);
    final pos = raw <= prev ? prev + step : raw;
    nodes.add(ScrapNode(pos, <ScrapReward>[entries[i].reward]));
    prev = pos;
  }
  if (nodes.isNotEmpty) {
    // 最后节点固定为总进度
    nodes[nodes.length - 1] = ScrapNode(total, nodes.last.rewards);
  }
  return nodes;
}

/// 废铁行动：指定 15 种 R6 部件，各 11 个碎片（先 5 后 6）
List<ScrapReward> buildScrapPartRewards(List<String> r6PartIds) => <ScrapReward>[
  for (final id in r6PartIds)
    ScrapReward(ScrapRewardKind.r6Part, kScrapR6FirstBatch, partId: id),
  for (final id in r6PartIds)
    ScrapReward(ScrapRewardKind.r6Part, kScrapR6SecondBatch, partId: id),
];

/// 齿轮奔袭：15 组随机 R6 部件，各 11 个碎片（先 5 后 6）
List<ScrapReward> buildGearPartRewards() => <ScrapReward>[
  for (var i = 0; i < 15; i++)
    const ScrapReward(ScrapRewardKind.randomR6Part, kScrapR6FirstBatch),
  for (var i = 0; i < 15; i++)
    const ScrapReward(ScrapRewardKind.randomR6Part, kScrapR6SecondBatch),
];

/// 生成废铁行动的奖励节点表（兼容旧接口）
List<ScrapNode> buildScrapNodes(List<String> r6PartIds) => buildMilestoneNodes(
  total: kScrapTotalProgress,
  step: kScrapNodeStep,
  partRewards: buildScrapPartRewards(r6PartIds),
);

/// 生成齿轮奔袭的奖励节点表
List<ScrapNode> buildGearNodes() => buildMilestoneNodes(
  total: kGearTotalProgress,
  step: kGearNodeStep,
  partRewards: buildGearPartRewards(),
);

// =====================================================================
// 四、帮派库
// =====================================================================

/// 固定帮派档案。
///
/// **后续会把真实帮派名导入到这里**：每个固定帮派有自己的数值随机范围
/// （成员数、每辆车的战力区间、活跃度区间）与**大致排名**；
/// 库外的帮派由 [kGangNamePrefix] × [kGangNameSuffix] 随机填充。
class GangArchetype {
  final String name;

  /// 大致排名（用于「锚定排名」参考）
  final int rankHint;

  /// 成员数区间
  final int memberMin;
  final int memberMax;

  /// 每辆车战力（HP+ATK）区间
  final int carPowerMin;
  final int carPowerMax;

  /// 活跃度区间（%）
  final int activityMin;
  final int activityMax;

  const GangArchetype({
    required this.name,
    required this.rankHint,
    required this.memberMin,
    required this.memberMax,
    required this.carPowerMin,
    required this.carPowerMax,
    required this.activityMin,
    required this.activityMax,
  });
}

/// 固定帮派库（占位名单，等真实帮派名导入后替换）
const List<GangArchetype> kGangLibrary = <GangArchetype>[
  GangArchetype(
    name: '喵星议会',
    rankHint: 1,
    memberMin: 18,
    memberMax: 24,
    carPowerMin: 3000000,
    carPowerMax: 6000000,
    activityMin: 70,
    activityMax: 95,
  ),
  GangArchetype(
    name: '钢铁猫爪',
    rankHint: 2,
    memberMin: 16,
    memberMax: 22,
    carPowerMin: 2400000,
    carPowerMax: 5000000,
    activityMin: 65,
    activityMax: 92,
  ),
  GangArchetype(
    name: '霓虹轨道',
    rankHint: 3,
    memberMin: 15,
    memberMax: 20,
    carPowerMin: 2000000,
    carPowerMax: 4200000,
    activityMin: 60,
    activityMax: 88,
  ),
  GangArchetype(
    name: '暴风车队',
    rankHint: 5,
    memberMin: 12,
    memberMax: 18,
    carPowerMin: 1500000,
    carPowerMax: 3200000,
    activityMin: 55,
    activityMax: 85,
  ),
  GangArchetype(
    name: '荒野旅团',
    rankHint: 8,
    memberMin: 10,
    memberMax: 16,
    carPowerMin: 900000,
    carPowerMax: 2200000,
    activityMin: 45,
    activityMax: 80,
  ),
  GangArchetype(
    name: '铁爪工坊',
    rankHint: 12,
    memberMin: 8,
    memberMax: 14,
    carPowerMin: 600000,
    carPowerMax: 1500000,
    activityMin: 40,
    activityMax: 75,
  ),
  GangArchetype(
    name: '月光俱乐部',
    rankHint: 20,
    memberMin: 6,
    memberMax: 12,
    carPowerMin: 300000,
    carPowerMax: 900000,
    activityMin: 30,
    activityMax: 70,
  ),
  GangArchetype(
    name: '沙暴猫团',
    rankHint: 35,
    memberMin: 4,
    memberMax: 10,
    carPowerMin: 150000,
    carPowerMax: 600000,
    activityMin: 25,
    activityMax: 65,
  ),
];

/// 随机帮派名前缀 / 后缀（库外帮派用）
const List<String> kGangNamePrefix = <String>[
  '星际',
  '暗影',
  '雷霆',
  '霓虹',
  '荒野',
  '钢铁',
  '月光',
  '暴风',
  '铁爪',
  '沙暴',
  '彩虹',
  '齿轮',
];

const List<String> kGangNameSuffix = <String>[
  '联盟',
  '车队',
  '议会',
  '工坊',
  '军团',
  '猫团',
  '俱乐部',
  '旅团',
  '小队',
  '公会',
];

/// AI 队友随机名字用词（前缀 + 编号）
const List<String> kMemberNamePrefix = <String>[
  '猫',
  '喵',
  '虎',
  '豹',
  '狮',
  '狐',
  '狼',
  '熊',
  '兔',
  '狸',
];

// =====================================================================
// 四之二、帮派联赛（金 / 银 / 铜 / 木，每赛季升降级）
// =====================================================================

/// 帮派组别（[index] 越大越强：木 → 铜 → 银 → 金）
enum GangDivision { wood, bronze, silver, gold }

extension GangDivisionInfo on GangDivision {
  String get nameZh => switch (this) {
    GangDivision.gold => '金',
    GangDivision.silver => '银',
    GangDivision.bronze => '铜',
    GangDivision.wood => '木',
  };

  String get nameEn => switch (this) {
    GangDivision.gold => 'Gold',
    GangDivision.silver => 'Silver',
    GangDivision.bronze => 'Bronze',
    GangDivision.wood => 'Wood',
  };

  /// 「金组」/「Gold League」
  String get leagueZh => '$nameZh组';
  String get leagueEn => '$nameEn League';

  /// 晋级后的组别（金组不再晋级 → null）
  GangDivision? get promoted =>
      this == GangDivision.gold ? null : GangDivision.values[index + 1];

  /// 退级后的组别（木组不再退级 → null）
  GangDivision? get demoted =>
      this == GangDivision.wood ? null : GangDivision.values[index - 1];
}

/// 每组席位数（前 [kGangPromoteRank] 名晋级、[kGangDemoteRank] 名及之后退级）
///
/// 这是金/银/铜三组的基准规模（用于全服排名的偏移量，不是「容量」）。
/// 一个组有多少帮派是**每个赛季算出来的数量**，见 [kGangDivisionGangCount]。
const int kGangDivisionSize = 100;

/// 分组别取「帮派初始名册」（离线模拟生成，见 gang_league_roster.dart）
const Map<GangDivision, List<GangSeed>> kGangSeedRoster =
    <GangDivision, List<GangSeed>>{
      GangDivision.wood: kGangSeedWood,
      GangDivision.bronze: kGangSeedBronze,
      GangDivision.silver: kGangSeedSilver,
      GangDivision.gold: kGangSeedGold,
    };

/// 某组别的名册规模（= 本季该组的帮派总数，运行时不再另外随机）
int gangDivisionRosterSize(GangDivision division) =>
    kGangSeedRoster[division]!.length;

/// 全服帮派总数
int get gangTotalSize => kGangSeedRoster.values.fold(
  0,
  (sum, list) => sum + list.length,
);

/// **离线生成用**：每组本赛季的帮派数量区间
///
/// 运行时的帮派来自 gang_league_roster.dart 里的名册（即用这些参数
/// 离线跑出来的结果），名册里有多少家，这个组就有多少家。
const Map<GangDivision, ({int min, int max})> kGangDivisionGangCount =
    <GangDivision, ({int min, int max})>{
      GangDivision.wood: (min: 200, max: 260),
      GangDivision.bronze: (min: 110, max: 130),
      GangDivision.silver: (min: 95, max: 110),
      // 金组最小：封存几家就可能不到 80 家上榜（那就不判退级）
      GangDivision.gold: (min: 80, max: 88),
    };

/// 每赛季**主动封存**（全员迁出到另一个组别的封存帮派、或掉级后留下的
/// 空帮派）的比例区间（%）。封存是主动行为，随时可以解封复活。
///
/// 注意：木组几乎不主动封存——木组帮派不上榜多半只是**单纯的缺人**
/// （成员不足 [kGangSealMinMembers] 人，打不了城市之王）。
const Map<GangDivision, ({int min, int max})> kGangDivisionSealedPct =
    <GangDivision, ({int min, int max})>{
      GangDivision.wood: (min: 1, max: 4),
      GangDivision.bronze: (min: 4, max: 9),
      GangDivision.silver: (min: 5, max: 10),
      GangDivision.gold: (min: 5, max: 12),
    };

/// 封存线：帮派成员**不足 5 人**无法参加城市之王（也会因此不上排行榜）
const int kGangSealMinMembers = 5;

/// 每个组别在全服排名里的偏移量（金 0 / 银 100 / 铜 200 / 木 300）
const int kGangRankOffsetPerDivision = 100;

/// **离线生成用**：帮派成员平均工具包数量随总战力变化的锚点（对数插值）
///
/// 越强的帮派（赢得越多）攒下的工具包越多；帮派战斗时指挥会参考
/// 双方排名决定用几个，用完就从平均值里扣掉。
const List<({int power, int toolkits})> kGangToolkitAnchors =
    <({int power, int toolkits})>[
      (power: 500000000, toolkits: 5),
      (power: 150000000, toolkits: 4),
      (power: 40000000, toolkits: 3),
      (power: 10000000, toolkits: 2),
      (power: 1000000, toolkits: 1),
      (power: 100000, toolkits: 0),
    ];

/// 按总战力取帮派「成员平均工具包数量」（0 ~ [kGangToolkitMax]）
int gangToolkitsForPower(int power) => _interpLog(
  power,
  <int>[for (final a in kGangToolkitAnchors) a.power],
  <int>[for (final a in kGangToolkitAnchors) a.toolkits],
).clamp(0, kGangToolkitMax);

/// 帮派成员平均工具包数量的上限（与单个部件的叠层上限一致）
const int kGangToolkitMax = 5;

/// 战斗中使用 1 个工具包给帮派车辆带来的加成（%）
///
/// 一个工具箱是给「某个部件 +40%」（约等于整车 +40%/5 个插槽）。
const int kToolboxBattleBoostPct = 8;

/// 帮派指挥的名次差步长：对手每比自己靠前这么多名，就多用 1 个工具包
const int kGangToolkitRankStep = 8;

/// 帮派指挥的决策水平区间（越低越容易做出糟糕决策）
const int kGangCommanderSkillMin = 35;
const int kGangCommanderSkillMax = 95;

/// 城市之王胜场超过这个数后，每多赢一场额外给一个工具箱
const int kCityToolboxAfterWins = 25;

/// 工具箱给对应部件增加的百分比（生命工具箱 → HP，攻击工具箱 → ATK）
const int kToolboxBonusPct = 40;

/// 同一个部件最多叠几个工具箱（+200%）
const int kToolboxMaxStack = 5;

/// 赛季结算奖励的档位（按**组内名次**，宝箱 = 随机一个该稀有度部件）
const List<
  ({
    int minRank,
    int maxRank,
    int chests,
    int chestRarityIndex,
    int token,
    int cash,
  })
>
kGangLeagueRewardTiers =
    <
      ({
        int minRank,
        int maxRank,
        int chests,
        int chestRarityIndex,
        int token,
        int cash,
      })
    >[
      (
        minRank: 1,
        maxRank: kGangPromoteRank,
        chests: 3,
        chestRarityIndex: 5,
        token: 120,
        cash: 900000,
      ),
      (
        minRank: 21,
        maxRank: 60,
        chests: 2,
        chestRarityIndex: 5,
        token: 80,
        cash: 500000,
      ),
      (
        minRank: 61,
        maxRank: 80,
        chests: 1,
        chestRarityIndex: 4,
        token: 40,
        cash: 200000,
      ),
      (
        minRank: kGangDemoteRank,
        maxRank: 1 << 30,
        chests: 0,
        chestRarityIndex: 4,
        token: 10,
        cash: 50000,
      ),
    ];

/// 赛季结算奖励的**组别系数**：高组别奖励明显更好
/// （金 4× / 银 3× / 铜 2× / 木 1×）
const Map<GangDivision, int> kGangLeagueRewardMul = <GangDivision, int>{
  GangDivision.gold: 4,
  GangDivision.silver: 3,
  GangDivision.bronze: 2,
  GangDivision.wood: 1,
};

/// 某组别某个名次的赛季结算奖励（已乘组别系数）
({int chests, int chestRarityIndex, int token, int cash}) gangLeagueReward(
  GangDivision division,
  int rank,
) {
  final mul = kGangLeagueRewardMul[division]!;
  for (final t in kGangLeagueRewardTiers) {
    if (rank >= t.minRank && rank <= t.maxRank) {
      return (
        chests: t.chests * mul,
        chestRarityIndex: t.chestRarityIndex,
        token: t.token * mul,
        cash: t.cash * mul,
      );
    }
  }
  return (chests: 0, chestRarityIndex: 4, token: 0, cash: 0);
}

/// 某组别的名次分段
///
/// 木组帮派更多，名次一直排到 120 之后，所以尾部拆成 **81-120 与 121+** 两段。
List<({int min, int max})> gangRankBands(GangDivision division) {
  if (division != GangDivision.wood) return kGangRankBands;
  return <({int min, int max})>[
    (min: 1, max: kGangPromoteRank),
    (min: 21, max: 40),
    (min: 41, max: 60),
    (min: 61, max: 80),
    (min: kGangDemoteRank, max: 120),
    (min: 121, max: kGangOpenBandMax),
  ];
}

/// 「120+」这类开区间尾段的哨兵值
const int kGangOpenBandMax = 1 << 30;

/// 晋级线：组内第 1 ~ 20 名晋级
const int kGangPromoteRank = 20;

/// 退级线：组内第 81 名及之后退级
const int kGangDemoteRank = 81;

/// 每组帮派总战力的区间（木最弱、金最强）
///
/// 组内梯度很大：**前列（尤其 1-20 名）明显更强、靠后（81-100 名）明显更弱**。
/// 因为胜场梯度奖励的存在，帮派会故意掉到低组别前列「刷胜场」，
/// 而连续失败又会拖低士气（活跃度），所以前列必须真的硬、靠后必须真的软。
/// 相邻组别的区间**故意重叠**：一个组的头部和下一个组的尾部实力相当，
/// 升降级之后不会立刻被退掉（也让「两个帮派互相轮换」看上去合理）。
const Map<GangDivision, ({int min, int max})> kGangDivisionPower =
    <GangDivision, ({int min, int max})>{
      GangDivision.wood: (min: 280000, max: 18000000),
      GangDivision.bronze: (min: 5500000, max: 73000000),
      GangDivision.silver: (min: 22000000, max: 220000000),
      GangDivision.gold: (min: 65000000, max: 550000000),
    };

/// 帮派成员上限（满员）
const int kGangMaxMembers = 25;

/// 帮派成员数随**帮派总战力**变化的锚点（对数插值，[power] 由大到小）
///
/// 帮派越强成员越多：金组顶级帮派长期满员（锚点可以高过
/// [kGangMaxMembers]，插值后统一 clamp 到上限），木组末尾的帮派只剩一两个人。
const List<({int power, int members})> kGangMemberAnchors =
    <({int power, int members})>[
      (power: 500000000, members: 27),
      (power: 150000000, members: 26),
      (power: 120000000, members: 24),
      (power: 60000000, members: 21),
      (power: 40000000, members: 18),
      (power: 20000000, members: 14),
      (power: 10000000, members: 11),
      (power: 4000000, members: 6),
      (power: 1000000, members: 4),
      (power: 100000, members: 2),
    ];

/// 城市之王失利对士气的打击（帮派活跃度会下降）
///
/// 第 1 场失败扣 [kCityLossActivityPenalty]，之后每多连败一场额外多扣
/// [kCityLossStreakExtra]，最多额外扣 [kCityLossStreakMaxExtra]
/// （即最多一场扣 2+3=5）；胜利会重置连败计数。
const int kCityLossActivityPenalty = 2;
const int kCityLossStreakExtra = 1;
const int kCityLossStreakMaxExtra = 3;

/// 帮派活跃度（%）随**帮派总战力**变化的锚点（对数插值）
///
/// 越强的帮派越活跃（高组别几乎每天都在打城市之王），
/// 末尾的帮派基本半死不活。
const List<({int power, int activity})> kGangActivityAnchors =
    <({int power, int activity})>[
      (power: 500000000, activity: 97),
      (power: 150000000, activity: 93),
      (power: 120000000, activity: 90),
      (power: 60000000, activity: 85),
      (power: 40000000, activity: 80),
      (power: 20000000, activity: 72),
      (power: 10000000, activity: 63),
      (power: 4000000, activity: 49),
      (power: 1000000, activity: 30),
      (power: 300000, activity: 12),
    ];

/// 按总战力取帮派成员数
int gangMembersForPower(int power) => _interpLog(
  power,
  <int>[for (final a in kGangMemberAnchors) a.power],
  <int>[for (final a in kGangMemberAnchors) a.members],
);

/// 按总战力取帮派活跃度（%）
int gangActivityForPower(int power) => _interpLog(
  power,
  <int>[for (final a in kGangActivityAnchors) a.power],
  <int>[for (final a in kGangActivityAnchors) a.activity],
);

/// 在 log(战力) 刻度上按锚点线性插值（[powers] 由大到小）
int _interpLog(int power, List<int> powers, List<int> values) {
  final p = max(1, power);
  if (p >= powers.first) return values.first;
  if (p <= powers.last) return values.last;
  for (var i = 0; i < powers.length - 1; i++) {
    final hi = powers[i];
    final lo = powers[i + 1];
    if (p <= hi && p >= lo) {
      final t =
          (log(hi.toDouble()) - log(p.toDouble())) /
          (log(hi.toDouble()) - log(lo.toDouble()));
      return (values[i] + (values[i + 1] - values[i]) * t).round();
    }
  }
  return values.last;
}

/// 名次分段（前 20 是晋级区、81 及之后是退级区）
const List<({int min, int max})> kGangRankBands = <({int min, int max})>[
  (min: 1, max: 20),
  (min: 21, max: 40),
  (min: 41, max: 60),
  (min: 61, max: 80),
  (min: 81, max: 100),
];

/// 某个名次区间上帮派数据的大致范围（由真实榜单统计得出）
class GangBandStat {
  final int rankMin;
  final int rankMax;
  final int powerMin;
  final int powerMax;
  final int powerAvg;
  final int membersMin;
  final int membersMax;
  final int activityMin;
  final int activityMax;

  /// 成员单辆车的平均战力（= 帮派战力 ÷ 成员数 ÷ 3）
  ///
  /// 城市之王对手上场的最强 3 辆车大致就是这个水平。
  final int carPowerMin;
  final int carPowerMax;

  /// 成员平均工具包数量
  final int toolkitsMin;
  final int toolkitsMax;

  const GangBandStat({
    required this.rankMin,
    required this.rankMax,
    required this.powerMin,
    required this.powerMax,
    required this.powerAvg,
    required this.membersMin,
    required this.membersMax,
    required this.activityMin,
    required this.activityMax,
    required this.carPowerMin,
    required this.carPowerMax,
    this.toolkitsMin = 0,
    this.toolkitsMax = 0,
  });

  String get labelZh => rankMin == rankMax
      ? '第 $rankMin 名'
      : (rankMax >= kGangOpenBandMax
            ? '第 $rankMin+ 名'
            : '第 $rankMin-$rankMax 名');
  String get labelEn => rankMin == rankMax
      ? '#$rankMin'
      : (rankMax >= kGangOpenBandMax ? '#$rankMin+' : '#$rankMin-$rankMax');
}

/// 统计某组别各名次区间的战力 / 成员数 / 活跃度 / 单车战力（取真实榜单）
///
/// 空的分段（该段还没有上榜帮派，例如木组的 121+）不会返回。
List<GangBandStat> gangDivisionBandStats({
  required GangDivision division,
  required int seed,
  required int seasonIndex,
}) {
  final board = buildGangDivisionBoard(
    division: division,
    seed: seed,
    seasonIndex: seasonIndex,
  );
  return <GangBandStat>[
    for (final b in gangRankBands(division))
      _bandStat(board.rows, b.min, b.max),
  ].where((s) => s.powerMax > 0).toList();
}

GangBandStat _bandStat(List<GangLeagueRow> board, int rankMin, int rankMax) {
  final slice = <GangLeagueRow>[
    for (final r in board)
      if (r.rank >= rankMin && r.rank <= rankMax) r,
  ];
  if (slice.isEmpty) {
    return GangBandStat(
      rankMin: rankMin,
      rankMax: rankMax,
      powerMin: 0,
      powerMax: 0,
      powerAvg: 0,
      membersMin: 0,
      membersMax: 0,
      activityMin: 0,
      activityMax: 0,
      carPowerMin: 0,
      carPowerMax: 0,
    );
  }
  var pMin = slice.first.power;
  var pMax = slice.first.power;
  var pSum = 0;
  var mMin = slice.first.members;
  var mMax = slice.first.members;
  var aMin = slice.first.activity;
  var aMax = slice.first.activity;
  var kMin = slice.first.toolkits;
  var kMax = slice.first.toolkits;
  var cMin = 1 << 62;
  var cMax = 0;
  for (final r in slice) {
    pMin = min(pMin, r.power);
    pMax = max(pMax, r.power);
    pSum += r.power;
    mMin = min(mMin, r.members);
    mMax = max(mMax, r.members);
    aMin = min(aMin, r.activity);
    aMax = max(aMax, r.activity);
    kMin = min(kMin, r.toolkits);
    kMax = max(kMax, r.toolkits);
    final perCar = r.power ~/ max(1, r.members) ~/ 3;
    cMin = min(cMin, perCar);
    cMax = max(cMax, perCar);
  }
  return GangBandStat(
    rankMin: rankMin,
    rankMax: rankMax,
    powerMin: pMin,
    powerMax: pMax,
    powerAvg: pSum ~/ slice.length,
    membersMin: mMin,
    membersMax: mMax,
    activityMin: aMin,
    activityMax: aMax,
    carPowerMin: cMin == 1 << 62 ? 0 : cMin,
    carPowerMax: cMax,
    toolkitsMin: kMin,
    toolkitsMax: kMax,
  );
}

/// 导入的真实帮派名单
///
/// - [division] + [rankMin]~[rankMax]：该帮派在**组内的名次区间**，
///   每个赛季在区间里取一个确定值（榜单按战力排序，帮派占用该名次）
/// - [altDivision] 等：**故意升降级轮换**的第二套归属。上面的组实力太强，
///   升上去拿到的奖励还不如留在下面，于是两个帮派相互轮换、
///   成员一直在两个帮派之间迁徙（按赛季序号的奇偶切换，[altPhase] 错开相位）
class GangLeagueEntry {
  final String name;
  final GangDivision division;
  final int rankMin;
  final int rankMax;
  final GangDivision? altDivision;
  final int altRankMin;
  final int altRankMax;
  final int altPhase;

  const GangLeagueEntry({
    required this.name,
    required this.division,
    required this.rankMin,
    required this.rankMax,
    this.altDivision,
    this.altRankMin = 0,
    this.altRankMax = 0,
    this.altPhase = 0,
  });
}

const List<GangLeagueEntry> kGangLeagueRoster = <GangLeagueEntry>[
  GangLeagueEntry(
    name: '风铃儿',
    division: GangDivision.gold,
    rankMin: 40,
    rankMax: 50,
  ),
  // 这一对在「银 1-3」与「金 81+」之间互相轮换
  GangLeagueEntry(
    name: '风起撼花铃',
    division: GangDivision.silver,
    rankMin: 1,
    rankMax: 3,
    altDivision: GangDivision.gold,
    altRankMin: 81,
    altRankMax: 100,
    altPhase: 0,
  ),
  GangLeagueEntry(
    name: '风动护花铃',
    division: GangDivision.silver,
    rankMin: 1,
    rankMax: 3,
    altDivision: GangDivision.gold,
    altRankMin: 81,
    altRankMax: 100,
    altPhase: 1,
  ),
  GangLeagueEntry(
    name: '风拂摇花铃',
    division: GangDivision.silver,
    rankMin: 30,
    rankMax: 45,
  ),
  GangLeagueEntry(
    name: '风过掠花铃',
    division: GangDivision.silver,
    rankMin: 30,
    rankMax: 45,
  ),
  GangLeagueEntry(
    name: '风吹稻花香',
    division: GangDivision.bronze,
    rankMin: 3,
    rankMax: 6,
  ),
];

/// 某个固定帮派在第 [seasonIndex] 个赛季的归属（处理故意升降级轮换）
({GangDivision division, int rankMin, int rankMax}) gangLeaguePlacement(
  GangLeagueEntry e,
  int seasonIndex,
) {
  final alt = e.altDivision;
  if (alt == null) {
    return (division: e.division, rankMin: e.rankMin, rankMax: e.rankMax);
  }
  final useAlt = (seasonIndex + e.altPhase) % 2 != 0;
  return useAlt
      ? (division: alt, rankMin: e.altRankMin, rankMax: e.altRankMax)
      : (division: e.division, rankMin: e.rankMin, rankMax: e.rankMax);
}

/// 联赛榜单上的一行
class GangLeagueRow {
  /// 组内名次（1 起）
  final int rank;
  final String name;

  /// 帮派总战力
  final int power;
  final int members;
  final int activity;

  /// **成员平均工具包数量**（战斗时指挥会决定用几个，用完就扣掉）
  final int toolkits;

  /// 帮派指挥的决策水平（0-100，越低越容易做出糟糕决策）
  final int commanderSkill;

  /// 是否是玩家自己的帮派
  final bool isPlayer;

  const GangLeagueRow({
    required this.rank,
    required this.name,
    required this.power,
    required this.members,
    required this.activity,
    this.toolkits = 0,
    this.commanderSkill = 60,
    this.isPlayer = false,
  });

  GangLeagueRow withRank(int newRank) => GangLeagueRow(
    rank: newRank,
    name: name,
    power: power,
    members: members,
    activity: activity,
    toolkits: toolkits,
    commanderSkill: commanderSkill,
    isPlayer: isPlayer,
  );
}

/// 生成一个随机帮派名（前缀 + 后缀）
String randomGangName(Random rng) =>
    '${kGangNamePrefix[rng.nextInt(kGangNamePrefix.length)]}'
    '${kGangNameSuffix[rng.nextInt(kGangNameSuffix.length)]}';

/// 一个可加入的帮派候选（来自联赛榜单的某一行）
///
/// 加入后玩家帮派就归到 [division] 组别；[members] 已满（满员）时不能加入。
class GangCandidate {
  final GangInstance gang;

  /// 该帮派所在的联赛组别
  final GangDivision division;

  /// 组内名次（1 起）
  final int rank;
  final int power;
  final int members;
  final int activity;

  /// 成员平均工具包数量（加入后就变成你的帮派资源）
  final int toolkits;

  const GangCandidate({
    required this.gang,
    required this.division,
    required this.rank,
    required this.power,
    required this.members,
    required this.activity,
    this.toolkits = 0,
  });

  /// 是否已满员（[kGangMaxMembers] 人）
  bool get full => members >= kGangMaxMembers;
}

/// 某组别某赛季的帮派情况
///
/// 组别**没有「容量」**：[total] 就是本季这个组有多少帮派（每赛季浮动）。
/// 其中一部分**主动封存**（全员迁出/掉级后留空，可解封复活），
/// 一部分**缺人**（成员不足 [kGangSealMinMembers] 人，打不了城市之王）。
/// 剩下真正打过城市之王的才会进排行榜（[rows]）。
class GangDivisionBoard {
  final GangDivision division;

  /// 本季该组的帮派总数
  final int total;

  /// 主动封存（不上榜，可解封复活）的帮派数
  final int sealedCount;

  /// 缺人（成员 < [kGangSealMinMembers]，参不了战）的帮派数
  final int shortHandedCount;

  /// 上榜帮派（打过城市之王，按战力降序，[GangLeagueRow.rank] 从 1 开始）
  final List<GangLeagueRow> rows;

  const GangDivisionBoard({
    required this.division,
    required this.total,
    required this.sealedCount,
    required this.shortHandedCount,
    required this.rows,
  });

  int get activeCount => rows.length;

  /// 上榜帮派不足 [kGangDemoteRank]-1（不足 80 家）时**不判退级**
  bool get canDemote => activeCount >= kGangDemoteRank - 1;
}

/// 生成某组别在第 [seasonIndex] 个赛季的帮派情况
///
/// - 帮派**总数每赛季浮动**（没有「容量」这一说），见 [kGangDivisionGangCount]
/// - 名次越前战力越高（对数刻度从组别上限铺到下限，再加抖动）
/// - 一部分帮派**主动封存**（全员迁出/留空，可解封复活）→ 本季不参战
/// - 一部分帮派**缺人**（成员 < [kGangSealMinMembers]）→ 本季参不了战
/// - 剩下真正参过战的帮派才在 [GangDivisionBoard.rows] 里（按战力降序）
/// - 每行还带**成员平均工具包数量**与**指挥决策水平**
/// - [kGangLeagueRoster] 里的固定帮派占用它们对应的名次
GangDivisionBoard buildGangDivisionBoard({
  required GangDivision division,
  required int seed,
  required int seasonIndex,
}) {
  // 赛季混进随机种子：同一赛季 / 同一种子结果稳定，换赛季会重排
  final rng = Random(seed + seasonIndex * 7919);
  final seeds = kGangSeedRoster[division]!;

  // 主动封存：全员迁出到另一个组别的封存帮派 / 掉级后留下的空帮派。
  // 每赛季重新抽名单（下赛季可能抽不到 → 就解封复活了）。
  final sealBand = kGangDivisionSealedPct[division]!;
  final sealPct = sealBand.min + rng.nextInt(sealBand.max - sealBand.min + 1);
  final sealedCount = (seeds.length * sealPct / 100).round();
  final pickOrder = List<int>.generate(seeds.length, (i) => i)..shuffle(rng);
  final sealedIdx = pickOrder.take(sealedCount).toSet();

  final entries = <GangLeagueRow>[];
  var shortHanded = 0;
  for (var i = 0; i < seeds.length; i++) {
    if (sealedIdx.contains(i)) continue;
    final s = seeds[i];
    // 缺人（成员不足 kGangSealMinMembers）的帮派参不了战 → 也不上榜
    if (s.members < kGangSealMinMembers) {
      shortHanded++;
      continue;
    }
    // 每赛季小幅浮动：战力 ±5%、活跃度 ±2、工具包 ±1
    final drift = 0.95 + rng.nextDouble() * 0.10;
    entries.add(
      GangLeagueRow(
        rank: 0,
        name: s.name,
        power: max(1, (s.power * drift).round()),
        members: s.members,
        activity: (s.activity + rng.nextInt(5) - 2).clamp(1, 99),
        toolkits: (s.toolkits + rng.nextInt(3) - 1).clamp(0, kGangToolkitMax),
        commanderSkill: s.skill,
      ),
    );
  }
  entries.sort((a, b) => b.power.compareTo(a.power));
  // 名次越前成员越多：把名册里的成员数按降序重新贴到名次上（分布不变）
  final memberCurve = entries.map((r) => r.members).toList()
    ..sort((a, b) => b - a);
  for (var i = 0; i < entries.length; i++) {
    entries[i] = GangLeagueRow(
      rank: i + 1,
      name: entries[i].name,
      power: entries[i].power,
      members: memberCurve[i],
      activity: entries[i].activity,
      toolkits: entries[i].toolkits,
      commanderSkill: entries[i].commanderSkill,
    );
  }
  final rows = entries;

  // 固定帮派占用对应名次（继承该名次的战力 / 成员数 / 活跃度 / 工具包）
  final usedSlots = <int>{};
  for (final e in kGangLeagueRoster) {
    final p = gangLeaguePlacement(e, seasonIndex);
    if (p.division != division) continue;
    if (rows.isEmpty) break;
    final span = p.rankMax - p.rankMin + 1;
    var idx = (p.rankMin + (span <= 1 ? 0 : rng.nextInt(span)) - 1).clamp(
      0,
      rows.length - 1,
    );
    // 两个固定帮派不能抢同一个名次
    var guard = 0;
    while (usedSlots.contains(idx) && guard < rows.length) {
      idx = (idx + 1) % rows.length;
      guard++;
    }
    usedSlots.add(idx);
    rows[idx] = GangLeagueRow(
      rank: idx + 1,
      name: e.name,
      power: rows[idx].power,
      members: rows[idx].members,
      activity: rows[idx].activity,
      toolkits: rows[idx].toolkits,
      commanderSkill: rows[idx].commanderSkill,
    );
  }
  return GangDivisionBoard(
    division: division,
    total: seeds.length,
    sealedCount: sealedCount,
    shortHandedCount: shortHanded,
    rows: rows,
  );
}

// =====================================================================
// 五、成就
// =====================================================================

class Achievement {
  final String id;
  final String icon;
  final String nameZh;
  final String nameEn;
  final String descZh;
  final String descEn;

  /// 判定（在每天结束 / 关键操作后调用）
  ///
  /// [power] 为引擎算出的当前车队战力（HP+ATK 合计），避免成就跑到部件库里重算。
  final bool Function(LifeSimSave save, int power) test;

  const Achievement({
    required this.id,
    required this.icon,
    required this.nameZh,
    required this.nameEn,
    required this.descZh,
    required this.descEn,
    required this.test,
  });
}

final List<Achievement> kAchievements = <Achievement>[
  Achievement(
    id: 'rank_a',
    icon: '🥈',
    nameZh: 'A 档车手',
    nameEn: 'A-Rank Driver',
    descZh: '某个活动结算达到 A 档',
    descEn: 'Finish an activity in A rank',
    test: (s, p) => s.rankACount >= 1,
  ),
  Achievement(
    id: 'rank_s',
    icon: '🥇',
    nameZh: 'S 档车手',
    nameEn: 'S-Rank Driver',
    descZh: '某个活动结算达到 S 档',
    descEn: 'Finish an activity in S rank',
    test: (s, p) => s.rankSCount >= 1,
  ),
  Achievement(
    id: 'rank_s5',
    icon: '👑',
    nameZh: '五连 S',
    nameEn: 'Five S Ranks',
    descZh: '累计 5 次 S 档',
    descEn: 'Reach S rank 5 times',
    test: (s, p) => s.rankSCount >= 5,
  ),
  Achievement(
    id: 'rank_s20',
    icon: '🌟',
    nameZh: '二十连 S',
    nameEn: 'Twenty S Ranks',
    descZh: '累计 20 次 S 档',
    descEn: 'Reach S rank 20 times',
    test: (s, p) => s.rankSCount >= 20,
  ),
  Achievement(
    id: 'cash_10k',
    icon: '💰',
    nameZh: '小有积蓄',
    nameEn: 'Saving Up',
    descZh: '累计获得 10000 紫票',
    descEn: 'Earn 10,000 Cash in total',
    test: (s, p) => s.lifetimeCash >= 10000,
  ),
  Achievement(
    id: 'cash_100k',
    icon: '💎',
    nameZh: '腰缠万贯',
    nameEn: 'Rich Cat',
    descZh: '累计获得 100000 紫票',
    descEn: 'Earn 100,000 Cash in total',
    test: (s, p) => s.lifetimeCash >= 100000,
  ),
  Achievement(
    id: 'token_5k',
    icon: '🪙',
    nameZh: '代币富翁',
    nameEn: 'Token Tycoon',
    descZh: '累计获得 5000 代币',
    descEn: 'Earn 5,000 Tokens in total',
    test: (s, p) => s.lifetimeToken >= 5000,
  ),
  Achievement(
    id: 'token_50k',
    icon: '🏦',
    nameZh: '代币银行',
    nameEn: 'Token Bank',
    descZh: '累计获得 50000 代币',
    descEn: 'Earn 50,000 Tokens in total',
    test: (s, p) => s.lifetimeToken >= 50000,
  ),
  Achievement(
    id: 'parts_30',
    icon: '🔧',
    nameZh: '收藏家 I',
    nameEn: 'Collector I',
    descZh: '拥有 30 个部件',
    descEn: 'Own 30 parts',
    test: (s, p) => s.ownedParts.length >= 30,
  ),
  Achievement(
    id: 'parts_70',
    icon: '🧰',
    nameZh: '收藏家 II',
    nameEn: 'Collector II',
    descZh: '拥有 70 个部件',
    descEn: 'Own 70 parts',
    test: (s, p) => s.ownedParts.length >= 70,
  ),
  Achievement(
    id: 'parts_140',
    icon: '🏭',
    nameZh: '收藏家 III',
    nameEn: 'Collector III',
    descZh: '拥有 140 个部件',
    descEn: 'Own 140 parts',
    test: (s, p) => s.ownedParts.length >= 140,
  ),
  Achievement(
    id: 'three_cars',
    icon: '🚗',
    nameZh: '三车齐全',
    nameEn: 'Full Garage',
    descZh: '组装出 3 辆车',
    descEn: 'Build 3 vehicles',
    test: (s, p) => s.builtVehicleCount >= 3,
  ),
  Achievement(
    id: 'power_5m',
    icon: '⚡',
    nameZh: '五百万战力',
    nameEn: 'Five Million',
    descZh: '车队战力（HP+ATK）达到 500 万',
    descEn: 'Reach 5,000,000 total power',
    test: (s, p) => p >= 5000000,
  ),
  Achievement(
    id: 'power_15m',
    icon: '🔥',
    nameZh: '一千五百万战力',
    nameEn: 'Fifteen Million',
    descZh: '车队战力（HP+ATK）达到 1500 万',
    descEn: 'Reach 15,000,000 total power',
    test: (s, p) => p >= 15000000,
  ),
  Achievement(
    id: 'found_gang',
    icon: '🏛️',
    nameZh: '开山祖师',
    nameEn: 'Founder',
    descZh: '组建自己的帮派',
    descEn: 'Found your own gang',
    test: (s, p) => s.gangOwned,
  ),
  Achievement(
    id: 'join_gang',
    icon: '🤝',
    nameZh: '入伙',
    nameEn: 'Joining Up',
    descZh: '加入一个已有帮派',
    descEn: 'Join an existing gang',
    test: (s, p) => s.inGang && !s.gangOwned,
  ),
  Achievement(
    id: 'recruit_3',
    icon: '📣',
    nameZh: '招兵买马',
    nameEn: 'Recruiting',
    descZh: '帮派拥有 3 名成员（不含自己）',
    descEn: 'Your gang has 3 members (excluding you)',
    test: (s, p) => s.gangMembers.length >= 3,
  ),
  Achievement(
    id: 'recruit_10',
    icon: '🎺',
    nameZh: '一呼百应',
    nameEn: 'Rallying Cry',
    descZh: '帮派拥有 10 名成员（不含自己）',
    descEn: 'Your gang has 10 members (excluding you)',
    test: (s, p) => s.gangMembers.length >= 10,
  ),
  Achievement(
    id: 'city_win1',
    icon: '⚔️',
    nameZh: '城市之王·首胜',
    nameEn: 'City King: First Win',
    descZh: '赢下第一场城市之王',
    descEn: 'Win your first City King battle',
    test: (s, p) => s.cityWins >= 1,
  ),
  Achievement(
    id: 'city_win10',
    icon: '🗡️',
    nameZh: '城市之王·十胜',
    nameEn: 'City King: 10 Wins',
    descZh: '赢下 10 场城市之王',
    descEn: 'Win 10 City King battles',
    test: (s, p) => s.cityWins >= 10,
  ),
  Achievement(
    id: 'city_win50',
    icon: '🛡️',
    nameZh: '城市之王·五十胜',
    nameEn: 'City King: 50 Wins',
    descZh: '赢下 50 场城市之王',
    descEn: 'Win 50 City King battles',
    test: (s, p) => s.cityWins >= 50,
  ),
  Achievement(
    id: 'gang_rank_10',
    icon: '📈',
    nameZh: '城市新贵',
    nameEn: 'Rising Star',
    descZh: '帮派大致排名进入前 10',
    descEn: 'Your gang reaches the top 10',
    test: (s, p) => s.gangRankHint > 0 && s.gangRankHint <= 10,
  ),
  Achievement(
    id: 'gang_rank_1',
    icon: '🏆',
    nameZh: '城市霸主',
    nameEn: 'City Overlord',
    descZh: '帮派大致排名第 1',
    descEn: 'Your gang ranks No.1',
    test: (s, p) => s.gangRankHint == 1,
  ),
  Achievement(
    id: 'day_30',
    icon: '📅',
    nameZh: '坚持一月',
    nameEn: 'One Month',
    descZh: '游玩到第 30 天',
    descEn: 'Survive to day 30',
    test: (s, p) => s.day >= 30,
  ),
  Achievement(
    id: 'day_100',
    icon: '🗓️',
    nameZh: '坚持百日',
    nameEn: 'One Hundred Days',
    descZh: '游玩到第 100 天',
    descEn: 'Survive to day 100',
    test: (s, p) => s.day >= 100,
  ),
  Achievement(
    id: 'day_365',
    icon: '🎆',
    nameZh: '一年之约',
    nameEn: 'One Year',
    descZh: '游玩到第 365 天',
    descEn: 'Survive to day 365',
    test: (s, p) => s.day >= 365,
  ),
];
