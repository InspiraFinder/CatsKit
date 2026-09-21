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

  /// 「部件」页的分类筛选
  PartCategory? _partFilter;

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
        Icons.account_balance_wallet,
        _fmt(s.money),
        s.money < 0 ? Colors.red : Colors.brown,
      ),
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

  Widget _buildMain(LifeSimSave s) {
    return Column(
      children: [
        Expanded(child: _buildLogStream(s)),
        _buildActionBar(s),
      ],
    );
  }

  /// 日志流（主界面）：纯文字显示，最早的在上面、最新的贴底，不做卡片背景
  Widget _buildLogStream(LifeSimSave s) {
    final logs = s.logs;
    if (logs.isEmpty) {
      return Center(
        child: Text(
          _t('还没有任何记录', 'No events yet'),
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      itemCount: logs.length,
      itemBuilder: (context, i) {
        final l = logs[i];
        final isDayStart = i == logs.length - 1 || logs[i + 1].day != l.day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDayStart)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  _t('── 第 ${l.day} 天 ──', '── Day ${l.day} ──'),
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${l.icon}  ${_locale == 'zh' ? l.zh : l.en}',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: _logColor(l.kind),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 日志按类型着色（仅文字颜色，不加背景）
  Color? _logColor(String kind) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (kind) {
      case 'reward':
        return isDark ? Colors.green[300] : Colors.green[800];
      case 'city':
        return isDark ? Colors.orange[300] : Colors.orange[800];
      case 'gang':
        return isDark ? Colors.teal[200] : Colors.teal[700];
      case 'achv':
        return isDark ? Colors.amber[300] : Colors.amber[800];
      case 'system':
        return isDark ? Colors.pink[200] : Colors.pink[700];
      case 'day':
        return Colors.grey;
      default:
        return null;
    }
  }

  /// 底部行动条：当前活动 / 进度 / 决策按钮 / 城市之王 / 结束这一天
  Widget _buildActionBar(LifeSimSave s) {
    final period = _engine.periodForDay(s.day);
    final activityId = period.activityId;
    final milestone = LifeSimEngine.isMilestoneActivity(activityId);
    final isGear = activityId == 'gear';
    final gearReady = !isGear || _engine.gearPowerReady(s);
    final limitedUsed = !_engine.canUseLimitedChoice(s);
    final isChamp = activityId == kChampActivityId;
    final isAllStar = LifeSimEngine.isAllStarActivity(activityId);
    final isGp = LifeSimEngine.isGpActivity(activityId);
    final gpRank = isGp ? _engine.gpRank(s) : 0;
    final gpTier = isGp ? _engine.gpTier(s) : null;
    final gpLocked = isGp && _engine.gpAllLocked(s);
    final gpRescue = isGp && _engine.gpRescueAvailable(s);
    final allStarRank = isAllStar ? _engine.allStarRank(s) : 0;
    final allStarTier = isAllStar ? _engine.allStarTier(s) : null;
    final canAd = LifeSimEngine.canWatchAd(activityId);
    final tiers = LifeSimEngine.tiersFor(period.isMajor);
    final rank = LifeSimEngine.rankFor(s.progress, period.isMajor);
    final nextTier = tiers.where((t) => t.min > s.progress).toList();
    final next = nextTier.isEmpty ? null : nextTier.last;
    final nodes = milestone
        ? _engine.milestoneNodes(activityId)
        : const <ScrapNode>[];
    final nextNode = milestone && s.scrapClaimed < nodes.length
        ? nodes[s.scrapClaimed]
        : null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 8,
      color: isDark ? const Color(0xFF16181D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  LifeSimEngine.activityName(period.activityId, _locale),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _t(
                    '第 ${period.dayInPeriod(s.day)}/${period.lengthDays} 天',
                    'Day ${period.dayInPeriod(s.day)}/${period.lengthDays}',
                  ),
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const Spacer(),
                if (milestone)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.scrapMultiplier > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.amber.withValues(
                              alpha: 0.25,
                            ),
                            label: Text(
                              _t(
                                '进度 ×${s.scrapMultiplier}',
                                'Progress ×${s.scrapMultiplier}',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => _showScrapNodesDialog(s),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _t('奖励节点', 'Nodes'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                else if (isChamp)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      _t('本期无活动', 'No activity'),
                      style: const TextStyle(fontSize: 11),
                    ),
                  )
                else if (isAllStar)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (s.scrapMultiplier > 1)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.amber.withValues(
                              alpha: 0.25,
                            ),
                            label: Text(
                              _t(
                                '分数 ×${s.scrapMultiplier}',
                                'Score ×${s.scrapMultiplier}',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      TextButton(
                        onPressed: () => _showAllStarBoardDialog(s),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _t('查看榜单', 'Board'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                else if (isGp)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.amber.withValues(alpha: 0.25),
                        label: Text(
                          _t(
                            '分数 ×${_engine.gpMultiplier(s).toStringAsFixed(2)}',
                            'Score ×${_engine.gpMultiplier(s).toStringAsFixed(2)}',
                          ),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showGpBoardDialog(s),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          _t('查看榜单', 'Board'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  )
                else
                  _rankChip(rank),
                if (s.unclaimedCount > 0)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _t('领取奖励', 'Claim rewards'),
                    icon: Badge(
                      label: Text('${s.unclaimedCount}'),
                      child: const Icon(Icons.card_giftcard, size: 20),
                    ),
                    onPressed: _claimRewards,
                  ),
              ],
            ),
            if (milestone) ...[
              Builder(
                builder: (context) {
                  final total =
                      LifeSimEngine.milestoneConfig(activityId)?.total ?? 0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (s.progress / total).clamp(0.0, 1.0),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextNode == null
                            ? _t(
                                '进度 ${s.progress}/$total（全部节点已达成）',
                                'Progress ${s.progress}/$total (all nodes done)',
                              )
                            : _t(
                                '进度 ${s.progress}/$total · 下一节点 ${nextNode.progress}',
                                'Progress ${s.progress}/$total · next node ${nextNode.progress}',
                              ),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      if (isGear) ...[
                        const SizedBox(height: 2),
                        Text(
                          _t(
                            '单车最高战力 ${_fmt(_engine.maxVehiclePower(s))} · '
                            '基础进度 ${gearBasePoints(_engine.maxVehiclePower(s))}',
                            'Top car power ${_fmt(_engine.maxVehiclePower(s))} · '
                            'base progress ${gearBasePoints(_engine.maxVehiclePower(s))}',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: gearReady ? Colors.grey[600] : Colors.red,
                          ),
                        ),
                        if (!gearReady)
                          Text(
                            _t(
                              '需要提升车辆战力（单车最高战力需 ≥ ${_fmt(kGearMinPower)}，'
                              '否则进度 ×0）',
                              'Increase your car power (top car must be ≥ ${_fmt(kGearMinPower)}, otherwise progress ×0)',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                            ),
                          ),
                      ],
                      if (limitedUsed)
                        Text(
                          _t(
                            '带倍率的决策每天只能用 1 次，今天已用完（明天恢复）',
                            'Multiplier choices are limited to once per day — used today (resets tomorrow)',
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                    ],
                  );
                },
              ),
            ] else if (isChamp)
              Text(
                _t(
                  '本期不设活动，只能看广告换紫票（1 精力）。',
                  'No activity this cycle — ads only (1 energy for Cash).',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            else if (isAllStar) ...[
              Text(
                _t(
                  '分数 ${_fmt(s.progress)} · 当前名次 #$allStarRank · '
                  '档位 ${allStarTier?.labelZh ?? ''}',
                  'Score ${_fmt(s.progress)} · rank #$allStarRank · '
                  '${allStarTier?.labelEn ?? ''}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _t(
                  '榜单每天变化；单车最高战力 ${_fmt(_engine.maxVehiclePower(s))} '
                  '→ 每次决策基础分 ${_fmt(allStarScore(_engine.maxVehiclePower(s)))}',
                  'The board changes daily. Top car power ${_fmt(_engine.maxVehiclePower(s))} '
                  '→ base score per choice ${_fmt(allStarScore(_engine.maxVehiclePower(s)))}',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (allStarTier != null)
                Text(
                  _t(
                    '本档奖励：部件 ${allStarTier.partKinds} 种×${allStarTier.partEach}、'
                    '代币 ${allStarTier.token}、紫票 ${_fmt(allStarTier.cash)}',
                    'Tier reward: ${allStarTier.partKinds} kinds ×${allStarTier.partEach}, '
                    '${allStarTier.token} tokens, ${_fmt(allStarTier.cash)} cash',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.teal),
                ),
            ] else if (isGp) ...[
              Text(
                _t(
                  '分数 ${_fmt(s.progress)} · 当前名次 #$gpRank · '
                  '档位 ${gpTier?.labelZh ?? ''}',
                  'Score ${_fmt(s.progress)} · rank #$gpRank · '
                  '${gpTier?.labelEn ?? ''}',
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _t(
                  '旗帜 ${_fmt(s.gpFlags)} · 汽油 ${_fmt(s.gpGasoline)} · '
                  '乘数 +${_engine.gpBonus(s)}%'
                  '（汽油 +${_engine.gpGasBonus(s)}% / 氪金 +${_engine.gpMoneyBonus(s)}%）',
                  'Flags ${_fmt(s.gpFlags)} · gasoline ${_fmt(s.gpGasoline)} · '
                  'multiplier +${_engine.gpBonus(s)}% '
                  '(gas +${_engine.gpGasBonus(s)}% / top-up +${_engine.gpMoneyBonus(s)}%)',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _t(
                  '与战车大小无关；榜单每天变化，名次奖励在周期结束时发放',
                  'Independent of car power. The board changes daily; '
                      'rewards are paid at the end of the cycle',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (gpLocked)
                Text(
                  _t(
                    '旗帜已归零 → 今天三档全部禁选（明天若起始仍为 0，可救一次低风险）',
                    'Flags are at zero → all options locked today '
                        '(tomorrow one low-risk rescue is allowed if still zero)',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                )
              else if (gpRescue)
                Text(
                  _t(
                    '旗帜归零 → 今天可以做 1 次低风险把旗帜救回来',
                    'Flags at zero → one low-risk rescue allowed today',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.orange),
                ),
              if (gpTier != null)
                Text(
                  _t(
                    '本档奖励：部件 ${gpTier.partKinds} 种×${gpTier.partEach}、'
                    '代币 ${gpTier.token}、紫票 ${_fmt(gpTier.cash)}',
                    'Tier reward: ${gpTier.partKinds} kinds ×${gpTier.partEach}, '
                        '${gpTier.token} tokens, ${_fmt(gpTier.cash)} cash',
                  ),
                  style: const TextStyle(fontSize: 12, color: Colors.teal),
                ),
            ] else
              Text(
                next == null
                    ? _t(
                        '进度 ${_fmt(s.progress)}（已达最高档）',
                        'Progress ${_fmt(s.progress)} (top rank)',
                      )
                    : _t(
                        '进度 ${_fmt(s.progress)} · 距 ${next.rank} 档 ${_fmt(next.min - s.progress)}',
                        'Progress ${_fmt(s.progress)} · ${_fmt(next.min - s.progress)} to ${next.rank}',
                      ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _engine.choicesFor(activityId))
                  ActionChip(
                    avatar: const Icon(Icons.bolt, size: 14),
                    label: Text(
                      '${_locale == 'zh' ? c.nameZh : c.nameEn} '
                      '${_milestoneChoiceBadge(s, activityId, c)}'
                      '${isGp ? '${c.gasCost}⛽ ' : ''}'
                      '${c.energyCost}⚡',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed:
                        s.energy >= c.energyCost &&
                            gearReady &&
                            !limitedUsed &&
                            (!isGp ||
                                (_engine.gpCanChoose(s, c) &&
                                    s.gpGasoline >= c.gasCost))
                        ? () => _makeChoice(c)
                        : null,
                  ),
                if (canAd) ...[
                  ActionChip(
                    avatar: const Icon(Icons.ondemand_video, size: 14),
                    label: Text(
                      _t(
                        '看广告 · $kAdEnergyCost⚡',
                        'Watch ad · $kAdEnergyCost⚡',
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: s.energy >= kAdEnergyCost ? _watchAd : null,
                  ),
                  if (milestone || isAllStar || isGp)
                    ActionChip(
                      avatar: const Icon(Icons.diamond, size: 14),
                      label: Text(
                        _t('氪金', 'Top-up'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _showTopUpDialog(s),
                    ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showCityKingDialog(s),
                  icon: const Icon(Icons.sports_kabaddi, size: 18),
                  label: Text(
                    _t('城市之王', 'City King'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _endDay,
                    icon: const Icon(Icons.nightlight_round, size: 18),
                    label: Text(
                      _t('结束这一天（+${LifeSimSave.kDailyEnergy} 精力）',
                          'End the day (+${LifeSimSave.kDailyEnergy} energy)'),
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
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

  /// 里程碑活动决策按钮上的小标签（直接显示本次会拿到的进度结果）
  String _milestoneChoiceBadge(
    LifeSimSave s,
    String activityId,
    ActivityChoice c,
  ) {
    if (activityId == 'scrap' ||
        activityId == 'gear' ||
        activityId == 'allstar') {
      final gain = _engine.milestoneGain(s, activityId, c);
      return '+${_fmt(gain)} · ';
    }
    return '';
  }

  /// 打榜榜单弹窗（全明星 / GP 共用）
  void _showBoardDialog({
    required String title,
    required List<AllStarEntry> board,
    required int rank,
    required AllStarTier tier,
    required List<AllStarTier> tiers,
    required int score,
    required String noteZh,
    required String noteEn,
    List<Widget> extra = const <Widget>[],
  }) {
    _dialog(
      title: title,
      children: [
        Text(
          _t(
            '分数 ${_fmt(score)} · 名次 #$rank（${tier.labelZh}）',
            'Score ${_fmt(score)} · rank #$rank (${tier.labelEn})',
          ),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        Text(
          _t(noteZh, noteEn),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        ...extra,
        const SizedBox(height: 8),
        // 榜首 + 玩家附近的名次
        for (var i = 0; i < board.length; i++)
          if ((i + 1 - rank).abs() <= 2 || i < 3)
            _boardRow(i + 1, board[i], isPlayer: false),
        _boardRow(rank, AllStarEntry(_t('你', 'You'), score), isPlayer: true),
        const SizedBox(height: 10),
        Text(
          _t('名次奖励', 'Rank rewards'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        for (final t in tiers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _t(
                '${t.labelZh}：部件 ${t.partKinds} 种×${t.partEach}、'
                '代币 ${t.token}、紫票 ${_fmt(t.cash)}',
                '${t.labelEn}: ${t.partKinds} kinds ×${t.partEach}, '
                '${t.token} tokens, ${_fmt(t.cash)} cash',
              ),
              style: TextStyle(
                fontSize: 11,
                color: t == tier ? Colors.teal : Colors.grey[700],
                fontWeight: t == tier ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
      ],
    );
  }

  /// 全明星榜单（含玩家名次与档位奖励表）
  void _showAllStarBoardDialog(LifeSimSave s) {
    _showBoardDialog(
      title: _t('全明星榜单', 'All-Star Board'),
      board: _engine.allStarBoard(s),
      rank: _engine.allStarRank(s),
      tier: _engine.allStarTier(s),
      tiers: kAllStarTiers,
      score: s.progress,
      noteZh: '榜单每天重新生成，可能出现加了分名次反而后退的情况。',
      noteEn:
          'The board is regenerated daily — your rank can slip even after gaining score.',
    );
  }

  /// GP 榜单（含玩家名次、乘数明细与档位奖励表）
  void _showGpBoardDialog(LifeSimSave s) {
    _showBoardDialog(
      title: _t('GP 榜单', 'Grand Prix Board'),
      board: _engine.gpBoard(s),
      rank: _engine.gpRank(s),
      tier: _engine.gpTier(s),
      tiers: kGpTiers,
      score: s.progress,
      noteZh: '与战车大小无关；榜单每天重新生成，名次奖励在周期结束时发放。',
      noteEn:
          'Independent of car power. The board is regenerated daily; '
          'rewards are paid at the end of the cycle.',
      extra: [
        Text(
          _t(
            '旗帜 ${_fmt(s.gpFlags)} · 汽油 ${_fmt(s.gpGasoline)} · '
            '乘数 +${_engine.gpBonus(s)}%'
            '（汽油 +${_engine.gpGasBonus(s)}% / 氪金 +${_engine.gpMoneyBonus(s)}%）',
            'Flags ${_fmt(s.gpFlags)} · gasoline ${_fmt(s.gpGasoline)} · '
            'multiplier +${_engine.gpBonus(s)}% '
            '(gas +${_engine.gpGasBonus(s)}% / top-up +${_engine.gpMoneyBonus(s)}%)',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
        ),
        Text(
          _t(
            '每消耗 $kGpGasBonusStep 汽油 → 乘数 +$kGpGasBonusStepPct%'
            '（上限 +$kGpGasBonusMaxPct%）；'
            '每 $kGpTopUpMoney 钱 → 乘数 +$kGpTopUpBonusPct%'
            '（上限 $kGpMaxTopUpCount 次）；整体封顶 +$kGpTotalBonusCapPct%',
            'Every $kGpGasBonusStep gasoline → +$kGpGasBonusStepPct% '
            '(max +$kGpGasBonusMaxPct%); every $kGpTopUpMoney money → '
            '+$kGpTopUpBonusPct% (max $kGpMaxTopUpCount times); '
            'overall cap +$kGpTotalBonusCapPct%',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _boardRow(int rank, AllStarEntry e, {required bool isPlayer}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isPlayer ? FontWeight.bold : FontWeight.normal,
                color: isPlayer ? Colors.teal : Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              e.id,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isPlayer ? FontWeight.bold : FontWeight.normal,
                color: isPlayer ? Colors.teal : null,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _fmt(e.score),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isPlayer ? FontWeight.bold : FontWeight.normal,
              color: isPlayer ? Colors.teal : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 里程碑活动的奖励节点列表
  void _showScrapNodesDialog(LifeSimSave s) {
    final period = _engine.periodForDay(s.day);
    final activityId = period.activityId;
    final config = LifeSimEngine.milestoneConfig(activityId);
    if (config == null) return;
    final nodes = _engine.milestoneNodes(activityId);
    final actName = LifeSimEngine.activityName(activityId, _locale);
    _dialog(
      title: _t(
        '$actName奖励节点（${s.scrapClaimed}/${nodes.length}）',
        '$actName nodes (${s.scrapClaimed}/${nodes.length})',
      ),
      children: [
        Text(
          _t(
            '总进度 ${config.total}，节点按对数分布（先密后疏）、'
            '一个节点只给一种奖励，达成后奖励立即发放。'
            '每个周期结束后进度与节点会重置。',
            'Total progress ${config.total}. Nodes are log-spaced (dense early, sparse late), one reward per node, granted immediately. Progress and nodes reset each cycle.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < nodes.length; i++)
          _scrapNodeRow(s, nodes[i], i < s.scrapClaimed, i == s.scrapClaimed),
      ],
    );
  }

  Widget _scrapNodeRow(
    LifeSimSave s,
    ScrapNode node,
    bool claimed,
    bool isNext,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              '${node.progress}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                color: claimed
                    ? Colors.green
                    : (isNext ? Colors.blue : Colors.grey[600]),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _scrapRewardText(node),
              style: TextStyle(
                fontSize: 12,
                color: claimed ? Colors.green : null,
              ),
            ),
          ),
          if (claimed) const Icon(Icons.check, size: 16, color: Colors.green),
        ],
      ),
    );
  }

  String _scrapRewardText(ScrapNode node) => node.rewards.map((r) {
    switch (r.kind) {
      case ScrapRewardKind.r6Part:
        final id = r.partId ?? '';
        return '${_engine.partLabel(id, _locale == 'zh')} ×${r.amount}';
      case ScrapRewardKind.randomR6Part:
        return _t('随机 R6 部件 ×${r.amount}', 'Random R6 part ×${r.amount}');
      case ScrapRewardKind.randomPart:
        return _t('随机部件宝箱 ×${r.amount}', 'Random part chest ×${r.amount}');
      case ScrapRewardKind.token:
        return _t('代币 ×${r.amount}', 'Tokens ×${r.amount}');
      case ScrapRewardKind.cash:
        return _t('紫票 ×${_fmt(r.amount)}', 'Cash ×${_fmt(r.amount)}');
    }
  }).join('、');

  /// 看广告（废铁行动）
  void _watchAd() {
    final s = _save!;
    final r = _engine.watchAd(s);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    _dialog(
      title: _t('广告奖励', 'Ad reward'),
      children: [
        Text(
          _t(
            '紫票 +${_fmt(r.cash)}　进度 +${r.progress}',
            'Cash +${_fmt(r.cash)}  Progress +${r.progress}',
          ),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        if (s.scrapMultiplier > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _t(
                '氪金倍率 ×${s.scrapMultiplier}：基础进度 ${r.baseProgress} → ${r.progress}',
                'Top-up ×${s.scrapMultiplier}: base progress ${r.baseProgress} → ${r.progress}',
              ),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
        if (r.nodes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _t(
              '同时达成 ${r.nodes.length} 个奖励节点（明细见日志）',
              'Also reached ${r.nodes.length} reward node(s) (see the log)',
            ),
          ),
        ],
      ],
    );
  }

  /// 氪金：里程碑活动消耗「钱」换进度倍率；全明星「买分」；GP「氪乘数」
  void _showTopUpDialog(LifeSimSave s) {
    final period = _engine.periodForDay(s.day);
    final isAllStar = LifeSimEngine.isAllStarActivity(period.activityId);
    final isGp = LifeSimEngine.isGpActivity(period.activityId);
    final unitZh = isAllStar ? '分数' : '进度';
    final unitEn = isAllStar ? 'score' : 'progress';
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(_t('氪金', 'Top-up')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isGp
                      ? _t(
                          '每花 $kGpTopUpMoney 钱，GP 分数乘数永久 +$kGpTopUpBonusPct%'
                          '（最多 $kGpMaxTopUpCount 次）。'
                          '钱可以为负。当前余额：${_fmt(s.money)}',
                          'Spend $kGpTopUpMoney money for a permanent '
                              '+$kGpTopUpBonusPct% GP score multiplier '
                              '(max $kGpMaxTopUpCount times). Money may go '
                              'negative. Balance: ${_fmt(s.money)}',
                        )
                      : _t(
                          '消耗「钱」获得本次活动的$unitZh倍率（周期结束时失效）。'
                          '钱可以为负。当前余额：${_fmt(s.money)}',
                          'Spend money for a $unitEn multiplier in this event '
                              'cycle (expires at cycle end). Money may go '
                              'negative. Balance: ${_fmt(s.money)}',
                        ),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                if (!isGp)
                  for (var i = 0; i < kTopUpTiers.length; i++)
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text(
                          _t(
                            '花费 ${kTopUpTiers[i].cost} 钱 → $unitZh ×${kTopUpTiers[i].multiplier}',
                            'Spend ${kTopUpTiers[i].cost} money → $unitEn ×${kTopUpTiers[i].multiplier}',
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        trailing:
                            s.scrapMultiplier >= kTopUpTiers[i].multiplier
                            ? const Icon(Icons.check, color: Colors.green)
                            : const Icon(Icons.chevron_right),
                        enabled: s.scrapMultiplier < kTopUpTiers[i].multiplier,
                        onTap: () {
                          final r = _engine.topUp(s, i);
                          if (!r.ok) {
                            _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                            return;
                          }
                          Navigator.pop(ctx);
                          _run(() {});
                          _snack(
                            _t(
                              '本次活动$unitZh ×${r.multiplier}',
                              'Event $unitEn ×${r.multiplier}',
                            ),
                          );
                        },
                      ),
                    ),
                if (isGp)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: Colors.purple.withValues(alpha: 0.10),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.trending_up,
                        size: 18,
                      ),
                      title: Text(
                        _t(
                          '氪乘数：$kGpTopUpMoney 钱 → 乘数 +$kGpTopUpBonusPct%'
                              '（已氪 ${s.gpTopUpCount}/$kGpMaxTopUpCount 次）',
                          'Top up: $kGpTopUpMoney money → multiplier '
                              '+$kGpTopUpBonusPct% '
                              '(${s.gpTopUpCount}/$kGpMaxTopUpCount used)',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        _t(
                          '当前总加成 +${_engine.gpBonus(s)}%'
                              ' · 分数 ×${_engine.gpMultiplier(s).toStringAsFixed(2)}'
                              ' · 整体封顶 +$kGpTotalBonusCapPct%',
                          'Current bonus +${_engine.gpBonus(s)}% '
                              '· score ×${_engine.gpMultiplier(s).toStringAsFixed(2)} '
                              '· cap +$kGpTotalBonusCapPct%',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                      enabled: s.gpTopUpCount < kGpMaxTopUpCount,
                      onTap: () {
                        final r = _engine.gpTopUp(s);
                        if (!r.ok) {
                          _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                          return;
                        }
                        setState(() {});
                        _run(() {});
                        _snack(
                          _t(
                            'GP 乘数总加成 +${r.bonusPct}%（第 ${r.count} 次）',
                            'GP total bonus +${r.bonusPct}% (#${r.count})',
                          ),
                        );
                      },
                    ),
                  ),
                if (isAllStar)
                  Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: Colors.purple.withValues(alpha: 0.10),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.add_circle_outline,
                        size: 18,
                      ),
                      title: Text(
                        _t(
                          '买分：$kAllStarBuyEnergyCost⚡ + $kAllStarBuyMoneyCost 钱'
                              ' → 分数 +${kAllStarBuyScore * s.scrapMultiplier}',
                          'Buy score: $kAllStarBuyEnergyCost⚡ + '
                              '$kAllStarBuyMoneyCost money → score '
                              '+${kAllStarBuyScore * s.scrapMultiplier}',
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: Text(
                        _t(
                          '次数不限 · 当前 ×${s.scrapMultiplier} 倍'
                              ' · 精力 ${s.energy}',
                          'Unlimited · current ×${s.scrapMultiplier}'
                              ' · energy ${s.energy}',
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                      enabled: s.energy >= kAllStarBuyEnergyCost,
                      onTap: () {
                        final r = _engine.buyAllStarScore(s);
                        if (!r.ok) {
                          _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                          return;
                        }
                        setState(() {});
                        _run(() {});
                        _snack(_t('分数 +${r.gain}', 'Score +${r.gain}'));
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('关闭', 'Close')),
            ),
          ],
        ),
      ),
    );
  }

  /// 城市之王详情 / 发起挑战
  void _showCityKingDialog(LifeSimSave s) {
    if (!s.inGang) {
      _dialog(
        title: _t('城市之王', 'City King'),
        children: [
          Text(
            _t(
              '加入或组建帮派后开启。每天可以挑战一个随机帮派，3 辆车逐一对位，胜场多者获胜。',
              'Unlocks after joining a gang. Each day you may challenge a random gang: 3 cars face off one by one.',
            ),
          ),
        ],
      );
      return;
    }
    final opp = s.cityOpponentCars;
    final canFight =
        !s.cityChallenged && s.energy >= LifeSimEngine.kCityEnergyCost;
    final scores = _engine.cityBaseScores(s);
    final mul = _engine.cityScoreMul(s);
    final myStrength = _engine.myCityStrength(s);
    final oppStrength = _engine.oppCityStrength(s);
    _dialog(
      title: _t('城市之王', 'City King'),
      children: [
        Text(
          _t('对手：${s.cityOpponentName ?? '——'}',
              'Opponent: ${s.cityOpponentName ?? '——'}'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          _t(
            '对手帮派战力 ${_fmt(s.cityOpponentPower)} · 活跃度 ${s.cityOpponentActivity}%',
            'Opponent power ${_fmt(s.cityOpponentPower)} · activity ${s.cityOpponentActivity}%',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          _t('对手三车：${opp.map(_fmt).join(' / ')}',
              'Opponent cars: ${opp.map(_fmt).join(' / ')}'),
          style: const TextStyle(fontSize: 13),
        ),
        Text(
          _t(
            '我方三车：${_engine.vehiclePowers(s).map(_fmt).join(' / ')}',
            'Your cars: ${_engine.vehiclePowers(s).map(_fmt).join(' / ')}',
          ),
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 6),
        Text(
          _t('战绩 ${s.cityWins} 胜 ${s.cityLosses} 负',
              'Record ${s.cityWins}W ${s.cityLosses}L'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const Divider(height: 16),
        // ---- 赛季（40 天）----
        Text(
          _t(
            '本赛季第 ${LifeSimEngine.citySeasonDay(s.day)}/'
                '$kCitySeasonDays 天 · ${s.citySeasonWins} 胜 · '
                '赛季分数 ${_fmt(s.citySeasonScore)}',
            'Season day ${LifeSimEngine.citySeasonDay(s.day)}/'
                '$kCitySeasonDays · ${s.citySeasonWins}W · '
                'season score ${_fmt(s.citySeasonScore)}',
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          _t(
            '本场结算分数：胜 +${_fmt(scores.win * mul)} / 败 +${_fmt(scores.loss * mul)}',
            'Settlement: win +${_fmt(scores.win * mul)} / loss +${_fmt(scores.loss * mul)}',
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        Text(
          _t(
            '（基础 胜 ${_fmt(scores.win)} / 败 ${_fmt(scores.loss)}，上限 $kCityMaxScore × 赛季倍率 $mul）',
            '(base win ${_fmt(scores.win)} / loss ${_fmt(scores.loss)}, '
                'cap $kCityMaxScore × season multiplier $mul)',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        Text(
          _t(
            '强度（车辆大小 × 活跃度加成）：我方 ${_fmt(myStrength)} vs 对手 ${_fmt(oppStrength)}'
                '　—— 差距越小，胜负分越接近；差距越大分差越大',
            'Strength (car size × activity): mine ${_fmt(myStrength)} vs '
                'opponent ${_fmt(oppStrength)}',
          ),
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: s.energy >= kGangActivityEnergyCost
                ? () {
                    Navigator.pop(context);
                    _boostGangActivity();
                  }
                : null,
            icon: const Icon(Icons.local_fire_department, size: 18),
            label: Text(
              _t(
                '提升活跃度（$kGangActivityEnergyCost 精力，随机 +$kGangActivityGainMin~$kGangActivityGainMax 点）',
                'Boost activity ($kGangActivityEnergyCost energy, '
                    '+$kGangActivityGainMin~$kGangActivityGainMax)',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _t('胜场奖励（每个宝箱 = 随机一个该稀有度部件）',
              'Win rewards (1 chest = 1 random part of that rarity)'),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        for (var i = 0; i < kCityWinMilestones.length; i++)
          Builder(
            builder: (context) {
              final m = kCityWinMilestones[i];
              final done = i < s.citySeasonClaimed;
              final next = i == s.citySeasonClaimed;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text(
                  _t(
                    '${done ? '✅' : (next ? '➡️' : '　')} ${m.wins} 胜：'
                        '${m.chestCount} × ${m.chestRarityName} 宝箱 + 代币 ${m.token}'
                        '（结算分数 ×${m.scoreMultiplier}）',
                    '${done ? '✅' : (next ? '➡️' : '  ')} ${m.wins} wins: '
                        '${m.chestCount} × ${m.chestRarityName} chests + '
                        '${m.token} tokens (score ×${m.scoreMultiplier})',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: done
                        ? Colors.green
                        : (next ? Colors.teal : Colors.grey[600]),
                    fontWeight: next ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 6),
        if (canFight)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _fightCityKing();
              },
              icon: const Icon(Icons.sports_kabaddi),
              label: Text(
                _t('发起挑战（${LifeSimEngine.kCityEnergyCost} 精力）',
                    'Challenge (${LifeSimEngine.kCityEnergyCost} energy)'),
              ),
            ),
          )
        else
          Text(
            s.cityChallenged
                ? _t('今日已挑战，明天再来。', 'Already challenged today.')
                : _t('精力不足，先结束这一天恢复精力。',
                    'Not enough energy. End the day to recover.'),
          ),
      ],
    );
  }

  // ===================================================================
  // 车库
  // ===================================================================

  Widget _buildGarage(LifeSimSave s) {
    final dup = _engine.findDuplicateParts(s);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          _t(
            '用活动奖励拿到的部件组建最多 3 辆车；部件数值随等级提升（等级在「部件」页升级）。'
            '同一个部件只能装在一辆车上，装到新车上时会自动从原车卸下。',
            'Build up to 3 cars from your parts. Stats scale with part level (upgrade on the Parts tab). '
            'Each part can only be fitted on one car; fitting it elsewhere removes it from the old car.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        if (dup.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            color: Colors.orange.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t(
                      '检测到 ${dup.length} 个部件被多辆车同时使用（旧存档遗留）',
                      '${dup.length} part(s) are used by multiple cars (legacy save)',
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t(
                      '同一部件只能装一辆车；清理后会保留在战力最高的那辆车上。',
                      'A part can only be on one car; cleanup keeps it on the strongest car.',
                    ),
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final n = _engine.removeDuplicateParts(s);
                        _run(() {});
                        _snack(
                          _t('已清理 $n 个重复部件', 'Removed $n duplicated part(s)'),
                        );
                      },
                      icon: const Icon(Icons.cleaning_services, size: 16),
                      label: Text(
                        _t('一键清理重复部件', 'Clean up duplicates'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        for (var i = 0; i < s.vehicles.length; i++) _vehicleCard(s, i),
      ],
    );
  }

  Widget _vehicleCard(LifeSimSave s, int index) {
    final v = s.vehicles[index];
    final val = _engine.evaluate(v, s.partLevels);
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
                Flexible(
                  child: Text(
                    _t('第 ${index + 1} 辆车', 'Car ${index + 1}'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    val.ok
                        ? _t(
                            'HP ${_fmt(val.hp)} · ATK ${_fmt(val.atk)}',
                            'HP ${_fmt(val.hp)} · ATK ${_fmt(val.atk)}',
                          )
                        : _t(val.error, val.error),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: val.ok ? Colors.green : Colors.red,
                    ),
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
                Expanded(
                  child: Text(
                    val.ok
                        ? _t(
                            '电力 ${val.powerSupply - val.powerConsumption}',
                            'Power ${val.powerSupply - val.powerConsumption}',
                          )
                        : '',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _run(() => _engine.autoBuild(s, index)),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text(
                    _t('一键最强', 'Auto'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _run(() => s.vehicles[index].clear()),
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(
                    _t('清空', 'Clear'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
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
                part == null
                    ? _t('空', 'Empty')
                    : '${_pn(part)}  Lv.${s.levelOf(part.id)}',
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
                          ? '${_pn(_engine.partIndex[ids[i]]!)} '
                                'Lv.${s.levelOf(ids[i])}'
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
                  '活跃度让帮派战力 ×${LifeSimEngine.activityMultiplier(s.gangActivity).toStringAsFixed(2)}'
                      '；也影响城市之王的胜负分',
                  'Activity multiplies gang power by '
                      '${LifeSimEngine.activityMultiplier(s.gangActivity).toStringAsFixed(2)}',
                ),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: s.gangActivity >= 100 ||
                          s.energy < kGangActivityEnergyCost
                      ? null
                      : () {
                          final r = _engine.boostGangActivity(s);
                          if (!r.ok) {
                            _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
                            return;
                          }
                          _run(() {});
                          _snack(
                            _t(
                              '帮派活跃度 +${r.gained}（当前 ${s.gangActivity}%）',
                              'Gang activity +${r.gained} (now ${s.gangActivity}%)',
                            ),
                          );
                        },
                  icon: const Icon(Icons.local_fire_department, size: 18),
                  label: Text(
                    _t(
                      '提升活跃度（$kGangActivityEnergyCost 精力，随机 +$kGangActivityGainMin~$kGangActivityGainMax 点）',
                      'Boost activity ($kGangActivityEnergyCost energy, '
                          '+$kGangActivityGainMin~$kGangActivityGainMax)',
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
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
  // 部件（碎片库存 + 等级升级）
  // ===================================================================

  Widget _buildParts(LifeSimSave s) {
    final ids = <String>[
      for (final id in s.ownedParts)
        if (_engine.partIndex[id] != null &&
            (_partFilter == null ||
                _engine.partIndex[id]!.category == _partFilter))
          id,
    ]..sort((a, b) {
      final pa = _engine.partIndex[a]!;
      final pb = _engine.partIndex[b]!;
      // 按稀有度降序，再按碎片降序
      final r = pb.rarity.index.compareTo(pa.rarity.index);
      if (r != 0) return r;
      return s.stockOf(b).compareTo(s.stockOf(a));
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t(
                  '碎片 = 重复获得的同名部件；升级消耗 碎片 + 紫票 + 代币（与游戏一致）。',
                  'Fragments come from duplicate parts. Upgrading costs fragments + Cash + Tokens.',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                _t(
                  '同一部件只能装在一辆车上（三辆车的部件不能重复）。',
                  'A part can only be fitted on one car (no duplicates across your 3 cars).',
                ),
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    label: Text(_t('全部', 'All'),
                        style: const TextStyle(fontSize: 12)),
                    selected: _partFilter == null,
                    onSelected: (_) => setState(() => _partFilter = null),
                  ),
                  for (final c in PartCategory.values)
                    ChoiceChip(
                      label: Text(
                        _categoryName(c),
                        style: const TextStyle(fontSize: 12),
                      ),
                      selected: _partFilter == c,
                      onSelected: (_) => setState(() => _partFilter = c),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ids.isEmpty
              ? Center(
                  child: Text(
                    _t('还没有部件，去活动里赚吧', 'No parts yet'),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: ids.length,
                  itemBuilder: (context, i) => _partTile(s, ids[i]),
                ),
        ),
      ],
    );
  }

  /// 某个部件当前装配在哪辆车上（未装配返回 null）
  int? _equippedCarIndex(LifeSimSave s, String partId) {
    for (var i = 0; i < s.vehicles.length; i++) {
      if (s.vehicles[i].allPartIds.contains(partId)) return i;
    }
    return null;
  }

  Widget _partTile(LifeSimSave s, String id) {
    final p = _engine.partIndex[id]!;
    final level = s.levelOf(id).clamp(1, p.maxLevel);
    final stock = s.stockOf(id);
    final cost = LifeSimEngine.upgradeCost(p, level);
    final need = cost?.pieces ?? 0;
    final canUpgrade = cost != null &&
        stock >= cost.pieces &&
        s.cash >= cost.cash &&
        s.token >= cost.token;
    final hpNow = p.hp(level);
    final atkNow = p.atk(level);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _engine.partLabel(id, _locale == 'zh'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_equippedCarIndex(s, id) != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      _t(
                        '第 ${_equippedCarIndex(s, id)! + 1} 辆车在用',
                        'On car ${_equippedCarIndex(s, id)! + 1}',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.teal,
                      ),
                    ),
                  ),
                Text(
                  'Lv.$level/${p.maxLevel}',
                  style: const TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'HP ${_fmt(hpNow)} · ATK ${_fmt(atkNow)}'
              '${p.power != 0 ? ' · 电力 ${p.power > 0 ? '+' : ''}${p.power}' : ''}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cost == null
                        ? _t('碎片 $stock · 已满级', 'Fragments $stock · MAX')
                        : _t(
                            '碎片 $stock/$need · 紫票 ${_fmt(cost.cash)} · 代币 ${_fmt(cost.token)}',
                            'Frag $stock/$need · Cash ${_fmt(cost.cash)} · Token ${_fmt(cost.token)}',
                          ),
                    style: TextStyle(
                      fontSize: 11,
                      color: cost != null && stock >= cost.pieces
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (cost != null)
                  TextButton.icon(
                    onPressed:
                        canUpgrade ? () => _upgradePart(s, id) : null,
                    icon: const Icon(Icons.arrow_upward, size: 16),
                    label: Text(
                      _t('升级', 'Upgrade'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(PartCategory c) => switch (c) {
    PartCategory.body => _t('车身', 'Body'),
    PartCategory.weapon => _t('武器', 'Weapon'),
    PartCategory.wheel => _t('车轮', 'Wheel'),
    PartCategory.gadget => _t('配件', 'Gadget'),
  };

  void _upgradePart(LifeSimSave s, String id) {
    final r = _engine.upgradePart(s, id);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
  }

  // ===================================================================
  // 成就
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

  // ===================================================================
  // 操作
  // ===================================================================

  void _makeChoice(ActivityChoice c) {
    final s = _save!;
    final isGp = LifeSimEngine.isGpActivity(
      _engine.periodForDay(s.day).activityId,
    );
    final r = _engine.makeChoice(s, c);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    if (isGp) {
      // GP：提示旗帜变动与分数
      final flag = r.flagDelta >= 0
          ? '+${r.flagDelta}'
          : '${r.flagDelta}';
      _snack(
        _t(
          '旗帜 $flag（剩 ${r.gpFlags}）· 分数 +${_fmt(r.progress)}',
          'Flags $flag (left ${r.gpFlags}) · Score +${_fmt(r.progress)}',
        ),
      );
      if (r.gpFlags <= 0) {
        _dialog(
          title: _t('旗帜归零', 'Flags at zero'),
          children: [
            Text(
              _t(
                '旗帜已经归零，今天的三个选项全部禁用。'
                '明天如果当天起始旗帜仍为 0，可以做 1 次低风险把它救回来。',
                'Your flags hit zero, so all three options are locked today. '
                    'Tomorrow, if the day starts at zero, one low-risk rescue '
                    'is allowed.',
              ),
            ),
          ],
        );
      }
      return;
    }
    if (r.scrapNodes.isNotEmpty) {
      // 废铁行动：本次达成了奖励节点（可能一次跨过多个）
      final shown = r.scrapNodes.take(5).toList();
      _dialog(
        title: _t('节点达成', 'Node reached'),
        children: [
          for (final n in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '🏁 ${n.progress}/$kScrapTotalProgress　${_scrapRewardText(n)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (r.scrapNodes.length > shown.length)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                _t(
                  '…以及另外 ${r.scrapNodes.length - shown.length} 个节点',
                  '…and ${r.scrapNodes.length - shown.length} more node(s)',
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            _t(
              '共达成 ${r.scrapNodes.length} 个节点，奖励已立即发放（明细见日志）',
              '${r.scrapNodes.length} node(s) reached; rewards granted (see the log)',
            ),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      );
      return;
    }
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
    } else if (r.settledActivityId != null) {
      // 废铁行动：只有节点奖励，进度条重置
      _snack(
        _t(
          '${LifeSimEngine.activityName(r.settledActivityId!, _locale)} 结束，'
          '进度条已重置（节点奖励已即时发放）',
          '${LifeSimEngine.activityName(r.settledActivityId!, _locale)} finished; '
          'the progress bar has been reset',
        ),
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

  void _boostGangActivity() {
    final s = _save!;
    final r = _engine.boostGangActivity(s);
    if (!r.ok) {
      _snack(_locale == 'zh' ? r.errorZh : r.errorEn);
      return;
    }
    _run(() {});
    _snack(
      _t(
        '帮派活跃度 +${r.gained}（当前 ${s.gangActivity}%）',
        'Gang activity +${r.gained} (now ${s.gangActivity}%)',
      ),
    );
    // 活跃度影响城市之王分数，方便连续提升 → 重新打开
    _showCityKingDialog(s);
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
        const Divider(height: 16),
        Text(
          _t('双方强度：我方 ${_fmt(r.myStrength)} vs 对手 ${_fmt(r.oppStrength)}',
              'Strength: mine ${_fmt(r.myStrength)} vs ${_fmt(r.oppStrength)}'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          _t('本场基础分：胜 ${_fmt(r.winScore)} / 败 ${_fmt(r.lossScore)}',
              'Base score: win ${_fmt(r.winScore)} / loss ${_fmt(r.lossScore)}'),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          _t(
            '赛季分数 +${_fmt(r.scoreGained)}'
                '（${r.won ? '胜' : '败'}场基础 ${_fmt(r.baseScore)} × ${r.scoreMultiplier} 倍）',
            'Season score +${_fmt(r.scoreGained)} '
                '(${r.won ? 'win' : 'loss'} base ${_fmt(r.baseScore)} × ${r.scoreMultiplier})',
          ),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          _t(
            '本赛季 ${r.seasonWins} 胜 · 累计 ${_fmt(r.seasonScore)} 分',
            'This season: ${r.seasonWins}W · ${_fmt(r.seasonScore)} score',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        if (r.chestParts.isNotEmpty || r.chestToken > 0) ...[
          const SizedBox(height: 6),
          Text(
            _t('🎁 达成胜场里程碑！',
                '🎁 Win milestone reached!'),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
          if (r.chestParts.isNotEmpty)
            Text(
              _t(
                '宝箱部件 ×${r.chestParts.length}：'
                '${r.chestParts.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join('、')}',
                'Chest parts ×${r.chestParts.length}: '
                    '${r.chestParts.map((id) => _engine.partIndex[id] == null ? id : _pn(_engine.partIndex[id]!)).join(', ')}',
              ),
              style: const TextStyle(fontSize: 13),
            ),
          if (r.chestToken > 0)
            Text(
              _t('里程碑代币 +${r.chestToken}',
                  'Milestone tokens +${r.chestToken}'),
              style: const TextStyle(fontSize: 13),
            ),
        ],
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
    // 部件不能重复：排除其他车辆正在使用的部件，
    // 以及本车其它插槽已装的部件（同一个部件不能装两次）
    final blocked = <String>{
      ..._engine.partsUsedByOtherCars(s, vehicleIndex),
      ...s.vehicles[vehicleIndex].allPartIds.where((id) => id != currentId),
    };
    final owned = <PartData>[
      for (final id in s.ownedParts)
        if (_engine.partIndex[id]?.category == category &&
            !blocked.contains(id))
          _engine.partIndex[id]!,
    ]..sort((a, b) {
      final sa = a.hpMax + a.atkMax;
      final sb = b.hpMax + b.atkMax;
      return sb.compareTo(sa);
    });
    final blockedInCategory = blocked
        .where((id) => _engine.partIndex[id]?.category == category)
        .length;

    _dialog(
      title: _t('选择部件', 'Choose a part'),
      children: [
        if (blockedInCategory > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              _t(
                '已排除其他车辆正在使用的 $blockedInCategory 个部件（同一部件只能装一辆车）',
                '$blockedInCategory part(s) hidden — already used by another car',
              ),
              style: TextStyle(fontSize: 12, color: Colors.orange[800]),
            ),
          ),
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
              Tab(text: _t('主界面', 'Home')),
              Tab(text: _t('部件', 'Parts')),
              Tab(text: _t('车库', 'Garage')),
              Tab(text: _t('帮派', 'Gang')),
              Tab(text: _t('成就', 'Achievements')),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildStatusBar(s),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMain(s),
                  _buildParts(s),
                  _buildGarage(s),
                  _buildGang(s),
                  _buildAchievements(s),
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
                  _showWelcome();
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

  /// 开局弹窗：以欢迎为主，另外告知获得了启程宝箱
  void _showWelcome() {
    _dialog(
      title: _t('欢迎', 'Welcome'),
      children: [
        Text(
          _locale == 'zh' ? kWelcomeZh : kWelcomeEn,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          _t(
            '另外，你获得了一个「启程宝箱」，已自动为你配好第 1 辆车（部件明细见日志）。',
            'You also received a Starter Chest, and your first car was auto-built (part details are in the log).',
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t(
            '在活动期间消耗精力做决策，活动结束时按档位领奖；'
            '重复获得的部件会变成碎片，可以在「部件」页升级。',
            'Spend energy on choices while an activity runs, then claim rank rewards when it ends. Duplicate parts become fragments you can spend to upgrade parts on the Parts tab.',
          ),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
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
