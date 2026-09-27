/// 「猫生重开」帮派联赛 —— **模拟系统**
///
/// 这个文件把帮派世界的模拟逻辑从"离线跑一次"变成程序的一部分：
/// - [generateGangDivisionSeeds]：按平衡参数生成某个组别的帮派名册
///   （离线跑一次的结果就是 `gang_league_roster.dart`，也就是游戏里的
///   **帮派初始数据**）
/// - [gangRosterDartSource]：把生成结果导出成 Dart 源码（用于重新生成名册）
/// - [simulateGangLeague] / [gangLeagueSimReport]：跑一次统计模拟，
///   输出每个组别的数量、封存/缺人、各名次区间的战力 / 成员 / 活跃度 /
///   工具包 / 单车战力，以及帮派指挥的决策分布
library;

import 'dart:math';

import 'gang_league_roster.dart';
import 'life_sim_data.dart';

/// 生成某个组别的帮派名册
///
/// 名次越前战力越高（在组别战力区间上按对数插值），
/// 成员数 / 活跃度 / 工具包 / 指挥水平都由战力决定，
/// 最后做「名次越前成员越多」的单调修正。
List<GangSeed> generateGangDivisionSeeds({
  required GangDivision division,
  required int seed,
  int? count,
}) {
  final rng = Random(seed);
  final band = kGangDivisionPower[division]!;
  final countBand = kGangDivisionGangCount[division]!;
  final total =
      count ?? (countBand.min + rng.nextInt(countBand.max - countBand.min + 1));
  final logHi = log(band.max.toDouble());
  final logLo = log(band.min.toDouble());
  final usedNames = <String>{};

  final rows = <GangSeed>[];
  for (var i = 0; i < total; i++) {
    final t = total == 1 ? 0.0 : i / (total - 1);
    final base = exp(logHi - (logHi - logLo) * t);
    final jitter = 0.94 + rng.nextDouble() * 0.12;
    var name = randomGangName(rng);
    var guard = 0;
    while (usedNames.contains(name) && guard < 20) {
      name = randomGangName(rng);
      guard++;
    }
    usedNames.add(name);
    final basePower = base.round();
    final members =
        (gangMembersForPower(basePower) * (0.96 + rng.nextDouble() * 0.04))
            .round()
            .clamp(1, kGangMaxMembers);
    final activity = (gangActivityForPower(basePower) + rng.nextInt(7) - 3)
        .clamp(1, 99);
    final toolkits = (gangToolkitsForPower(basePower) + rng.nextInt(3) - 1)
        .clamp(0, kGangToolkitMax);
    final skill =
        (kGangCommanderSkillMin +
                (kGangCommanderSkillMax - kGangCommanderSkillMin) *
                    (0.35 + 0.65 * (1 - t)) *
                    (0.85 + rng.nextDouble() * 0.3))
            .round()
            .clamp(kGangCommanderSkillMin, kGangCommanderSkillMax);
    rows.add((
      name: name,
      power: max(1, (base * jitter).round()),
      members: members,
      activity: activity,
      toolkits: toolkits,
      skill: skill,
    ));
  }
  rows.sort((a, b) => b.power.compareTo(a.power));
  // 名次越前成员越多
  var prev = kGangMaxMembers;
  for (var i = 0; i < rows.length; i++) {
    final m = min(prev, rows[i].members);
    prev = m;
    rows[i] = (
      name: rows[i].name,
      power: rows[i].power,
      members: m,
      activity: rows[i].activity,
      toolkits: rows[i].toolkits,
      skill: rows[i].skill,
    );
  }
  return rows;
}

/// 把名册导出成 Dart 源码（可直接覆盖 `gang_league_roster.dart`）
String gangRosterDartSource({
  int goldSeed = 20260927,
  int silverSeed = 20260928,
  int bronzeSeed = 20260929,
  int woodSeed = 20260930,
}) {
  final seeds = <GangDivision, int>{
    GangDivision.gold: goldSeed,
    GangDivision.silver: silverSeed,
    GangDivision.bronze: bronzeSeed,
    GangDivision.wood: woodSeed,
  };
  final out = StringBuffer()
    ..writeln('// 由 lib/life_sim/gang_league_sim.dart 的 gangRosterDartSource() 生成，勿手改。')
    ..writeln('//')
    ..writeln('// 帮派联赛的**初始名册**：每个组别的帮派数量、战力、成员数、活跃度、')
    ..writeln('// 成员平均工具包数量、指挥水平都来自离线模拟（平衡参数见 life_sim_data.dart）。')
    ..writeln('//')
    ..writeln('// 运行时每赛季会在这些数值上做小幅浮动（战力 ±5%）、随机让一部分帮派')
    ..writeln('// 「主动封存」不上榜（下赛季可能解封复活），所以同一批帮派会长期存在。')
    ..writeln()
    ..writeln('/// 名册里的一项')
    ..writeln('typedef GangSeed = ({')
    ..writeln('  String name,')
    ..writeln('  int power,')
    ..writeln('  int members,')
    ..writeln('  int activity,')
    ..writeln('  int toolkits,')
    ..writeln('  int skill,')
    ..writeln('});')
    ..writeln();
  for (final d in <GangDivision>[
    GangDivision.gold,
    GangDivision.silver,
    GangDivision.bronze,
    GangDivision.wood,
  ]) {
    final rows = generateGangDivisionSeeds(division: d, seed: seeds[d]!);
    final band = kGangDivisionPower[d]!;
    final name = 'kGangSeed${d.name[0].toUpperCase()}${d.name.substring(1)}';
    out.writeln('/// ${d.leagueZh}：${rows.length} 家（战力 '
        '${band.min}-${band.max}）');
    out.writeln('const List<GangSeed> $name = <GangSeed>[');
    for (final r in rows) {
      out.writeln(
        "  (name: '${r.name}', power: ${r.power}, members: ${r.members}, "
        'activity: ${r.activity}, toolkits: ${r.toolkits}, '
        'skill: ${r.skill}),',
      );
    }
    out.writeln('];');
    out.writeln();
  }
  return out.toString();
}

