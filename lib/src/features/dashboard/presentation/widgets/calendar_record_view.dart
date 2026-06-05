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
  late String _selectedDay;
  List<RecordDayEntry> _dayEntries = [];
  bool _loadingDay = false;

  @override
  void initState() {
    super.initState();
    _activeDays = widget.summary.monthlyShots.toSet();
    final now = DateTime.now();
    _selectedDay = widget.summary.monthlyShots.isNotEmpty
        ? widget.summary.monthlyShots.first
        : '${now.day}';
    _loadSelectedDay();
  }

  Future<void> _loadSelectedDay() async {
    setState(() => _loadingDay = true);
    final day = int.tryParse(_selectedDay) ?? 1;
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, day);
    final entries = await widget.loadDayEntries(date);
    if (!mounted) return;
    setState(() {
      _dayEntries = entries;
      _loadingDay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(31, (i) => '${i + 1}');
    final active = _activeDays.contains(_selectedDay);

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
              const Text(
                '今月のカレンダー',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1,
                ),
                itemBuilder: (_, i) {
                  final d = days[i];
                  final isActive = _activeDays.contains(d);
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
                    '$_selectedDay日',
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
              else if (_dayEntries.isNotEmpty) ...[
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
                            color: AppColors.blackElevated.withValues(alpha: 0.7),
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
                    for (final name in _dayEntries
                        .expand((e) => e.companionNames)
                        .toSet()
                        .take(6))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FriendAvatar(
                          displayName: name.isNotEmpty ? name[0] : '?',
                          radius: 16,
                          showStatusDot: true,
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
              const Text('栄養サマリ', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.blackElevated.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  '準備中 — 栄養・AI分析は今後のアップデートで提供予定です',
                  style: TextStyle(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.35,
                  ),
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
              const Text(
                'メモ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
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
        Text(label, style: TextStyle(color: AppColors.textSubtle, fontSize: 12)),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      ],
    );
  }
}
