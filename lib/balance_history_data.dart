/// 历史平衡数据：历次平衡性调整记录（程序内数据源）。
///
/// 与 `balance_notes/` 目录中的记录保持一致；
/// 该目录不参与 Flutter 打包（仅 `assets/` 下声明的目录会打包），
/// 因此这里内置一份结构化数据供「历史平衡」界面展示。
library;

/// 单项改动
class BalanceChange {
  /// 部件中文名
  final String partName;

  /// 字段：'hp' | 'power' | 'slots' | 'note'
  final String field;

  /// 旧值（展示用文本）
  final String oldValue;

  /// 新值（展示用文本）
  final String newValue;

  /// 变化幅度展示文本（如 '+10.7%'、'配件 +1'），无则 null。
  ///
  /// 注意：`power`（电力）字段这里填写的百分比**不用于界面展示**，
  /// 界面会按 [oldValue]/[newValue] 自动换算为绝对差值（如 `+5`），
  /// 保留该字段仅作调整记录之用。
  final String? percent;

  /// 幅度是否为增加（决定颜色：绿=增、红=减）。
  ///
  /// 同理，`power` 字段的颜色由新旧值自动判定。
  final bool percentUp;

  const BalanceChange({
    required this.partName,
    required this.field,
    required this.oldValue,
    required this.newValue,
    this.percent,
    this.percentUp = true,
  });
}

/// 一次平衡性调整（某日期的一批改动）
class BalancePatch {
  /// 日期 'YYYY-MM-DD'
  final String date;

  /// 服务器：'intl' | 'cn'
  final String server;

  /// 备注（中文）
  final String? noteZh;

  /// 备注（英文）
  final String? noteEn;

  /// 改动列表
  final List<BalanceChange> changes;

  const BalancePatch({
    required this.date,
    this.server = 'intl',
    this.noteZh,
    this.noteEn,
    required this.changes,
  });
}

/// 历次平衡性调整（最新在前）
const List<BalancePatch> kBalanceHistory = [
  BalancePatch(
    date: '2026-09-10',
    changes: [
      BalanceChange(
        partName: '肥猫巴士',
        field: 'hp',
        oldValue: '35,750',
        newValue: '32,500',
        percent: '-9.1%',
        percentUp: false,
      ),
    ],
  ),
  BalancePatch(
    date: '2026-09-09',
    noteZh: '',
    noteEn: '',
    changes: [
      BalanceChange(
        partName: '肥猫巴士',
        field: 'hp',
        oldValue: '35,825',
        newValue: '35,750',
        percent: '-0.2%',
        percentUp: false,
      ),
      BalanceChange(
        partName: '幻影马戏团',
        field: 'hp',
        oldValue: '46,088',
        newValue: '51,000',
        percent: '+10.7%',
      ),
      BalanceChange(
        partName: '酷酷鸭',
        field: 'hp',
        oldValue: '52,560',
        newValue: '55,000',
        percent: '+4.6%',
      ),
      BalanceChange(
        partName: '绿龙',
        field: 'hp',
        oldValue: '48,392',
        newValue: '50,000',
        percent: '+3.3%',
      ),
      BalanceChange(
        partName: '繁花之星',
        field: 'hp',
        oldValue: '40,164',
        newValue: '42,000',
        percent: '+4.6%',
      ),
      BalanceChange(
        partName: 'R.A.M.',
        field: 'power',
        oldValue: '35',
        newValue: '40',
        percent: '+14.3%',
      ),
      BalanceChange(
        partName: 'R.A.M.',
        field: 'hp',
        oldValue: '32,568',
        newValue: '33,000',
        percent: '+1.3%',
      ),
      BalanceChange(
        partName: 'R.A.M.',
        field: 'slots',
        oldValue: '3武/3轮/1配',
        newValue: '3武/3轮/2配',
        percent: '配件 +1',
      ),
      BalanceChange(
        partName: '铁娘子',
        field: 'power',
        oldValue: '35',
        newValue: '40',
        percent: '+14.3%',
      ),
    ],
  ),
  BalancePatch(
    date: '2026-08-27',
    noteZh: '',
    noteEn: '',
    changes: [
      BalanceChange(
        partName: '铁娘子',
        field: 'hp',
        oldValue: '48,120',
        newValue: '53,000',
        percent: '+10.1%',
      ),
    ],
  ),
];
