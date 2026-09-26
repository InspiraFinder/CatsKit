/// 「猫生重开」模拟器（CatsKit 2.0） —— 规则引擎
///
/// **纯逻辑，无 Widget 依赖**（可单测）。所有随机通过注入的 [Random] 产生，
/// 因此测试里给固定种子即可复现。
///
/// ## 时间模型
/// - 以「天」计数，第 1 天 = 活动日历锚点周（2026-08-20 那周）的**大活动**周期，
///   与现实时间完全解耦。
/// - 每 7 天为一个「周」，前 4 天 = 大活动（4 天周期），后 3 天 = 小活动（3 天周期），
///   活动 id 直接取自 `ActivityCalendar`（国服 / 国际服各自的轮换顺序）。
/// - 活动周期结束 → 结算成档位奖励 → 进入**待领取**列表，玩家点击领取后入账。
///
/// ## 每日循环
/// 玩家在活动周期内消耗**精力**做决策累积进度；「结束这一天」会恢复精力、
/// 推进天数、跨周期时结算活动、并刷新当天「城市之王」的对手。
library;

import 'dart:math';

import '../activity_calendar_screen.dart';
import '../main.dart' show CarValidation;
import '../parts_data.dart';
import 'life_sim_data.dart';
import 'life_sim_models.dart';

/// 活动周期
class SimPeriod {
  final int startDay;
  final int endDay;
  final bool isMajor;
  final int weekIndex;
  final String activityId;

  const SimPeriod({
    required this.startDay,
    required this.endDay,
    required this.isMajor,
    required this.weekIndex,
    required this.activityId,
  });

  int get lengthDays => endDay - startDay + 1;

  /// 第 [day] 天是本周期的第几天（1 起）
  int dayInPeriod(int day) => day - startDay + 1;
}

/// 活动决策的结果
class ChoiceOutcome {
  final bool ok;
  final String errorZh;
  final String errorEn;
  final int progress;
  final bool backfired;
  final bool wildCard;
  final double effectiveCoef;
  final int cash;
  final int token;

  /// 废铁行动：本次达成并已发放的奖励节点
  final List<ScrapNode> scrapNodes;

  /// GP：本次决策的旗帜变动（可为负；已按「不可为负」截断到实际值）
  final int flagDelta;

  /// GP：决策后剩余的旗帜
  final int gpFlags;

  /// GP：本次决策的实际分数乘数（1.0 起）
  final double gpMultiplier;

  const ChoiceOutcome({
    required this.ok,
    this.errorZh = '',
    this.errorEn = '',
    this.progress = 0,
    this.backfired = false,
    this.wildCard = false,
    this.effectiveCoef = 0,
    this.cash = 0,
    this.token = 0,
    this.scrapNodes = const <ScrapNode>[],
    this.flagDelta = 0,
    this.gpFlags = 0,
    this.gpMultiplier = 1,
  });
}

/// 「结束这一天」的结果
class EndDayResult {
  final int newDay;

  /// 本次跨周期结算出的奖励（未领取）
  final RewardBundle? settledPeriod;

  /// 结算的活动 id（无结算时为 null）
  final String? settledActivityId;

  /// 结算出的档位
  final String? settledRank;

  final List<Achievement> newAchievements;

  const EndDayResult({
    required this.newDay,
    this.settledPeriod,
    this.settledActivityId,
    this.settledRank,
    this.newAchievements = const <Achievement>[],
  });
}

/// 「城市之王」对战结果（3v3 逐车对位）
class CityKingResult {
  final bool ok;
  final String errorZh;
  final String errorEn;

  /// 胜负（[draw] 为 true 时 [won] 恒为 false）
  final bool won;
  final bool draw;

  /// 每轮：我方 / 对方战力，以及本轮结果（true=我方胜，false=对方胜，null=平局）
  final List<int> myCars;
  final List<int> oppCars;
  final List<bool?> rounds;

  final String opponentName;

  /// 奖励
  final int cash;
  final int token;
  final List<String> parts;

  /// 帮派活跃度提升
  final int activityGained;

  /// 本赛季分场次结算分数：本次基础分、本次倍率、本次实际得分
  final int baseScore;
  final int scoreMultiplier;
  final int scoreGained;

  /// 双方强度（帮派车辆大小 × 活跃度加成）与本场胜 / 败基础分
  final int myStrength;
  final int oppStrength;
  final int winScore;
  final int lossScore;

  /// 打完这场后的本赛季累计胜场 / 赛季分数
  final int seasonWins;
  final int seasonScore;

  /// 本次跨过的胜场里程碑发放的宝箱部件与代币
  final List<String> chestParts;
  final int chestToken;

  /// 本次胜利额外掉落的工具箱（25 胜之后每胜一场给一个）
  final int hpToolboxGained;
  final int atkToolboxGained;

  const CityKingResult({
    required this.ok,
    this.errorZh = '',
    this.errorEn = '',
    this.won = false,
    this.draw = false,
    this.myCars = const <int>[],
    this.oppCars = const <int>[],
    this.rounds = const <bool?>[],
    this.opponentName = '',
    this.cash = 0,
    this.token = 0,
    this.parts = const <String>[],
    this.activityGained = 0,
    this.baseScore = 0,
    this.scoreMultiplier = 1,
    this.scoreGained = 0,
    this.myStrength = 0,
    this.oppStrength = 0,
    this.winScore = 0,
    this.lossScore = 0,
    this.seasonWins = 0,
    this.seasonScore = 0,
    this.chestParts = const <String>[],
    this.chestToken = 0,
    this.hpToolboxGained = 0,
    this.atkToolboxGained = 0,
  });

  int get myWins => rounds.where((r) => r == true).length;
  int get oppWins => rounds.where((r) => r == false).length;
  int get draws => rounds.where((r) => r == null).length;
}

class LifeSimEngine {
  LifeSimEngine({this.server = 'cn', Random? random})
    : _rng = random ?? Random();

  /// 'cn' | 'intl'
  final String server;
  final Random _rng;

  /// 城市之王：发起挑战消耗的精力
  static const int kCityEnergyCost = 2;

  /// 组建帮派消耗的紫票
  static const int kFoundGangCashCost = 500;

  /// 招募一名成员的基础消耗
  static const int kRecruitCashBase = 200;
  static const int kRecruitCashStep = 80;
  static const int kRecruitEnergyCost = 3;

  // ===================================================================
  // 部件索引 / 车辆数值
  // ===================================================================

  static final Map<String, Map<String, PartData>> _partIndexCache =
      <String, Map<String, PartData>>{};

  /// 当前服务器部件表（id → PartData）
  Map<String, PartData> get partIndex => _partIndexCache.putIfAbsent(
    server,
    () => <String, PartData>{
      for (final p in PartDatabase.partsForServer(server)) p.id: p,
    },
  );

  /// 计算一辆车的数值（复用组车工具的公式；部件按 [partLevels] 中的等级，
  /// 缺省 1 级）
  ///
  /// [hpBoxes] / [atkBoxes] 是「生命/攻击工具箱」在每个部件上叠的层数
  /// （每层 +[kToolboxBonusPct]%，独立乘区）。
  CarValidation evaluate(
    SimVehicle sv, [
    Map<String, int>? partLevels,
    Map<String, int>? hpBoxes,
    Map<String, int>? atkBoxes,
  ]) {
    final idx = partIndex;
    PartData? look(String? id) => id == null ? null : idx[id];
    final body = look(sv.bodyId);
    final extra = look(sv.extraWeaponId);
    final weapons = <PartData>[
      for (final id in sv.weaponIds)
        if (idx[id] != null) idx[id]!,
    ];
    final wheels = <PartData>[
      for (final id in sv.wheelIds)
        if (idx[id] != null) idx[id]!,
    ];
    final gadgets = <PartData>[
      for (final id in sv.gadgetIds)
        if (idx[id] != null) idx[id]!,
    ];
    final levels = <String, int>{};
    for (final p in <PartData?>[body, extra, ...weapons, ...wheels, ...gadgets]) {
      if (p == null) continue;
      // 与组车工具一致：等级限制在 1 ~ maxLevel
      final lv = partLevels?[p.id] ?? 1;
      levels[p.id] = lv.clamp(1, p.maxLevel);
    }
    return CarValidation.compute(
      body,
      weapons,
      wheels,
      gadgets,
      extra,
      levels,
      const <String, int>{},
      hpBoxPct: boxPct(hpBoxes),
      atkBoxPct: boxPct(atkBoxes),
    );
  }

  /// 工具箱层数 → 加成百分比（层数 × [kToolboxBonusPct]）
  static Map<String, int> boxPct(Map<String, int>? boxes) {
    if (boxes == null || boxes.isEmpty) return const <String, int>{};
    return <String, int>{
      for (final e in boxes.entries)
        if (e.value > 0) e.key: e.value * kToolboxBonusPct,
    };
  }

  /// 单辆车的战力（HP+ATK，未组车返回 0）
  int vehiclePower(
    SimVehicle sv, [
    Map<String, int>? partLevels,
    Map<String, int>? hpBoxes,
    Map<String, int>? atkBoxes,
  ]) {
    if (sv.isEmpty) return 0;
    final v = evaluate(sv, partLevels, hpBoxes, atkBoxes);
    return (v.hp + v.atk).round();
  }

  /// 每辆车的战力列表（含未组装的 0；含工具箱加成）
  List<int> vehiclePowers(LifeSimSave save) => [
    for (final v in save.vehicles)
      vehiclePower(v, save.partLevels, save.partHpBoxes, save.partAtkBoxes),
  ];

  /// 车队中**单车最高战力**（齿轮奔袭按此判定；未组车返回 0）
  int maxVehiclePower(LifeSimSave save) {
    var best = 0;
    for (final p in vehiclePowers(save)) {
      if (p > best) best = p;
    }
    return best;
  }

  /// 其他车辆已使用的部件 id
  ///
  /// **三辆车的部件不能重复**：装配/自动配车时都要排除这些部件。
  Set<String> partsUsedByOtherCars(LifeSimSave save, int vehicleIndex) {
    final used = <String>{};
    for (var i = 0; i < save.vehicles.length; i++) {
      if (i == vehicleIndex) continue;
      used.addAll(save.vehicles[i].allPartIds);
    }
    return used;
  }

  /// 某个部件是否已被其他车辆占用
  bool isPartUsedByOtherCar(
    LifeSimSave save,
    int vehicleIndex,
    String partId,
  ) => partsUsedByOtherCars(save, vehicleIndex).contains(partId);

  /// 某辆车可用的部件（已解锁且未被其他车辆占用）
  List<PartData> availableParts(
    LifeSimSave save,
    int vehicleIndex, {
    PartCategory? category,
  }) {
    final blocked = partsUsedByOtherCars(save, vehicleIndex);
    return <PartData>[
      for (final id in save.ownedParts)
        if (partIndex[id] != null &&
            !blocked.contains(id) &&
            (category == null || partIndex[id]!.category == category))
          partIndex[id]!,
    ];
  }

  /// 某辆车上装配的部件是否与其他车辆重复（重复返回 true）
  bool hasDuplicateParts(LifeSimSave save, int vehicleIndex) {
    final blocked = partsUsedByOtherCars(save, vehicleIndex);
    return save.vehicles[vehicleIndex].allPartIds.any(blocked.contains);
  }

  /// 找出被多辆车同时使用的部件：partId → 车辆序号列表
  ///
  /// 用于兼容旧存档（改规则之前配的车可能已经重复）。
  Map<String, List<int>> findDuplicateParts(LifeSimSave save) {
    final map = <String, List<int>>{};
    for (var i = 0; i < save.vehicles.length; i++) {
      for (final id in save.vehicles[i].allPartIds) {
        map.putIfAbsent(id, () => <int>[]).add(i);
      }
    }
    map.removeWhere((_, cars) => cars.length <= 1);
    return map;
  }

  /// 清理重复部件：每个重复部件只保留在「单车战力最高」的那辆车上，
  /// 其余车辆移除该部件；返回被移除的部件引用数。
  int removeDuplicateParts(LifeSimSave save) {
    final dup = findDuplicateParts(save);
    if (dup.isEmpty) return 0;
    var removed = 0;
    for (final entry in dup.entries) {
      final cars = entry.value;
      var keep = cars.first;
      var bestPower = -1;
      for (final i in cars) {
        final p = vehiclePower(save.vehicles[i], save.partLevels);
        if (p > bestPower) {
          bestPower = p;
          keep = i;
        }
      }
      for (final i in cars) {
        if (i == keep) continue;
        final v = save.vehicles[i];
        if (v.bodyId == entry.key) {
          // 换车身会牵动插槽，直接清空这辆车（部件会随之释放）
          removed += v.partCount;
          v.clear();
          continue;
        }
        if (v.extraWeaponId == entry.key) {
          v.extraWeaponId = null;
          removed++;
        }
        if (v.weaponIds.remove(entry.key)) removed++;
        if (v.wheelIds.remove(entry.key)) removed++;
        if (v.gadgetIds.remove(entry.key)) removed++;
      }
    }
    if (removed > 0) {
      _log(
        save,
        '🧹',
        'garage',
        '清理了重复部件：移除 $removed 个（同一部件只能装一辆车）',
        'Removed $removed duplicated part(s) (a part can only be on one car)',
      );
    }
    return removed;
  }

  /// 车队总战力
  int fleetPower(LifeSimSave save) =>
      vehiclePowers(save).fold(0, (a, b) => a + b);

  /// 进度用「战力分」= 车队总战力 / 1000
  int powerScore(LifeSimSave save) => fleetPower(save) ~/ 1000;

  /// 帮派活跃度对战力/进度的加成倍率（活跃 100 → ×1.5）
  static double activityMultiplier(int activity) => 1 + activity / 200.0;

  // ===================================================================
  // 时间 / 周期
  // ===================================================================

  /// 第 [day] 天所在活动周期的第一天
  static int periodStartDay(int day) {
    final zero = day - 1;
    if (zero < 0) return 1;
    final week = zero ~/ 7;
    return zero % 7 < 4 ? week * 7 + 1 : week * 7 + 5;
  }

  /// 该周期是否为「大活动」（4 天）
  static bool isMajorPeriodStart(int startDay) =>
      ((startDay - 1) % 7) < 4;

  /// 按周期第一天构造周期信息
  SimPeriod periodOf(int startDay) {
    final week = (startDay - 1) ~/ 7;
    final isMajor = isMajorPeriodStart(startDay);
    return SimPeriod(
      startDay: startDay,
      endDay: isMajor ? week * 7 + 4 : week * 7 + 7,
      isMajor: isMajor,
      weekIndex: week,
      activityId: isMajor ? _majorActivity(week) : _minorActivity(week),
    );
  }

