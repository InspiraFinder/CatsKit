/// 锦标赛战车 · 基础数据（25 档 = 5 材质 × 5 星级）
///
/// 由 `tool/gen_champ_data.js` 从机制指南的表格常量生成，勿手改。
/// 每档有 3 个「参数组合」（数值组合 1/2/3）。
library;

/// 材质中文名（索引 = 材质 0..4）
const List<String> kChampMaterialZh = <String>['木质', '金属', '军用', '黄金', '碳钢'];
const List<String> kChampMaterialEn = <String>[
  'Wood',
  'Metal',
  'Military',
  'Gold',
  'Carbon',
];

/// 档位（0..24）→ 材质索引（0..4）与星级（1..5）
int champMaterialOf(int tier) => tier ~/ 5;
int champStarOf(int tier) => tier % 5 + 1;

/// 档位名的中文/英文（如「金属 3 星」）
String champTierNameZh(int tier) =>
    '${kChampMaterialZh[champMaterialOf(tier)]} ${champStarOf(tier)} 星';
String champTierNameEn(int tier) {
  final s = champStarOf(tier);
  return '${kChampMaterialEn[champMaterialOf(tier)]} $s ${s == 1 ? 'star' : 'stars'}';
}

/// 星级 → 最高等级（6 / 11 / 16 / 21 / 26）
int champMaxLevel(int tier) => champStarOf(tier) * 5 + 1;

/// kChampBodyHp
const List<List<int>> kChampBodyHp = <List<int>>[
  [45, 45, 45],
  [75, 60, 45],
  [105, 90, 75],
  [135, 120, 105],
  [180, 158, 135],
  [285, 233, 180],
  [405, 345, 285],
  [555, 480, 405],
  [720, 645, 555],
  [915, 818, 720],
  [1380, 1148, 915],
  [1935, 1658, 1380],
  [2580, 2258, 1935],
  [3330, 2955, 2580],
  [4170, 3750, 3330],
  [6255, 5213, 4170],
  [8760, 7508, 6255],
  [11685, 10223, 8760],
  [15030, 13358, 11685],
  [18795, 16920, 15030],
  [28215, 23505, 18795],
  [39525, 33870, 28215],
  [52725, 46125, 39525],
  [67800, 60255, 52725],
  [84780, 76290, 67800],
];

/// kChampBodySupply
const List<List<int>> kChampBodySupply = <List<int>>[
  [6, 6, 6],
  [6, 7, 8],
  [9, 10, 11],
  [12, 13, 14],
  [15, 16, 17],
  [8, 9, 10],
  [10, 11, 12],
  [12, 13, 14],
  [14, 15, 16],
  [16, 17, 18],
  [8, 9, 10],
  [10, 11, 12],
  [12, 13, 14],
  [14, 15, 16],
  [16, 17, 18],
  [8, 9, 10],
  [10, 11, 12],
  [12, 13, 14],
  [14, 15, 16],
  [16, 17, 18],
  [8, 9, 10],
  [10, 11, 12],
  [12, 13, 14],
  [14, 15, 16],
  [16, 17, 18],
];

/// kChampWeaponDrain
const List<List<int>> kChampWeaponDrain = <List<int>>[
  [4, 5, 6],
  [5, 6, 7],
  [6, 7, 8],
  [7, 8, 9],
  [8, 9, 10],
  [4, 5, 6],
  [5, 6, 7],
  [6, 7, 8],
  [7, 8, 9],
  [8, 9, 10],
  [4, 5, 6],
  [5, 6, 7],
  [6, 7, 8],
  [7, 8, 9],
  [8, 9, 10],
  [4, 5, 6],
  [5, 6, 7],
  [6, 7, 8],
  [7, 8, 9],
  [8, 9, 10],
  [4, 5, 6],
  [5, 6, 7],
  [6, 7, 8],
  [7, 8, 9],
  [8, 9, 10],
];

/// kChampWeaponAtk
const List<List<int>> kChampWeaponAtk = <List<int>>[
  [20, 25, 30],
  [30, 40, 50],
  [50, 60, 70],
  [70, 80, 90],
  [90, 105, 120],
  [120, 155, 190],
  [190, 230, 270],
  [270, 320, 370],
  [370, 430, 480],
  [480, 545, 610],
  [610, 765, 920],
  [920, 1105, 1290],
  [1290, 1505, 1720],
  [1720, 1970, 2220],
  [2220, 2500, 2780],
  [2780, 3475, 4170],
  [4170, 5005, 5840],
  [5840, 6815, 7790],
  [7790, 8905, 10020],
  [10020, 11280, 12530],
  [12530, 15670, 18810],
  [18810, 22580, 26350],
  [26350, 30750, 35150],
  [35150, 40170, 45200],
  [45200, 50860, 56520],
];

