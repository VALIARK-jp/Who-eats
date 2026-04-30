import 'package:flutter/material.dart';

import '../../domain/entities/app_entities.dart';
import '../../../../core/theme/app_theme.dart';
import 'friend_avatar.dart';
import 'glass_panel.dart';

/// Calendar-style record view.
///
/// MVP: domain model only has monthly shots + basic nutrition stats.
/// Daily details are represented with light mock placeholders.
class CalendarRecordView extends StatefulWidget {
  const CalendarRecordView({
    super.key,
    required this.summary,
  });

  final RecordSummary summary;

  @override
  State<CalendarRecordView> createState() => _CalendarRecordViewState();
}

class _CalendarRecordViewState extends State<CalendarRecordView> {
  late final Set<String> _activeDays;
  String _selectedDay = '1';

  @override
  void initState() {
    super.initState();
    _activeDays = widget.summary.monthlyShots.toSet();
    _selectedDay = widget.summary.monthlyShots.isNotEmpty
        ? widget.summary.monthlyShots.first
        : '1';
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(31, (i) => '${i + 1}');
    final active = _activeDays.contains(_selectedDay);
    final selectedIndex = days.indexOf(_selectedDay);

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
                    onTap: () => setState(() => _selectedDay = d),
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
                '${active ? (selectedIndex % 3) + 1 : 0}回',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '訪れたお店',
                style: TextStyle(color: AppColors.textSubtle, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int k = 0; k < (active ? 3 : 0); k++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.blackElevated.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        ['and people udagawa', '恵比寿焼肉', '渋谷らーめん本舗'][k],
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
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
                  for (int i = 0; i < (active ? 3 : 0); i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                      child: FriendAvatar(
                        displayName: ['H', 'R', 'M'][i],
                        radius: 16,
                        showStatusDot: true,
                      ),
                    ),
                ],
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
              const Text('栄養サマリ', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _Kpi(label: '平均カロリー', value: '${widget.summary.caloriesAvg} kcal'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Kpi(label: '平均タンパク質', value: '${widget.summary.proteinAvg} g'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'AI提案',
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