  /// 第 [day] 天所在的周期
  SimPeriod periodForDay(int day) => periodOf(periodStartDay(day));

  String _majorActivity(int week) =>
      ActivityCalendar.activityForWeek(server, week);

  String _minorActivity(int week) {
    final seq = server == 'cn'
        ? ActivityCalendar.cnShortSequence
        : ActivityCalendar.intlShortSequence;
    if (seq.isEmpty) return 'champ';
    final i = week % seq.length;
    return seq[i < 0 ? i + seq.length : i];
  }

  /// 活动显示名（按语言）
  static String activityName(String activityId, String locale) {
    final info = kActivities[activityId];
    if (info == null) return activityId;
    return locale == 'zh' ? info.nameZh : info.nameEn;
  }

  /// 活动图标资源
  static String activityIcon(String activityId) =>
      kActivities[activityId]?.iconAsset ?? '';

  /// 档位线（大活动 / 小活动）
  static List<RankTier> tiersFor(bool isMajor) =>
      isMajor ? kMajorTiers : kMinorTiers;

  /// 进度分 → 档位
  static String rankFor(int progress, bool isMajor) {
    for (final t in tiersFor(isMajor)) {
      if (progress >= t.min) return t.rank;
    }
    return 'D';
  }

  // ===================================================================
  // 新存档
  // ===================================================================

  /// 创建新存档：
  /// 1. 第 1 天弹出欢迎语（日志第一条）；
  /// 2. 发放「启程宝箱」：15 个部件（车身 3 / 武器 3 / 配件 3 / 车轮 6），
  ///    稀有度以 R2 为主，并**保底 1 个 R6**；
  /// 3. 用这些部件自动配好第 1 辆车。
  LifeSimSave newSave() {
    final ids = _rollStarterParts();
    final save = LifeSimSave(progressPeriodStart: 1);

    _log(save, '🐱', 'system', kWelcomeZh, kWelcomeEn);
    _log(
      save,
      '🎁',
      'reward',
      '开启启程宝箱，获得 $kStarterPartTotal 个部件',
      'Opened the Starter Chest: $kStarterPartTotal parts',
    );
    grantParts(save, ids);
    autoBuild(save, 0);
    _log(
      save,
      '🚗',
      'garage',
      '已用现有部件自动配好第 1 辆车',
      'Your first car was auto-built from your parts',
    );
    save.cityOpponentName = '——';
    _syncGpDay(save);
    return save;
  }

  /// 发放部件并写日志：首次获得即解锁，重复获得累积为碎片
  ///
  /// 日志格式（每个部件一行）：
  /// `获得车身：甲壳虫[R2] 3个 库存/升级：3/1`
  /// - 库存 = 当前持有的碎片数量
  /// - 升级 = 升到下一级需要的碎片数量（满级显示「满级」）
  Map<String, int> grantParts(LifeSimSave save, List<String> partIds) {
    final gained = save.grantParts(partIds);
    // 按 分类 → 部件 顺序输出，便于阅读
    const order = <PartCategory>[
      PartCategory.body,
      PartCategory.weapon,
      PartCategory.gadget,
      PartCategory.wheel,
    ];
    final entries = gained.entries
        .where((e) => partIndex[e.key] != null)
        .toList();
    for (final c in order) {
      for (final e in entries) {
        if (partIndex[e.key]!.category != c) continue;
        final p = partIndex[e.key]!;
        final stock = save.stockOf(e.key);
        final level = save.levelOf(e.key);
        final need = upgradePieceCost(p, level);
        final needZh = need?.toString() ?? '满级';
        final needEn = need?.toString() ?? 'MAX';
        final zh = _catZh[c] ?? '';
        final en = _catEn[c] ?? '';
        _log(
          save,
          '🎒',
          'reward',
          '获得$zh：${_partLabel(e.key, true)} ${e.value}个 '
              '库存/升级：$stock/$needZh',
          'Gained $en: ${_partLabel(e.key, false)} ×${e.value} '
              'Stock/Upg: $stock/$needEn',
        );
      }
    }
    return gained;
  }

  /// 从 [level] 升到下一级需要的碎片数（满级返回 null）
  static int? upgradePieceCost(PartData p, int level) {
    if (level >= p.maxLevel) return null;
    final table = upgradeCosts[p.rarity];
    if (table == null || level + 1 >= table.length) return null;
    return table[level + 1].pieces;
  }

  /// 从 [level] 升到下一级的完整消耗（满级返回 null）
  static UpgradeCostEntry? upgradeCost(PartData p, int level) {
    if (level >= p.maxLevel) return null;
    final table = upgradeCosts[p.rarity];
    if (table == null || level + 1 >= table.length) return null;
    return table[level + 1];
  }

  /// 随机抽取 15 个开局部件（含 1 个 R6 保底）
  List<String> _rollStarterParts() {
    final slots = <PartCategory>[
      ...List<PartCategory>.filled(kStarterBodyCount, PartCategory.body),
      ...List<PartCategory>.filled(kStarterWeaponCount, PartCategory.weapon),
      ...List<PartCategory>.filled(kStarterGadgetCount, PartCategory.gadget),
      ...List<PartCategory>.filled(kStarterWheelCount, PartCategory.wheel),
    ];
    final used = <String>{};
    final ids = <String>[];
    for (final c in slots) {
      final id = _rollPartOfCategory(c, used);
      if (id.isNotEmpty) {
        used.add(id);
        ids.add(id);
      }
    }
    // 保底 1 个 R6：没有抽到就把一个随机槽位替换为同分类的 R6
    final hasR6 = ids.any((id) => partIndex[id]?.rarity == Rarity.r6);
    if (!hasR6 && ids.isNotEmpty) {
      final guaranteed = Rarity.values[kStarterGuaranteedRarityIndex];
      final order = List<int>.generate(ids.length, (i) => i)..shuffle(_rng);
      for (final i in order) {
        final id = _rollPartOfCategory(
          slots[i],
          used,
          rarity: guaranteed,
        );
        if (id.isNotEmpty) {
          used.remove(ids[i]);
          ids[i] = id;
          break;
        }
      }
    }
    return ids;
  }

  /// 按开局的稀有度权重抽一个指定分类的部件
  String _rollPartOfCategory(
    PartCategory category,
    Set<String> used, {
    Rarity? rarity,
  }) {
    final pool = PartDatabase.partsForServer(server)
        .where(
          (p) => p.category == category && (rarity == null || p.rarity == rarity),
        )
        .toList();
    if (pool.isEmpty) return '';
    if (rarity != null) {
      // 保底：优先给还没拥有的同稀有度部件
      final fresh = pool.where((p) => !used.contains(p.id)).toList();
      final from = fresh.isEmpty ? pool : fresh;
      return from[_rng.nextInt(from.length)].id;
    }
    // 按权重抽稀有度，再在该稀有度内随机挑一个未使用的
    final weights = kStarterRarityWeights;
    for (var attempt = 0; attempt < 12; attempt++) {
      final total = weights.fold(0, (a, b) => a + b);
      var roll = _rng.nextInt(total);
      var index = 0;
      for (var i = 0; i < weights.length; i++) {
        roll -= weights[i];
        if (roll < 0) {
          index = i;
          break;
        }
      }
      final target = Rarity.values[index.clamp(0, Rarity.values.length - 1)];
      final candidates = pool.where((p) => p.rarity == target).toList();
      if (candidates.isEmpty) continue;
      candidates.shuffle(_rng);
      for (final p in candidates) {
        if (!used.contains(p.id)) return p.id;
      }
    }
    return pool[_rng.nextInt(pool.length)].id;
  }

  // ===================================================================
  // 自动配车（贪心）
  // ===================================================================

  /// 用已解锁的最强部件自动配好第 [index] 辆车（按部件当前等级计算）
  ///
  /// **不会使用其他车辆已装配的部件**（三辆车的部件不能重复）。
  void autoBuild(LifeSimSave save, int index) {
    if (index < 0 || index >= save.vehicles.length) return;
    final idx = partIndex;
    final blocked = partsUsedByOtherCars(save, index);
    final owned = <PartData>[
      for (final id in save.ownedParts)
        if (idx[id] != null && !blocked.contains(id)) idx[id]!,
    ];
    // 部件实际数值随等级变化，排序也必须用等级后的值
    double hpOf(PartData p) => p.hp(save.levelOf(p.id).clamp(1, p.maxLevel));

    final bodies = owned
        .where((p) => p.category == PartCategory.body)
        .toList()
      ..sort((a, b) => hpOf(b).compareTo(hpOf(a)));
    if (bodies.isEmpty) return;

    SimVehicle? best;
    double bestPower = -1;
    for (final body in bodies) {
      final cand = _greedyFill(save, body, owned);
      final v = evaluate(cand, save.partLevels);
      if (!v.ok) continue;
      final total = v.hp + v.atk;
      if (total > bestPower) {
        bestPower = total;
        best = cand;
      }
    }
    if (best == null) return;
    final sv = save.vehicles[index];
    sv.bodyId = best.bodyId;
    sv.extraWeaponId = best.extraWeaponId;
    sv.weaponIds
      ..clear()
      ..addAll(best.weaponIds);
    sv.wheelIds
      ..clear()
      ..addAll(best.wheelIds);
    sv.gadgetIds
      ..clear()
      ..addAll(best.gadgetIds);
  }

  SimVehicle _greedyFill(
    LifeSimSave save,
    PartData body,
    List<PartData> owned,
  ) {
    final slots = body.slots;
    final sv = SimVehicle(bodyId: body.id);
    if (slots == null) return sv;

    double hpOf(PartData p) => p.hp(save.levelOf(p.id).clamp(1, p.maxLevel));
    double atkOf(PartData p) => p.atk(save.levelOf(p.id).clamp(1, p.maxLevel));

    final weapons = owned.where((p) => p.category == PartCategory.weapon).toList()
      ..sort((a, b) => atkOf(b).compareTo(atkOf(a)));
    final wheels = owned.where((p) => p.category == PartCategory.wheel).toList()
      ..sort(
        (a, b) => (hpOf(b) + atkOf(b)).compareTo(hpOf(a) + atkOf(a)),
      );
    final gadgets = owned.where((p) => p.category == PartCategory.gadget).toList()
      ..sort((a, b) => hpOf(b).compareTo(hpOf(a)));

    sv.wheelIds.addAll(wheels.take(slots.wheel).map((p) => p.id));
    sv.gadgetIds.addAll(gadgets.take(slots.gadget).map((p) => p.id));

    int supply = body.power > 0 ? body.power : 0;
    for (final id in sv.wheelIds) {
      final p = partIndex[id]!;
      if (p.power > 0) supply += p.power;
    }
    for (final id in sv.gadgetIds) {
      final p = partIndex[id]!;
      if (p.power > 0) supply += p.power;
    }
    // 车轮 / 配件的负电力先计入消耗
    int consumption = 0;
    for (final id in <String>[...sv.wheelIds, ...sv.gadgetIds]) {
      final p = partIndex[id]!;
      if (p.power < 0) consumption += -p.power;
    }

    // 武器：ATK 从高到低，电力允许就装
    for (final w in weapons) {
      if (sv.weaponIds.length >= slots.weapon) break;
      final need = w.power < 0 ? -w.power : 0;
      if (consumption + need <= supply) {
        sv.weaponIds.add(w.id);
        consumption += need;
      }
    }

    // 额外武器（不占普通槽、不耗电）：取未使用的最高 ATK 武器
    for (final w in weapons) {
      if (!sv.weaponIds.contains(w.id)) {
        sv.extraWeaponId = w.id;
        break;
      }
    }
    return sv;
  }

  // ===================================================================
  // 活动决策
  // ===================================================================

  /// 本期「只能看广告」的活动（没有任何决策选项）
  ///
  /// 太空 / 酒馆 / 王牌暂时只保留看广告（紫票）；以后要恢复它们的决策时，
  /// 从这个集合里删掉即可（[kCommonChoices] / [kSignatureChoices] 都还留着）。
  static const Set<String> kAdOnlyActivities = <String>{
    kChampActivityId,
    'space',
    'tavern',
    'joker',
  };

  /// 该活动本期是否只能看广告（没有决策选项）
  static bool isAdOnlyActivity(String activityId) =>
      kAdOnlyActivities.contains(activityId);

  /// 当前周期可用的决策列表
  ///
  /// - 废铁行动 / 齿轮奔袭 / 全明星：同一套四档「浅尝辄止…」
  /// - GP：三档「高/中/低风险」
  /// - 24h锦标赛+黑市 / 太空 / 酒馆 / 王牌：本期不设决策，只能看广告换紫票
  /// - 其他活动：通用 3 个 + 专属 1 个
  List<ActivityChoice> choicesFor(String activityId) {
    if (activityId == 'scrap') return kScrapChoices;
    if (activityId == 'gear') return kGearChoices;
    if (activityId == 'allstar') return kAllStarChoices;
    if (activityId == 'gp') return kGpChoices;
    if (isAdOnlyActivity(activityId)) return const <ActivityChoice>[];
    return <ActivityChoice>[
      ...kCommonChoices,
      if (kSignatureChoices[activityId] != null) kSignatureChoices[activityId]!,
    ];
  }