/// kChampWheelHp
const List<List<int>> kChampWheelHp = <List<int>>[
  [10, 13, 15],
  [15, 20, 25],
  [25, 30, 35],
  [35, 40, 45],
  [45, 53, 60],
  [60, 78, 95],
  [95, 115, 135],
  [135, 160, 185],
  [185, 215, 240],
  [240, 273, 305],
  [305, 383, 460],
  [460, 553, 645],
  [645, 753, 860],
  [860, 985, 1110],
  [1110, 1250, 1390],
  [1390, 1738, 2085],
  [2085, 2503, 2920],
  [2920, 3408, 3895],
  [3895, 4453, 5010],
  [5010, 5640, 6265],
  [6265, 7835, 9405],
  [9405, 11290, 13175],
  [13175, 15375, 17575],
  [17575, 20085, 22600],
  [22600, 25430, 28260],
];

/// kChampGadgetHp
const List<List<int>> kChampGadgetHp = <List<int>>[
  [10, 13, 15],
  [15, 20, 25],
  [25, 30, 35],
  [35, 40, 45],
  [45, 53, 60],
  [60, 78, 95],
  [95, 115, 135],
  [135, 160, 185],
  [185, 215, 240],
  [240, 273, 305],
  [305, 383, 460],
  [460, 553, 645],
  [645, 753, 860],
  [860, 985, 1110],
  [1110, 1250, 1390],
  [1390, 1738, 2085],
  [2085, 2503, 2920],
  [2920, 3408, 3895],
  [3895, 4453, 5010],
  [5010, 5640, 6265],
  [6265, 7835, 9405],
  [9405, 11290, 13175],
  [13175, 15375, 17575],
  [17575, 20085, 22600],
  [22600, 25430, 28260],
];

/// 配件基础治疗量（按档位）
const List<int> kChampGadgetHeal = <int>[
  19,
  30,
  45,
  60,
  79,
  116,
  173,
  240,
  323,
  409,
  574,
  829,
  1129,
  1478,
  1875,
  2606,
  3754,
  5111,
  6679,
  8460,
  11753,
  16935,
  23063,
  30128,
  38145,
];

