/// 极限数值（离线预计算结果，App 端只做展示，不在设备上计算）
///
/// 数据来源：配套离线程序（`tool/max_fleet.dart` / `max_single.dart` / `verify_atk3.dart`）
///  - 目标 = HP + ATK 之和，部件全部满级、车内与三车之间部件不可重复、电力 ≥ 0
///  - 「工具箱」= 加成道具（游戏内的加成道具/工具箱）
///  - 道具预算：单车 10 个；三车一共 10 个（三辆车共用）
///    HP 道具 +40%（仅非武器部件且每件≤3）、ATK 道具 +150%（每把武器≤1）、
///    插槽激活道具仅车身可用（占 1 个道具，与车身 HP 道具互斥）
///  - 「单车」为搜索 + 穷举校验得到的最优解；「多车」为启发式最优（多车部件分配），
///    多组搜索会落在相差 ≤0.5% 的平台，故可视为下界
library;

/// 道具总预算（单车）；三车类目中为三辆车共用数
const int kStatItemBudget = 10;

/// 工具（加成道具）使用模式
enum ItemMode {
  /// 使用工具箱（不限制，插槽道具用不用都行）
  free('使用工具箱', 'With items'),

  /// 强制使用插槽工具箱（必须用插槽激活道具）
  forceSlot('强制使用插槽工具箱', 'Slot item forced'),

  /// 仅使用插槽工具箱（只用那 1 个插槽激活道具）
  onlySlot('仅使用插槽工具箱', 'Slot item only'),

  /// 不使用工具箱（裸数值）
  none('不使用工具箱', 'No items');

  final String labelZh;
  final String labelEn;
  const ItemMode(this.labelZh, this.labelEn);
}

/// 单个加成道具分配（[pct] = 该部件的额外加成百分比）
class StatItem {
  final String partId;
  final int pct;
  const StatItem(this.partId, this.pct);

  /// 该部件用掉的道具个数（武器 150%/个，其它 40%/个）
  int get count => pct % 150 == 0 ? pct ~/ 150 : pct ~/ 40;
}

/// 一辆车的极限配置与数值
class StatVehicle {
  final String bodyId;
  final String? extraId; // 额外武器（使用插槽激活道具时才有）
  final List<String> weaponIds;
  final List<String> wheelIds;
  final List<String> gadgetIds;
  final double hp;
  final double atk;
  final int netPower; // 净电力（不含额外武器）
  final List<StatItem> items;


  const StatVehicle({
    required this.bodyId,
    this.extraId,
    this.weaponIds = const [],
    this.wheelIds = const [],
    this.gadgetIds = const [],
    required this.hp,
    required this.atk,
    this.netPower = 0,
    this.items = const [],
  });

  double get total => hp + atk;

  bool get useSlotItem => extraId != null;

  int get itemsUsed =>
      (useSlotItem ? 1 : 0) +
      items.fold(0, (int s, StatItem it) => s + it.count);
}

/// 一类极限值 = 车辆数 × 工具模式，含两个服务器的结果
class StatCase {
  final String id;

  /// 车辆数：1 = 单车，3 = 三车
  final int vehCount;
  final ItemMode itemMode;
  final List<StatVehicle> intl;
  final List<StatVehicle> cn;

  /// 离线程序报告中的合计值（用于数据自检，误差容差 ±3）
  final double intlTotalRef;
  final double cnTotalRef;

  const StatCase({
    required this.id,
    required this.vehCount,
    required this.itemMode,
    required this.intl,
    required this.cn,
    required this.intlTotalRef,
    required this.cnTotalRef,
  });

  String get nameZh => '${vehCount == 1 ? '单车' : '三车'} · ${itemMode.labelZh}';
  String get nameEn =>
      '${vehCount == 1 ? '1 car' : '3 cars'} · ${itemMode.labelEn}';

  String get descZh {
    if (itemMode == ItemMode.none) return '完全不使用加成道具（裸数值）';
    if (itemMode == ItemMode.onlySlot) {
      return vehCount > 1 ? '只允许那 1 个插槽激活道具（三辆车共用）' : '只允许那 1 个插槽激活道具';
    }
    final base = vehCount > 1 ? '三辆车共用 10 个加成道具' : '10 个加成道具';
    if (itemMode == ItemMode.forceSlot) return '$base，且必须使用插槽激活道具';
    return '$base（插槽道具用不用都行，取最优）';
  }