  /// 做出一次活动决策
  ChoiceOutcome makeChoice(LifeSimSave save, ActivityChoice choice) {
    final period0 = periodForDay(save.day);
    // GP 是独立玩法（两种专用代币 + 旗帜禁选规则）
    if (isGpActivity(period0.activityId)) {
      return _makeGpChoice(save, choice);
    }
    if (save.energy < choice.energyCost) {
      return const ChoiceOutcome(
        ok: false,
        errorZh: '精力不足',
        errorEn: 'Not enough energy',
      );
    }
    final period = periodForDay(save.day);
    // 带倍率的决策（齿轮奔袭四档）合计每天只能用一次
    if (isDailyLimitedChoice(period.activityId) &&
        save.limitedChoiceDay == save.day) {
      return const ChoiceOutcome(
        ok: false,
        errorZh: '今天已经用过带倍率的决策了（每天 1 次）',
        errorEn: 'You already used a multiplier choice today (once per day)',
      );
    }
    save.energy -= choice.energyCost;

    var coef = choice.coef;
    var wild = false;
    if (choice.wildCard) {
      coef = 0.8 + _rng.nextDouble() * 1.2;
      wild = true;
    }
    var backfired = false;
    if (choice.backfireChance > 0 &&
        _rng.nextDouble() < choice.backfireChance) {
      coef = choice.backfireCoef;
      backfired = true;
    }

    final score = powerScore(save);
    final gangMul = save.inGang ? activityMultiplier(save.gangActivity) : 1.0;
    final jitter = 0.9 + _rng.nextDouble() * 0.2;
    final isMilestone = isMilestoneActivity(period.activityId);
    final gain = isMilestone
        ? milestoneGain(save, period.activityId, choice)
        : (score *
                  coef *
                  (1 + save.activeActivityBonus) *
                  gangMul *
                  jitter)
              .round();

    save.progress += gain;
    save.totalChoices++;
    if (isDailyLimitedChoice(period.activityId)) {
      // 记录「今天已用过带倍率的决策」
      save.limitedChoiceDay = save.day;
    }
    if (choice.bonusCash > 0) {
      save.cash += choice.bonusCash;
      save.lifetimeCash += choice.bonusCash;
    }
    if (choice.bonusToken > 0) {
      save.token += choice.bonusToken;
      save.lifetimeToken += choice.bonusToken;
    }
    if (choice.gangActivityGain > 0 && save.inGang) {
      save.gangActivity = min(100, save.gangActivity + choice.gangActivityGain);
    }
    if (choice.nextActivityBonus > 0) {
      save.nextActivityBonus = min(1.0, save.nextActivityBonus + choice.nextActivityBonus);
    }

    final actName = activityName(period.activityId, 'zh');
    final actNameEn = activityName(period.activityId, 'en');
    final total = isMilestone
        ? milestoneConfig(period.activityId)!.total
        : 0;
    final progressSuffix = isMilestone ? '（${save.progress}/$total）' : '';
    final progressSuffixEn = isMilestone
        ? ' (${save.progress}/$total)'
        : '';
    if (backfired) {
      _log(
        save,
        '💥',
        'activity',
        '$actName：${choice.nameZh} 翻车了，只拿到 $gain 点进度',
        '$actNameEn: ${choice.nameEn} backfired, only $gain progress',
      );
    } else {
      _log(
        save,
        '🎯',
        'activity',
        '$actName：${choice.nameZh}，进度 +$gain$progressSuffix',
        '$actNameEn: ${choice.nameEn}, progress +$gain$progressSuffixEn',
      );
    }
    // 里程碑活动：达到节点立即发奖
    final nodes = isMilestone
        ? claimMilestoneNodes(save, period.activityId)
        : const <ScrapNode>[];

    return ChoiceOutcome(
      ok: true,
      progress: gain,
      backfired: backfired,
      wildCard: wild,
      effectiveCoef: coef,
      cash: choice.bonusCash,
      token: choice.bonusToken,
      scrapNodes: nodes,
    );
  }

  // ===================================================================
  // 里程碑活动（废铁行动 / 齿轮奔袭）：总进度条 + 奖励节点
  // ===================================================================

  /// 该活动是否为里程碑式活动（有总进度条与奖励节点）
  static bool isMilestoneActivity(String activityId) =>
      kMilestoneActivities.containsKey(activityId);

  /// 该活动是否为废铁行动
  static bool isScrapActivity(String activityId) => activityId == 'scrap';

  /// 里程碑活动配置（非里程碑返回 null）
  static MilestoneConfig? milestoneConfig(String activityId) =>
      kMilestoneActivities[activityId];

  /// 是否可以看广告（所有活动都可以；「仅看广告」的活动只给紫票）
  static bool canWatchAd(String activityId) =>
      isAdOnlyActivity(activityId) ||
      isMilestoneActivity(activityId) ||
      isAllStarActivity(activityId) ||
      isGpActivity(activityId);

  /// 里程碑活动一次决策的进度
  ///
  /// - 废铁行动：决策的固定点数 × 氪金倍率
  /// - 齿轮奔袭 / 全明星：**单车最高战力**的阶梯基础值（进度 / 分数）
  ///   × 精力倍数 × 氪金倍率
  ///   （齿轮：单车最高战力 < [kGearMinPower] 时基础值为 0，即进度 ×0）
  int milestoneGain(
    LifeSimSave save,
    String activityId,
    ActivityChoice choice,
  ) {
    final mul = save.scrapMultiplier;
    if (activityId == 'gear') {
      final base = gearBasePoints(maxVehiclePower(save));
      final energyMul = kGearEnergyMultipliers[choice.energyCost] ?? 1.0;
      return (base * energyMul * mul).round();
    }
    if (activityId == 'allstar') {
      final base = allStarScore(maxVehiclePower(save));
      final energyMul = kAllStarEnergyMultipliers[choice.energyCost] ?? 1.0;
      return (base * energyMul * mul).round();
    }
    return (choice.fixedPoints ?? 0) * mul;
  }

  /// 全明星：该活动是否为打榜活动
  static bool isAllStarActivity(String activityId) => activityId == 'allstar';

  static final Map<String, List<AllStarEntry>> _allStarBoardCache =
      <String, List<AllStarEntry>>{};

  /// 当天的全明星榜单（同一天同一服务器固定；换天会重新生成）
  List<AllStarEntry> allStarBoard(LifeSimSave save) {
    final period = periodForDay(save.day);
    final key = '$server/${period.startDay}/${save.day}';
    return _allStarBoardCache.putIfAbsent(key, () {
      final seed =
          server.hashCode * 31 +
          period.startDay * 7919 +
          save.day * 104729;
      return buildAllStarBoard(seed: seed);
    });
  }

  /// 玩家在当天榜单上的名次（1 起；分数越高名次越靠前）
  int allStarRank(LifeSimSave save) {
    final board = allStarBoard(save);
    var better = 0;
    for (final e in board) {
      if (e.score > save.progress) better++;
    }
    return better + 1;
  }

  /// 玩家当前名次对应的档位
  AllStarTier allStarTier(LifeSimSave save) =>
      allStarTierFor(allStarRank(save));

  // ===================================================================
  // GP 大奖赛（高随机 / 高耗体；与战车大小无关）
  // ===================================================================

  /// 该活动是否为 GP 大奖赛
  static bool isGpActivity(String activityId) => activityId == 'gp';

  /// GP：汽油带来的乘数加成（百分比）
  int gpGasBonus(LifeSimSave save) => gpGasBonusPct(save.gpGasConsumed);

  /// GP：氪金带来的乘数加成（百分比）
  int gpMoneyBonus(LifeSimSave save) => gpMoneyBonusPct(save.gpTopUpCount);

  /// GP：乘数总加成（百分比，整体封顶 +7650%）
  int gpBonus(LifeSimSave save) => gpBonusPct(
    gasConsumed: save.gpGasConsumed,
    topUpCount: save.gpTopUpCount,
  );

  /// GP：当前分数乘数（1.0 起）
  double gpMultiplier(LifeSimSave save) => gpMultiplierOf(
    gasConsumed: save.gpGasConsumed,
    topUpCount: save.gpTopUpCount,
  );

  /// GP：旗帜是否已归零
  bool gpFlagZero(LifeSimSave save) => save.gpFlags <= 0;

  /// GP：今天是否还能靠「起始为 0 的那一次低风险」把旗帜救回来
  bool gpRescueAvailable(LifeSimSave save) =>
      gpFlagZero(save) &&
      save.gpDayStartFlags <= 0 &&
      save.gpFlagsRescueDay != save.day;

  /// GP：这一档决策现在能不能选
  ///
  /// - 旗帜 > 0：三档都能选（只要汽油 / 精力够）
  /// - 旗帜 = 0 且当天开始时也是 0，且今天还没用过救援：
  ///   **只允许一次低风险**（低风险旗帜只增不减，见 `flagMin >= 0`）
  /// - 其余情况：高中低全部禁选
  bool gpCanChoose(LifeSimSave save, ActivityChoice choice) {
    if (save.gpFlags > 0) return true;
    if (!gpRescueAvailable(save)) return false;
    return choice.flagMin >= 0;
  }

  /// GP：三档是否都被「旗帜归零」禁掉了
  bool gpAllLocked(LifeSimSave save) => !gpCanChoose(save, kGpChoices.first);

  /// GP：做一次决策（扣汽油 + 精力 → 随机变动旗帜 → 按乘数加分）
  ChoiceOutcome _makeGpChoice(LifeSimSave save, ActivityChoice choice) {
    if (!gpCanChoose(save, choice)) {
      if (gpFlagZero(save)) {
        return const ChoiceOutcome(
          ok: false,
          errorZh: '旗帜已归零，今天不能再决策了',
          errorEn: 'Flags are at zero — no more choices today',
        );
      }
      return const ChoiceOutcome(
        ok: false,
        errorZh: '这一档现在不能选',
        errorEn: 'This option is not available now',
      );
    }
    if (save.energy < choice.energyCost) {
      return const ChoiceOutcome(
        ok: false,
        errorZh: '精力不足',
        errorEn: 'Not enough energy',
      );
    }
    if (save.gpGasoline < choice.gasCost) {
      return ChoiceOutcome(
        ok: false,
        errorZh: '汽油不足（需要 ${choice.gasCost}，当前 ${save.gpGasoline}）',
        errorEn:
            'Not enough gasoline (need ${choice.gasCost}, have ${save.gpGasoline})',
      );
    }

    // 乘数取「本次消耗之前」的汽油累计（先消耗满 1000 才拿到 +50%）
    final mul = gpMultiplier(save);
    final wasZero = gpFlagZero(save);

    save.energy -= choice.energyCost;
    save.gpGasoline -= choice.gasCost;
    save.gpGasConsumed += choice.gasCost;

    // 旗帜随机（区间含两端），且不可为负
    final roll =
        choice.flagMin + _rng.nextInt(choice.flagMax - choice.flagMin + 1);
    final before = save.gpFlags;
    save.gpFlags = max(0, save.gpFlags + roll);
    final delta = save.gpFlags - before;

    // 用掉今天「起始为 0」的那一次低风险救援
    if (wasZero && choice.flagMin >= 0) {
      save.gpFlagsRescueDay = save.day;
    }

    final gain = gpChoiceScore(choice, mul);
    save.progress += gain;
    save.totalChoices++;

    final actZh = activityName('gp', 'zh');
    final actEn = activityName('gp', 'en');
    final flagText = delta >= 0 ? '+$delta' : '$delta';
    _log(
      save,
      '🏁',
      'activity',
      '$actZh ${choice.nameZh}：旗帜 $flagText（剩 ${save.gpFlags}）、'
          '分数 +$gain（×${mul.toStringAsFixed(2)}）、'
          '汽油 -${choice.gasCost}（剩 ${save.gpGasoline}）',
      '$actEn ${choice.nameEn}: flags $flagText (left ${save.gpFlags}), '
          'score +$gain (×${mul.toStringAsFixed(2)}), '
          'gasoline -${choice.gasCost} (left ${save.gpGasoline})',
    );

    return ChoiceOutcome(
      ok: true,
      progress: gain,
      effectiveCoef: mul,
      gpMultiplier: mul,
      flagDelta: delta,
      gpFlags: save.gpFlags,
    );
  }

  /// GP：氪乘数（每 [kGpTopUpMoney] 钱 → 乘数 +[kGpTopUpBonusPct]%，上限 50 次）
  ({bool ok, String errorZh, String errorEn, int bonusPct, int count})
  gpTopUp(LifeSimSave save) {
    final period = periodForDay(save.day);
    if (!isGpActivity(period.activityId)) {
      return (
        ok: false,
        errorZh: '只有在 GP 周期才能氪乘数',
        errorEn: 'GP multiplier top-up is only available during GP',
        bonusPct: gpBonus(save),
        count: save.gpTopUpCount,
      );
    }
    if (save.gpTopUpCount >= kGpMaxTopUpCount) {
      return (
        ok: false,
        errorZh: '已氪满 $kGpMaxTopUpCount 次',
        errorEn: 'Already topped up $kGpMaxTopUpCount times',
        bonusPct: gpBonus(save),
        count: save.gpTopUpCount,
      );
    }
    save.money -= kGpTopUpMoney;
    save.gpTopUpCount++;
    final pct = gpBonus(save);
    _log(
      save,
      '💎',
      'activity',
      'GP 氪乘数：花费 $kGpTopUpMoney 钱 → 分数乘数 +$kGpTopUpBonusPct%'
          '（第 ${save.gpTopUpCount}/$kGpMaxTopUpCount 次，'
          '当前总加成 +$pct%，钱余额 ${save.money}）',
      'GP top-up: spent $kGpTopUpMoney money → multiplier '
          '+$kGpTopUpBonusPct% (${save.gpTopUpCount}/$kGpMaxTopUpCount, '
          'total bonus +$pct%, money ${save.money})',
    );
    return (
      ok: true,
      errorZh: '',
      errorEn: '',
      bonusPct: pct,
      count: save.gpTopUpCount,
    );
  }

  static final Map<String, List<AllStarEntry>> _gpBoardCache =
      <String, List<AllStarEntry>>{};

  /// 当天的 GP 榜单（同一天同一服务器固定；换天会重新生成）
  List<AllStarEntry> gpBoard(LifeSimSave save) {
    final period = periodForDay(save.day);
    final key = 'gp/$server/${period.startDay}/${save.day}';
    return _gpBoardCache.putIfAbsent(key, () {
      final seed =
          server.hashCode * 67 +
          period.startDay * 15485863 +
          save.day * 32452843;
      return buildGpBoard(seed: seed);
    });
  }

  /// 玩家在当天 GP 榜单上的名次（1 起；分数越高名次越靠前）
  int gpRank(LifeSimSave save) {
    final board = gpBoard(save);
    var better = 0;
    for (final e in board) {
      if (e.score > save.progress) better++;
    }
    return better + 1;
  }

  /// 玩家当前 GP 名次对应的奖励档位
  AllStarTier gpTier(LifeSimSave save) => gpTierFor(gpRank(save));

  /// 齿轮奔袭：单车最高战力是否达标（不达标则进度 ×0）
  bool gearPowerReady(LifeSimSave save) =>
      maxVehiclePower(save) >= kGearMinPower;

  /// 该活动的决策是否「带倍率、每天只能用一次」（齿轮奔袭 / 全明星）
  static bool isDailyLimitedChoice(String activityId) =>
      activityId == 'allstar' ||
      (milestoneConfig(activityId)?.oneChoicePerDay ?? false);

  /// 今天是否还能选带倍率的决策
  bool canUseLimitedChoice(LifeSimSave save) {
    final period = periodForDay(save.day);
    if (!isDailyLimitedChoice(period.activityId)) return true;
    return save.limitedChoiceDay != save.day;
  }

