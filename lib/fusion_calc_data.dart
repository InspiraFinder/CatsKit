/// 锦标赛战车 · 熔铸（融合）计算 —— 纯逻辑，不依赖 Flutter。
///
/// 全部公式来自游戏自带 cljs 源码（`.so` 内未混淆），
/// 与机制指南「融合：经验、花费与出售」一节完全一致：
///
/// * **部件综合价值** = 固有价值 + Σ（历次融合获得的经验）
/// * **部件经验价值** = 固有价值 + 0.7 × Σ（历次融合获得的经验）
/// * **融合获得经验** = ⌈(1 + 本次融合时的专业机械师) × 品质系数 × 被融合部件的经验价值⌉
/// * **部件金币价值** = 把部件综合价值当坐标去查金币阶梯（线性插值）
/// * **被融合需要** = round(**自己**的部件金币价值 × (1 − 专业交易商))
///   —— 把这一件**当材料**喂掉要花的钱（融合时扣的就是**材料**这个数，与目标部件无关）
/// * **出售价**   = round(自己的被融合需要 × 0.5 × 品质系数 × (1 + 商人))
///
/// 所有取整都按游戏口径（`Math.round` / `Math.ceil`）；
/// 为了不受浮点误差影响，内部一律用**整数**运算再取整。
library;

// ==================== 基础枚举与文案 ====================

/// 部件材质（顺序即游戏配置里的下标：0 木质 … 4 碳钢）
enum PartMaterial { wood, metal, military, gold, carbon }

/// 部件品质（普通 / 魔法 / 传奇）
enum PartQuality { common, magic, legendary }

const List<String> kMaterialZh = <String>['木质', '金属', '军用', '黄金', '碳钢'];
const List<String> kMaterialEn = <String>[
  'Wood',
  'Metal',
  'Military',
  'Gold',
  'Carbon',
];

const List<String> kQualityZh = <String>['普通', '魔法', '传奇'];
const List<String> kQualityEn = <String>['Common', 'Magic', 'Legendary'];

/// 品质系数：普通 1、魔法 2、传奇 4
/// （= `magicSellCoeff` × `legendarySellCoeffs[传奇档]`，传奇件同时也是「魔法件」）
int qualityFactor(PartQuality q) => switch (q) {
  PartQuality.common => 1,
  PartQuality.magic => 2,
  PartQuality.legendary => 4,
};

// ==================== 配置数组 ====================

/// 经验阶梯（`vehiclePartExpValueMap`，斐波那契 F(2)…F(35)，共 34 项）
const List<int> kExpLadder = <int>[
  1,
  2,
  3,
  5,
  8,
  13,
  21,
  34,
  55,
  89,
  144,
  233,
  377,
  610,
  987,
  1597,
  2584,
  4181,
  6765,
  10946,
  17711,
  28657,
  46368,
  75025,
  121393,
  196418,
  317811,
  514229,
  832040,
  1346269,
  2178309,
  3524578,
  5702887,
  9227465,
];

/// 金币阶梯（`upgradeCostMap`，与经验阶梯同索引、共 34 项）
const List<int> kCoinLadder = <int>[
  469,
  750,
  1125,
  1688,
  2438,
  3375,
  4500,
  5813,
  7313,
  9000,
  10875,
  12938,
  15188,
  17625,
  20250,
  23063,
  26063,
  29250,
  32625,
  36188,
  39938,
  43875,
  48000,
  52313,
  56813,
  61875,
  66938,
  72000,
  77063,
  82125,
  87188,
  92250,
  97313,
  102375,
];

/// 「**累计**到第 L 级」的基础经验（实际值 = 本表 × 材质 k）；下标 0 → 1 级，共 26 项。
///
/// 规律：累计到第 L 级 = k × (L(L+1)/2 − 1)，但**第 26 级是游戏原始表的收窄值 334**
/// （不是规律里的 350）：25 → 26 级只需要 10k。
const List<int> kCumulativeBase = <int>[
  0,
  2,
  5,
  9,
  14,
  20,
  27,
  35,
  44,
  54,
  65,
  77,
  90,
  104,
  119,
  135,
  152,
  170,
  189,
  209,
  230,
  252,
  275,
  299,
  324,
  334,
];

/// 星级（1..5）→ 内部最大等级；**界面显示的最高等级 = 本表 + 1**（即 5 × 星级 + 1）
const List<int> kMaxInternalLevel = <int>[5, 10, 15, 20, 25];

