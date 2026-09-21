/// 「猫生重开」模拟器（CatsKit 2.0） —— 主界面
///
/// 五个分页：今日（活动决策 / 城市之王）、车库（组车）、帮派、成就、日志。
/// 所有规则都由 [LifeSimEngine] 负责，本文件只做展示与交互。
library;

import 'package:flutter/material.dart';

import '../parts_data.dart';
import 'life_sim_data.dart';
import 'life_sim_engine.dart';
import 'life_sim_models.dart';
import 'life_sim_store.dart';

class LifeSimScreen extends StatefulWidget {
  final String locale;
  final String server;

  /// 是否深色模式（由主菜单传入，仅用于自定义配色）
  final bool darkMode;

  const LifeSimScreen({
    super.key,
    this.locale = 'zh',
    this.server = 'cn',
    this.darkMode = false,
  });

  @override
  State<LifeSimScreen> createState() => _LifeSimScreenState();
}

class _LifeSimScreenState extends State<LifeSimScreen> {
  late String _locale;
  late LifeSimEngine _engine;
  LifeSimSave? _save;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _locale = widget.locale;
    _engine = LifeSimEngine(server: widget.server);
    _load();
  }

  @override
  void didUpdateWidget(LifeSimScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.locale != oldWidget.locale) _locale = widget.locale;
    if (widget.server != oldWidget.server) {
      _engine = LifeSimEngine(server: widget.server);
    }
  }

  String _t(String zh, String en) => _locale == 'zh' ? zh : en;

  Future<void> _load() async {
    final loaded = await LifeSimStore.load();
    if (!mounted) return;
    setState(() {
      _save = loaded;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    final s = _save;
    if (s != null) await LifeSimStore.save(s);
  }

  /// 统一的「执行操作 → 落盘 → 刷新」流程
  void _run(void Function() action) {
    action();
    setState(() {});
    _persist();
  }

  String _fmt(num v) {
    final s = v.round().abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return (v < 0 ? '-' : '') + buf.toString();
  }

  String _pn(PartData p) =>
      _locale == 'zh' && p.nameZh.isNotEmpty ? p.nameZh : p.name;

  // ===================================================================
  // 顶部状态栏
  // ===================================================================

  Widget _buildStatusBar(LifeSimSave s) {
    final period = _engine.periodForDay(s.day);
    final actName = LifeSimEngine.activityName(period.activityId, _locale);
    final dayIn = period.dayInPeriod(s.day);
    final items = <(IconData, String, Color)>[
      (
        Icons.event,
        _t('第 ${s.day} 天', 'Day ${s.day}'),
        Colors.cyan,
      ),
      (
        Icons.bolt,
        '${s.energy}/${s.maxEnergy}',
        s.energy > 0 ? Colors.green : Colors.red,
      ),
      (Icons.confirmation_number, _fmt(s.cash), Colors.purple),
      (Icons.monetization_on, _fmt(s.token), Colors.orange),
      (
        Icons.speed,
        _t('战力 ${_fmt(_engine.fleetPower(s))}', 'Power ${_fmt(_engine.fleetPower(s))}'),
        Colors.blue,
      ),
      (
        Icons.groups,
        s.inGang ? s.gangName! : _t('无帮派', 'No gang'),
        Colors.teal,
      ),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$actName · ${_t('第 $dayIn/${period.lengthDays} 天', 'Day $dayIn/${period.lengthDays}')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (s.unclaimedCount > 0)
                TextButton.icon(
                  onPressed: _claimRewards,
                  icon: Badge(
                    label: Text('${s.unclaimedCount}'),
                    child: const Icon(Icons.card_giftcard, size: 18),
                  ),
                  label: Text(_t('领奖', 'Claim')),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final it in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(it.$1, size: 14, color: it.$3),
                    const SizedBox(width: 3),
                    Text(it.$2, style: const TextStyle(fontSize: 12)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 今日
  // ===================================================================

  Widget _buildToday(LifeSimSave s) {
    final period = _engine.periodForDay(s.day);
    final tiers = LifeSimEngine.tiersFor(period.isMajor);
    final rank = LifeSimEngine.rankFor(s.progress, period.isMajor);
    final nextTier = tiers.where((t) => t.min > s.progress).toList();
    final next = nextTier.isEmpty ? null : nextTier.last;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          title: LifeSimEngine.activityName(period.activityId, _locale),
          subtitle: period.isMajor
              ? _t('大活动 · 4 天周期', 'Major activity · 4-day cycle')
              : _t('小活动 · 3 天周期', 'Mini activity · 3-day cycle'),
          icon: '🎯',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _t('进度 ', 'Progress ') + _fmt(s.progress),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  _rankChip(rank),
                ],
              ),
              const SizedBox(height: 6),
              if (next != null)
                Text(
                  _t(
                    '距 ${next.rank} 档还需 ${_fmt(next.min - s.progress)}',
                    '${_fmt(next.min - s.progress)} to rank ${next.rank}',
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in tiers)
                    Chip(
                      label: Text(
                        '${t.rank} ${t.min == 0 ? '0' : _fmt(t.min)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: s.progress >= t.min
                          ? Colors.green.withValues(alpha: 0.2)
                          : null,
                    ),
                ],
              ),
              if (s.activeActivityBonus > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _t(
                      '本周期进度加成 +${(s.activeActivityBonus * 100).round()}%',
                      'This cycle bonus +${(s.activeActivityBonus * 100).round()}%',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
                ),
              if (s.nextActivityBonus > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _t(
                      '下周期进度加成 +${(s.nextActivityBonus * 100).round()}%',
                      'Next cycle bonus +${(s.nextActivityBonus * 100).round()}%',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.teal),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionTitle(_t('做出决策', 'Make a choice')),
        for (final c in _engine.choicesFor(period.activityId))
          _choiceTile(s, c),
        const SizedBox(height: 12),
        _cityKingCard(s),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _endDay,
            icon: const Icon(Icons.nightlight_round),
            label: Text(
              _t('结束这一天（+${LifeSimSave.kDailyEnergy} 精力）',
                  'End the day (+${LifeSimSave.kDailyEnergy} energy)'),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _rankChip(String rank) {
    final color = switch (rank) {
      'S' => Colors.amber,
      'A' => Colors.purple,
      'B' => Colors.blue,
      'C' => Colors.green,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        rank,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _choiceTile(LifeSimSave s, ActivityChoice c) {
    final affordable = s.energy >= c.energyCost;
    final gain = (_engine.powerScore(s) * c.coef).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        enabled: affordable,
        leading: CircleAvatar(
          backgroundColor: affordable ? Colors.teal : Colors.grey,
          child: Text(
            '${c.energyCost}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
        title: Text(_locale == 'zh' ? c.nameZh : c.nameEn),
        subtitle: Text(
          '${_locale == 'zh' ? c.descZh : c.descEn} · ${_t('约 +$gain 进度', '~+$gain progress')}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.play_arrow),
        onTap: affordable ? () => _makeChoice(c) : null,
      ),
    );
  }

  Widget _cityKingCard(LifeSimSave s) {
    if (!s.inGang) {
      return _card(
        title: _t('城市之王', 'City King'),
        subtitle: _t('加入或组建帮派后开启', 'Unlocks after joining a gang'),
        icon: '⚔️',
        child: Text(
          _t('每天随机挑战一个帮派，3 辆车逐一对位，胜场多者获胜。',
              'Challenge a random gang daily: 3 cars face off one by one.'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      );
    }
    final opp = s.cityOpponentCars;
    return _card(
      title: _t('城市之王', 'City King'),
      subtitle: s.cityChallenged
          ? _t('今日已挑战', 'Already challenged today')
          : _t('对手：${s.cityOpponentName ?? '——'}',
              'Opponent: ${s.cityOpponentName ?? '——'}'),
      icon: '⚔️',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t(
              '对手帮派战力 ${_fmt(s.cityOpponentPower)} · 活跃度 ${s.cityOpponentActivity}%',
              'Opponent power ${_fmt(s.cityOpponentPower)} · activity ${s.cityOpponentActivity}%',
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            _t(
              '对手三车：${opp.map(_fmt).join(' / ')}',
              'Opponent cars: ${opp.map(_fmt).join(' / ')}',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: s.cityChallenged || s.energy < LifeSimEngine.kCityEnergyCost
                  ? null
                  : _fightCityKing,
              icon: const Icon(Icons.sports_kabaddi),
              label: Text(
                _t('发起挑战（${LifeSimEngine.kCityEnergyCost} 精力）',
                    'Challenge (${LifeSimEngine.kCityEnergyCost} energy)'),
              ),
            ),
          ),
          Text(
            _t('战绩 ${s.cityWins} 胜 ${s.cityLosses} 负',
                'Record ${s.cityWins}W ${s.cityLosses}L'),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 车库
  // ===================================================================

  Widget _buildGarage(LifeSimSave s) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          _t(
            '用活动奖励拿到的部件组建最多 3 辆车；部件按满级计算，已解锁即可重复使用。',
            'Build up to 3 cars with parts from rewards. Parts count at max level and can be reused once unlocked.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < s.vehicles.length; i++) _vehicleCard(s, i),
      ],
    );
  }

  Widget _vehicleCard(LifeSimSave s, int index) {
    final v = s.vehicles[index];
    final val = _engine.evaluate(v);
    final body = v.bodyId == null ? null : _engine.partIndex[v.bodyId];
    final slots = body?.slots;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _t('第 ${index + 1} 辆车', 'Car ${index + 1}'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  val.ok
                      ? _t(
                          'HP ${_fmt(val.hp)} · ATK ${_fmt(val.atk)}',
                          'HP ${_fmt(val.hp)} · ATK ${_fmt(val.atk)}',
                        )
                      : _t(val.error, val.error),
                  style: TextStyle(
                    fontSize: 12,
                    color: val.ok ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _slotRow(
              s,
              index,
              _t('车身', 'Body'),
              _PartSlotRef.body,
              v.bodyId,
              single: true,
            ),
            _slotRow(
              s,
              index,
              _t('额外武器', 'Extra'),
              _PartSlotRef.extra,
              v.extraWeaponId,
              single: true,
            ),
            _multiSlotRow(
              s,
              index,
              _t('武器', 'Weapons'),
              _PartSlotRef.weapon,
              v.weaponIds,
              slots?.weapon ?? 0,
            ),
            _multiSlotRow(
              s,
              index,
              _t('车轮', 'Wheels'),
              _PartSlotRef.wheel,
              v.wheelIds,
              slots?.wheel ?? 0,
            ),
            _multiSlotRow(
              s,
              index,
              _t('配件', 'Gadgets'),
              _PartSlotRef.gadget,
              v.gadgetIds,
              slots?.gadget ?? 0,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  val.ok
                      ? _t(
                          '电力 ${val.powerSupply - val.powerConsumption}',
                          'Power ${val.powerSupply - val.powerConsumption}',
                        )
                      : '',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _run(() => _engine.autoBuild(s, index)),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(_t('一键最强', 'Auto best')),
                ),
                TextButton.icon(
                  onPressed: () => _run(() => s.vehicles[index].clear()),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(_t('清空', 'Clear')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _slotRow(
    LifeSimSave s,
    int index,
    String label,
    _PartSlotRef ref,
    String? id, {
    bool single = false,
  }) {
    final part = id == null ? null : _engine.partIndex[id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pickPart(s, index, ref, 0, id),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                alignment: Alignment.centerLeft,
              ),
              child: Text(
                part == null ? _t('空', 'Empty') : _pn(part),
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _multiSlotRow(
    LifeSimSave s,
    int index,
    String label,
    _PartSlotRef ref,
    List<String> ids,
    int slotCount,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(label, style: const TextStyle(fontSize: 12)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < slotCount; i++)
                  OutlinedButton(
                    onPressed: () => _pickPart(
                      s,
                      index,
                      ref,
                      i,
                      i < ids.length ? ids[i] : null,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                    child: Text(
                      i < ids.length
                          ? _pn(_engine.partIndex[ids[i]]!)
                          : _t('空', 'Empty'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 帮派
  // ===================================================================

  Widget _buildGang(LifeSimSave s) {
    if (!s.inGang) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            _t(
              '加入一个帮派可以每天开启「城市之王」，并让帮派活跃度提升你的战力；'
              '也可以自己组建帮派，慢慢招募成员。',
              'Join a gang to unlock daily City King battles and let gang activity boost your power — or found your own and recruit members.',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _showGangCandidates(s),
              icon: const Icon(Icons.search),
              label: Text(_t('加入帮派', 'Join a gang')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showFoundGang(s),
              icon: const Icon(Icons.add_home_work),
              label: Text(
                _t('组建帮派（${LifeSimEngine.kFoundGangCashCost} 紫票）',
                    'Found a gang (${LifeSimEngine.kFoundGangCashCost} Cash)'),
              ),
            ),
          ),
        ],
      );
    }
    final rank = _engine.estimateGangRank(s);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _card(
          title: s.gangName!,
          subtitle: s.gangOwned
              ? _t('你组建的帮派', 'Your own gang')
              : _t('已加入的帮派', 'Joined gang'),
          icon: '🏛️',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  '帮派战力 ${_fmt(_engine.gangPower(s))}（你的车队 ${_fmt(_engine.fleetPower(s))}）',
                  'Gang power ${_fmt(_engine.gangPower(s))} (your fleet ${_fmt(_engine.fleetPower(s))})',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                _t('大致排名：第 $rank 位', 'Estimated rank: #$rank'),
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(_t('活跃度', 'Activity')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: s.gangActivity / 100,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${s.gangActivity}%'),
                ],
              ),
              Text(
                _t(
                  '活跃度让帮派战力 ×${LifeSimEngine.activityMultiplier(s.gangActivity).toStringAsFixed(2)}',
                  'Activity multiplies gang power by ${LifeSimEngine.activityMultiplier(s.gangActivity).toStringAsFixed(2)}',
                ),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _card(
          title: _t('成员（${s.gangMembers.length}）', 'Members (${s.gangMembers.length})'),
          icon: '👥',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(_t('我（玩家）', 'Me (player)')),
                trailing: Text(_fmt(_engine.fleetPower(s))),
              ),
              for (final m in s.gangMembers)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(m.name),
                  trailing: Text(_fmt(m.totalPower)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _recruit(s),
            icon: const Icon(Icons.person_add),
            label: Text(
              _t(
                '招募成员（${LifeSimEngine.kRecruitCashBase + LifeSimEngine.kRecruitCashStep * s.gangMembers.length} 紫票 + ${LifeSimEngine.kRecruitEnergyCost} 精力）',
                'Recruit (${LifeSimEngine.kRecruitCashBase + LifeSimEngine.kRecruitCashStep * s.gangMembers.length} Cash + ${LifeSimEngine.kRecruitEnergyCost} energy)',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _confirmLeaveGang(s),
          icon: const Icon(Icons.logout, color: Colors.red),
          label: Text(
            _t('退出帮派', 'Leave gang'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // 成就 / 日志
  // ===================================================================

  Widget _buildAchievements(LifeSimSave s) {
    final unlocked = s.achievements.toSet();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          _t(
            '已解锁 ${unlocked.length}/${kAchievements.length}',
            'Unlocked ${unlocked.length}/${kAchievements.length}',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final a in kAchievements)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              leading: Text(a.icon, style: const TextStyle(fontSize: 24)),
              title: Text(
                _locale == 'zh' ? a.nameZh : a.nameEn,
                style: TextStyle(
                  color: unlocked.contains(a.id) ? null : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                _locale == 'zh' ? a.descZh : a.descEn,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: unlocked.contains(a.id)
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.lock_outline, color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Widget _buildLogs(LifeSimSave s) {
    if (s.logs.isEmpty) {
      return Center(child: Text(_t('还没有任何记录', 'No events yet')));
    }
    return ListView.builder(
      itemCount: s.logs.length,
      itemBuilder: (context, i) {
        final l = s.logs[i];
        return ListTile(
          dense: true,
          leading: Text(l.icon, style: const TextStyle(fontSize: 20)),
          title: Text(
            _locale == 'zh' ? l.zh : l.en,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: Text(
            _t('第 ${l.day} 天', 'Day ${l.day}'),
            style: const TextStyle(fontSize: 11),
          ),
        );
      },
    );
  }

  // ===================================================================
  // 操作
  // ===================================================================

  void _makeChoice(ActivityChoice c) {
    final s = _save!;
    final r = _engine.makeChoice(s, c);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    if (r.backfired) {
      _snack(_t('翻车了！只拿到 ${r.progress} 进度', 'Backfired! Only ${r.progress} progress'));
    } else {
      _snack(_t('进度 +${r.progress}', 'Progress +${r.progress}'));
    }
  }

  void _endDay() {
    final s = _save!;
    final r = _engine.endDay(s);
    _run(() {});
    if (r.settledPeriod != null) {
      final name = LifeSimEngine.activityName(r.settledActivityId ?? '', _locale);
      _dialog(
        title: _t('活动结束', 'Activity finished'),
        children: [
          Text(
            _t(
              '$name 结算档位 ${r.settledRank}，奖励已放入待领取列表。',
              '$name settled at rank ${r.settledRank}. Reward is pending.',
            ),
          ),
          const SizedBox(height: 8),
          _rewardPreview(r.settledPeriod!),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _claimRewards();
              },
              child: Text(_t('立即领取', 'Claim now')),
            ),
          ),
        ],
      );
    } else {
      _snack(_t('进入第 ${r.newDay} 天', 'Day ${r.newDay} begins'));
    }
  }

  Widget _rewardPreview(RewardBundle r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('紫票 +${_fmt(r.cash)}　代币 +${_fmt(r.token)}',
            'Cash +${_fmt(r.cash)}  Tokens +${_fmt(r.token)}')),
        if (r.partIds.isNotEmpty)
          Text(
            _t(
              '部件：${r.partIds.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join('、')}',
              'Parts: ${r.partIds.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join(', ')}',
            ),
            style: const TextStyle(fontSize: 13),
          ),
      ],
    );
  }

  void _claimRewards() {
    final s = _save!;
    final claimed = _engine.claimRewards(s);
    if (claimed.isEmpty) {
      _snack(_t('没有可领取的奖励', 'Nothing to claim'));
      return;
    }
    _run(() {});
    _dialog(
      title: _t('领取奖励', 'Rewards claimed'),
      children: [for (final r in claimed) ...[
        _rewardPreview(r),
        const Divider(),
      ]],
    );
  }

  void _fightCityKing() {
    final s = _save!;
    final r = _engine.fightCityKing(s);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    final rows = <Widget>[];
    for (var i = 0; i < r.rounds.length; i++) {
      final res = r.rounds[i];
      final icon = res == null ? '🤝' : (res ? '✅' : '❌');
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('${i + 1}. ', style: const TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  '${_fmt(r.myCars[i])}  vs  ${_fmt(r.oppCars[i])}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(icon),
            ],
          ),
        ),
      );
    }
    _dialog(
      title: r.draw
          ? _t('平局', 'Draw')
          : r.won
          ? _t('胜利！', 'Victory!')
          : _t('失败', 'Defeat'),
      children: [
        Text(
          _t('对手：${r.opponentName}', 'Opponent: ${r.opponentName}'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...rows,
        const SizedBox(height: 8),
        Text(
          _t('比分 ${r.myWins}:${r.oppWins}${r.draws > 0 ? '（平 ${r.draws}）' : ''}',
              'Score ${r.myWins}:${r.oppWins}${r.draws > 0 ? ' (${r.draws} drawn)' : ''}'),
        ),
        if (r.cash > 0 || r.token > 0)
          Text(_t('紫票 +${_fmt(r.cash)}　代币 +${_fmt(r.token)}',
              'Cash +${_fmt(r.cash)}  Tokens +${_fmt(r.token)}')),
        if (r.parts.isNotEmpty)
          Text(
            _t(
              '部件：${r.parts.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join('、')}',
              'Parts: ${r.parts.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join(', ')}',
            ),
          ),
      ],
    );
  }

  void _recruit(LifeSimSave s) {
    final r = _engine.recruitMember(s);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    _snack(
      _t('招募了「${r.member?.name}」', 'Recruited "${r.member?.name}"'),
    );
  }

  void _confirmLeaveGang(LifeSimSave s) {
    _dialog(
      title: _t('退出帮派', 'Leave gang'),
      children: [
        Text(_t('退出后城市之王与帮派加成会失效，确定吗？',
            'City King and gang bonuses will be lost. Continue?')),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _run(() => _engine.leaveGang(s));
              },
              child: Text(_t('确定', 'Confirm')),
            ),
          ],
        ),
      ],
    );
  }

  void _showFoundGang(LifeSimSave s) {
    final controller = TextEditingController(
      text: _t('我的猫团', 'My Cat Gang'),
    );
    _dialog(
      title: _t('组建帮派', 'Found a gang'),
      children: [
        Text(_t('花费 ${LifeSimEngine.kFoundGangCashCost} 紫票创建帮派：',
            'Create a gang for ${LifeSimEngine.kFoundGangCashCost} Cash:')),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(labelText: _t('帮派名称', 'Gang name')),
          maxLength: 12,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () {
                final r = _engine.foundGang(s, controller.text);
                if (!r.ok) {
                  _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                  return;
                }
                Navigator.pop(context);
                _run(() {});
              },
              child: Text(_t('创建', 'Create')),
            ),
          ],
        ),
      ],
    );
  }

  void _showGangCandidates(LifeSimSave s) {
    final list = _engine.gangCandidates(s);
    _dialog(
      title: _t('选择帮派', 'Choose a gang'),
      children: [
        for (final g in list)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              title: Text(
                g.name + (g.rankHint != null ? '  #${g.rankHint}' : ''),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                _t(
                  '${g.memberCount} 名成员 · 战力 ${_fmt(g.totalPower)} · 活跃度 ${g.activity}%',
                  '${g.memberCount} members · power ${_fmt(g.totalPower)} · activity ${g.activity}%',
                ),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                final r = _engine.joinGang(s, g);
                if (!r.ok) {
                  _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                  return;
                }
                Navigator.pop(context);
                _run(() {});
              },
            ),
          ),
      ],
    );
  }

  void _pickPart(
    LifeSimSave s,
    int vehicleIndex,
    _PartSlotRef ref,
    int slot,
    String? currentId,
  ) {
    final category = switch (ref) {
      _PartSlotRef.body => PartCategory.body,
      _PartSlotRef.extra || _PartSlotRef.weapon => PartCategory.weapon,
      _PartSlotRef.wheel => PartCategory.wheel,
      _PartSlotRef.gadget => PartCategory.gadget,
    };
    final owned = <PartData>[
      for (final id in s.ownedParts)
        if (_engine.partIndex[id]?.category == category) _engine.partIndex[id]!,
    ]..sort((a, b) {
      final sa = a.hpMax + a.atkMax;
      final sb = b.hpMax + b.atkMax;
      return sb.compareTo(sa);
    });

    _dialog(
      title: _t('选择部件', 'Choose a part'),
      children: [
        if (owned.isEmpty)
          Text(_t('没有该分类的部件', 'No parts in this category')),
        for (final p in owned)
          ListTile(
            dense: true,
            selected: p.id == currentId,
            title: Text(_pn(p), style: const TextStyle(fontSize: 13)),
            subtitle: Text(
              'R${p.rarity.index + 1} · HP ${_fmt(p.hpMax)} · ATK ${_fmt(p.atkMax)}'
              '${p.power != 0 ? ' · 电 ${p.power > 0 ? '+' : ''}${p.power}' : ''}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: p.id == currentId ? const Icon(Icons.check) : null,
            onTap: () {
              Navigator.pop(context);
              _run(() {
                final v = s.vehicles[vehicleIndex];
                switch (ref) {
                  case _PartSlotRef.body:
                    v.bodyId = p.id;
                    // 换车身时清掉超出槽位的部件
                    final slots = p.slots;
                    if (slots != null) {
                      if (v.weaponIds.length > slots.weapon) {
                        v.weaponIds.removeRange(slots.weapon, v.weaponIds.length);
                      }
                      if (v.wheelIds.length > slots.wheel) {
                        v.wheelIds.removeRange(slots.wheel, v.wheelIds.length);
                      }
                      if (v.gadgetIds.length > slots.gadget) {
                        v.gadgetIds.removeRange(
                          slots.gadget,
                          v.gadgetIds.length,
                        );
                      }
                    }
                  case _PartSlotRef.extra:
                    v.extraWeaponId = p.id;
                  case _PartSlotRef.weapon:
                    _setSlot(v.weaponIds, slot, p.id);
                  case _PartSlotRef.wheel:
                    _setSlot(v.wheelIds, slot, p.id);
                  case _PartSlotRef.gadget:
                    _setSlot(v.gadgetIds, slot, p.id);
                }
              });
            },
          ),
        if (currentId != null)
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _run(() {
                final v = s.vehicles[vehicleIndex];
                switch (ref) {
                  case _PartSlotRef.body:
                    v.clear();
                  case _PartSlotRef.extra:
                    v.extraWeaponId = null;
                  case _PartSlotRef.weapon:
                    _setSlot(v.weaponIds, slot, null);
                  case _PartSlotRef.wheel:
                    _setSlot(v.wheelIds, slot, null);
                  case _PartSlotRef.gadget:
                    _setSlot(v.gadgetIds, slot, null);
                }
              });
            },
            icon: const Icon(Icons.delete_outline, size: 16),
            label: Text(_t('移除', 'Remove')),
          ),
      ],
    );
  }

  void _setSlot(List<String> list, int index, String? value) {
    if (value == null) {
      if (index < list.length) list.removeAt(index);
      return;
    }
    while (list.length <= index) {
      list.add('');
    }
    list[index] = value;
    list.removeWhere((e) => e.isEmpty);
  }

  // ===================================================================
  // 通用小组件
  // ===================================================================

  Widget _card({
    required String title,
    String? subtitle,
    required String icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              )
            else
              const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    ),
  );

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _dialog({required String title, required List<Widget> children}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_t('关闭', 'Close')),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 构建
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = _save;
    if (s == null) return _buildStart();
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_t('猫生重开', 'Life Restart')),
          actions: [
            IconButton(
              tooltip: _t('重置存档', 'Reset save'),
              icon: const Icon(Icons.restart_alt),
              onPressed: _confirmReset,
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: _t('今日', 'Today')),
              Tab(text: _t('车库', 'Garage')),
              Tab(text: _t('帮派', 'Gang')),
              Tab(text: _t('成就', 'Achievements')),
              Tab(text: _t('日志', 'Log')),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildStatusBar(s),
            Expanded(
              child: TabBarView(
                children: [
                  _buildToday(s),
                  _buildGarage(s),
                  _buildGang(s),
                  _buildAchievements(s),
                  _buildLogs(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStart() {
    final e = _engine;
    return Scaffold(
      appBar: AppBar(title: Text(_t('猫生重开', 'Life Restart'))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🐱', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(
                _t('以「天」为单位重开猫生', 'Restart your cat life day by day'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                _t(
                  '按活动日历的轮换顺序度过一个个活动周期：在活动进行时消耗精力做出决策累积进度，'
                  '活动结束时按档位领取部件、紫票与代币；用部件组建自己的车，'
                  '加入帮派后每天还能参加「城市之王」。',
                  'Live through activity cycles in calendar order: spend energy on choices while an activity runs, then claim parts, Cash and Tokens by rank when it ends. Build cars from your parts and fight the daily City King once you join a gang.',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  final save = e.newSave();
                  setState(() => _save = save);
                  _persist();
                },
                icon: const Icon(Icons.play_arrow),
                label: Text(_t('开始新的猫生', 'Start a new life')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset() {
    _dialog(
      title: _t('重置存档', 'Reset save'),
      children: [
        Text(_t('所有进度将被清空，且无法恢复。确定吗？',
            'All progress will be erased. Continue?')),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('取消', 'Cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                await LifeSimStore.clear();
                if (!mounted) return;
                setState(() => _save = null);
              },
              child: Text(_t('重置', 'Reset')),
            ),
          ],
        ),
      ],
    );
  }
}

/// 车辆插槽类型
enum _PartSlotRef { body, extra, weapon, wheel, gadget }