  /// 看广告：消耗 1 精力
  ///
  /// - 24h锦标赛+黑市：只给随机紫票（本期不设活动）
  /// - 里程碑活动：随机紫票 + 随机进度（进度受氪金倍率影响）
  ({bool ok, String errorZh, String errorEn, int cash, int progress, int baseProgress, List<ScrapNode> nodes})
  watchAd(LifeSimSave save) {
    final period = periodForDay(save.day);
    final activityId = period.activityId;
    if (!canWatchAd(activityId)) {
      return (
        ok: false,
        errorZh: '当前活动没有看广告',
        errorEn: 'No ads for the current activity',
        cash: 0,
        progress: 0,
        baseProgress: 0,
        nodes: const <ScrapNode>[],
      );
    }
    if (save.energy < kAdEnergyCost) {
      return (
        ok: false,
        errorZh: '精力不足',
        errorEn: 'Not enough energy',
        cash: 0,
        progress: 0,
        baseProgress: 0,
        nodes: const <ScrapNode>[],
      );
    }
    save.energy -= kAdEnergyCost;
    final cash = kAdCashTiers[_rng.nextInt(kAdCashTiers.length)];
    save.cash += cash;
    save.lifetimeCash += cash;

    final config = milestoneConfig(activityId);
    var base = 0;
    var progress = 0;
    var nodes = const <ScrapNode>[];
    final actZh = activityName(activityId, 'zh');
    final actEn = activityName(activityId, 'en');
    if (config != null && config.adProgressTiers.isNotEmpty) {
      base = config.adProgressTiers[_rng.nextInt(
        config.adProgressTiers.length,
      )];
      // 齿轮奔袭：单车最高战力不达标时进度 ×0
      final ready =
          activityId != 'gear' || gearPowerReady(save);
      progress = ready ? base * save.scrapMultiplier : 0;
      save.progress += progress;
      nodes = claimMilestoneNodes(save, activityId);
      _log(
        save,
        '📺',
        'activity',
        progress > 0
            ? '$actZh看广告：紫票 +$cash、进度 +$progress'
                  '（${save.progress}/${config.total}）'
            : '$actZh看广告：紫票 +$cash（单车最高战力不足 $kGearMinPower，进度 ×0）',
        progress > 0
            ? '$actEn ad: Cash +$cash, progress +$progress'
                  ' (${save.progress}/${config.total})'
            : '$actEn ad: Cash +$cash (top car power below $kGearMinPower, progress ×0)',
      );
    } else if (isAllStarActivity(activityId)) {
      // 全明星：紫票 + 少量分数（不占「带倍率决策」的每日次数）
      base = kAllStarAdScoreTiers[_rng.nextInt(kAllStarAdScoreTiers.length)];
      progress = (base * save.scrapMultiplier).round();
      save.progress += progress;
      _log(
        save,
        '📺',
        'activity',
        '$actZh看广告：紫票 +$cash、分数 +$progress（当前 ${save.progress} 分）',
        '$actEn ad: Cash +$cash, score +$progress (now ${save.progress})',
      );
    } else {
      _log(
        save,
        '📺',
        'activity',
        '$actZh看广告：紫票 +$cash',
        '$actEn ad: Cash +$cash',
      );
    }
    return (
      ok: true,
      errorZh: '',
      errorEn: '',
      cash: cash,
      progress: progress,
      baseProgress: base,
      nodes: nodes,
    );
  }

  /// 氪金：消耗「钱」换取本次里程碑活动的进度倍率
  ///
  /// 钱可以扣至负值；倍率取「更高者」，周期结束时重置为 1。
  ({bool ok, String errorZh, String errorEn, int multiplier})
  topUp(LifeSimSave save, int tierIndex) {
    if (tierIndex < 0 || tierIndex >= kTopUpTiers.length) {
      return (
        ok: false,
        errorZh: '档位不存在',
        errorEn: 'Unknown tier',
        multiplier: save.scrapMultiplier,
      );
    }
    final period = periodForDay(save.day);
    if (!isMilestoneActivity(period.activityId) &&
        !isAllStarActivity(period.activityId)) {
      return (
        ok: false,
        errorZh: '只有里程碑活动（废铁行动 / 齿轮奔袭）与全明星才能氪金',
        errorEn: 'Top-up is only available during Scrap Run / Gear Run',
        multiplier: save.scrapMultiplier,
      );
    }
    final tier = kTopUpTiers[tierIndex];
    if (save.scrapMultiplier >= tier.multiplier) {
      return (
        ok: false,
        errorZh: '已有效果不低于该档（当前 ×${save.scrapMultiplier}）',
        errorEn: 'Current multiplier is already ×${save.scrapMultiplier}',
        multiplier: save.scrapMultiplier,
      );
    }
    // 钱可以扣至负值
    save.money -= tier.cost;
    save.scrapMultiplier = tier.multiplier;
    final actZh = activityName(period.activityId, 'zh');
    final actEn = activityName(period.activityId, 'en');
    _log(
      save,
      '💎',
      'system',
      '氪金：花费 ${tier.cost} 钱，本次$actZh进度 ×${tier.multiplier}'
          '（钱余额 ${save.money}）',
      'Top-up: spent ${tier.cost} money, $actEn progress ×${tier.multiplier}'
          ' (money balance ${save.money})',
    );
    return (
      ok: true,
      errorZh: '',
      errorEn: '',
      multiplier: tier.multiplier,
    );
  }

  /// 全明星「买分」：消耗 1 精力 + 10 钱，获得 15000 分
  ///
  /// 与 [topUp] 的区别：这项**没有次数限制**（只受精力限制），
  /// 拿到的分数会被当前氪金倍率 [LifeSimSave.scrapMultiplier] 放大。
  /// 只在全明星（打榜）周期可用；钱可以扣至负值。
  ({bool ok, String errorZh, String errorEn, int gain}) buyAllStarScore(
    LifeSimSave save,
  ) {
    final period = periodForDay(save.day);
    if (!isAllStarActivity(period.activityId)) {
      return (
        ok: false,
        errorZh: '只有在全明星周期才能买分',
        errorEn: 'Score purchase is only available during All-Star',
        gain: 0,
      );
    }
    if (save.energy < kAllStarBuyEnergyCost) {
      return (
        ok: false,
        errorZh: '精力不足（需要 $kAllStarBuyEnergyCost 点）',
        errorEn: 'Not enough energy (need $kAllStarBuyEnergyCost)',
        gain: 0,
      );
    }
    save.energy -= kAllStarBuyEnergyCost;
    save.money -= kAllStarBuyMoneyCost;
    final gain = kAllStarBuyScore * save.scrapMultiplier;
    save.progress += gain;
    _log(
      save,
      '💎',
      'activity',
      '氪金买分：花费 $kAllStarBuyEnergyCost 精力 + $kAllStarBuyMoneyCost 钱，'
          '分数 +$gain（$kAllStarBuyScore × ${save.scrapMultiplier} 倍），'
          '当前 ${save.progress} 分（钱余额 ${save.money}）',
      'Score top-up: $kAllStarBuyEnergyCost energy + '
          '$kAllStarBuyMoneyCost money → score +$gain '
          '($kAllStarBuyScore × ${save.scrapMultiplier}), '
          'now ${save.progress} (money ${save.money})',
    );
    return (ok: true, errorZh: '', errorEn: '', gain: gain);
  }

  static final Map<String, List<ScrapNode>> _milestoneNodesCache =
      <String, List<ScrapNode>>{};

  /// 废铁行动奖励的 R6 部件（15 种）
  List<String> get scrapR6PartIds {
    final all = PartDatabase.partsForServer(server)
        .where((p) => p.rarity == Rarity.r6)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final explicit = kScrapR6PartIds
        .where((id) => partIndex.containsKey(id))
        .toList();
    final result = <String>[...explicit];
    for (final p in all) {
      if (result.length >= 15) break;
      if (!result.contains(p.id)) result.add(p.id);
    }
    return result.take(15).toList();
  }

  /// 当前服务器的废铁行动节点表
  List<ScrapNode> get scrapNodes => milestoneNodes('scrap');

  /// 某个里程碑活动的节点表
  List<ScrapNode> milestoneNodes(String activityId) =>
      _milestoneNodesCache.putIfAbsent('$server/$activityId', () {
        if (activityId == 'gear') return buildGearNodes();
        return buildScrapNodes(scrapR6PartIds);
      });

  /// 领取所有已达成的节点（按顺序），返回本次新达成的节点
  List<ScrapNode> claimMilestoneNodes(LifeSimSave save, String activityId) {
    final nodes = milestoneNodes(activityId);
    final gained = <ScrapNode>[];
    while (save.scrapClaimed < nodes.length &&
        nodes[save.scrapClaimed].progress <= save.progress) {
      final node = nodes[save.scrapClaimed];
      _grantMilestoneNode(save, activityId, node);
      gained.add(node);
      save.scrapClaimed++;
    }
    return gained;
  }

  /// 兼容旧接口
  List<ScrapNode> claimScrapNodes(LifeSimSave save) =>
      claimMilestoneNodes(save, 'scrap');

  // ===================================================================
  // GP：周期初始化与结算
  // ===================================================================

  /// 进入 GP 周期的第一天：发旗帜与首日汽油，并清空本周期累计
  void _startGpCycle(LifeSimSave save) {
    save.gpGasoline = kGpDailyGasoline;
    save.gpFlags = kGpInitialFlags;
    save.gpGasConsumed = 0;
    save.gpTopUpCount = 0;
    save.gpFlagsRescueDay = -1;
    _log(
      save,
      '🏁',
      'activity',
      'GP 开始：旗帜 $kGpInitialFlags、汽油 $kGpDailyGasoline'
          '（旗帜归零则当天三档全禁；当天起始为 0 时可救一次低风险）',
      'GP started: $kGpInitialFlags flags, $kGpDailyGasoline gasoline '
          '(flags at zero locks all options for the day)',
    );
  }

  /// 天数推进后同步 GP 状态（补汽油、记录当天起始旗帜）
  void _syncGpDay(LifeSimSave save) {
    final p = periodForDay(save.day);
    if (isGpActivity(p.activityId)) {
      if (save.day == p.startDay) {
        _startGpCycle(save);
      } else {
        save.gpGasoline += kGpDailyGasoline;
        _log(
          save,
          '⛽',
          'day',
          'GP 汽油 +$kGpDailyGasoline（当前 ${save.gpGasoline}）',
          'GP gasoline +$kGpDailyGasoline (now ${save.gpGasoline})',
        );
      }
    }
    // 「当天起始旗帜」用于判断归零禁选与低风险救援
    save.gpDayStartFlags = save.gpFlags;
  }

  /// GP 结算：按当日名次档位生成奖励（进待领取）
  RewardBundle _settleGp(LifeSimSave save, int endedDay) {
    final rank = gpRank(save);
    final tier = gpTierFor(rank);
    final pool = PartDatabase.partsForServer(
      server,
    ).where((p) => p.rarity == Rarity.r6).toList()..shuffle(_rng);
    final kinds = <String>[
      for (final p in pool.take(tier.partKinds)) p.id,
    ];
    final partIds = <String>[
      for (final id in kinds) ...List<String>.filled(tier.partEach, id),
    ];
    final bundle = RewardBundle(
      activityId: 'gp',
      rank: tier.labelZh,
      day: save.day,
      cash: tier.cash,
      token: tier.token,
      partIds: partIds,
    );
    save.pendingRewards.add(bundle);
    _log(
      save,
      '🏆',
      'reward',
      'GP 结算：$rank 名（${tier.labelZh}，总分 ${save.progress}，'
          '共氪 ${save.gpTopUpCount} 次、消耗汽油 ${save.gpGasConsumed}）'
          '→ 部件 ${tier.partKinds} 种×${tier.partEach}、'
          '代币 ${tier.token}、紫票 ${tier.cash}，奖励待领取',
      'GP settled: rank $rank (${tier.labelEn}, score ${save.progress}, '
          '${save.gpTopUpCount} top-ups, ${save.gpGasConsumed} gasoline) '
          '→ ${tier.partKinds} kinds ×${tier.partEach}, '
          '${tier.token} tokens, ${tier.cash} cash (pending)',
    );
    save.progress = 0;
    save.scrapClaimed = 0;
    save.scrapMultiplier = 1;
    // GP 本周期状态清空（旗帜留到下次进入 GP 时由 _startGpCycle 重发）
    save.gpGasoline = 0;
    save.gpGasConsumed = 0;
    save.gpTopUpCount = 0;
    save.activeActivityBonus = min(1.0, save.nextActivityBonus);
    save.nextActivityBonus = 0;
    save.progressPeriodStart = periodStartDay(endedDay + 1);
    return bundle;
  }

  /// 全明星结算：按名次档位生成奖励（进待领取）
  RewardBundle _settleAllStar(LifeSimSave save, int endedDay) {
    final rank = allStarRank(save);
    final tier = allStarTierFor(rank);
    // 部件：随机抽不重复的 N 种 R6 部件，每种若干碎片
    final pool = PartDatabase.partsForServer(
      server,
    ).where((p) => p.rarity == Rarity.r6).toList()..shuffle(_rng);
    final kinds = <String>[
      for (final p in pool.take(tier.partKinds)) p.id,
    ];
    final partIds = <String>[
      for (final id in kinds) ...List<String>.filled(tier.partEach, id),
    ];
    final bundle = RewardBundle(
      activityId: 'allstar',
      rank: tier.labelZh,
      day: save.day,
      cash: tier.cash,
      token: tier.token,
      partIds: partIds,
    );
    save.pendingRewards.add(bundle);
    _log(
      save,
      '🏆',
      'reward',
      '全明星结算：$rank 名（${tier.labelZh}，总分 ${save.progress}）'
          '→ 部件 ${tier.partKinds} 种×${tier.partEach}、'
          '代币 ${tier.token}、紫票 ${tier.cash}，奖励待领取',
      'All-Star settled: rank $rank (${tier.labelEn}, score ${save.progress})'
          ' → ${tier.partKinds} kinds ×${tier.partEach}, '
          '${tier.token} tokens, ${tier.cash} cash (pending)',
    );
    save.progress = 0;
    save.scrapClaimed = 0;
    save.scrapMultiplier = 1;
    save.activeActivityBonus = min(1.0, save.nextActivityBonus);
    save.nextActivityBonus = 0;
    save.progressPeriodStart = periodStartDay(endedDay + 1);
    return bundle;
  }

  /// 随机抽一个 R6 部件
  String rollR6Part() {
    final pool = PartDatabase.partsForServer(
      server,
    ).where((p) => p.rarity == Rarity.r6).toList();
    if (pool.isEmpty) return '';
    return pool[_rng.nextInt(pool.length)].id;
  }