/// 固定回收比例（`fusionEfficiencyCoefficient`）
const double kFusionEfficiency = 0.7;

/// 出售价系数（`sellPriceCoefficient`）
const double kSellCoefficient = 0.5;

/// 技能档位（0 = 未学习）→ 百分比
int skillPercent(int level) => switch (level) {
  1 => 10,
  2 => 20,
  3 => 30,
  _ => 0,
};

// ==================== 档位与固有价值 ====================

/// 档位下标 = (星级 − 1) + 5 × 材质下标（0 起）
int tierIndex(int materialIdx, int star) => (star - 1) + 5 * materialIdx;

/// 段位（1..25）= 档位下标 + 1
int tierNumber(int materialIdx, int star) => tierIndex(materialIdx, star) + 1;

/// 固有价值（材料 × 星级）= 经验阶梯上该档位的基准值。
///
/// **1 星一行就是各材质的 k**（木质 1 / 金属 13 / 军用 144 / 黄金 1597 / 碳钢 17711）。
int intrinsicValue(int materialIdx, int star) =>
    kExpLadder[tierIndex(materialIdx, star)];

/// 材质 k（= 该材质 1 星的固有价值）
int materialFactor(int materialIdx) => intrinsicValue(materialIdx, 1);

/// 显示的最高等级（= 5 × 星级 + 1）
int maxDisplayLevel(int star) => kMaxInternalLevel[star - 1] + 1;

/// **满级那一级的经验上限**（＝「累计到最高等级」）。
///
/// 最高等级**没有自己的经验段**：它就是「上一级的 100%」。例如
/// 5 星 26 级 ＝ 25 级 100%、4 星 21 级 ＝ 20 级 100%、3 星 16 级 ＝ 15 级 100%，
/// 所以满级部件的进度永远是 **0%**，经验也不会超过这个上限。
int maxExpOf(int materialIdx, int star) =>
    materialFactor(materialIdx) * kCumulativeBase[maxDisplayLevel(star) - 1];

/// 把「已投入经验」夹到 `[0, maxExpOf]`
int clampExp(int exp, int materialIdx, int star) =>
    exp.clamp(0, maxExpOf(materialIdx, star));

// ==================== 等级 ↔ 经验 ====================

/// 由「已投入经验」得到显示等级（1 起）。
///
/// 第 L 级的区间是 `[累计到 L 级, 累计到 L+1 级)`；
/// 最高等级（如 5 星的 26 级）**只对应一个点**（= [@link maxExpOf]），即上一级的 100%。
int levelOfExp(int exp, int materialIdx, int star) {
  final k = materialFactor(materialIdx);
  final top = maxDisplayLevel(star);
  for (int lv = 1; lv < top; lv++) {
    if (k * kCumulativeBase[lv] > exp) return lv;
  }
  return top;
}

/// 当前等级内的进度（0..1）。
///
/// **满级固定为 0**（最高一级没有进度条：它等于上一级的 100%）。
double progressOfExp(int exp, int materialIdx, int star) {
  final k = materialFactor(materialIdx);
  final lv = levelOfExp(exp, materialIdx, star);
  final top = maxDisplayLevel(star);
  if (lv >= top) return 0;
  final lo = k * kCumulativeBase[lv - 1];
  final hi = k * kCumulativeBase[lv];
  return (exp - lo) / (hi - lo);
}

/// 由等级 + 进度换算「已投入经验」：
/// `已投入经验 = k × (L(L+1)/2 − 1) + 进度 × (L + 1) × k`
///
/// 选到最高等级时进度无意义（返回满级上限）；
/// 在上一级拉到 100% 得到的也正是同一个值。
int expFromLevelProgress({
  required int level,
  required double progress,
  required int materialIdx,
  required int star,
}) {
  final k = materialFactor(materialIdx);
  final top = maxDisplayLevel(star);
  final lv = level.clamp(1, top);
  final lo = k * kCumulativeBase[lv - 1];
  if (lv >= top) return lo;
  final hi = k * kCumulativeBase[lv];
  final p = progress.clamp(0.0, 1.0);
  return (lo + p * (hi - lo)).round();
}