/// 某个组别名次区间的模拟统计
class GangSimBand {
  final String label;
  final int powerMin;
  final int powerMax;
  final int powerAvg;
  final int membersMin;
  final int membersMax;
  final int activityMin;
  final int activityMax;
  final int toolkitsMin;
  final int toolkitsMax;
  final double toolkitsAvg;
  final int carPowerMin;
  final int carPowerMax;

  const GangSimBand({
    required this.label,
    required this.powerMin,
    required this.powerMax,
    required this.powerAvg,
    required this.membersMin,
    required this.membersMax,
    required this.activityMin,
    required this.activityMax,
    required this.toolkitsMin,
    required this.toolkitsMax,
    required this.toolkitsAvg,
    required this.carPowerMin,
    required this.carPowerMax,
  });
}

/// 某个组别的模拟统计
class GangSimDivision {
  final GangDivision division;
  final int totalMin;
  final int totalMax;
  final int sealedMin;
  final int sealedMax;
  final int shortHandedMin;
  final int shortHandedMax;
  final int rankedMin;
  final int rankedMax;
  final List<GangSimBand> bands;

  const GangSimDivision({
    required this.division,
    required this.totalMin,
    required this.totalMax,
    required this.sealedMin,
    required this.sealedMax,
    required this.shortHandedMin,
    required this.shortHandedMax,
    required this.rankedMin,
    required this.rankedMax,
    required this.bands,
  });

  /// 本季上榜家数是否可能不足 80（不足就不判退级）
  bool get demotionPossible => rankedMin + 1 >= kGangDemoteRank - 1;
}

/// 跑一次帮派联赛模拟（默认 6 个种子 × 8 个赛季，取真实榜单统计）
List<GangSimDivision> simulateGangLeague({int seeds = 6, int seasons = 8}) {
  const seedList = <int>[7, 42, 123, 999, 2024, 31337];
  final out = <GangSimDivision>[];
  for (final d in <GangDivision>[
    GangDivision.gold,
    GangDivision.silver,
    GangDivision.bronze,
    GangDivision.wood,
  ]) {
    var tMin = 1 << 62, tMax = 0, sMin = 1 << 62, sMax = 0;
    var hMin = 1 << 62, hMax = 0, aMin = 1 << 62, aMax = 0;
    for (final seed in seedList.take(seeds)) {
      for (var season = 0; season < seasons; season++) {
        final b = buildGangDivisionBoard(
          division: d,
          seed: seed,
          seasonIndex: season,
        );
        tMin = min(tMin, b.total);
        tMax = max(tMax, b.total);
        sMin = min(sMin, b.sealedCount);
        sMax = max(sMax, b.sealedCount);
        hMin = min(hMin, b.shortHandedCount);
        hMax = max(hMax, b.shortHandedCount);
        aMin = min(aMin, b.activeCount);
        aMax = max(aMax, b.activeCount);
      }
    }

    final bands = <GangSimBand>[];
    for (final band in gangRankBands(d)) {
      var pMin = 1 << 62, pMax = 0, pSum = 0, n = 0;
      var mMin = 1 << 62, mMax = 0;
      var a0Min = 1 << 62, a0Max = 0;
      var kMin = 1 << 62, kMax = 0, kSum = 0;
      var cMin = 1 << 62, cMax = 0;
      for (final seed in seedList.take(seeds)) {
        for (var season = 0; season < seasons; season++) {
          final board = buildGangDivisionBoard(
            division: d,
            seed: seed,
            seasonIndex: season,
          );
          for (final r in board.rows) {
            if (r.rank < band.min || r.rank > band.max) continue;
            pMin = min(pMin, r.power);
            pMax = max(pMax, r.power);
            pSum += r.power;
            n++;
            mMin = min(mMin, r.members);
            mMax = max(mMax, r.members);
            a0Min = min(a0Min, r.activity);
            a0Max = max(a0Max, r.activity);
            kMin = min(kMin, r.toolkits);
            kMax = max(kMax, r.toolkits);
            kSum += r.toolkits;
            final pc = r.power ~/ max(1, r.members) ~/ 3;
            cMin = min(cMin, pc);
            cMax = max(cMax, pc);
          }
        }
      }
      if (n == 0) continue;
      final label = band.max >= kGangOpenBandMax
          ? '${band.min}+'
          : '${band.min}-${band.max}';
      bands.add(
        GangSimBand(
          label: label,
          powerMin: pMin,
          powerMax: pMax,
          powerAvg: pSum ~/ n,
          membersMin: mMin,
          membersMax: mMax,
          activityMin: a0Min,
          activityMax: a0Max,
          toolkitsMin: kMin,
          toolkitsMax: kMax,
          toolkitsAvg: kSum / n,
          carPowerMin: cMin == 1 << 62 ? 0 : cMin,
          carPowerMax: cMax,
        ),
      );
    }
    out.add(
      GangSimDivision(
        division: d,
        totalMin: tMin,
        totalMax: tMax,
        sealedMin: sMin,
        sealedMax: sMax,
        shortHandedMin: hMin,
        shortHandedMax: hMax,
        rankedMin: aMin,
        rankedMax: aMax,
        bands: bands,
      ),
    );
  }
  return out;
}

