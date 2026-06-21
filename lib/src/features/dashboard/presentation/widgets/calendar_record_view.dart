import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
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

  int get _daysInMonth =>
      DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

  int get _firstWeekdayOffset =>
      DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

  static const List<String> _weekdayLabels = [
    '日',
    '月',
    '火',
    '水',
    '木',
    '金',
    '土',
  ];

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      children: [
        const Text(
          '記録',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(12),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left, size: 20),
                    color: AppColors.textSubtle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _monthTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right, size: 20),
                    color: AppColors.textSubtle,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _weekdayLabels
                    .map(
                      (label) => Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 6),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length + _firstWeekdayOffset,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (_, i) {
                  if (i < _firstWeekdayOffset) {
                    return const SizedBox();
                  }
                  final d = days[i - _firstWeekdayOffset];
                  final isActive = _currentActiveDays.contains(d);
                  final isSelected = d == _selectedDay;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedDay = d);
                      _loadSelectedDay();
                    },
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
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        d,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.black : Colors.white,
                          height: 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$_selectedDay日 ($_selectedWeekday)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    active ? '記録あり' : '未投稿',
                    style: TextStyle(
                      color: active
                          ? AppColors.orangeAccent
                          : AppColors.textInactive,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '食べた回数',
                style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '${_dayEntries.length}回',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              if (_loadingDay)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              else if (_dayEntries.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'この日は記録がありません。',
                  style: TextStyle(color: AppColors.textInactive, fontSize: 12),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Text(
                  '訪れたお店・自炊',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in _dayEntries)
                      GestureDetector(
                        onTap: () => widget.onOpenPost(entry),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.blackElevated.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (entry.imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(
                                    entry.imageUrl,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              if (entry.imageUrl.isNotEmpty)
                                const SizedBox(width: 6),
                              Text(
                                entry.placeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '一緒に行った友達',
                  style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final token
                        in _dayEntries
                            .expand((e) => e.companionNames)
                            .toSet()
                            .take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Builder(
                          builder: (context) {
                            final resolved = FriendAvatar.fromToken(token);
                            return FriendAvatar(
                              displayName: resolved.displayName,
                              avatarUrl: resolved.avatarUrl,
                              radius: 16,
                              showStatusDot: true,
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '栄養サマリ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NutritionKpi(
                      label: '平均カロリー',
                      value: '${widget.summary.caloriesAvg} kcal',
                    ),
                    _NutritionKpi(
                      label: '平均たんぱく質',
                      value: '${widget.summary.proteinAvg} g',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _Kpi(
                      label: '連続記録',
                      value: '${widget.summary.streakDays}日',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kpi(
                      label: '今月の投稿',
                      value: '${widget.summary.monthlyShots.length}日',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text('メモ', style: TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(widget.summary.aiSuggestion),
            ],
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
          style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    );
  }
}

class _NutritionKpi extends StatelessWidget {
  const _NutritionKpi({required this.label, required this.value});
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
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
      ],
    );
  }
}