/// 升到下一级还需要多少经验（满级返回 0）
int expToNextLevel(int exp, int materialIdx, int star) {
  final k = materialFactor(materialIdx);
  final lv = levelOfExp(exp, materialIdx, star);
  final top = maxDisplayLevel(star);
  if (lv >= top) return 0;
  return k * kCumulativeBase[lv] - exp;
}

// ==================== 价值与价格 ====================

/// 在经验阶梯上定位坐标，返回相邻两格的读数
class _LadderHit {
  final int lowExp, highExp, lowCoin, highCoin;
  const _LadderHit(this.lowExp, this.highExp, this.lowCoin, this.highCoin);
}

_LadderHit _locate(int coordinate) {
  int i = 0;
  for (int j = 0; j < kExpLadder.length; j++) {
    if (kExpLadder[j] <= coordinate) {
      i = j;
    } else {
      break;
    }
  }
  final lastIndex = kExpLadder.length - 1;
  final lowExp = kExpLadder[i];
  final highExp = i < lastIndex ? kExpLadder[i + 1] : lowExp + 1;
  final lowCoin = kCoinLadder[i];
  final highCoin = i < lastIndex ? kCoinLadder[i + 1] : lowCoin;
  return _LadderHit(lowExp, highExp, lowCoin, highCoin);
}

/// 部件综合价值 = 固有价值 + 已投入经验
int compositeValueOf(int exp, int materialIdx, int star) =>
    intrinsicValue(materialIdx, star) + exp;

/// 部件经验价值 = 固有价值 + 0.7 × 已投入经验
double xpValueOf(int exp, int materialIdx, int star) =>
    intrinsicValue(materialIdx, star) + kFusionEfficiency * exp;

/// 部件金币价值（未取整）= 把综合价值当坐标，在金币阶梯上线性插值
double coinValueOf(int exp, int materialIdx, int star) {
  final coordinate = compositeValueOf(exp, materialIdx, star);
  final hit = _locate(coordinate);
  final span = hit.highExp - hit.lowExp;
  return hit.lowCoin +
      (coordinate - hit.lowExp) * (hit.highCoin - hit.lowCoin) / span;
}

/// 四舍五入（JS `Math.round` 口径：正数下等于 floor(x + 0.5)）
int _roundHalfUp(int numerator, int denominator) =>
    (2 * numerator + denominator) ~/ (2 * denominator);

/// 这个部件自己的**被融合花费**（＝ 把**它当材料**喂给别的部件时要花多少金币）
/// = round(部件金币价值 × (1 − 专业交易商))
///
/// ⚠ 与被喂的目标部件**无关**：游戏里 `upgrade_cost` 用的是**材料**这一侧的
/// 档位 / 星级 / 已投入经验，所以融合时扣的是**材料**这个数。
int fusionCostOf(int exp, int materialIdx, int star, int dealerLevel) {
  final coordinate = compositeValueOf(exp, materialIdx, star);
  final hit = _locate(coordinate);
  final span = hit.highExp - hit.lowExp;
  final scaled = // = 部件金币价值 × span（整数）
      hit.lowCoin * span +
      (coordinate - hit.lowExp) * (hit.highCoin - hit.lowCoin);
  final keep = 100 - skillPercent(dealerLevel);
  return _roundHalfUp(scaled * keep, span * 100);
}

/// 出售价 = round(自己的被融合花费 × 0.5 × 品质系数 × (1 + 商人))
int sellPriceOf(
  int exp,
  int materialIdx,
  int star, {
  required PartQuality quality,
  required int dealerLevel,
  required int merchantLevel,
}) {
  final cost = fusionCostOf(exp, materialIdx, star, dealerLevel);
  final factor = qualityFactor(quality) * (100 + skillPercent(merchantLevel));
  return _roundHalfUp(cost * factor, 200);
}

/// 融合获得经验 = ⌈(1 + 本次融合时的专业机械师) × 品质系数 × 被融合部件的经验价值⌉
///
/// 内部用整数算：`(100 + 技能) × 品质系数 × (10 × 固有价值 + 7 × 已投入经验) / 1000`
int fusionXpGainOf({
  required int materialExp,
  required int materialIdx,
  required int materialStar,
  required PartQuality materialQuality,
  required int mechanicLevel,
}) {
  final inner =
      10 * intrinsicValue(materialIdx, materialStar) + 7 * materialExp;
  final numerator =
      (100 + skillPercent(mechanicLevel)) *
      qualityFactor(materialQuality) *
      inner;
  return (numerator + 999) ~/ 1000;
}

