import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/format/yen_format.dart';
import 'friend_avatar.dart';
import 'glass_panel.dart';

/// Calendar-style record view with real day data from Supabase.
class CalendarRecordView extends StatefulWidget {
  const CalendarRecordView({
    super.key,
    required this.summary,
    required this.loadDayEntries,
    required this.onOpenPost,
  });

  final RecordSummary summary;
  final Future<List<RecordDayEntry>> Function(DateTime dayLocal) loadDayEntries;
  final Future<void> Function(RecordDayEntry entry) onOpenPost;

  @override
  State<CalendarRecordView> createState() => _CalendarRecordViewState();
}

class _CalendarRecordViewState extends State<CalendarRecordView> {
  late final Set<String> _activeDays;
  late DateTime _currentMonth;
  late String _selectedDay;
  List<RecordDayEntry> _dayEntries = [];
  bool _loadingDay = false;

  static const List<String> _weekdayLabels = [
    '日',
    '月',
    '火',
    '水',
    '木',
    '金',
    '土',
  ];

  int get _daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  int get _firstWeekdayOffset =>
      DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

  String get _monthTitle => '${_currentMonth.year}年${_currentMonth.month}月';

  String get _selectedWeekday {
    final day = int.tryParse(_selectedDay) ?? 1;
    final weekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      day,
    ).weekday;
    return _weekdayLabels[weekday % 7];
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentMonth.year == now.year && _currentMonth.month == now.month;
  }

  Set<String> get _currentActiveDays => _isCurrentMonth ? _activeDays : {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    final monthlyShots = [...widget.summary.monthlyShots]
      ..sort((a, b) {
        final ai = int.tryParse(a) ?? 0;
        final bi = int.tryParse(b) ?? 0;
        return ai.compareTo(bi);
      });
    _activeDays = monthlyShots.toSet();
    _selectedDay = '${now.day.clamp(1, _daysInMonth)}';
    _loadSelectedDay();
  }

  Future<void> _loadSelectedDay() async {
    setState(() => _loadingDay = true);
    final day = int.tryParse(_selectedDay) ?? 1;
    final date = DateTime(_currentMonth.year, _currentMonth.month, day);
    final entries = await widget.loadDayEntries(date);
    if (!mounted) return;
    setState(() {
      _dayEntries = entries;
      _loadingDay = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      final limitedDay = int.tryParse(_selectedDay) ?? 1;
      _selectedDay = '${limitedDay.clamp(1, _daysInMonth)}';
    });
    _loadSelectedDay();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(_daysInMonth, (i) => '${i + 1}');
    final active = _currentActiveDays.contains(_selectedDay);
    final selectedDaySpendingYen = _dayEntries.fold<int>(
      0,
      (sum, entry) => sum + (entry.priceYen ?? 0),
    );
    final companionTokens = _dayEntries
        .expand((e) => e.companionNames)
        .toSet()
        .take(6)
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '記録',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _CalendarPanel(
            monthTitle: _monthTitle,
            days: days,
            firstWeekdayOffset: _firstWeekdayOffset,
            activeDays: _currentActiveDays,
            selectedDay: _selectedDay,
            onPreviousMonth: () => _changeMonth(-1),
            onNextMonth: () => _changeMonth(1),
            onDaySelected: (day) {
              setState(() => _selectedDay = day);
              _loadSelectedDay();
            },
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _DayDetailPanel(
              selectedDay: _selectedDay,
              selectedWeekday: _selectedWeekday,
              hasRecord: active,
              loading: _loadingDay,
              entries: _dayEntries,
              mealCount: _dayEntries.length,
              daySpendingYen: selectedDaySpendingYen,
              companionTokens: companionTokens,
              onOpenPost: widget.onOpenPost,
            ),
          ),
          const SizedBox(height: 8),
          _BottomSummaryPanel(summary: widget.summary),
        ],
      ),
    );
  }
}

class _CalendarPanel extends StatelessWidget {
  const _CalendarPanel({
    required this.monthTitle,
    required this.days,
    required this.firstWeekdayOffset,
    required this.activeDays,
    required this.selectedDay,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDaySelected,
  });