  /// 发放一个节点的奖励并写日志
  void _grantMilestoneNode(
    LifeSimSave save,
    String activityId,
    ScrapNode node,
  ) {
    final partIds = <String>[];
    var token = 0;
    var cash = 0;
    final summaryZh = <String>[];
    final summaryEn = <String>[];

    for (final r in node.rewards) {
      switch (r.kind) {
        case ScrapRewardKind.r6Part:
          final id = r.partId;
          if (id == null) break;
          partIds.addAll(List<String>.filled(r.amount, id));
          summaryZh.add('${_partLabel(id, true)} ×${r.amount}');
          summaryEn.add('${_partLabel(id, false)} ×${r.amount}');
          break;
        case ScrapRewardKind.randomR6Part:
          final id = rollR6Part();
          if (id.isEmpty) break;
          partIds.addAll(List<String>.filled(r.amount, id));
          summaryZh.add('${_partLabel(id, true)} ×${r.amount}（随机 R6）');
          summaryEn.add('${_partLabel(id, false)} ×${r.amount} (random R6)');
          break;
        case ScrapRewardKind.randomPart:
          final ids = <String>[
            for (var i = 0; i < r.amount; i++) rollPart('scrap'),
          ]..removeWhere((id) => id.isEmpty);
          partIds.addAll(ids);
          summaryZh.add('随机部件宝箱 ×${ids.length}');
          summaryEn.add('random part chest ×${ids.length}');
          break;
        case ScrapRewardKind.token:
          token += r.amount;
          summaryZh.add('代币 ×${r.amount}');
          summaryEn.add('Tokens ×${r.amount}');
          break;
        case ScrapRewardKind.cash:
          cash += r.amount;
          summaryZh.add('紫票 ×${r.amount}');
          summaryEn.add('Cash ×${r.amount}');
          break;
      }
    }

    if (cash > 0) {
      save.cash += cash;
      save.lifetimeCash += cash;
    }
    if (token > 0) {
      save.token += token;
      save.lifetimeToken += token;
    }
    final config = milestoneConfig(activityId);
    final total = config?.total ?? 0;
    final actZh = activityName(activityId, 'zh');
    final actEn = activityName(activityId, 'en');
    _log(
      save,
      '🏁',
      'reward',
      '$actZh节点 ${node.progress}/$total：${summaryZh.join('、')}',
      '$actEn node ${node.progress}/$total: ${summaryEn.join(', ')}',
    );
    if (partIds.isNotEmpty) {
      save.partsGained += partIds.length;
      grantParts(save, partIds);
    }
    checkAchievements(save);
  }

  /// 结算当前周期的活动（跨周期时由 [endDay] 调用）
  ///
  /// 废铁行动是特殊活动：不结算档位，改为总进度条 + 奖励节点
  /// （节点奖励在达成时即时发放），这里只收尾并重置进度。
  RewardBundle? _settle(LifeSimSave save, int endedDay) {
    final period = periodOf(save.progressPeriodStart);
    final nameZh = activityName(period.activityId, 'zh');
    final nameEn = activityName(period.activityId, 'en');

    if (isAllStarActivity(period.activityId)) {
      // 全明星：打榜活动，按名次档位发奖
      return _settleAllStar(save, endedDay);
    }

    if (isGpActivity(period.activityId)) {
      // GP：打榜活动（与战车大小无关），按名次档位发奖
      return _settleGp(save, endedDay);
    }

    if (isMilestoneActivity(period.activityId)) {
      final nodes = milestoneNodes(period.activityId);
      final total = milestoneConfig(period.activityId)!.total;
      _log(
        save,
        '📦',
        'reward',
        '$nameZh 结束：进度 ${save.progress}/$total，'
            '已领取 ${save.scrapClaimed}/${nodes.length} 个奖励节点'
            '（节点奖励已即时发放）',
        '$nameEn finished: progress ${save.progress}/$total, '
            '${save.scrapClaimed}/${nodes.length} nodes claimed',
      );
      save.scrapClaimed = 0;
      save.scrapMultiplier = 1;
      save.progress = 0;
      save.activeActivityBonus = min(1.0, save.nextActivityBonus);
      save.nextActivityBonus = 0;
      save.progressPeriodStart = periodStartDay(endedDay + 1);
      return null;
    }

    if (period.activityId == kChampActivityId) {
      // 24h锦标赛+黑市：本期不设活动，不结算档位
      _log(
        save,
        '📦',
        'reward',
        '$nameZh 结束：本期不设活动（仅可看广告换紫票）',
        '$nameEn finished: no activity this cycle (ads only)',
      );
      save.progress = 0;
      save.scrapClaimed = 0;
      save.activeActivityBonus = min(1.0, save.nextActivityBonus);
      save.nextActivityBonus = 0;
      save.progressPeriodStart = periodStartDay(endedDay + 1);
      return null;
    }

    final rank = rankFor(save.progress, period.isMajor);
    final reward = _buildReward(
      period.activityId,
      rank,
      period.isMajor,
      save.day,
    );
    save.pendingRewards.add(reward);
    if (rank == 'S') save.rankSCount++;
    if (rank == 'A') save.rankACount++;

    _log(
      save,
      '📦',
      'reward',
      '$nameZh 结束，结算档位 $rank（进度 ${save.progress}），奖励待领取',
      '$nameEn finished: rank $rank (progress ${save.progress}), reward pending',
    );

    save.progress = 0;
    save.activeActivityBonus = min(1.0, save.nextActivityBonus);
    save.nextActivityBonus = 0;
    save.progressPeriodStart = periodStartDay(endedDay + 1);
    return reward;
  }

  RewardBundle _buildReward(
    String activityId,
    String rank,
    bool isMajor,
    int day,
  ) {
    final base = kRankRewards[rank] ?? kRankRewards['D']!;
    final scale = isMajor ? 1.0 : kMinorRewardScale;
    var parts = base.partCount;
    if (base.extraPartChancePct > 0 &&
        _rng.nextInt(100) < base.extraPartChancePct) {
      parts += 1;
    }
    final partIds = <String>[
      for (var i = 0; i < parts; i++) rollPart(activityId),
    ]..removeWhere((id) => id.isEmpty);
    return RewardBundle(
      activityId: activityId,
      rank: rank,
      day: day,
      cash: (base.cash * scale).round(),
      token: (base.token * scale).round(),
      partIds: partIds,
    );
  }

