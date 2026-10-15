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

  /// 字段：'hp' | 'atk' | 'power' | 'slots' | 'note'
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

/// 同一天内的第几次调整（1 起，按时间先后）
///
/// [kBalanceHistory] 是「最新在前」，所以同一天里**靠后**的条目序号更小：
/// 最后一个同日期条目 = 1st、倒数第二个 = 2nd，依次类推。
int balanceOrdinalOf(int index) {
  final date = kBalanceHistory[index].date;
  var later = 0;
  for (var j = index + 1; j < kBalanceHistory.length; j++) {
    if (kBalanceHistory[j].date == date) later++;
  }
  return later + 1;
}

/// 序号后缀：1 → '1st'、2 → '2nd'、3 → '3rd'、其余 'Nth'
String balanceOrdinalSuffix(int ordinal) {
  final mod100 = ordinal % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${ordinal}th';
  switch (ordinal % 10) {
    case 1:
      return '${ordinal}st';
    case 2:
      return '${ordinal}nd';
    case 3:
      return '${ordinal}rd';
    default:
      return '${ordinal}th';
  }
}

/// 历次平衡性调整（最新在前）
const List<BalancePatch> kBalanceHistory = [
  // 2026-10-15 当天第二次调整（最新）
  BalancePatch(
    date: '2026-10-15',
    changes: [
      BalanceChange(
        partName: '口香糖枪',
        field: 'power',
        oldValue: '10',
        newValue: '15',
        percent: '+50.0%',
      ),
      BalanceChange(
        partName: '口香糖枪',
        field: 'atk',
        oldValue: '8,500',
        newValue: '10,920',
        percent: '+28.5%',
      ),
    ],
  ),
  // 2026-10-15 当天第一次调整
  BalancePatch(
    date: '2026-10-15',
    changes: [
      BalanceChange(
        partName: '蝙蝠',
        field: 'atk',
        oldValue: '8,000',
        newValue: '9,000',
        percent: '+12.5%',
      ),
      BalanceChange(
        partName: '口香糖枪',
        field: 'power',
        oldValue: '15',
        newValue: '10',
        percent: '-33.3%',
        percentUp: false,
      ),
      BalanceChange(
        partName: '口香糖枪',
        field: 'atk',
        oldValue: '10,920',
        newValue: '8,500',
        percent: '-22.2%',
        percentUp: false,
      ),
      BalanceChange(
        partName: '等离子哨兵',
        field: 'atk',
        oldValue: '4,500',
        newValue: '5,400',
        percent: '+20.0%',
      ),
    ],
  ),
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
