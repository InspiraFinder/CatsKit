/// 「猫生重开」模拟器（CatsKit 2.0） —— 存档数据模型
///
/// 本文件只包含数据结构与 JSON 读写，**不含任何游戏规则逻辑**：
/// - 规则逻辑 → `life_sim_engine.dart`
/// - 静态数据（决策表 / 档位 / 奖励 / 帮派库 / 成就） → `life_sim_data.dart`
/// - 存档读写 → `life_sim_store.dart`
///
/// 核心设计（与需求对齐）：
/// - **以「天」计数**，游戏内第 1 天 = 活动日历锚点周（2026-08-20 那周）的大活动周期，
///   与现实时间完全解耦（见 `life_sim_engine.dart` 的周期映射）。
/// - 每个活动周期是「活动进行时」：玩家消耗**精力**做出决策累积进度；
///   周期结束（活动结束）时结算成档位奖励，奖励进入**待领取**列表，由玩家点击领取。
/// - 奖励形态：**部件 / 紫票 / 代币**；部件用于组建自己的车，车数值反过来影响活动与城市之王。
/// - 玩家可**组建帮派**或**加入**随机帮派；在帮派中每天开启「城市之王」，与随机帮派 **3v3 逐车对位**。
library;

/// 一辆游戏内车辆。
///
/// 部件一旦获得即视为「解锁蓝图」，可自由重复装配、不消耗；
/// 所有部件按 **满级** 计算（与「极限数值」模块口径一致）。
class SimVehicle {
  String? bodyId;
  String? extraWeaponId;
  final List<String> weaponIds;
  final List<String> wheelIds;
  final List<String> gadgetIds;

  SimVehicle({
    this.bodyId,
    this.extraWeaponId,
    List<String>? weaponIds,
    List<String>? wheelIds,
    List<String>? gadgetIds,
  }) : weaponIds = weaponIds ?? <String>[],
       wheelIds = wheelIds ?? <String>[],
       gadgetIds = gadgetIds ?? <String>[];

  bool get isEmpty => bodyId == null;

  /// 使用的部件 id 总数（用于展示）
  int get partCount =>
      (bodyId == null ? 0 : 1) +
      (extraWeaponId == null ? 0 : 1) +
      weaponIds.length +
      wheelIds.length +
      gadgetIds.length;

  List<String> get allPartIds => <String>[
    ?bodyId,
    ?extraWeaponId,
    ...weaponIds,
    ...wheelIds,
    ...gadgetIds,
  ];

  void clear() {
    bodyId = null;
    extraWeaponId = null;
    weaponIds.clear();
    wheelIds.clear();
    gadgetIds.clear();
  }

  SimVehicle clone() => SimVehicle(
    bodyId: bodyId,
    extraWeaponId: extraWeaponId,
    weaponIds: List<String>.from(weaponIds),
    wheelIds: List<String>.from(wheelIds),
    gadgetIds: List<String>.from(gadgetIds),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (bodyId != null) 'b': bodyId,
    if (extraWeaponId != null) 'x': extraWeaponId,
    if (weaponIds.isNotEmpty) 'w': weaponIds,
    if (wheelIds.isNotEmpty) 'h': wheelIds,
    if (gadgetIds.isNotEmpty) 'g': gadgetIds,
  };

  factory SimVehicle.fromJson(Map<String, dynamic> json) => SimVehicle(
    bodyId: json['b'] as String?,
    extraWeaponId: json['x'] as String?,
    weaponIds: _strList(json['w']),
    wheelIds: _strList(json['h']),
    gadgetIds: _strList(json['g']),
  );
}

List<String> _strList(dynamic v) =>
    v == null ? <String>[] : (v as List).map((e) => e.toString()).toList();

/// 帮派成员（AI 队友；玩家自己不算在内，玩家车辆由存档的 `vehicles` 提供）
class SimGangMember {
  final String name;

  /// 该成员的车辆战力（HP+ATK），最多 3 辆，按从强到弱
  final List<int> carPowers;
  const SimGangMember({
    required this.name,
    required this.carPowers,
  });