  String get descEn {
    if (itemMode == ItemMode.none) return 'No bonus items at all (raw stats)';
    if (itemMode == ItemMode.onlySlot) {
      return vehCount > 1
          ? 'Only the single slot-activation item (shared by 3 cars)'
          : 'Only the single slot-activation item';
    }
    final base = vehCount > 1
        ? '10 bonus items shared by the 3 cars'
        : '10 bonus items';
    if (itemMode == ItemMode.forceSlot) {
      return '$base, slot-activation item required';
    }
    return '$base (slot item optional, best of both)';
  }

  /// 该类别下多车是否共用道具预算
  bool get sharedItems => vehCount > 1 && itemMode != ItemMode.none;

  /// 道具总预算（单车 10；三车共用 10；仅插槽 1；无道具 0）
  int get itemBudget {
    switch (itemMode) {
      case ItemMode.none:
        return 0;
      case ItemMode.onlySlot:
        return 1;
      default:
        return kStatItemBudget;
    }
  }

  double _sum(List<StatVehicle> vs, double Function(StatVehicle) f) =>
      vs.fold(0.0, (double s, StatVehicle v) => s + f(v));

  double hpOf(String server) => _sum(server == 'cn' ? cn : intl, (v) => v.hp);
  double atkOf(String server) => _sum(server == 'cn' ? cn : intl, (v) => v.atk);
  double totalOf(String server) => hpOf(server) + atkOf(server);
  List<StatVehicle> vehiclesOf(String server) => server == 'cn' ? cn : intl;
}

/// 全部类别（单车/三车 × 4 种工具模式）
///
/// 数值由 `tool/max_fleet.dart`（同一套联合搜索）算出；三车类目里
/// 「使用工具箱」与「强制使用插槽工具箱」相同，是因为最优解本来就用了插槽道具。
/// 2026-10-29：按国际服 10-29 平衡调整后的部件数值重新计算。
const List<StatCase> kStatCases = [
// ───────── 单车 · 使用工具箱（10 个道具，插槽道具可选） ─────────
  StatCase(
    id: 'solo_free',
    vehCount: 1,
    itemMode: ItemMode.free,
    intlTotalRef: 10684901,
    cnTotalRef: 9363835,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        extraId: 'mystic_slime',
        weaponIds: ['mad_panda', 'blazing_dragon', 'sea_monster'],
        wheelIds: ['seashell_roller', 'coconut_knob', 'sand_tire'],
        gadgetIds: ['kitty_ghost', 'swapper'],
        hp: 4463513,
        atk: 6221387,
        items: [StatItem('mystic_slime', 150), StatItem('mad_panda', 150), StatItem('blazing_dragon', 150), StatItem('sea_monster', 150), StatItem('kitty_ghost', 120), StatItem('swapper', 80)],
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['hairball_thrower', 'blazing_dragon'],
        wheelIds: ['red_flame_wheel', 'flowing_light_wheel', 'seashell_roller'],
        gadgetIds: ['healing_drone', 'nirvana_stone'],
        hp: 7923870,
        atk: 1439965,
        items: [StatItem('iron_maiden', 120), StatItem('hairball_thrower', 150), StatItem('blazing_dragon', 150), StatItem('red_flame_wheel', 80), StatItem('flowing_light_wheel', 120)],
      ),
    ],
  ),

// ───────── 单车 · 强制使用插槽工具箱 ─────────
  StatCase(
    id: 'solo_force',
    vehCount: 1,
    itemMode: ItemMode.forceSlot,
    intlTotalRef: 10684901,
    cnTotalRef: 9205864,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        extraId: 'mad_panda',
        weaponIds: ['mystic_slime', 'blazing_dragon', 'sea_monster'],
        wheelIds: ['seashell_roller', 'coconut_knob', 'sand_tire'],
        gadgetIds: ['kitty_ghost', 'swapper'],
        hp: 4463513,
        atk: 6221387,
        items: [StatItem('mad_panda', 150), StatItem('mystic_slime', 150), StatItem('blazing_dragon', 150), StatItem('sea_monster', 150), StatItem('kitty_ghost', 120), StatItem('swapper', 80)],
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'tubby_bus',
        extraId: 'gumball_gun',
        weaponIds: ['falling_feather', 'sea_monster'],
        wheelIds: ['flowing_light_wheel', 'biscuit_booster_roller', 'seashell_roller'],
        gadgetIds: ['squid_cannon', 'coffee_cup'],
        hp: 5788047,
        atk: 3417817,
        netPower: 5,
        items: [StatItem('gumball_gun', 150), StatItem('falling_feather', 150), StatItem('sea_monster', 150), StatItem('flowing_light_wheel', 120), StatItem('biscuit_booster_roller', 120)],
      ),
    ],
  ),

