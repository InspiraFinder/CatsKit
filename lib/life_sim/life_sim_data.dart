/// 「猫生重开」模拟器（CatsKit 2.0） —— 静态数据表
///
/// 这里集中放所有**可调平衡数值**与文案：活动决策、档位阈值、奖励表、
/// 部件掉落权重、帮派库、成就定义。改平衡只需要改本文件。
library;

import 'dart:math';

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

/// 齿轮奔袭：精力 → 倍数
const Map<int, double> kGearEnergyMultipliers = <int, double>{
  1: 0.25,
  2: 0.5,
  4: 0.75,
  8: 1.0,
};

/// 齿轮奔袭的四档决策（进度 = 战力基础值 × 倍数）
const List<ActivityChoice> kGearChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'gear1',
    nameZh: '低速档',
    nameEn: 'Low Gear',
    descZh: '战力基础值 ×0.25',
    descEn: 'Base ×0.25',
    energyCost: 1,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear2',
    nameZh: '中速档',
    nameEn: 'Mid Gear',
    descZh: '战力基础值 ×0.5',
    descEn: 'Base ×0.5',
    energyCost: 2,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear3',
    nameZh: '高速档',
    nameEn: 'High Gear',
    descZh: '战力基础值 ×0.75',
    descEn: 'Base ×0.75',
    energyCost: 4,
    coef: 0,
  ),
  ActivityChoice(
    id: 'gear4',
    nameZh: '超频档',
    nameEn: 'Overdrive',
    descZh: '战力基础值 ×1',
    descEn: 'Base ×1',
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

/// 废铁行动的四档决策：进度 +50/100/150/200，精力 1/2/4/8
///
/// 前两档每点精力更划算（+50/精力），后两档用来快速把剩余精力砸进进度条。
const List<ActivityChoice> kScrapChoices = <ActivityChoice>[
  ActivityChoice(
    id: 'scrap1',
    nameZh: '捡废铁',
    nameEn: 'Scavenge',
    descZh: '进度 +50',
    descEn: 'Progress +50',
    energyCost: 1,
    coef: 0,
    fixedPoints: 50,
  ),
  ActivityChoice(
    id: 'scrap2',
    nameZh: '小队搜刮',
    nameEn: 'Squad Sweep',
    descZh: '进度 +100',
    descEn: 'Progress +100',
    energyCost: 2,
    coef: 0,
    fixedPoints: 100,
  ),
  ActivityChoice(
    id: 'scrap3',
    nameZh: '大举搜刮',
    nameEn: 'Mass Sweep',
    descZh: '进度 +150',
    descEn: 'Progress +150',
    energyCost: 4,
    coef: 0,
    fixedPoints: 150,
  ),
  ActivityChoice(
    id: 'scrap4',
    nameZh: '全城清空',
    nameEn: 'City Clear',
    descZh: '进度 +200',
    descEn: 'Progress +200',
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