  int get totalPower => carPowers.fold(0, (s, v) => s + v);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'n': name,
    'p': carPowers,
  };

  factory SimGangMember.fromJson(Map<String, dynamic> json) => SimGangMember(
    name: json['n'] as String? ?? '',
    carPowers: ((json['p'] as List?) ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
  );
}

/// 帮派实例（库内固定帮派 或 随机生成的帮派）
class GangInstance {
  final String name;

  /// 是否来自固定帮派库（库内帮派带大致排名与固定强弱范围）
  final bool fromLibrary;
  final List<SimGangMember> members;
  final int activity;

  /// 大致排名（库内帮派专用；null = 未知）
  final int? rankHint;

  const GangInstance({
    required this.name,
    required this.fromLibrary,
    required this.members,
    required this.activity,
    this.rankHint,
  });

  int get totalPower => members.fold(0, (s, m) => s + m.totalPower);

  int get memberCount => members.length;
}

/// 一次活动结算产生的奖励包（等待玩家领取）
class RewardBundle {
  final String activityId;
  final String rank;
  final int day;
  final int cash;
  final int token;
  final List<String> partIds;
  bool claimed;

  RewardBundle({
    required this.activityId,
    required this.rank,
    required this.day,
    required this.cash,
    required this.token,
    required this.partIds,
    this.claimed = false,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'a': activityId,
    'r': rank,
    'd': day,
    'c': cash,
    't': token,
    'p': partIds,
    'k': claimed,
  };

  factory RewardBundle.fromJson(Map<String, dynamic> json) => RewardBundle(
    activityId: json['a'] as String? ?? '',
    rank: json['r'] as String? ?? 'D',
    day: (json['d'] as num?)?.toInt() ?? 0,
    cash: (json['c'] as num?)?.toInt() ?? 0,
    token: (json['t'] as num?)?.toInt() ?? 0,
    partIds: _strList(json['p']),
    claimed: json['k'] as bool? ?? false,
  );
}

/// 事件日志条目（中英双份文本，切换语言时无需重算）
class LogEntry {
  final int day;
  final String icon;
  final String kind;
  final String zh;
  final String en;

  const LogEntry({
    required this.day,
    required this.icon,
    required this.kind,
    required this.zh,
    required this.en,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
    'd': day,
    'i': icon,
    'k': kind,
    'z': zh,
    'e': en,
  };

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
    day: (json['d'] as num?)?.toInt() ?? 0,
    icon: json['i'] as String? ?? '•',
    kind: json['k'] as String? ?? 'info',
    zh: json['z'] as String? ?? '',
    en: json['e'] as String? ?? '',
  );
}

/// 游戏存档（全部状态）
class LifeSimSave {
  /// 存档结构版本（后续结构变更时用于迁移）
  static const int schemaVersion = 1;

  /// 游戏内天数（1 起）
  int day;

  /// 当前精力 / 精力上限
  int energy;
  int maxEnergy;

  /// 紫票 / 代币
  int cash;
  int token;

  /// 「钱」：新货币，初始 0，**可以扣至负值**（氪金时消耗）
  int money;

  /// 累计获得（用于成就判定）
  int lifetimeCash;
  int lifetimeToken;

  /// 已解锁部件 id（获得过即可装配）
  final List<String> ownedParts;

  /// 部件碎片库存：partId → 碎片数量
  ///
  /// **碎片 = 重复获得的同名部件**（与游戏一致）；升级部件时消耗。
  final Map<String, int> partStock;

  /// 部件等级：partId → 等级（缺省按 1 级；上限见 `PartData.maxLevel`）
  final Map<String, int> partLevels;

  /// 玩家的车辆（最多 3 辆）
  final List<SimVehicle> vehicles;

  /// 帮派
  String? gangName;
  bool gangOwned;
  int gangActivity;
  final List<SimGangMember> gangMembers;
  int gangRankHint;

  /// 当前活动进度
  int progress;

  /// 本活动周期第一天的「起始天」（用于判断周期切换 → 结算）
  int progressPeriodStart;

  /// 废铁行动：本周期已领取到的奖励节点序号（进度条重置时归零）
  int scrapClaimed;

  /// 废铁行动：本次活动的进度倍率（氪金获得，周期结束时重置为 1）
  int scrapMultiplier;

