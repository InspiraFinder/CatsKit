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
  CarValidation evaluate(SimVehicle sv, [Map<String, int>? partLevels]) {
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
    );
  }

  /// 单辆车的战力（HP+ATK，未组车返回 0）
  int vehiclePower(SimVehicle sv, [Map<String, int>? partLevels]) {
    if (sv.isEmpty) return 0;
    final v = evaluate(sv, partLevels);
    return (v.hp + v.atk).round();
  }

  /// 每辆车的战力列表（含未组装的 0）
  List<int> vehiclePowers(LifeSimSave save) =>
      [for (final v in save.vehicles) vehiclePower(v, save.partLevels)];

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

  /// 当前周期可用的决策列表
  ///
  /// - 废铁行动：四档固定进度决策
  /// - 齿轮奔袭：四档「战力基础值 × 倍数」决策
  /// - 24h锦标赛+黑市：本期不设活动（空列表，只有看广告）
  /// - 其他活动：通用 3 个 + 专属 1 个
  List<ActivityChoice> choicesFor(String activityId) {
    if (activityId == 'scrap') return kScrapChoices;
    if (activityId == 'gear') return kGearChoices;
    if (activityId == 'allstar') return kAllStarChoices;
    if (activityId == kChampActivityId) return const <ActivityChoice>[];
    return <ActivityChoice>[
      ...kCommonChoices,
      if (kSignatureChoices[activityId] != null) kSignatureChoices[activityId]!,
    ];
  }

  /// 做出一次活动决策
  ChoiceOutcome makeChoice(LifeSimSave save, ActivityChoice choice) {
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

  /// 是否可以看广告（24h锦标赛+黑市、里程碑活动与全明星）
  static bool canWatchAd(String activityId) =>
      activityId == kChampActivityId ||
      isMilestoneActivity(activityId) ||
      isAllStarActivity(activityId);

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

  int _archetypePower(GangArchetype a) {
    final members = (a.memberMin + a.memberMax) / 2;
    final carPower = (a.carPowerMin + a.carPowerMax) / 2;
    return (members * 3 * carPower).round();
  }

  /// 玩家帮派的「大致排名」（与固定帮派库对照；1 = 最强）
  int estimateGangRank(LifeSimSave save) {
    final mine = gangPower(save);
    final sorted = [...kGangLibrary]
      ..sort((a, b) => a.rankHint.compareTo(b.rankHint));
    for (final a in sorted) {
      if (_archetypePower(a) > mine) return a.rankHint;
    }
    return 1;
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

  /// 可加入的帮派候选（固定帮派库 + 2 个随机帮派）
  List<GangInstance> gangCandidates(LifeSimSave save, {int libraryCount = 6}) {
    final list = <GangInstance>[];
    final lib = [...kGangLibrary]..shuffle(_rng);
    for (final a in lib.take(libraryCount)) {
      list.add(generateGang(save, archetype: a));
    }
    list.add(generateGang(save));
    list.add(generateGang(save));
    return list;
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
    save.gangsJoined++;
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '🏛️',
      'gang',
      '你组建了帮派「$trimmed」，花费 $kFoundGangCashCost 紫票',
      'You founded the gang "$trimmed" for $kFoundGangCashCost Cash',
    );
    rollCityOpponent(save);
    checkAchievements(save);
    return (ok: true, errorZh: '', errorEn: '');
  }

  /// 加入一个已有帮派
  ({bool ok, String errorZh, String errorEn}) joinGang(
    LifeSimSave save,
    GangInstance gang,
  ) {
    if (save.inGang) {
      return (
        ok: false,
        errorZh: '你已经在帮派中了',
        errorEn: 'You are already in a gang',
      );
    }
    save.gangName = gang.name;
    save.gangOwned = false;
    save.gangMembers
      ..clear()
      ..addAll(gang.members);
    save.gangActivity = gang.activity;
    save.gangsJoined++;
    save.gangRankHint = estimateGangRank(save);
    _log(
      save,
      '🤝',
      'gang',
      '你加入了帮派「${gang.name}」（${gang.memberCount} 名成员）',
      'You joined the gang "${gang.name}" (${gang.memberCount} members)',
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

  // ===================================================================
  // 城市之王（3v3 逐车对位）
  // ===================================================================

  /// 刷新当天的城市之王对手
  void rollCityOpponent(LifeSimSave save) {
    final useLibrary = kGangLibrary.isNotEmpty && _rng.nextInt(100) < 60;
    final GangInstance gang;
    if (useLibrary) {
      final a = kGangLibrary[_rng.nextInt(kGangLibrary.length)];
      gang = generateGang(save, archetype: a);
    } else {
      gang = generateGang(save);
    }
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
    var cash = 0;
    var token = 0;
    var activityGained = 0;
    final parts = <String>[];
    if (won) {
      save.cityWins++;
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
      activityGained = 5;
      save.gangActivity = min(100, save.gangActivity + activityGained);
    } else {
      save.cityLosses++;
      token = 20;
      save.token += token;
      save.lifetimeToken += token;
      activityGained = 1;
      save.gangActivity = min(100, save.gangActivity + activityGained);
    }
    save.cityChallenged = true;
    save.gangRankHint = estimateGangRank(save);

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
      activityGained: activityGained,
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