/// 工具箱加成：+HP / +ATK（按部件档位）
const List<int> kChampToolboxHp = <int>[
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
const List<int> kChampToolboxAtk = <int>[
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

/// 每级加成（最终值，已乘系数），索引 = 材质 0..4
const List<double> kChampBodyHpPerLevel = <double>[3.6, 18, 90, 450, 1800];
const List<double> kChampWeaponAtkPerLevel = <double>[1.6, 8, 40, 200, 800];
const List<double> kChampWheelHpPerLevel = <double>[2, 10, 50, 250, 1000];
const List<double> kChampWheelAtkPerLevel = <double>[0.8, 4, 20, 100, 400];
const List<double> kChampGadgetHpPerLevel = <double>[2, 10, 50, 250, 1000];
const List<double> kChampHealPerLevel = <double>[6, 30, 150, 750, 3000];

/// 配件耗电：低/高组（按星级：1-2 星 1/2，3-5 星 2/3）
int champGadgetDrain(int tier, {required bool highGroup}) {
  final star = champStarOf(tier);
  final low = star <= 2 ? 1 : 2;
  return highGroup ? low + 1 : low;
}

// ==================== 具体部件（含 HP/ATK 倍数与技能） ====================

/// 技能等级 → 加成百分比（无 / 1 级 / 2 级 / 3 级）
const List<int> kChampSkillPcts = <int>[0, 10, 20, 30];

/// 具体车身（13 种）：倍数只作用在 HP 上，不影响供电
class ChampBodyInfo {
  final String nameZh;
  final String nameEn;
  final double multiplier;
  final bool hasHpSkill;

  const ChampBodyInfo(
    this.nameZh,
    this.nameEn,
    this.multiplier,
    this.hasHpSkill,
  );
}

const List<ChampBodyInfo> kChampBodies = <ChampBodyInfo>[
  ChampBodyInfo('经典', 'Classic', 1.0, true),
  ChampBodyInfo('滑头', 'Sneaky', 1.3333, true),
  ChampBodyInfo('磐石', 'Boulder', 1.6667, true),
  ChampBodyInfo('巨鲸', 'Whale', 1.6667, true),
  ChampBodyInfo('金字塔', 'Pyramid', 1.6667, true),
  ChampBodyInfo('浪板', 'Surfer', 1.8333, true),
  ChampBodyInfo('泰坦', 'Titan', 2.0, true),
  ChampBodyInfo('钻石', 'Diamond', 2.0, false),
  ChampBodyInfo('蝎', 'Scorpion', 2.0, false),
  ChampBodyInfo('箭', 'Arrow', 2.0, false),
  ChampBodyInfo('向量', 'Vector', 2.1667, false),
  ChampBodyInfo('虎鲸', 'Orca', 2.1667, false),
  ChampBodyInfo('圣骑士', 'Paladin', 2.3333, false),
];

/// 具体武器（19 种）
class ChampWeaponInfo {
  final String nameZh;
  final String nameEn;
  final double multiplier;
  final bool hasAtkSkill;

  const ChampWeaponInfo(
    this.nameZh,
    this.nameEn,
    this.multiplier,
    this.hasAtkSkill,
  );
}

const List<ChampWeaponInfo> kChampWeapons = <ChampWeaponInfo>[
  ChampWeaponInfo('圆锯', 'Saw', 0.33, true),
  ChampWeaponInfo('双头圆锯', 'Double saw', 0.66, false),
  ChampWeaponInfo('火箭', 'Rocket', 0.35, true),
  ChampWeaponInfo('双管火箭', 'Double rocket', 0.35, true),
  ChampWeaponInfo('旋转火箭', 'Tilted rocket', 0.35, false),
  ChampWeaponInfo('激光', 'Laser', 0.4, true),
  ChampWeaponInfo('死亡射灯', 'Death ray', 0.4, false),
  ChampWeaponInfo('回旋镖', 'Boomerang', 0.4, false),
  ChampWeaponInfo('长钉', 'Stinger', 0.615, true),
  ChampWeaponInfo('猎枪', 'Shotgun', 0.7, false),
  ChampWeaponInfo('燃烧瓶', 'Molotov', 0.75, false),
  ChampWeaponInfo('电钻', 'Drill', 0.855, true),
  ChampWeaponInfo('旋转电钻', 'Tilted drill', 0.855, false),
  ChampWeaponInfo('电锯', 'Chainsaw', 1.0, true),
  ChampWeaponInfo('急射小机枪', 'Rapid gun', 1.0, false),
  ChampWeaponInfo('土豆大炮', 'Potato cannon', 1.0, false),
  ChampWeaponInfo('旋转电锯', 'Tilted chainsaw', 1.2, false),
  ChampWeaponInfo('直升无人机', 'Copter Drone', 0.64, false),
  ChampWeaponInfo('直升无人机（随从）', 'Copter Drone (minion)', 1.0, false),
];

/// 具体车轮（10 种）：[classes] = 能读到的尺寸档（0 小 / 1 中 / 2 大），
/// 组合选项数量 = classes 的长度（1-3 个，不同车轮不一样）
class ChampWheelInfo {
  final String nameZh;
  final String nameEn;
  final List<int> classes;
  final bool hasHpSkill;

  const ChampWheelInfo(this.nameZh, this.nameEn, this.classes, this.hasHpSkill);
}

const List<ChampWheelInfo> kChampWheels = <ChampWheelInfo>[
  ChampWheelInfo('旋钮轮', 'Knob wheel', <int>[0, 1, 2], true),
  ChampWheelInfo('滚轮', 'Roller', <int>[0, 1, 2], true),
  ChampWheelInfo('黏地轮 · 滚轮', 'Sticky roller', <int>[0, 1, 2], true),
  ChampWheelInfo('爬坡轮胎', 'Climbing big', <int>[0, 1, 2], false),
  ChampWheelInfo('滑板轮', 'Skateboard wheel', <int>[1, 2], true),
  ChampWheelInfo('轱辘轮', 'Cart wheel', <int>[1, 2], true),
  ChampWheelInfo('黏地轮 · 轱辘轮', 'Sticky cart wheel', <int>[1, 2], true),
  ChampWheelInfo('悬浮轮胎', 'Hover tire', <int>[1, 2], false),
  ChampWheelInfo('反重力滑板轮', 'Anti-gravity skateboard wheel', <int>[1, 2], false),
  ChampWheelInfo('大脚轮', 'Bigfoot', <int>[2], true),
];

/// 具体配件（12 种）
class ChampGadgetInfo {
  final String nameZh;
  final String nameEn;

  /// 是否有组合 2（低组耗电 + 高组 HP）
  final bool hasCombo2;

  /// 组合 1 的耗电是否为高组
  final bool combo1HighDrain;

  /// 组合 1 的基础 HP 组：0 低 / 1 中 / 2 高
  final int combo1HpGroup;
  final bool hasHpSkill;

  const ChampGadgetInfo(
    this.nameZh,
    this.nameEn, {
    required this.hasCombo2,
    required this.combo1HighDrain,
    required this.combo1HpGroup,
    required this.hasHpSkill,
  });
}

const List<ChampGadgetInfo> kChampGadgets = <ChampGadgetInfo>[
  ChampGadgetInfo(
    '急救套件',
    'First-aid kit',
    hasCombo2: true,
    combo1HighDrain: true,
    combo1HpGroup: 0,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '深度冻结',
    'Deep freeze',
    hasCombo2: true,
    combo1HighDrain: true,
    combo1HpGroup: 0,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '升降机',
    'Lift',
    hasCombo2: true,
    combo1HighDrain: true,
    combo1HpGroup: 0,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '叉车',
    'Forklift',
    hasCombo2: true,
    combo1HighDrain: true,
    combo1HpGroup: 0,
    hasHpSkill: true,
  ),
  ChampGadgetInfo(
    '护盾',
    'Shield',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 0,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '镇静剂之枪',
    'Tranquilizer gun',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 0,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '反弹器',
    'Bouncer',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 1,
    hasHpSkill: true,
  ),
  ChampGadgetInfo(
    '古怪手套',
    'Odd glove',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 1,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '推进器',
    'Thruster',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 2,
    hasHpSkill: true,
  ),
  ChampGadgetInfo(
    '反推器',
    'Repulser',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 2,
    hasHpSkill: true,
  ),
  ChampGadgetInfo(
    '渔网',
    'Fishnet',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 2,
    hasHpSkill: false,
  ),
  ChampGadgetInfo(
    '渔叉',
    'Harpoon',
    hasCombo2: false,
    combo1HighDrain: false,
    combo1HpGroup: 2,
    hasHpSkill: false,
  ),
];

// ==================== 公式（机制指南口径） ====================

/// 车身 HP = 向上取整(基础 HP × 0.6 × (1+技能) × 倍数) + 每级加成 × (等级-1)
double champBodyHpValue({
  required int tier,
  required int combo,
  required int level,
  required ChampBodyInfo body,
  required int skillPct,
}) {
  final base = kChampBodyHp[tier][combo];
  final first = (base * 0.6 * (1 + skillPct / 100) * body.multiplier).ceil();
  return first + kChampBodyHpPerLevel[champMaterialOf(tier)] * (level - 1);
}

/// 武器 ATK = 向上取整(基础 ATK × 倍数 × (1+技能)) + 每级加成 × (等级-1)
double champWeaponAtkValue({
  required int tier,
  required int combo,
  required int level,
  required ChampWeaponInfo weapon,
  required int skillPct,
}) {
  final base = kChampWeaponAtk[tier][combo];
  final first = (base * weapon.multiplier * (1 + skillPct / 100)).ceil();
  return first + kChampWeaponAtkPerLevel[champMaterialOf(tier)] * (level - 1);
}

/// 车轮 HP = 向上取整(基础车轮 HP × (1+技能)) + 每级加成 × (等级-1)
/// [sizeClass] 为车轮 classes 中选中的尺寸档（0 小 / 1 中 / 2 大）
double champWheelHpValue({
  required int tier,
  required int sizeClass,
  required int level,
  required int skillPct,
}) {
  final base = kChampWheelHp[tier][sizeClass];
  final first = (base * (1 + skillPct / 100)).ceil();
  return first + kChampWheelHpPerLevel[champMaterialOf(tier)] * (level - 1);
}

/// 车轮碾压 ATK = 向上取整(基础车轮 HP × 0.4) + 每级加成 × (等级-1)
double champWheelAtkValue({
  required int tier,
  required int sizeClass,
  required int level,
}) {
  final base = kChampWheelHp[tier][sizeClass];
  return (base * 0.4).ceil() +
      kChampWheelAtkPerLevel[champMaterialOf(tier)] * (level - 1);
}

/// 配件 HP = 向上取整(基础配件 HP × (1+技能)) + 每级加成 × (等级-1)
double champGadgetHpValue({
  required int tier,
  required int hpGroup,
  required int level,
  required int skillPct,
}) {
  final base = kChampGadgetHp[tier][hpGroup];
  final first = (base * (1 + skillPct / 100)).ceil();
  return first + kChampGadgetHpPerLevel[champMaterialOf(tier)] * (level - 1);
}

/// 配件治疗量 = 基础治疗量 + 每级加成 × (等级-1)
double champGadgetHealValue({required int tier, required int level}) =>
    kChampGadgetHeal[tier] +
    kChampHealPerLevel[champMaterialOf(tier)] * (level - 1);

/// 配件某个组合是否使用高组耗电
bool champGadgetHighDrain(ChampGadgetInfo g, int combo) =>
    combo == 0 ? g.combo1HighDrain : false;

/// 配件某个组合的 HP 组（0 低 / 1 中 / 2 高）
int champGadgetHpGroup(ChampGadgetInfo g, int combo) =>
    combo == 0 ? g.combo1HpGroup : (g.combo1HpGroup == 0 ? 2 : 0);