  /// 最近一次使用「带倍率的决策」的天数
  ///
  /// 齿轮奔袭的决策合计每天只能用 1 次：`limitedChoiceDay == day` 表示今天已用过。
  int limitedChoiceDay;

  /// GP：汽油（每天 +[kGpDailyGasoline] 累积；不可为负）
  int gpGasoline;

  /// GP：旗帜（开局给 [kGpInitialFlags]，**整局只给一次**；不可为负）
  int gpFlags;

  /// GP：本周期累计消耗的汽油（决定汽油乘数加成）
  int gpGasConsumed;

  /// GP：本周期已氪金次数（每次 10 钱 → 分数 +150%）
  int gpTopUpCount;

  /// GP：当天开始时的旗帜数
  ///
  /// 用于实现「旗帜归零则当天禁选」以及
  /// 「当天开始时旗帜就是 0 → 可以救一次低风险」。
  int gpDayStartFlags;

  /// GP：已用掉「起始为 0 的那一次低风险」的天数（-1 = 还没用过）
  int gpFlagsRescueDay;

  /// 本活动周期生效的进度加成
  double activeActivityBonus;

  /// 下个活动周期的进度加成（来自「酒馆情报」等决策）
  double nextActivityBonus;

  /// 待领取奖励
  final List<RewardBundle> pendingRewards;

  /// 城市之王（每天刷新对手）
  String? cityOpponentName;
  List<int> cityOpponentCars;
  int cityOpponentActivity;
  int cityOpponentPower;
  bool cityChallenged;
  int cityWins;
  int cityLosses;

  /// 统计（成就用）
  int totalChoices;
  int rankSCount;
  int rankACount;
  int partsGained;
  int gangsJoined;

  /// 已解锁成就 id
  final List<String> achievements;

  /// 事件日志（最新在前，仅保留最近 [maxLogs] 条）
  final List<LogEntry> logs;

  static const int maxLogs = 300;

  LifeSimSave({
    this.day = 1,
    this.energy = kInitialEnergy,
    this.maxEnergy = kInitialMaxEnergy,
    this.cash = kInitialCash,
    this.token = kInitialToken,
    this.money = kInitialMoney,
    this.lifetimeCash = 0,
    this.lifetimeToken = 0,
    List<String>? ownedParts,
    Map<String, int>? partStock,
    Map<String, int>? partLevels,
    List<SimVehicle>? vehicles,
    this.gangName,
    this.gangOwned = false,
    this.gangActivity = 0,
    List<SimGangMember>? gangMembers,
    this.gangRankHint = 0,
    this.progress = 0,
    this.progressPeriodStart = 1,
    this.scrapClaimed = 0,
    this.scrapMultiplier = 1,
    this.limitedChoiceDay = 0,
    this.gpGasoline = 0,
    this.gpFlags = kGpInitialFlags,
    this.gpGasConsumed = 0,
    this.gpTopUpCount = 0,
    this.gpDayStartFlags = kGpInitialFlags,
    this.gpFlagsRescueDay = -1,
    this.activeActivityBonus = 0,
    this.nextActivityBonus = 0,
    List<RewardBundle>? pendingRewards,
    this.cityOpponentName,
    List<int>? cityOpponentCars,
    this.cityOpponentActivity = 0,
    this.cityOpponentPower = 0,
    this.cityChallenged = false,
    this.cityWins = 0,
    this.cityLosses = 0,
    this.totalChoices = 0,
    this.rankSCount = 0,
    this.rankACount = 0,
    this.partsGained = 0,
    this.gangsJoined = 0,
    List<String>? achievements,
    List<LogEntry>? logs,
  }) : ownedParts = ownedParts ?? <String>[],
       partStock = partStock ?? <String, int>{},
       partLevels = partLevels ?? <String, int>{},
       vehicles =
           vehicles ??
           List<SimVehicle>.generate(maxVehicles, (_) => SimVehicle()),
       gangMembers = gangMembers ?? <SimGangMember>[],
       pendingRewards = pendingRewards ?? <RewardBundle>[],
       cityOpponentCars = cityOpponentCars ?? <int>[],
       achievements = achievements ?? <String>[],
       logs = logs ?? <LogEntry>[];