// ───────── 单车 · 仅使用插槽工具箱（只有 1 个插槽道具） ─────────
  StatCase(
    id: 'solo_only',
    vehCount: 1,
    itemMode: ItemMode.onlySlot,
    intlTotalRef: 5783298,
    cnTotalRef: 5716770,
    intl: [
      StatVehicle(
        bodyId: 'tubby_bus',
        extraId: 'mad_panda',
        weaponIds: ['eel', 'sea_monster'],
        wheelIds: ['seashell_roller', 'coconut_knob', 'sand_tire'],
        gadgetIds: ['voodoo_doll', 'squid_cannon', 'slug_snot'],
        hp: 4475153,
        atk: 1308144,
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'iron_maiden',
        extraId: 'falling_feather',
        weaponIds: ['blazing_dragon', 'sea_monster'],
        wheelIds: ['red_flame_wheel', 'flowing_light_wheel', 'seashell_roller'],
        gadgetIds: ['swapper', 'squid_cannon'],
        hp: 4535614,
        atk: 1181156,
      ),
    ],
  ),

// ───────── 单车 · 不使用工具箱（裸数值） ─────────
  StatCase(
    id: 'solo_none',
    vehCount: 1,
    itemMode: ItemMode.none,
    intlTotalRef: 5060895,
    cnTotalRef: 5115347,
    intl: [
      StatVehicle(
        bodyId: 'tubby_bus',
        weaponIds: ['eel', 'sea_monster'],
        wheelIds: ['seashell_roller', 'sand_tire', 'coconut_knob'],
        gadgetIds: ['squid_cannon', 'voodoo_doll', 'slug_snot'],
        hp: 4315326,
        atk: 745568,
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['robot_head', 'blazing_dragon'],
        wheelIds: ['red_flame_wheel', 'flowing_light_wheel', 'seashell_roller'],
        gadgetIds: ['squid_cannon', 'swapper'],
        hp: 4459845,
        atk: 655502,
      ),
    ],
  ),

// ───────── 三车 · 使用工具箱（三车共用 10 个道具） ─────────
  StatCase(
    id: 'three_free',
    vehCount: 3,
    itemMode: ItemMode.free,
    intlTotalRef: 22555900,
    cnTotalRef: 21201856,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        extraId: 'mystic_slime',
        weaponIds: ['mad_panda', 'blazing_dragon', 'sea_monster'],
        wheelIds: ['seashell_roller', 'onion_thruster', 'sand_tire'],
        gadgetIds: ['kitty_ghost', 'swapper'],
        hp: 2991395,
        atk: 6588053,
        items: [StatItem('mystic_slime', 150), StatItem('mad_panda', 150), StatItem('blazing_dragon', 150), StatItem('sea_monster', 150)],
      ),
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['kitty_orb', 'hairball_thrower'],
        wheelIds: ['sand_scooter', 'flower_hover'],
        gadgetIds: ['deflecting_shield', 'healing_drone'],
        hp: 6709365,
        atk: 521612,
        netPower: 5,
        items: [StatItem('iron_maiden', 120)],
      ),
      StatVehicle(
        bodyId: 'tubby_bus',
        extraId: 'gumball_gun',
        weaponIds: ['bats', 'eel'],
        wheelIds: ['coconut_knob', 'big_pumpkin_wheel', 'small_pumpkin_wheel'],
        gadgetIds: ['coffee_cup', 'squid_cannon', 'voodoo_doll'],
        hp: 3921186,
        atk: 1824290,
        items: [StatItem('gumball_gun', 150)],
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'popsicle_beast',
        extraId: 'falling_feather',
        weaponIds: ['eel', 'sea_monster', 'gumball_gun'],
        wheelIds: ['seashell_roller', 'biscuit_booster_roller'],
        gadgetIds: ['meow_lantern', 'coffee_cup'],
        hp: 2682256,
        atk: 5384338,
        items: [StatItem('falling_feather', 150), StatItem('eel', 150), StatItem('sea_monster', 150), StatItem('gumball_gun', 150)],
      ),
      StatVehicle(
        bodyId: 'green_dragon',
        weaponIds: ['acid_alien', 'bats'],
        wheelIds: ['flowing_light_wheel', 'red_flame_wheel', 'sand_scooter'],
        gadgetIds: ['healing_drone', 'water_blaster'],
        hp: 6435248,
        atk: 498485,
        netPower: 5,
        items: [StatItem('green_dragon', 120)],
      ),
      StatVehicle(
        bodyId: 'shadow_cavalry',
        extraId: 'blazing_dragon',
        weaponIds: ['spicy_barrage'],
        wheelIds: ['donuts_sticky_roller', 'coconut_knob'],
        gadgetIds: ['voodoo_doll', 'nirvana_stone', 'swapper', 'squid_cannon'],
        hp: 4893261,
        atk: 1308268,
        items: [StatItem('blazing_dragon', 150)],
      ),
    ],
  ),