  /// 按活动的稀有度权重抽一个部件（优先给尚未拥有的）
  String rollPart(String activityId) {
    final weights = kDropWeights[activityId] ?? kDropWeights['gp']!;
    final total = weights.fold(0, (a, b) => a + b);
    if (total <= 0) return '';
    var roll = _rng.nextInt(total);
    var rarityIndex = 0;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        rarityIndex = i;
        break;
      }
    }
    final rarity = Rarity.values[rarityIndex.clamp(0, Rarity.values.length - 1)];
    final pool = PartDatabase.partsForServer(
      server,
    ).where((p) => p.rarity == rarity).toList();
    if (pool.isEmpty) return '';
    pool.shuffle(_rng);
    return pool.first.id;
  }

  /// 领取全部待领取奖励
  List<RewardBundle> claimRewards(LifeSimSave save) {
    final claimed = <RewardBundle>[];
    for (final r in save.pendingRewards) {
      if (r.claimed) continue;
      r.claimed = true;
      save.cash += r.cash;
      save.lifetimeCash += r.cash;
      save.token += r.token;
      save.lifetimeToken += r.token;
      final actZh = activityName(r.activityId, 'zh');
      final actEn = activityName(r.activityId, 'en');
      _log(
        save,
        '🎁',
        'reward',
        '领取 $actZh 奖励：紫票 +${r.cash}、代币 +${r.token}',
        'Claimed $actEn reward: +${r.cash} Cash, +${r.token} Tokens',
      );
      // 部件（重复获得即累积为碎片）
      save.partsGained += r.partIds.length;
      grantParts(save, r.partIds);
      claimed.add(r);
    }
    save.pendingRewards.removeWhere((r) => r.claimed);
    checkAchievements(save);
    return claimed;
  }

  // ===================================================================
  // 天数推进
  // ===================================================================

  /// 结束这一天：结算跨周期的活动、恢复精力、推进天数、刷新城市之王对手
  EndDayResult endDay(LifeSimSave save) {
    final today = save.day;
    final nextStart = periodStartDay(today + 1);
    RewardBundle? settled;
    String? settledActivity;
    String? settledRank;
    if (nextStart != save.progressPeriodStart) {
      settledActivity = periodOf(save.progressPeriodStart).activityId;
      final bundle = _settle(save, today);
      settled = bundle;
      settledRank = bundle?.rank;
    }

    save.day = today + 1;
    save.energy = min(save.maxEnergy, save.energy + LifeSimSave.kDailyEnergy);
    _log(
      save,
      '🌅',
      'day',
      '第 ${save.day} 天开始了，精力恢复到 ${save.energy}/${save.maxEnergy}',
      'Day ${save.day} begins. Energy restored to ${save.energy}/${save.maxEnergy}',
    );

    // GP：补汽油 + 记录当天起始旗帜
    _syncGpDay(save);

    // 城市之王：跨赛季（40 天）时结算并清零胜场 / 赛季分数
    if (citySeasonStartDay(today) != citySeasonStartDay(save.day)) {
      _log(
        save,
        '🏁',
        'city',
        '城市之王赛季结束：$kCitySeasonDays 天里胜 ${save.citySeasonWins} 场'
            '、赛季结算分数 ${save.citySeasonScore}'
            '（生涯累计胜 ${save.cityWins} 场）',
        'City King season ended: ${save.citySeasonWins} wins in '
            '$kCitySeasonDays days, season score ${save.citySeasonScore} '
            '(career wins ${save.cityWins})',
      );
      save.citySeasonWins = 0;
      save.citySeasonScore = 0;
      save.citySeasonClaimed = 0;
      // 帮派联赛：同一个赛季结束时结算晋级 / 退级（要在清零「本季参战」前）
      settleGangLeague(save);
      save.citySeasonFought = false;
      _log(
        save,
        '🏁',
        'city',
        '新的城市之王赛季开始（第 ${citySeasonDay(save.day)}/$kCitySeasonDays 天）',
        'A new City King season begins '
            '(day ${citySeasonDay(save.day)}/$kCitySeasonDays)',
      );
    }

    // 城市之王：每天刷新对手
    if (save.inGang) {
      rollCityOpponent(save);
    } else {
      save.cityOpponentName = null;
      save.cityOpponentCars = <int>[];
      save.cityOpponentPower = 0;
    }
    save.cityChallenged = false;

    final achv = checkAchievements(save);
    return EndDayResult(
      newDay: save.day,
      settledPeriod: settled,
      settledActivityId: settledActivity,
      settledRank: settledRank,
      newAchievements: achv,
    );
  }

  // ===================================================================
  // 帮派
  // ===================================================================

  /// 累计帮派战力（自己的车队 + 队友）
  int gangPower(LifeSimSave save) {
    var total = fleetPower(save);
    for (final m in save.gangMembers) {
      total += m.totalPower;
    }
    return total;
  }

  /// 玩家帮派的「大致排名」（全服 [kGangTotalCapacity] 个帮派里的位置；1 = 最强）
  ///
  /// 由联赛组别 + 组内名次推导：金组 = 1-100、银组 = 101-200、
  /// 铜组 = 201-300、木组 = 301-500。
  /// **0 = 本季未上榜**（没打过城市之王或已封存）。
  int estimateGangRank(LifeSimSave save) {
    if (!save.inGang) return 0;
    final rank = gangLeagueRank(save);
    if (rank <= 0) return 0;
    final div = gangDivision(save);
    final fromTop = GangDivision.values.length - 1 - div.index;
    return fromTop * kGangDivisionSize + rank;
  }

  /// 生成一个帮派实例
  ///
  /// [archetype] 非空时按固定帮派的数值范围生成；否则按玩家战力缩放随机生成
  /// （保证城市之王始终有得打），名称为随机前缀 + 后缀。
  GangInstance generateGang(LifeSimSave save, {GangArchetype? archetype}) {
    if (archetype != null) {
      final count = _between(archetype.memberMin, archetype.memberMax);
      final members = <SimGangMember>[
        for (var i = 0; i < count; i++)
          SimGangMember(
            name: _memberName(),
            carPowers: _randomCarPowers(
              archetype.carPowerMin,
              archetype.carPowerMax,
            ),
          ),
      ];
      return GangInstance(
        name: archetype.name,
        fromLibrary: true,
        members: members,
        activity: _between(archetype.activityMin, archetype.activityMax),
        rankHint: archetype.rankHint,
      );
    }
    // 随机帮派：以玩家每车战力为基准浮动
    final myPerCar = max(1, fleetPower(save) ~/ 3);
    final base = myPerCar < 20000 ? 20000 : myPerCar;
    final lo = (base * 0.5).round();
    final hi = (base * 1.8).round();
    final count = _between(3, 10);
    return GangInstance(
      name: _randomGangName(),
      fromLibrary: false,
      members: <SimGangMember>[
        for (var i = 0; i < count; i++)
          SimGangMember(
            name: _memberName(),
            carPowers: _randomCarPowers(lo, hi),
          ),
      ],
      activity: _between(20, 85),
    );
  }

  /// 可加入的帮派候选：**四个组别都能看到**，每组取几个
  ///
  /// 每组会给：组内第 1 名（顶级帮派，基本已满员 → 只是展示）+ 几个
  /// 还有空位的帮派；满员的帮派 [GangCandidate.full] 为 true，不能加入。
  List<GangCandidate> gangCandidates(LifeSimSave save, {int perDivision = 2}) {
    final out = <GangCandidate>[];
    for (final d in GangDivision.values.reversed) {
      final board = _npcBoard(d, save.day);
      if (board.isEmpty) continue;
      final picked = <GangLeagueRow>[board.first];
      final joinable = board
          .where((r) => r.members < kGangMaxMembers)
          .toList()
        ..sort((a, b) => a.rank.compareTo(b.rank));
      final pool = joinable.take(perDivision * 3).toList()..shuffle(_rng);
      for (final r in pool) {
        if (picked.length > perDivision) break;
        if (picked.any((x) => x.name == r.name)) continue;
        picked.add(r);
      }
      for (final r in picked) {
        out.add(
          GangCandidate(
            gang: gangFromRow(r),
            division: d,
            rank: r.rank,
            power: r.power,
            members: r.members,
            activity: r.activity,
          ),
        );
      }
    }
    return out;
  }

  /// 组建自己的帮派
  ({bool ok, String errorZh, String errorEn}) foundGang(
    LifeSimSave save,
    String name,
  ) {
    if (save.inGang) {
      return (
        ok: false,
        errorZh: '你已经在帮派中了',
        errorEn: 'You are already in a gang',
      );
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return (ok: false, errorZh: '请输入帮派名称', errorEn: 'Enter a gang name');
    }
    if (save.cash < kFoundGangCashCost) {
      return (
        ok: false,
        errorZh: '紫票不足（需要 $kFoundGangCashCost）',
        errorEn: 'Not enough Cash (need $kFoundGangCashCost)',
      );
    }
    save.cash -= kFoundGangCashCost;
    save.gangName = trimmed;
    save.gangOwned = true;
    save.gangMembers.clear();
    save.gangActivity = 20;
    // 新建的帮派必须从最低组别（木组）起步，之后靠联赛升降级往上爬
    save.gangDivisionIndex = GangDivision.wood.index;
    save.cityLossStreak = 0;
    save.citySeasonFought = false;
    save.gangsJoined++;
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '🏛️',
      'gang',
      '你组建了帮派「$trimmed」（花费 $kFoundGangCashCost 紫票），'
          '新帮派从${GangDivision.wood.leagueZh}起步',
      'You founded the gang "$trimmed" for $kFoundGangCashCost Cash; '
          'new gangs start in the ${GangDivision.wood.leagueEn}',
    );
    rollCityOpponent(save);
    checkAchievements(save);
    return (ok: true, errorZh: '', errorEn: '');
  }

  /// 加入一个已有帮派（[candidate] 来自 [gangCandidates]）
  ///
  /// 加入哪个组别的帮派，玩家就属于哪个组别（可以一步加入金组）。
  ({bool ok, String errorZh, String errorEn}) joinGang(
    LifeSimSave save,
    GangCandidate candidate,
  ) {
    if (save.inGang) {
      return (
        ok: false,
        errorZh: '你已经在帮派中了',
        errorEn: 'You are already in a gang',
      );
    }
    if (candidate.full) {
      return (
        ok: false,
        errorZh: '该帮派已满员（${candidate.members}/$kGangMaxMembers）',
        errorEn: 'That gang is full (${candidate.members}/$kGangMaxMembers)',
      );
    }
    final gang = candidate.gang;
    save.gangName = gang.name;
    save.gangOwned = false;
    save.gangMembers
      ..clear()
      ..addAll(gang.members);
    save.gangActivity = gang.activity;
    save.gangDivisionIndex = candidate.division.index;
    save.cityLossStreak = 0;
    save.citySeasonFought = false;
    save.gangsJoined++;
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '🤝',
      'gang',
      '你加入了帮派「${gang.name}」'
          '（${candidate.division.leagueZh} 第 ${candidate.rank} 名，'
          '${candidate.members} 名成员）',
      'You joined the gang "${gang.name}" '
          '(${candidate.division.leagueEn} #${candidate.rank}, '
          '${candidate.members} members)',
    );
    rollCityOpponent(save);
    checkAchievements(save);
    return (ok: true, errorZh: '', errorEn: '');
  }

  /// 退出帮派
  void leaveGang(LifeSimSave save) {
    if (!save.inGang) return;
    final name = save.gangName!;
    save.gangName = null;
    save.gangOwned = false;
    save.gangMembers.clear();
    save.gangActivity = 0;
    save.gangRankHint = 0;
    save.cityLossStreak = 0;
    save.cityOpponentName = null;
    save.cityOpponentCars = <int>[];
    save.cityOpponentPower = 0;
    _log(
      save,
      '🚪',
      'gang',
      '你退出了帮派「$name」',
      'You left the gang "$name"',
    );
  }

  /// 招募一名 AI 成员（战力随玩家车队成长）
  ({bool ok, String errorZh, String errorEn, SimGangMember? member})
  recruitMember(LifeSimSave save) {
    if (!save.inGang) {
      return (
        ok: false,
        errorZh: '需要先加入或组建帮派',
        errorEn: 'Join or found a gang first',
        member: null,
      );
    }
    if (1 + save.gangMembers.length >= kGangMaxMembers) {
      return (
        ok: false,
        errorZh: '帮派已满员（$kGangMaxMembers/$kGangMaxMembers）',
        errorEn: 'Your gang is full ($kGangMaxMembers/$kGangMaxMembers)',
        member: null,
      );
    }
    if (save.gangRecruitLocked) {
      return (
        ok: false,
        errorZh: '帮派已设为「禁止加入」（封存中），先关闭该设置才能招募',
        errorEn: 'Recruiting is disabled (the gang is sealed)',
        member: null,
      );
    }
    final cost =
        kRecruitCashBase + kRecruitCashStep * save.gangMembers.length;
    if (save.energy < kRecruitEnergyCost) {
      return (
        ok: false,
        errorZh: '精力不足（需要 $kRecruitEnergyCost）',
        errorEn: 'Not enough energy (need $kRecruitEnergyCost)',
        member: null,
      );
    }
    if (save.cash < cost) {
      return (
        ok: false,
        errorZh: '紫票不足（需要 $cost）',
        errorEn: 'Not enough Cash (need $cost)',
        member: null,
      );
    }
    save.energy -= kRecruitEnergyCost;
    save.cash -= cost;
    final perCar = max(20000, fleetPower(save) ~/ 3);
    final member = SimGangMember(
      name: _memberName(),
      carPowers: _randomCarPowers(
        (perCar * 0.6).round(),
        (perCar * 1.4).round(),
      ),
    );
    save.gangMembers.add(member);
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '📣',
      'gang',
      '招募了新成员「${member.name}」（战力 ${member.totalPower}），花费 $cost 紫票',
      'Recruited "${member.name}" (power ${member.totalPower}) for $cost Cash',
    );
    checkAchievements(save);
    return (ok: true, errorZh: '', errorEn: '', member: member);
  }

  /// 踢出一名成员（只有自己组建的帮派才能踢）
  ///
  /// 把人数压到 [kGangSealMinMembers] 以下就是「封存」：
  /// 打不了城市之王、不上排行榜，也就不会被判 80+ 掉级。
  ({bool ok, String errorZh, String errorEn, SimGangMember? member})
  kickMember(LifeSimSave save) {
    if (!save.inGang || !save.gangOwned) {
      return (
        ok: false,
        errorZh: '只有自己组建的帮派才能踢人',
        errorEn: 'You can only kick members from your own gang',
        member: null,
      );
    }
    if (save.gangMembers.isEmpty) {
      return (
        ok: false,
        errorZh: '帮派里没有可踢出的成员',
        errorEn: 'There is nobody to kick',
        member: null,
      );
    }
    final m = save.gangMembers.removeAt(save.gangMembers.length - 1);
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '👋',
      'gang',
      '踢出了成员「${m.name}」（现剩 ${save.gangMembers.length} 名成员）',
      'Kicked "${m.name}" (${save.gangMembers.length} members left)',
    );
    return (ok: true, errorZh: '', errorEn: '', member: m);
  }

  /// 设置「禁止加入」（封存开关）：开启后无法招募新成员
  void setGangRecruitLocked(LifeSimSave save, bool locked) {
    save.gangRecruitLocked = locked;
    _log(
      save,
      locked ? '🧊' : '🔓',
      'gang',
      locked
          ? '帮派已设为「禁止加入」：无法招募新成员'
              '${isGangSealed(save) ? '（当前已封存，不上排行榜）' : ''}'
          : '帮派已取消「禁止加入」，可以继续招募',
      locked
          ? 'Recruiting disabled: the gang accepts no new members'
          : 'Recruiting re-enabled',
    );
  }

  /// 使用一个工具箱（生命 / 攻击）→ 对应部件 +[kToolboxBonusPct]%
  ({bool ok, String errorZh, String errorEn, int stacks}) useToolbox(
    LifeSimSave save,
    String partId, {
    required bool hp,
  }) {
    final p = partIndex[partId];
    if (p == null) {
      return (
        ok: false,
        errorZh: '部件不存在',
        errorEn: 'Unknown part',
        stacks: 0,
      );
    }
    final have = hp ? save.hpToolbox : save.atkToolbox;
    if (have <= 0) {
      return (
        ok: false,
        errorZh: hp ? '没有生命工具箱' : '没有攻击力工具箱',
        errorEn: hp ? 'No HP toolbox' : 'No ATK toolbox',
        stacks: 0,
      );
    }
    if (hp && p.hp(1) <= 0) {
      return (
        ok: false,
        errorZh: '该部件没有生命值，用不了生命工具箱',
        errorEn: 'That part has no HP',
        stacks: 0,
      );
    }
    if (!hp && p.atk(1) <= 0) {
      return (
        ok: false,
        errorZh: '该部件没有攻击力，用不了攻击工具箱',
        errorEn: 'That part has no ATK',
        stacks: 0,
      );
    }
    final map = hp ? save.partHpBoxes : save.partAtkBoxes;
    final applied = map[partId] ?? 0;
    if (applied >= kToolboxMaxStack) {
      return (
        ok: false,
        errorZh:
            '该部件的工具箱已叠满（+${kToolboxMaxStack * kToolboxBonusPct}%）',
        errorEn: 'This part is already at max toolbox stacks',
        stacks: applied,
      );
    }
    if (hp) {
      save.hpToolbox--;
    } else {
      save.atkToolbox--;
    }
    map[partId] = applied + 1;
    _log(
      save,
      '🧰',
      'part',
      '对「${_partLabel(partId, true)}」使用${hp ? '生命' : '攻击'}工具箱：'
          '+$kToolboxBonusPct% ${hp ? '生命值' : '伤害'}'
          '（已叠 ${applied + 1}/$kToolboxMaxStack 层）',
      'Used a ${hp ? 'HP' : 'ATK'} toolbox on "${p.id}": '
          '+$kToolboxBonusPct% (stack ${applied + 1}/$kToolboxMaxStack)',
    );
    return (ok: true, errorZh: '', errorEn: '', stacks: applied + 1);
  }

  // ===================================================================
  // 城市之王（3v3 逐车对位）
  // ===================================================================

  /// 城市之王赛季（[kCitySeasonDays] 天一赛季）的起始天
  static int citySeasonStartDay(int day) =>
      ((day - 1) ~/ kCitySeasonDays) * kCitySeasonDays + 1;

  /// 第 [day] 天所属赛季的序号（0 起）——城市之王与帮派联赛共用同一个赛季
  static int seasonIndexOf(int day) => (day - 1) ~/ kCitySeasonDays;

  // ===================================================================
  // 帮派联赛（金 / 银 / 铜 / 木）
  // ===================================================================

  /// 玩家帮派所在的联赛组别
  GangDivision gangDivision(LifeSimSave save) => GangDivision
      .values[save.gangDivisionIndex.clamp(0, GangDivision.values.length - 1)];

  static final Map<String, GangDivisionBoard> _gangBoardCache =
      <String, GangDivisionBoard>{};

  /// 某组别在第 [day] 天所在赛季的榜单（不含玩家，按组别 + 赛季缓存）
  GangDivisionBoard _npcBoardFull(GangDivision div, int day) {
    final season = seasonIndexOf(day);
    final key = '$server/${div.name}/$season';
    return _gangBoardCache.putIfAbsent(
      key,
      () => buildGangDivisionBoard(
        division: div,
        seed: server.hashCode * 131 + div.index * 7717 + season * 104729,
        seasonIndex: season,
      ),
    );
  }

  /// 某组别本季上榜的对手
  List<GangLeagueRow> _npcBoard(GangDivision div, int day) =>
      _npcBoardFull(div, day).rows;

  /// 玩家帮派是否处于**封存**状态（成员不足 [kGangSealMinMembers] 人）
  ///
  /// 封存的帮派打不了城市之王，因此整季不上排行榜，也就不会被判 80+ 掉级。
  bool isGangSealed(LifeSimSave save) =>
      save.inGang && 1 + save.gangMembers.length < kGangSealMinMembers;

  /// 玩家帮派是否已在本赛季上榜（打过至少一场城市之王）
  bool isGangRanked(LifeSimSave save) =>
      save.inGang && !isGangSealed(save) && save.citySeasonFought;

  /// 玩家所在组别的联赛榜单（本季上榜的对手 + 玩家自己，按战力降序）
  ///
  /// - 一个赛季内榜单固定（按服务器 + 组别 + 赛季序号做种子）
  /// - **整季没打过城市之王的帮派不上榜**：玩家必须先打一场才会出现在榜单上
  /// - 封存的帮派（成员不足 5 人）永远不上榜
  List<GangLeagueRow> gangBoard(LifeSimSave save) {
    final div = gangDivision(save);
    final board = _npcBoardFull(div, save.day);
    final npc = board.rows;
    if (!isGangRanked(save)) return npc;
    final rows = <GangLeagueRow>[
      ...npc,
      GangLeagueRow(
        rank: 0,
        name: save.gangName!,
        power: gangPower(save),
        members: min(kGangMaxMembers, 1 + save.gangMembers.length),
        activity: save.gangActivity,
        isPlayer: true,
      ),
    ]..sort((a, b) => b.power.compareTo(a.power));
    // 玩家也占组内一个席位（超过容量时挤掉最弱的那个对手）
    final capacity = kGangDivisionCapacity[div]!;
    while (rows.length > capacity) {
      final weakest = rows.lastIndexWhere((r) => !r.isPlayer);
      if (weakest < 0) break;
      rows.removeAt(weakest);
    }
    return <GangLeagueRow>[
      for (var i = 0; i < rows.length; i++) rows[i].withRank(i + 1),
    ];
  }

  /// 本季该组别上榜 / 封存的帮派数（用于界面与「不足 80 家不退级」判定）
  ({int active, int sealed, int capacity, bool canDemote}) divisionStatus(
    LifeSimSave save,
    GangDivision div,
  ) {
    final board = _npcBoardFull(div, save.day);
    final extra = isGangRanked(save) && gangDivision(save) == div ? 1 : 0;
    final active = board.activeCount + extra;
    return (
      active: active,
      sealed: board.sealedCount,
      capacity: board.capacity,
      canDemote: active >= kGangDemoteRank - 1,
    );
  }

  /// 某组别第 [day] 天所在赛季的各名次区间数据参考
  ///
  /// （战力 / 成员数 / 活跃度 / 单车战力，用于界面展示与平衡校验）
  List<GangBandStat> divisionBandStats(LifeSimSave save, GangDivision div) {
    final season = seasonIndexOf(save.day);
    return gangDivisionBandStats(
      division: div,
      seed: server.hashCode * 131 + div.index * 7717 + season * 104729,
      seasonIndex: season,
    );
  }

  /// 玩家在所在组别的名次（1 起）
  ///
  /// **0 = 本季还没上榜**（没打过城市之王或帮派已封存）。
  int gangLeagueRank(LifeSimSave save) {
    if (!isGangRanked(save)) return 0;
    final board = gangBoard(save);
    for (final r in board) {
      if (r.isPlayer) return r.rank;
    }
    return 0;
  }

  /// 按榜单一行生成一个帮派实例（成员战力由总战力与成员数反推）
  GangInstance gangFromRow(GangLeagueRow row) {
    final count = max(1, row.members);
    final perCar = max(1, row.power ~/ count ~/ 3);
    return GangInstance(
      name: row.name,
      fromLibrary: kGangLeagueRoster.any((e) => e.name == row.name),
      members: <SimGangMember>[
        for (var i = 0; i < count; i++)
          SimGangMember(
            name: _memberName(),
            carPowers: <int>[
              for (var c = 0; c < 3; c++)
                max(1, (perCar * (0.85 + _rng.nextDouble() * 0.3)).round()),
            ],
          ),
      ],
      activity: row.activity,
    );
  }

  /// 帮派联赛赛季结算
  ///
  /// - 组内前 [kGangPromoteRank] 名晋级、[kGangDemoteRank] 名及之后退级
  ///   （金组不再晋级 / 木组不再退级）
  /// - **整季没打过城市之王（封存/未参战）→ 不上榜、不参与升降级**
  /// - **本组上榜帮派不足 80 家 → 本季不判退级**
  /// - 结算时发放赛季奖励（名次越前越高，组别越高越多）
  void settleGangLeague(LifeSimSave save) {
    if (!save.inGang) return;
    final div = gangDivision(save);
    final board = _npcBoardFull(div, save.day);
    if (isGangSealed(save)) {
      _log(
        save,
        '🧊',
        'gang',
        '帮派联赛赛季结束：成员不足 $kGangSealMinMembers 人（已封存），'
            '本季未上榜，不参与升降级',
        'Gang league season ended: sealed (fewer than $kGangSealMinMembers '
            'members), not ranked this season — no promotion or relegation',
      );
      save.gangRankHint = estimateGangRank(save);
      return;
    }
    if (!save.citySeasonFought) {
      _log(
        save,
        '💤',
        'gang',
        '帮派联赛赛季结束：本季一场城市之王都没打，未进入排行榜，'
            '不参与升降级（打过一场才会进榜）',
        'Gang league season ended: no City King battle this season, so the '
            'gang was never ranked — no promotion or relegation',
      );
      save.gangRankHint = estimateGangRank(save);
      return;
    }
    final rank = gangLeagueRank(save);
    final size = board.activeCount + 1;
    // 赛季奖励：名次越前越高、组别越高越多
    final reward = gangLeagueReward(div, rank);
    if (reward.cash > 0 || reward.token > 0 || reward.chests > 0) {
      save.cash += reward.cash;
      save.lifetimeCash += reward.cash;
      save.token += reward.token;
      save.lifetimeToken += reward.token;
      final parts = <String>[
        for (var i = 0; i < reward.chests; i++) _rollPartOfRarity(reward.chestRarityIndex),
      ].where((id) => id.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        grantParts(save, parts);
        save.partsGained += parts.length;
      }
      _log(
        save,
        '🎁',
        'gang',
        '帮派联赛赛季奖励（${div.leagueZh} 第 $rank 名，组别系数 '
            '×${kGangLeagueRewardMul[div]}）：紫票 +${reward.cash}'
            '、代币 +${reward.token}'
            '${parts.isEmpty ? '' : '、${parts.length} 个宝箱部件'}',
        'Gang league season reward (${div.leagueEn} #$rank, '
            '×${kGangLeagueRewardMul[div]}): +${reward.cash} Cash, '
            '+${reward.token} tokens'
            '${parts.isEmpty ? '' : ', ${parts.length} chest part(s)'}',
      );
    }
    if (!board.canDemote) {
      // 上榜帮派不足 80 家 → 本季不判退级
      if (rank <= kGangPromoteRank) {
        final next = div.promoted;
        if (next != null) {
          save.gangDivisionIndex = next.index;
          _log(
            save,
            '🏅',
            'gang',
            '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名 → '
                '**晋级 ${next.leagueZh}**',
            'Gang league season ended: ${div.leagueEn} #$rank/$size → '
                '**promoted to ${next.leagueEn}**',
          );
        }
      } else {
        _log(
          save,
          '🏅',
          'gang',
          '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名（保级）'
              '——本组本季上榜帮派只有 ${board.activeCount} 家（不足 '
              '${kGangDemoteRank - 1} 家），不判退级',
          'Gang league season ended: ${div.leagueEn} #$rank/$size (stayed) — '
              'only ${board.activeCount} ranked gangs this season '
              '(< ${kGangDemoteRank - 1}), so nobody is relegated',
        );
      }
      save.gangRankHint = estimateGangRank(save);
      return;
    }
    if (rank > 0 && rank <= kGangPromoteRank) {
      final next = div.promoted;
      if (next == null) {
        _log(
          save,
          '🏅',
          'gang',
          '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名'
              '（已是最高组别，无法再晋级）',
          'Gang league season ended: ${div.leagueEn} #$rank/$size '
              '(already the top division)',
        );
      } else {
        save.gangDivisionIndex = next.index;
        _log(
          save,
          '🏅',
          'gang',
          '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名 → '
              '**晋级 ${next.leagueZh}**',
          'Gang league season ended: ${div.leagueEn} #$rank/$size → '
              '**promoted to ${next.leagueEn}**',
        );
      }
    } else if (rank >= kGangDemoteRank) {
      final prev = div.demoted;
      if (prev == null) {
        _log(
          save,
          '🏅',
          'gang',
          '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名'
              '（已是最低组别，无法再退级）',
          'Gang league season ended: ${div.leagueEn} #$rank/$size '
              '(already the lowest division)',
        );
      } else {
        save.gangDivisionIndex = prev.index;
        _log(
          save,
          '🏅',
          'gang',
          '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名 → '
              '**退级 ${prev.leagueZh}**',
          'Gang league season ended: ${div.leagueEn} #$rank/$size → '
              '**relegated to ${prev.leagueEn}**',
        );
      }
    } else {
      _log(
        save,
        '🏅',
        'gang',
        '帮派联赛赛季结束：${div.leagueZh} 第 $rank/$size 名（保级）',
        'Gang league season ended: ${div.leagueEn} #$rank/$size (stayed)',
      );
    }
    save.gangRankHint = estimateGangRank(save);
  }

  /// 城市之王赛季的结束天
  static int citySeasonEndDay(int day) =>
      citySeasonStartDay(day) + kCitySeasonDays - 1;

  /// 今天是本赛季第几天（1 起）
  static int citySeasonDay(int day) => day - citySeasonStartDay(day) + 1;

  /// 我方城市之王强度（帮派车辆大小 × 我方活跃度加成）
  int myCityStrength(LifeSimSave save) => gangStrengthOf(
    gangPower: gangPower(save),
    gangActivity: save.gangActivity,
  );

  /// 对手城市之王强度（对手帮派战力 × 对手活跃度加成）
  int oppCityStrength(LifeSimSave save) => gangStrengthOf(
    gangPower: save.cityOpponentPower,
    gangActivity: save.cityOpponentActivity,
  );

  /// 本场胜 / 败的**基础**结算分数（未乘赛季倍率）
  ///
  /// 双方强度越接近，胜负分越接近（均势时相等）；
  /// 差距越大分差越大，单场最高 [kCityMaxScore]。
  ({int win, int loss}) cityBaseScores(LifeSimSave save) => cityBattleScoresOf(
    myStrength: myCityStrength(save),
    oppStrength: oppCityStrength(save),
  );

  /// 提升帮派活跃度：消耗 [kGangActivityEnergyCost] 精力，随机提升
  /// [kGangActivityGainMin]~[kGangActivityGainMax] 点（上限 100）
  ({bool ok, String errorZh, String errorEn, int gained}) boostGangActivity(
    LifeSimSave save,
  ) {
    if (!save.inGang) {
      return (
        ok: false,
        errorZh: '需要先加入或组建帮派',
        errorEn: 'Join or found a gang first',
        gained: 0,
      );
    }
    if (save.gangActivity >= 100) {
      return (
        ok: false,
        errorZh: '帮派活跃度已满（100%）',
        errorEn: 'Gang activity is already at 100%',
        gained: 0,
      );
    }
    if (save.energy < kGangActivityEnergyCost) {
      return (
        ok: false,
        errorZh: '精力不足',
        errorEn: 'Not enough energy',
        gained: 0,
      );
    }
    save.energy -= kGangActivityEnergyCost;
    final roll =
        kGangActivityGainMin +
        _rng.nextInt(kGangActivityGainMax - kGangActivityGainMin + 1);
    final before = save.gangActivity;
    save.gangActivity = min(100, save.gangActivity + roll);
    final gained = save.gangActivity - before;
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '🔥',
      'gang',
      '组织帮派活动：消耗 $kGangActivityEnergyCost 精力，'
          '活跃度 +$gained（当前 ${save.gangActivity}%）',
      'Gang rally: spent $kGangActivityEnergyCost energy, activity +$gained '
          '(now ${save.gangActivity}%)',
    );
    return (ok: true, errorZh: '', errorEn: '', gained: gained);
  }

  /// 当前赛季胜场对应的结算分数倍率
  int cityScoreMul(LifeSimSave save) =>
      cityScoreMultiplier(save.citySeasonWins);

  /// 下一场失利会扣除的帮派活跃度（连败越久扣得越多）
  int nextCityLossPenalty(LifeSimSave save) =>
      kCityLossActivityPenalty +
      min(kCityLossStreakMaxExtra, save.cityLossStreak) * kCityLossStreakExtra;

  /// 下一个未达成的胜场里程碑（全部达成返回 null）
  CityWinMilestone? nextCityMilestone(LifeSimSave save) {
    for (final m in kCityWinMilestones) {
      if (save.citySeasonWins < m.wins) return m;
    }
    return null;
  }

  /// 抽一个指定稀有度下标的部件（城市之王宝箱）
  String _rollPartOfRarity(int rarityIndex) {
    final rarity = Rarity.values[rarityIndex.clamp(
      0,
      Rarity.values.length - 1,
    )];
    final pool = PartDatabase.partsForServer(
      server,
    ).where((p) => p.rarity == rarity).toList();
    if (pool.isEmpty) return '';
    return pool[_rng.nextInt(pool.length)].id;
  }

  /// 领取本赛季已达成但还没领的胜场里程碑（发宝箱 + 代币）
  ///
  /// 返回本次发出的宝箱部件 id（调用方负责 [grantParts]）与代币数量。
  ({List<String> parts, int token}) claimCityMilestones(
    LifeSimSave save, {
    bool silent = false,
  }) {
    final gained = <String>[];
    var tokenGained = 0;
    while (save.citySeasonClaimed < kCityWinMilestones.length &&
        save.citySeasonWins >=
            kCityWinMilestones[save.citySeasonClaimed].wins) {
      final m = kCityWinMilestones[save.citySeasonClaimed];
      final opened = <String>[];
      for (var i = 0; i < m.chestCount; i++) {
        final id = _rollPartOfRarity(m.chestRarityIndex);
        if (id.isNotEmpty) opened.add(id);
      }
      gained.addAll(opened);
      save.token += m.token;
      save.lifetimeToken += m.token;
      tokenGained += m.token;
      save.citySeasonClaimed++;
      if (!silent) {
        _log(
          save,
          '🎁',
          'city',
          '城市之王赛季奖励：${m.wins} 胜 → '
              '${m.chestCount} 个 ${m.chestRarityName} 宝箱 + 代币 ${m.token}'
              '；此后每场结算分数 ×${m.scoreMultiplier}',
          'City King season reward: ${m.wins} wins → '
              '${m.chestCount} × ${m.chestRarityName} chests + ${m.token} tokens; '
              'settlement score ×${m.scoreMultiplier} from now on',
        );
      }
    }
    if (gained.isNotEmpty) {
      save.partsGained += gained.length;
      if (!silent) {
        _log(
          save,
          '📦',
          'city',
          '共开启 ${gained.length} 个宝箱，获得 ${gained.length} 个部件'
              '${tokenGained > 0 ? '、代币 +$tokenGained' : ''}',
          'Opened ${gained.length} chest(s): ${gained.length} part(s)'
              '${tokenGained > 0 ? ', tokens +$tokenGained' : ''}',
        );
      }
    }
    return (parts: gained, token: tokenGained);
  }

  /// 刷新当天的城市之王对手
  ///
  /// **同组别匹配**：只从玩家帮派所在组别的联赛榜单里挑对手（不含自己）。
  void rollCityOpponent(LifeSimSave save) {
    final board = gangBoard(
      save,
    ).where((r) => !r.isPlayer).toList(growable: false);
    if (board.isEmpty) return;
    final row = board[_rng.nextInt(board.length)];
    final gang = gangFromRow(row);
    save.cityOpponentName = gang.name;
    save.cityOpponentCars = _topCars(gang);
    save.cityOpponentActivity = gang.activity;
    save.cityOpponentPower = gang.totalPower;
    save.cityChallenged = false;
  }

  /// 取帮派最强的 3 辆车
  List<int> _topCars(GangInstance gang) {
    final cars = <int>[
      for (final m in gang.members) ...m.carPowers,
    ]..sort((a, b) => b.compareTo(a));
    while (cars.length < 3) {
      cars.add(0);
    }
    return cars.take(3).toList();
  }

  /// 发起城市之王挑战（3v3 逐车对位，胜场多者赢）
  CityKingResult fightCityKing(LifeSimSave save) {
    if (!save.inGang) {
      return const CityKingResult(
        ok: false,
        errorZh: '需要先加入或组建帮派',
        errorEn: 'Join or found a gang first',
      );
    }
    if (isGangSealed(save)) {
      return CityKingResult(
        ok: false,
        errorZh: '帮派成员不足 $kGangSealMinMembers 人（已封存），'
            '无法参加城市之王',
        errorEn: 'Sealed gang: fewer than $kGangSealMinMembers members, '
            'cannot fight City King',
      );
    }
    if (save.cityChallenged) {
      return const CityKingResult(
        ok: false,
        errorZh: '今天已经挑战过了',
        errorEn: 'Already challenged today',
      );
    }
    if (save.energy < kCityEnergyCost) {
      return const CityKingResult(
        ok: false,
        errorZh: '精力不足',
        errorEn: 'Not enough energy',
      );
    }
    save.energy -= kCityEnergyCost;

    final myMul = activityMultiplier(save.gangActivity);
    final oppMul = activityMultiplier(save.cityOpponentActivity);
    final myCars = [
      for (final p in vehiclePowers(save)) (p * myMul).round(),
    ]..sort((a, b) => b.compareTo(a));
    while (myCars.length < 3) {
      myCars.add(0);
    }
    final mine = myCars.take(3).toList();
    final opp = <int>[
      for (var i = 0; i < 3; i++)
        i < save.cityOpponentCars.length
            ? (save.cityOpponentCars[i] * oppMul).round()
            : 0,
    ];

    final rounds = <bool?>[];
    for (var i = 0; i < 3; i++) {
      if (mine[i] == opp[i]) {
        rounds.add(null);
      } else {
        rounds.add(mine[i] > opp[i]);
      }
    }
    final myWins = rounds.where((r) => r == true).length;
    final oppWins = rounds.where((r) => r == false).length;
    final drawCount = rounds.where((r) => r == null).length;
    var draw = false;
    var won = myWins > oppWins;
    if (myWins == oppWins) {
      // 胜场相同（含全平）→ 比双方总战力，再相同则算平局
      final myTotal = mine.fold(0, (a, b) => a + b);
      final oppTotal = opp.fold(0, (a, b) => a + b);
      if (myTotal == oppTotal) {
        draw = true;
        won = false;
      } else {
        won = myTotal > oppTotal;
      }
    }
    final scoreText = '$myWins:$oppWins'
        '${drawCount > 0 ? '（平 $drawCount）' : ''}';
    final scoreTextEn = '$myWins:$oppWins'
        '${drawCount > 0 ? ' ($drawCount drawn)' : ''}';

    final opponentName = save.cityOpponentName ?? '——';
    // 用「打之前」的双方强度算胜负分（本场涨的活跃度不算进来）
    final myStrength = myCityStrength(save);
    final oppStrength = oppCityStrength(save);
    final battleScores = cityBattleScoresOf(
      myStrength: myStrength,
      oppStrength: oppStrength,
    );
    var cash = 0;
    var token = 0;
    var activityGained = 0;
    var hpTools = 0;
    var atkTools = 0;
    final parts = <String>[];
    // 打过一场就算参战 → 本季进入排行榜
    save.citySeasonFought = true;
    if (won) {
      save.cityWins++;
      save.citySeasonWins++;
      cash = 120 + save.cityOpponentPower ~/ 50000;
      token = 60;
      // 战利品部件（重复获得即累积为碎片）
      final lootCount = 1 + (_rng.nextInt(100) < 60 ? 1 : 0);
      for (var i = 0; i < lootCount; i++) {
        final id = rollPart('gp');
        if (id.isNotEmpty) parts.add(id);
      }
      save.partsGained += parts.length;
      save.cash += cash;
      save.lifetimeCash += cash;
      save.token += token;
      save.lifetimeToken += token;
      // 打赢一场士气就回来了
      save.cityLossStreak = 0;
      activityGained = 5;
      save.gangActivity = min(100, save.gangActivity + activityGained);
      // 本赛季超过 [kCityToolboxAfterWins] 胜后，每多赢一场额外给一个工具箱
      if (save.citySeasonWins > kCityToolboxAfterWins) {
        if (_rng.nextBool()) {
          save.hpToolbox++;
          hpTools = 1;
        } else {
          save.atkToolbox++;
          atkTools = 1;
        }
        _log(
          save,
          '🧰',
          'city',
          '本赛季第 ${save.citySeasonWins} 胜：额外获得'
              '「${hpTools > 0 ? '生命' : '攻击'}工具箱」×1'
              '（可用于给对应部件 +$kToolboxBonusPct%，最多叠 $kToolboxMaxStack 层）',
          'Season win #${save.citySeasonWins}: gained a '
              '${hpTools > 0 ? 'HP' : 'ATK'} toolbox (+$kToolboxBonusPct%)',
        );
      }
    } else {
      save.cityLosses++;
      token = 20;
      save.token += token;
      save.lifetimeToken += token;
      if (draw) {
        activityGained = 0;
      } else {
        // 失利打击士气：活跃度下降，连败每多一场多扣一点
        save.cityLossStreak++;
        final penalty =
            kCityLossActivityPenalty +
            min(
              kCityLossStreakMaxExtra,
              save.cityLossStreak - 1,
            ) *
                kCityLossStreakExtra;
        final before = save.gangActivity;
        save.gangActivity = max(0, save.gangActivity - penalty);
        activityGained = save.gangActivity - before;
      }
    }
    save.cityChallenged = true;
    save.gangRankHint = estimateGangRank(save);

    // ---- 赛季结算分数：胜/败基础分（双方强度决定）× 胜场倍率 ----
    // 倍率按「本场结束后的胜场数」取（第 1 胜当场就吃 ×2）
    final baseScore = won ? battleScores.win : battleScores.loss;
    final scoreMul = cityScoreMultiplier(save.citySeasonWins);
    final scoreGained = baseScore * scoreMul;
    save.citySeasonScore += scoreGained;

    // ---- 胜场里程碑：发宝箱 + 代币，并抬高后续每场的倍率 ----
    final chest = claimCityMilestones(save);
    final chestToken = chest.token;

    _log(
      save,
      won ? '🏆' : (draw ? '🤝' : '💢'),
      'city',
      won
          ? '城市之王：战胜「$opponentName」（$scoreText）'
          : draw
          ? '城市之王：与「$opponentName」打成平手（$scoreText）'
          : '城市之王：败给「$opponentName」（$scoreText）',
      won
          ? 'City King: defeated "$opponentName" ($scoreTextEn)'
          : draw
          ? 'City King: drew with "$opponentName" ($scoreTextEn)'
          : 'City King: lost to "$opponentName" ($scoreTextEn)',
    );
    if (parts.isNotEmpty) {
      _log(
        save,
        '🔩',
        'city',
        '城市之王战利品：${parts.length} 个部件',
        'City King loot: ${parts.length} part(s)',
      );
      grantParts(save, parts);
    }
    if (activityGained < 0) {
      _log(
        save,
        '😞',
        'city',
        '连续第 ${save.cityLossStreak} 场失利，帮派士气受挫：'
            '活跃度 $activityGained（当前 ${save.gangActivity}%）——'
            '活跃度会同时拖低帮派战力与结算分数',
        'Loss streak ${save.cityLossStreak}: gang morale hit, activity '
            '$activityGained (now ${save.gangActivity}%)',
      );
    }
    if (chest.parts.isNotEmpty) {
      grantParts(save, chest.parts);
    }
    _log(
      save,
      '📊',
      'city',
      '城市之王赛季分数 +$scoreGained'
          '（${won ? '胜' : '败'}场基础 $baseScore × $scoreMul 倍；'
          '我方强度 $myStrength vs 对手 $oppStrength；'
          '本赛季 ${save.citySeasonWins} 胜、累计 ${save.citySeasonScore} 分）',
      'City King season score +$scoreGained '
          '(${won ? 'win' : 'loss'} base $baseScore × $scoreMul; '
          'my strength $myStrength vs $oppStrength; '
          'season ${save.citySeasonWins} wins, total ${save.citySeasonScore})',
    );
    checkAchievements(save);

    return CityKingResult(
      ok: true,
      won: won,
      draw: draw,
      myCars: mine,
      oppCars: opp,
      rounds: rounds,
      opponentName: opponentName,
      cash: cash,
      token: token,
      parts: parts,
      baseScore: baseScore,
      scoreMultiplier: scoreMul,
      scoreGained: scoreGained,
      myStrength: myStrength,
      oppStrength: oppStrength,
      winScore: battleScores.win,
      lossScore: battleScores.loss,
      seasonWins: save.citySeasonWins,
      seasonScore: save.citySeasonScore,
      chestParts: chest.parts,
      chestToken: chestToken,
      activityGained: activityGained,
      hpToolboxGained: hpTools,
      atkToolboxGained: atkTools,
    );
  }

  // ===================================================================
  // 部件升级
  // ===================================================================

  /// 升级一个部件（消耗 碎片 + 紫票 + 代币，费用表与「碎片计算」一致）
  ///
  /// 碎片来自重复获得的同名部件。
  ({bool ok, String errorZh, String errorEn, int fromLevel, int toLevel})
  upgradePart(LifeSimSave save, String partId) {
    final p = partIndex[partId];
    if (p == null) {
      return (
        ok: false,
        errorZh: '部件不存在',
        errorEn: 'Unknown part',
        fromLevel: 0,
        toLevel: 0,
      );
    }
    final from = save.levelOf(partId).clamp(1, p.maxLevel);
    final cost = upgradeCost(p, from);
    if (cost == null) {
      return (
        ok: false,
        errorZh: '已经是满级（Lv.$from）',
        errorEn: 'Already at max level (Lv.$from)',
        fromLevel: from,
        toLevel: from,
      );
    }
    if (save.stockOf(partId) < cost.pieces) {
      return (
        ok: false,
        errorZh: '碎片不足（需要 ${cost.pieces}，持有 ${save.stockOf(partId)}）',
        errorEn:
            'Not enough fragments (need ${cost.pieces}, have ${save.stockOf(partId)})',
        fromLevel: from,
        toLevel: from,
      );
    }
    if (save.cash < cost.cash) {
      return (
        ok: false,
        errorZh: '紫票不足（需要 ${cost.cash}）',
        errorEn: 'Not enough Cash (need ${cost.cash})',
        fromLevel: from,
        toLevel: from,
      );
    }
    if (save.token < cost.token) {
      return (
        ok: false,
        errorZh: '代币不足（需要 ${cost.token}）',
        errorEn: 'Not enough Tokens (need ${cost.token})',
        fromLevel: from,
        toLevel: from,
      );
    }
    save.partStock[partId] = save.stockOf(partId) - cost.pieces;
    save.cash -= cost.cash;
    save.token -= cost.token;
    save.partLevels[partId] = from + 1;

    final nameZh = _partLabel(partId, true);
    final nameEn = _partLabel(partId, false);
    _log(
      save,
      '⬆️',
      'garage',
      '升级部件：$nameZh Lv.$from → Lv.${from + 1}'
          '（碎片 -${cost.pieces}、紫票 -${cost.cash}、代币 -${cost.token}）',
      'Upgraded $nameEn Lv.$from → Lv.${from + 1}'
          ' (fragments -${cost.pieces}, Cash -${cost.cash}, Tokens -${cost.token})',
    );
    checkAchievements(save);
    return (
      ok: true,
      errorZh: '',
      errorEn: '',
      fromLevel: from,
      toLevel: from + 1,
    );
  }

  /// 批量升级：尽量把 [partId] 升到 [targetLevel]（受资源限制）
  int upgradePartTo(LifeSimSave save, String partId, int targetLevel) {
    var count = 0;
    while (save.levelOf(partId) < targetLevel) {
      final r = upgradePart(save, partId);
      if (!r.ok) break;
      count++;
    }
    return count;
  }

  // ===================================================================
  // 成就
  // ===================================================================

  /// 检查成就，返回本次新解锁的
  List<Achievement> checkAchievements(LifeSimSave save) {
    final power = fleetPower(save);
    final unlocked = <Achievement>[];
    for (final a in kAchievements) {
      if (save.achievements.contains(a.id)) continue;
      bool ok;
      try {
        ok = a.test(save, power);
      } catch (_) {
        ok = false;
      }
      if (ok) {
        save.achievements.add(a.id);
        unlocked.add(a);
      }
    }
    if (unlocked.isNotEmpty) {
      save.gangRankHint = save.inGang ? estimateGangRank(save) : 0;
      for (final a in unlocked) {
        _log(
          save,
          a.icon,
          'achv',
          '达成成就「${a.nameZh}」',
          'Achievement unlocked: "${a.nameEn}"',
        );
      }
    }
    return unlocked;
  }

  // ===================================================================
  // 工具
  // ===================================================================

  void _log(
    LifeSimSave save,
    String icon,
    String kind,
    String zh,
    String en,
  ) {
    save.logs.insert(
      0,
      LogEntry(day: save.day, icon: icon, kind: kind, zh: zh, en: en),
    );
    if (save.logs.length > LifeSimSave.maxLogs) {
      save.logs.removeRange(LifeSimSave.maxLogs, save.logs.length);
    }
  }

  /// 分类中文 / 英文名（日志用）
  static const Map<PartCategory, String> _catZh = <PartCategory, String>{
    PartCategory.body: '车身',
    PartCategory.weapon: '武器',
    PartCategory.wheel: '车轮',
    PartCategory.gadget: '配件',
  };

  static const Map<PartCategory, String> _catEn = <PartCategory, String>{
    PartCategory.body: 'body',
    PartCategory.weapon: 'weapon',
    PartCategory.wheel: 'wheel',
    PartCategory.gadget: 'gadget',
  };

  /// 单个部件的显示名（带稀有度标记：`甲壳虫[R2]`）
  String _partLabel(String id, bool zh) {
    final p = partIndex[id];
    if (p == null) return id;
    final name = zh ? (p.nameZh.isEmpty ? p.name : p.nameZh) : p.name;
    return '$name[R${p.rarity.index + 1}]';
  }

  /// 多个部件的显示名（分隔符按语言区分）
  String partLabels(List<String> ids, bool zh) => ids
      .where((id) => id.isNotEmpty)
      .map((id) => _partLabel(id, zh))
      .join(zh ? '、' : ', ');

  /// 单个部件的显示名（对外，供界面复用）
  String partLabel(String id, bool zh) => _partLabel(id, zh);

  int _between(int lo, int hi) {
    if (hi <= lo) return lo;
    return lo + _rng.nextInt(hi - lo + 1);
  }

  List<int> _randomCarPowers(int lo, int hi) {
    final cars = <int>[for (var i = 0; i < 3; i++) _between(lo, hi)]
      ..sort((a, b) => b.compareTo(a));
    return cars;
  }

  String _randomGangName() {
    final a = kGangNamePrefix[_rng.nextInt(kGangNamePrefix.length)];
    final b = kGangNameSuffix[_rng.nextInt(kGangNameSuffix.length)];
    // 避免与库内固定帮派重名
    final name = '$a$b';
    if (kGangLibrary.any((g) => g.name == name)) {
      return '$name·${_rng.nextInt(99) + 1}';
    }
    return name;
  }

  String _memberName() {
    final p = kMemberNamePrefix[_rng.nextInt(kMemberNamePrefix.length)];
    return '$p${_rng.nextInt(999) + 1}号';
  }
}