/// 帮派指挥的决策分布（在给定局面下用几个工具包的次数分布）
List<int> commanderDecisionDistribution({
  required int rankDiff,
  required int stock,
  required int skill,
  int samples = 200,
  int seed = 1,
}) {
  final rng = Random(seed);
  final counts = List<int>.filled(stock + 1, 0);
  for (var i = 0; i < samples; i++) {
    final rng2 = Random(rng.nextInt(1 << 30));
    final used = commanderToolkitsPreview(
      rankDiff: rankDiff,
      stock: stock,
      skill: skill,
      rng: rng2,
    );
    counts[used.clamp(0, stock)]++;
  }
  return counts;
}

/// 指挥决策的纯函数版本（方便模拟/测试；语义同引擎里的 commanderToolkits）
int commanderToolkitsPreview({
  required int rankDiff,
  required int stock,
  required int skill,
  required Random rng,
}) {
  if (stock <= 0) return 0;
  var need = 0;
  if (rankDiff < 0) {
    need = (-rankDiff / kGangToolkitRankStep).ceil();
  } else if (rankDiff <= 5) {
    need = 1;
  }
  if (rng.nextDouble() < (100 - skill) / 100.0) {
    need += rng.nextInt(3) - 1;
    if (skill < 50 && rng.nextBool()) need += rng.nextInt(2) + 1;
  }
  return need.clamp(0, stock);
}

/// 生成完整报告文本（界面里直接显示 / 方便贴出来讨论）
String gangLeagueSimReport({int seeds = 6, int seasons = 8}) {
  final out = StringBuffer();
  final divisions = simulateGangLeague(seeds: seeds, seasons: seasons);
  for (final d in divisions) {
    out.writeln(
      '【${d.division.leagueZh}】共 ${d.totalMin}-${d.totalMax} 家 · '
      '主动封存 ${d.sealedMin}-${d.sealedMax} · '
      '缺人 ${d.shortHandedMin}-${d.shortHandedMax} · '
      '上榜 ${d.rankedMin}-${d.rankedMax}'
      '${d.demotionPossible ? '' : '（不足 80 家 → 本季不判退级）'}',
    );
    for (final b in d.bands) {
      out.writeln(
        '  第 ${b.label} 名：战力 ${b.powerMin}-${b.powerMax}'
        '（均 ${b.powerAvg}）· 成员 ${b.membersMin}-${b.membersMax}'
        ' · 活跃 ${b.activityMin}-${b.activityMax}%'
        ' · 工具包 ${b.toolkitsMin}-${b.toolkitsMax}'
        '（均 ${b.toolkitsAvg.toStringAsFixed(1)}）'
        ' · 单车 ${b.carPowerMin}-${b.carPowerMax}',
      );
    }
  }
  out.writeln();
  out.writeln('指挥决策（存量 3，每格 200 次采样）：用了几个工具包');
  for (final diff in <int>[-40, -16, -8, -2, 6, 30]) {
    out.write(
      '  ${diff < 0 ? '对手强 ${diff.abs()}' : '对手弱 $diff'} 名：',
    );
    for (final skill in <int>[kGangCommanderSkillMin, 60, kGangCommanderSkillMax]) {
      final dist = commanderDecisionDistribution(
        rankDiff: diff,
        stock: 3,
        skill: skill,
      );
      out.write(' 水平$skill→${dist.join('/')}');
    }
    out.writeln();
  }
  return out.toString();
}