// ───────── 三车 · 强制使用插槽工具箱 ─────────
  StatCase(
    id: 'three_force',
    vehCount: 3,
    itemMode: ItemMode.forceSlot,
    intlTotalRef: 22508061,
    cnTotalRef: 21201856,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        extraId: 'mystic_slime',
        weaponIds: ['blazing_dragon', 'sea_monster', 'mad_panda'],
        wheelIds: ['seashell_roller', 'sand_tire', 'onion_thruster'],
        gadgetIds: ['kitty_ghost', 'swapper'],
        hp: 2991395,
        atk: 6588053,
        items: [StatItem('mystic_slime', 150), StatItem('blazing_dragon', 150), StatItem('sea_monster', 150), StatItem('mad_panda', 150)],
      ),
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['kitty_orb', 'hairball_thrower'],
        wheelIds: ['life_scooter', 'space_knob'],
        gadgetIds: ['deflecting_shield', '5_alarm_engine'],
        hp: 6589852,
        atk: 490424,
        items: [StatItem('iron_maiden', 120)],
      ),
      StatVehicle(
        bodyId: 'tubby_bus',
        extraId: 'gumball_gun',
        weaponIds: ['eel', 'bento_drone'],
        wheelIds: ['coconut_knob', 'big_pumpkin_wheel', 'sand_scooter'],
        gadgetIds: ['coffee_cup', 'squid_cannon', 'voodoo_doll'],
        hp: 4192655,
        atk: 1655683,
        items: [StatItem('gumball_gun', 150)],
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'popsicle_beast',
        extraId: 'falling_feather',
        weaponIds: ['eel', 'sea_monster', 'gumball_gun'],
        wheelIds: ['seashell_roller', 'biscuit_booster_roller'],
        gadgetIds: ['meow_lantern', 'coffee_cup'],
        hp: 2682256,
        atk: 5384338,
        items: [StatItem('falling_feather', 150), StatItem('eel', 150), StatItem('sea_monster', 150), StatItem('gumball_gun', 150)],
      ),
      StatVehicle(
        bodyId: 'green_dragon',
        weaponIds: ['acid_alien', 'bats'],
        wheelIds: ['flowing_light_wheel', 'red_flame_wheel', 'sand_scooter'],
        gadgetIds: ['healing_drone', 'water_blaster'],
        hp: 6435248,
        atk: 498485,
        netPower: 5,
        items: [StatItem('green_dragon', 120)],
      ),
      StatVehicle(
        bodyId: 'shadow_cavalry',
        extraId: 'blazing_dragon',
        weaponIds: ['spicy_barrage'],
        wheelIds: ['donuts_sticky_roller', 'coconut_knob'],
        gadgetIds: ['voodoo_doll', 'nirvana_stone', 'swapper', 'squid_cannon'],
        hp: 4893261,
        atk: 1308268,
        items: [StatItem('blazing_dragon', 150)],
      ),
    ],
  ),