  /// 可拥有的车辆上限
  static const int maxVehicles = 3;

  /// 初始精力上限 / 初始精力
  static const int kInitialMaxEnergy = 20;
  static const int kInitialEnergy = 20;

  /// 初始紫票 / 代币 / 钱
  static const int kInitialCash = 10000;
  static const int kInitialToken = 0;
  static const int kInitialMoney = 0;

  /// 每天恢复的精力
  static const int kDailyEnergy = 12;

  /// GP：开局给的旗帜（**整局只给一次**，之后不再补）
  static const int kGpInitialFlags = 10000;

  /// 在帮派中
  bool get inGang => gangName != null && gangName!.isNotEmpty;

  /// 已组装的车辆数（有车身即算一辆）
  int get builtVehicleCount => vehicles.where((v) => !v.isEmpty).length;

  /// 待领取奖励数量
  int get unclaimedCount => pendingRewards.where((r) => !r.claimed).length;

  /// 已解锁的部件 id（过滤掉已失效的旧数据）
  List<String> get ownedPartIds => List<String>.unmodifiable(ownedParts);

  /// 某个部件的碎片库存
  int stockOf(String partId) => partStock[partId] ?? 0;

  /// 某个部件的等级（缺省 1 级）
  int levelOf(String partId) => partLevels[partId] ?? 1;

  /// 发放部件：首次获得即解锁，重复获得累积为碎片
  ///
  /// 返回：partId → 本次获得的个数（保持传入顺序）
  Map<String, int> grantParts(List<String> partIds) {
    final gained = <String, int>{};
    for (final id in partIds) {
      if (id.isEmpty) continue;
      if (!ownedParts.contains(id)) ownedParts.add(id);
      partStock[id] = stockOf(id) + 1;
      gained[id] = (gained[id] ?? 0) + 1;
    }
    return gained;
  }

  /// 直接设置碎片库存（默认值用）
  void setStock(String partId, int count) {
    if (count > 0 && !ownedParts.contains(partId)) ownedParts.add(partId);
    partStock[partId] = count;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'v': schemaVersion,
    'day': day,
    'energy': energy,
    'maxEnergy': maxEnergy,
    'cash': cash,
    'token': token,
    'money': money,
    'lc': lifetimeCash,
    'lt': lifetimeToken,
    'owned': ownedParts,
    'stock': partStock,
    'lv': partLevels,
    'veh': [for (final v in vehicles) v.toJson()],
    'gang': gangName,
    'gangOwned': gangOwned,
    'gangAct': gangActivity,
    'gangMem': [for (final m in gangMembers) m.toJson()],
    'gangRank': gangRankHint,
    'prog': progress,
    'progStart': progressPeriodStart,
    'scrap': scrapClaimed,
    'scrapMul': scrapMultiplier,
    'lcd': limitedChoiceDay,
    'gpGas': gpGasoline,
    'gpFlag': gpFlags,
    'gpGasUsed': gpGasConsumed,
    'gpTop': gpTopUpCount,
    'gpDayFlag': gpDayStartFlags,
    'gpRescue': gpFlagsRescueDay,
    'actBonus': activeActivityBonus,
    'nextBonus': nextActivityBonus,
    'pending': [for (final r in pendingRewards) r.toJson()],
    'cName': cityOpponentName,
    'cCars': cityOpponentCars,
    'cAct': cityOpponentActivity,
    'cPower': cityOpponentPower,
    'cDone': cityChallenged,
    'cWin': cityWins,
    'cLose': cityLosses,
    'choices': totalChoices,
    'sCount': rankSCount,
    'aCount': rankACount,
    'parts': partsGained,
    'gangs': gangsJoined,
    'achv': achievements,
    'logs': [for (final l in logs) l.toJson()],
  };