  final String monthTitle;
  final List<String> days;
  final int firstWeekdayOffset;
  final Set<String> activeDays;
  final String selectedDay;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<String> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final rowCount = ((days.length + firstWeekdayOffset) / 7).ceil();

    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left, size: 18),
                color: AppColors.textSubtle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
              Expanded(
                child: Text(
                  monthTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right, size: 18),
                color: AppColors.textSubtle,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: _CalendarRecordViewState._weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSubtle.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              final cellSize = (constraints.maxWidth - 6 * 4) / 7;
              final gridHeight = rowCount * cellSize + (rowCount - 1) * 4;
              return SizedBox(
                height: gridHeight,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length + firstWeekdayOffset,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    mainAxisExtent: cellSize,
                  ),
                  itemBuilder: (_, i) {
                    if (i < firstWeekdayOffset) {
                      return const SizedBox();
                    }
                    final d = days[i - firstWeekdayOffset];
                    final isActive = activeDays.contains(d);
                    final isSelected = d == selectedDay;
                    return GestureDetector(
                      onTap: () => onDaySelected(d),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? AppColors.orange
                              : isActive
                              ? AppColors.orange.withValues(alpha: 0.35)
                              : AppColors.cardElevated,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.orangeAccent.withValues(alpha: 0.65)
                                : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected ? Colors.black : Colors.white,
                            height: 1,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  const _DayDetailPanel({
    required this.selectedDay,
    required this.selectedWeekday,
    required this.hasRecord,
    required this.loading,
    required this.entries,
    required this.mealCount,
    required this.daySpendingYen,
    required this.companionTokens,
    required this.onOpenPost,
  });

  final String selectedDay;
  final String selectedWeekday;
  final bool hasRecord;
  final bool loading;
  final List<RecordDayEntry> entries;
  final int mealCount;
  final int daySpendingYen;
  final List<String> companionTokens;
  final Future<void> Function(RecordDayEntry entry) onOpenPost;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$selectedDay日 ($selectedWeekday)',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Text(
                hasRecord ? '記録あり' : '未投稿',
                style: TextStyle(
                  color: hasRecord
                      ? AppColors.orangeAccent
                      : AppColors.textInactive,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _CompactMetric(label: '食べた回数', value: '$mealCount回'),
              if (daySpendingYen > 0) ...[
                const SizedBox(width: 16),
                _CompactMetric(
                  label: 'この日の食費',
                  value: formatYen(daySpendingYen),
                  valueColor: AppColors.orangeAccent,
                ),
              ],
            ],
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'この日は記録がありません。',
                style: TextStyle(
                  color: AppColors.textInactive.withValues(alpha: 0.9),
                  fontSize: 12,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return _DayEntryPhoto(
                    entry: entry,
                    onTap: () => onOpenPost(entry),
                  );
                },
              ),
            ),
            if (companionTokens.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    '一緒',
                    style: TextStyle(
                      color: AppColors.textSubtle.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  for (final token in companionTokens)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Builder(
                        builder: (context) {
                          final resolved = FriendAvatar.fromToken(token);
                          return FriendAvatar(
                            displayName: resolved.displayName,
                            avatarUrl: resolved.avatarUrl,
                            radius: 13,
                            showStatusDot: true,
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DayEntryPhoto extends StatelessWidget {
  const _DayEntryPhoto({required this.entry, required this.onTap});

  final RecordDayEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blackElevated,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 76,
          height: 76,
          child: entry.imageUrl.isNotEmpty
              ? Image.network(
                  entry.imageUrl,
                  fit: BoxFit.cover,
                )
              : Container(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.restaurant_outlined,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
        ),
      ),
    );
  }
}

class _BottomSummaryPanel extends StatelessWidget {
  const _BottomSummaryPanel({required this.summary});

  final RecordSummary summary;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '食費サマリ',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Kpi(
                  label: '今日',
                  value: formatYen(summary.todaySpendingYen),
                ),
              ),
              Expanded(
                child: _Kpi(
                  label: '今週',
                  value: formatYen(summary.weekSpendingYen),
                ),
              ),
              Expanded(
                child: _Kpi(
                  label: '今月',
                  value: formatYen(summary.monthSpendingYen),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSubtle, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textSubtle, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