// ==================== 工具箱 ====================

// ---- 下面三张是「按类型加成」的配置口径数据 ----
// 界面现在只统计工具箱的**数量**（不区分类型、也不算加成），所以这一段在 UI 里
// 没有用到；保留是为了与配置 / 机制指南对齐，随时可以恢复「加成」显示：
// 生命值/攻击力加成 × (1 + 加强工具箱技能) 向下取整；电力 +1；魔法 +10%（有上限）。

/// 25 档工具箱加成：生命值工具箱 +HP（`toolboxBonuses.HEALTH`）
const List<int> kToolboxHealthBonus = <int>[
  8,
  12,
  20,
  28,
  36,
  48,
  76,
  108,
  148,
  192,
  244,
  368,
  516,
  688,
  888,
  1112,
  1668,
  2336,
  3116,
  4008,
  5012,
  7524,
  10540,
  14060,
  18080,
];

/// 25 档工具箱加成：攻击力工具箱 +ATK（`toolboxBonuses.DAMAGE`）
const List<int> kToolboxAttackBonus = <int>[
  4,
  6,
  10,
  14,
  18,
  24,
  38,
  54,
  74,
  96,
  122,
  184,
  258,
  344,
  444,
  556,
  834,
  1168,
  1558,
  2004,
  2506,
  3762,
  5270,
  7030,
  9040,
];

/// 25 档工具箱**融合基础花费**（`toolboxFuseBaseCosts`）；
/// 工具箱自己的**售价恒等于 8 × 本值**（也就是往空部件上融第 1 个它的花费）
const List<int> kToolboxBaseCost = <int>[
  100,
  150,
  225,
  325,
  450,
  600,
  775,
  975,
  1200,
  1450,
  1725,
  2025,
  2350,
  2700,
  3075,
  3475,
  3900,
  4350,
  4825,
  5325,
  5850,
  6400,
  6975,
  7575,
  8137,
];

/// 第 k 个工具箱（k 从 0 起）的倍率：×8、×16、×32 … 第 7 个及以后恒为 **×512**
/// （= 首件的 64 倍，`toolboxFuseCostMultipliers` 封顶）
int toolboxFuseMultiplier(int alreadyFused) {
  final k = alreadyFused.clamp(0, 19);
  return k >= 6 ? 512 : 8 << k;
}

/// 往该部件上再融一个工具箱的花费 = 基础花费 × 倍率
int toolboxFuseCostOf({
  required int materialIdx,
  required int star,
  required int alreadyFused,
}) =>
    kToolboxBaseCost[tierIndex(materialIdx, star)] *
    toolboxFuseMultiplier(alreadyFused);

/// 工具箱自己的出售价 = 基础花费 × 8（= 首融花费）
int toolboxSellPriceOf(int materialIdx, int star) =>
    8 * kToolboxBaseCost[tierIndex(materialIdx, star)];

/// 已经融进部件的工具箱，卖掉部件时只按 **50%** 折算收回
///
/// ⚠ 回收额按**这个工具箱自己的售价**算（= 它自己的首融价），
/// **与它是该部件上的第几个无关**：翻倍的只是你付出的花费，不是它的身价。
/// 所以叠 3 个的回收率是 50% / 25% / 12.5%（源码：`ConfigHelper::calculatePartSellPrice`
/// 逐个 `getToolboxSellPrice(tier, stars) × getFusedToolboxSellPriceMultiplier()` 累加）。
const int kFusedToolboxSellPercent = 50;

/// 「加强工具箱」技能（生命值 / 攻击力）的百分比：**+15% / +30% / +45%**
/// （段位 6 / 段位 9 解锁，各 1 / 2 / 3 点；与 [skillPercent] 的 10/20/30 不同）
int toolboxSkillPercent(int level) => switch (level) {
  1 => 15,
  2 => 30,
  3 => 45,
  _ => 0,
};

/// 已经融进某个部件的一个工具箱
///
/// 只记「材质 + 星级」（决定融它花多少钱、卖掉能回收多少）；
/// **不记类型**——界面只统计工具箱的数量（生命值 / 攻击力 / 电力 / 魔法不做区分）。
class FusionToolbox {
  int materialIdx;
  int star;

  FusionToolbox({required this.materialIdx, required this.star});

  int get tier => tierNumber(materialIdx, star);
  int get baseCost => kToolboxBaseCost[tierIndex(materialIdx, star)];