  factory LifeSimSave.fromJson(Map<String, dynamic> json) {
    final rawVehicles = (json['veh'] as List?) ?? const [];
    final vehicles = <SimVehicle>[];
    for (var i = 0; i < maxVehicles; i++) {
      if (i < rawVehicles.length && rawVehicles[i] is Map) {
        vehicles.add(
          SimVehicle.fromJson(
            (rawVehicles[i] as Map).cast<String, dynamic>(),
          ),
        );
      } else {
        vehicles.add(SimVehicle());
      }
    }
    return LifeSimSave(
      day: (json['day'] as num?)?.toInt() ?? 1,
      energy: (json['energy'] as num?)?.toInt() ?? kInitialEnergy,
      maxEnergy: (json['maxEnergy'] as num?)?.toInt() ?? kInitialMaxEnergy,
      cash: (json['cash'] as num?)?.toInt() ?? 0,
      token: (json['token'] as num?)?.toInt() ?? 0,
      money: (json['money'] as num?)?.toInt() ?? 0,
      lifetimeCash: (json['lc'] as num?)?.toInt() ?? 0,
      lifetimeToken: (json['lt'] as num?)?.toInt() ?? 0,
      ownedParts: _strList(json['owned']),
      partStock: _intMap(json['stock']),
      partLevels: _intMap(json['lv']),
      vehicles: vehicles,
      gangName: json['gang'] as String?,
      gangOwned: json['gangOwned'] as bool? ?? false,
      gangActivity: (json['gangAct'] as num?)?.toInt() ?? 0,
      gangMembers: ((json['gangMem'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => SimGangMember.fromJson(m.cast<String, dynamic>()))
          .toList(),
      gangRankHint: (json['gangRank'] as num?)?.toInt() ?? 0,
      progress: (json['prog'] as num?)?.toInt() ?? 0,
      progressPeriodStart: (json['progStart'] as num?)?.toInt() ?? 1,
      scrapClaimed: (json['scrap'] as num?)?.toInt() ?? 0,
      scrapMultiplier: (json['scrapMul'] as num?)?.toInt() ?? 1,
      limitedChoiceDay: (json['lcd'] as num?)?.toInt() ?? 0,
      gpGasoline: (json['gpGas'] as num?)?.toInt() ?? 0,
      gpFlags: (json['gpFlag'] as num?)?.toInt() ?? kGpInitialFlags,
      gpGasConsumed: (json['gpGasUsed'] as num?)?.toInt() ?? 0,
      gpTopUpCount: (json['gpTop'] as num?)?.toInt() ?? 0,
      gpDayStartFlags:
          (json['gpDayFlag'] as num?)?.toInt() ??
          (json['gpFlag'] as num?)?.toInt() ??
          kGpInitialFlags,
      gpFlagsRescueDay: (json['gpRescue'] as num?)?.toInt() ?? -1,
      activeActivityBonus: (json['actBonus'] as num?)?.toDouble() ?? 0,
      nextActivityBonus: (json['nextBonus'] as num?)?.toDouble() ?? 0,
      pendingRewards: ((json['pending'] as List?) ?? const [])
          .whereType<Map>()
          .map((r) => RewardBundle.fromJson(r.cast<String, dynamic>()))
          .toList(),
      cityOpponentName: json['cName'] as String?,
      cityOpponentCars: ((json['cCars'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      cityOpponentActivity: (json['cAct'] as num?)?.toInt() ?? 0,
      cityOpponentPower: (json['cPower'] as num?)?.toInt() ?? 0,
      cityChallenged: json['cDone'] as bool? ?? false,
      cityWins: (json['cWin'] as num?)?.toInt() ?? 0,
      cityLosses: (json['cLose'] as num?)?.toInt() ?? 0,
      totalChoices: (json['choices'] as num?)?.toInt() ?? 0,
      rankSCount: (json['sCount'] as num?)?.toInt() ?? 0,
      rankACount: (json['aCount'] as num?)?.toInt() ?? 0,
      partsGained: (json['parts'] as num?)?.toInt() ?? 0,
      gangsJoined: (json['gangs'] as num?)?.toInt() ?? 0,
      achievements: _strList(json['achv']),
      logs: ((json['logs'] as List?) ?? const [])
          .whereType<Map>()
          .map((l) => LogEntry.fromJson(l.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// 解析 `{String: int}` 形式的 JSON 字段
Map<String, int> _intMap(dynamic v) {
  if (v is! Map) return <String, int>{};
  final out = <String, int>{};
  v.forEach((k, value) {
    if (value is num) out[k.toString()] = value.toInt();
  });
  return out;
}