// ───────── 三车 · 仅使用插槽工具箱（三车共用那 1 个插槽道具） ─────────
  StatCase(
    id: 'three_only',
    vehCount: 3,
    itemMode: ItemMode.onlySlot,
    intlTotalRef: 14500404,
    cnTotalRef: 14793384,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        extraId: 'sea_monster',
        weaponIds: ['blazing_dragon', 'mad_panda', 'mystic_slime'],
        wheelIds: ['seashell_roller', 'sand_tire', 'onion_thruster'],
        gadgetIds: ['kitty_ghost', 'slug_snot'],
        hp: 3015615,
        atk: 2518929,
        netPower: 5,
      ),
      StatVehicle(
        bodyId: 'tubby_bus',
        weaponIds: ['eel', 'bento_drone'],
        wheelIds: ['coconut_knob', 'big_pumpkin_wheel', 'sand_scooter'],
        gadgetIds: ['squid_cannon', 'voodoo_doll', 'coffee_cup'],
        hp: 4042918,
        atk: 649592,
      ),
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['kitty_orb', 'hairball_thrower'],
        wheelIds: ['life_scooter', 'space_knob'],
        gadgetIds: ['deflecting_shield', 'swapper'],
        hp: 3712305,
        atk: 561045,
        netPower: 5,
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'green_dragon',
        weaponIds: ['sea_monster', 'bats'],
        wheelIds: ['red_flame_wheel', 'flowing_light_wheel', 'seashell_roller'],
        gadgetIds: ['squid_cannon', 'water_blaster'],
        hp: 4333605,
        atk: 610286,
      ),
      StatVehicle(
        bodyId: 'shadow_cavalry',
        extraId: 'blazing_dragon',
        weaponIds: ['robot_head'],
        wheelIds: ['donuts_sticky_roller', 'biscuit_booster_roller'],
        gadgetIds: ['swapper', 'voodoo_doll', 'deflecting_shield', 'coffee_cup'],
        hp: 4704549,
        atk: 871314,
        netPower: 10,
      ),
      StatVehicle(
        bodyId: 'fire_phoenix',
        weaponIds: ['acid_alien', 'kappa_drone'],
        wheelIds: ['coconut_knob', 'sand_scooter'],
        gadgetIds: ['nirvana_stone', 'geyser', 'healing_drone'],
        hp: 3728231,
        atk: 545399,
      ),
    ],
  ),

// ───────── 三车 · 不使用工具箱（裸数值） ─────────
  StatCase(
    id: 'three_none',
    vehCount: 3,
    itemMode: ItemMode.none,
    intlTotalRef: 13707075,
    cnTotalRef: 14153887,
    intl: [
      StatVehicle(
        bodyId: 'ram',
        weaponIds: ['sea_monster', 'blazing_dragon', 'mad_panda'],
        wheelIds: ['onion_thruster', 'sand_tire', 'seashell_roller'],
        gadgetIds: ['swapper', 'kitty_ghost'],
        hp: 2884559,
        atk: 1853044,
      ),
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['kitty_orb', 'bats'],
        wheelIds: ['sand_scooter', 'flower_hover'],
        gadgetIds: ['deflecting_shield', 'healing_drone'],
        hp: 3773438,
        atk: 521612,
        netPower: 5,
      ),
      StatVehicle(
        bodyId: 'tubby_bus',
        weaponIds: ['eel', 'bento_drone'],
        wheelIds: ['big_pumpkin_wheel', 'coconut_knob', 'nigiri_knob'],
        gadgetIds: ['slug_snot', 'squid_cannon', 'voodoo_doll'],
        hp: 4094474,
        atk: 579948,
      ),
    ],
    cn: [
      StatVehicle(
        bodyId: 'fire_phoenix',
        weaponIds: ['bento_drone', 'eel'],
        wheelIds: ['biscuit_booster_roller', 'coconut_knob'],
        gadgetIds: ['nirvana_stone', 'voodoo_doll', 'coffee_cup'],
        hp: 3859919,
        atk: 625940,
      ),
      StatVehicle(
        bodyId: 'shadow_cavalry',
        weaponIds: ['robot_head'],
        wheelIds: ['donuts_sticky_roller', 'nigiri_knob'],
        gadgetIds: ['enrager', 'deflecting_shield', 'swapper', 'hungry_hook'],
        hp: 4258669,
        atk: 305919,
      ),
      StatVehicle(
        bodyId: 'iron_maiden',
        weaponIds: ['blazing_dragon', 'hairball_thrower'],
        wheelIds: ['flowing_light_wheel', 'seashell_roller', 'red_flame_wheel'],
        gadgetIds: ['squid_cannon', 'healing_drone'],
        hp: 4527454,
        atk: 575986,
      ),
    ],
  ),
];