  /// 它自己的售价（还没融进部件时的价格）
  int get sellPrice => toolboxSellPriceOf(materialIdx, star);

  /// 融进部件后再卖掉部件，只能收回这么多
  ///
  /// **不随「它是第几个」变化**：第 2 个虽然花了 2 倍的钱，回收仍然是这里的值。
  int get refund => sellPrice * kFusedToolboxSellPercent ~/ 100;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'm': materialIdx,
    's': star,
  };

  static FusionToolbox fromJson(Map<String, dynamic> json) => FusionToolbox(
    materialIdx: (json['m'] as num?)?.toInt() ?? 0,
    star: (json['s'] as num?)?.toInt() ?? 1,
  );
}

// ==================== 部件模型 ====================

/// 模块里添加的一个部件
class FusionPart {
  final String id;
  int materialIdx;
  int star;
  int exp; // 已投入经验
  PartQuality quality;

  /// 已经融进去的工具箱（**加成不继承、卖掉只回收一半**）
  final List<FusionToolbox> toolboxes;

  FusionPart({
    required this.id,
    required this.materialIdx,
    required this.star,
    required this.exp,
    required this.quality,
    List<FusionToolbox>? toolboxes,
  }) : toolboxes = toolboxes ?? <FusionToolbox>[];

  int get tier => tierNumber(materialIdx, star);
  int get intrinsic => intrinsicValue(materialIdx, star);
  int get compositeValue => compositeValueOf(exp, materialIdx, star);
  double get xpValue => xpValueOf(exp, materialIdx, star);
  int get level => levelOfExp(exp, materialIdx, star);
  int get maxLevel => maxDisplayLevel(star);
  double get progress => progressOfExp(exp, materialIdx, star);
  int get toNextLevel => expToNextLevel(exp, materialIdx, star);

  /// 本级经验条：本级已经积累了多少（＝ 已投入经验 － 累计到本级）
  int get xpInLevel {
    final k = materialFactor(materialIdx);
    return exp - k * kCumulativeBase[level - 1];
  }

  /// 本级经验条：升到下一级需要多少（＝ 本级的条长；满级没有自己的经验段，返回 0）
  int get levelExpSpan {
    final k = materialFactor(materialIdx);
    if (level >= maxDisplayLevel(star)) return 0;
    return k * (kCumulativeBase[level] - kCumulativeBase[level - 1]);
  }

  /// 满级上限（＝「累计到最高等级」）；满级部件的进度永远是 0%
  int get maxExp => maxExpOf(materialIdx, star);

  bool get isMaxLevel => exp >= maxExp;

  /// 加入经验并夹到满级上限，返回**实际加进去**的经验（被丢掉的部分 = gained − 返回值）
  int addExp(int delta) {
    final before = exp;
    exp = clampExp(exp + delta, materialIdx, star);
    return exp - before;
  }

  // ---------- 工具箱 ----------

  /// 已融的工具箱个数（也就是下一个工具箱的 k）
  int get toolboxCount => toolboxes.length;

  /// 卖掉这个部件时，已融工具箱能收回的金币（每个都按**它自己的售价 × 50%**，
  /// 与「第几个」无关：第 2 个花了 2 倍的钱，回收还是 1 份）
  int get toolboxRefund => toolboxes.fold(0, (s, t) => s + t.refund);

  /// 再往这个部件上融一个工具箱的花费
  int nextToolboxFuseCost(int materialIdx, int star) => toolboxFuseCostOf(
    materialIdx: materialIdx,
    star: star,
    alreadyFused: toolboxes.length,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'm': materialIdx,
    's': star,
    'e': exp,
    'q': quality.index,
    if (toolboxes.isNotEmpty) 'tb': toolboxes.map((t) => t.toJson()).toList(),
  };

  static FusionPart fromJson(Map<String, dynamic> json) => FusionPart(
    id: json['id'] as String? ?? '',
    materialIdx: (json['m'] as num?)?.toInt() ?? 0,
    star: (json['s'] as num?)?.toInt() ?? 1,
    exp: (json['e'] as num?)?.toInt() ?? 0,
    quality: PartQuality.values[(json['q'] as num?)?.toInt() ?? 0],
    toolboxes: (json['tb'] as List<dynamic>?)
        ?.map(
          (e) => FusionToolbox.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}
