import 'package:flutter/material.dart';

// ─── Mock Data ───────────────────────────────────────────────────────────────

class LeaderboardEntry {
  final int rank;
  final String name;
  final int points;
  final String trend; // 'up', 'down', 'same'
  final int trendDelta;

  const LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.trend,
    required this.trendDelta,
  });
}

class CommunityGoal {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int currentPoints;
  final int targetPoints;
  final int daysLeft;

  const CommunityGoal({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentPoints,
    required this.targetPoints,
    required this.daysLeft,
  });

  double get progress => (currentPoints / targetPoints).clamp(0.0, 1.0);
}

class ImpactStat {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const ImpactStat({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
}

const _districtLeaderboard = [
  LeaderboardEntry(
      rank: 1, name: 'South Delhi (D-5)', points: 120400, trend: 'up', trendDelta: 2),
  LeaderboardEntry(
      rank: 2, name: 'Central Delhi (D-2)', points: 115200, trend: 'same', trendDelta: 0),
  LeaderboardEntry(
      rank: 3, name: 'West Delhi (D-9)', points: 109800, trend: 'up', trendDelta: 1),
  LeaderboardEntry(
      rank: 4, name: 'North Delhi (D-3)', points: 98500, trend: 'down', trendDelta: 1),
  LeaderboardEntry(
      rank: 5, name: 'East Delhi (D-8)', points: 87200, trend: 'up', trendDelta: 3),
];

const _communityGoals = [
  CommunityGoal(
    title: 'New Solar Lighting',
    description: 'Solar-powered lamps for Lodhi Garden walking paths',
    icon: Icons.solar_power_rounded,
    color: Color(0xFFF57C00),
    currentPoints: 15000,
    targetPoints: 20000,
    daysLeft: 12,
  ),
  CommunityGoal(
    title: 'Water Fountain Station',
    description: 'Public water fountains at 3 DDA parks',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF0288D1),
    currentPoints: 8200,
    targetPoints: 25000,
    daysLeft: 28,
  ),
  CommunityGoal(
    title: 'Butterfly Garden',
    description: 'Native flowering plants in Deer Park',
    icon: Icons.spa_rounded,
    color: Color(0xFF7B1FA2),
    currentPoints: 4100,
    targetPoints: 10000,
    daysLeft: 45,
  ),
];

const _impactStats = [
  ImpactStat(
    label: 'CO₂ Offset',
    value: '347',
    unit: 'kg saved',
    icon: Icons.eco_rounded,
    color: Color(0xFF43A047),
  ),
  ImpactStat(
    label: 'Trees Scanned',
    value: '89',
    unit: 'species',
    icon: Icons.park_rounded,
    color: Color(0xFF2E7D32),
  ),
  ImpactStat(
    label: 'Quests Done',
    value: '23',
    unit: 'completed',
    icon: Icons.task_alt_rounded,
    color: Color(0xFF1565C0),
  ),
  ImpactStat(
    label: 'Walk Hours',
    value: '64',
    unit: 'hours logged',
    icon: Icons.directions_walk_rounded,
    color: Color(0xFFF57C00),
  ),
];

// ─── Profile / Impact Screen ─────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Impact Dashboard',
                style: tt.titleLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      cs.primaryContainer.withValues(alpha: 0.3),
                      cs.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Profile card ─────────────────────────────────────
                  _ProfileHeader(cs: cs, tt: tt),
                  const SizedBox(height: 24),

                  // ── Impact stats grid ────────────────────────────────
                  _SectionTitle(title: 'Your Impact', cs: cs, tt: tt),
                  const SizedBox(height: 12),
                  _ImpactStatsGrid(cs: cs, tt: tt),
                  const SizedBox(height: 28),

                  // ── Community point pooling ──────────────────────────
                  _SectionTitle(
                      title: 'Community Goals', cs: cs, tt: tt),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Community goal cards (horizontal scroll)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 200,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: _communityGoals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  return _CommunityGoalCard(
                    goal: _communityGoals[index],
                    cs: cs,
                    tt: tt,
                  );
                },
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 28),

                  // ── District Leaderboard ─────────────────────────────
                  _SectionTitle(
                      title: 'District Leaderboard', cs: cs, tt: tt),
                  const SizedBox(height: 12),
                  _LeaderboardTable(cs: cs, tt: tt),
                  const SizedBox(height: 100), // bottom padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  final TextTheme tt;

  const _SectionTitle({
    required this.title,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── Profile Header Card ─────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _ProfileHeader({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Center(
              child: Icon(Icons.person_rounded, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citizen Scientist',
                  style: tt.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                // Trust badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9)),
                      const SizedBox(width: 4),
                      Text(
                        'Verified Pro',
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Total points
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '12,580',
                style: tt.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Total XP',
                style: tt.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Impact Stats Grid ───────────────────────────────────────────────────────

class _ImpactStatsGrid extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _ImpactStatsGrid({required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: _impactStats.map((stat) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: stat.color.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: stat.color.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: stat.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(stat.icon, color: stat.color, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    stat.label,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    stat.value,
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      stat.unit,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Community Goal Card ─────────────────────────────────────────────────────

class _CommunityGoalCard extends StatelessWidget {
  final CommunityGoal goal;
  final ColorScheme cs;
  final TextTheme tt;

  const _CommunityGoalCard({
    required this.goal,
    required this.cs,
    required this.tt,
  });

  String _formatPoints(int pts) {
    if (pts >= 1000) return '${(pts / 1000).toStringAsFixed(1)}k';
    return pts.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: goal.color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: goal.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goal.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(goal.icon, color: goal.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${goal.daysLeft} days left',
                      style: tt.labelSmall?.copyWith(
                        color: goal.daysLeft <= 14
                            ? const Color(0xFFEF5350)
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            goal.description,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),

          // Progress bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatPoints(goal.currentPoints),
                style: tt.labelSmall?.copyWith(
                  color: goal.color,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
              Text(
                _formatPoints(goal.targetPoints),
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: goal.color.withValues(alpha: 0.1),
              color: goal.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(goal.progress * 100).toInt()}% funded',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard Table ───────────────────────────────────────────────────────

class _LeaderboardTable extends StatelessWidget {
  final ColorScheme cs;
  final TextTheme tt;

  const _LeaderboardTable({required this.cs, required this.tt});

  String _formatPts(int pts) {
    return pts.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Leaderboard rows
          for (int i = 0; i < _districtLeaderboard.length; i++) ...[
            _LeaderboardRow(
              entry: _districtLeaderboard[i],
              cs: cs,
              tt: tt,
            ),
            if (i < _districtLeaderboard.length - 1)
              Divider(
                height: 1,
                indent: 60,
                endIndent: 16,
                color: cs.outline.withValues(alpha: 0.1),
              ),
          ],

          // Separator
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: cs.primary.withValues(alpha: 0.15),
          ),

          // Your district (highlighted)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.25),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Rank badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '#12',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Your District (D-7)',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.my_location_rounded,
                              size: 14, color: cs.primary),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_formatPts(45200)} pts',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Trend
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF43A047).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded,
                          size: 12, color: Color(0xFF43A047)),
                      const SizedBox(width: 2),
                      Text(
                        '3',
                        style: tt.labelSmall?.copyWith(
                          color: const Color(0xFF43A047),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final ColorScheme cs;
  final TextTheme tt;

  const _LeaderboardRow({
    required this.entry,
    required this.cs,
    required this.tt,
  });

  Color get _rankColor {
    switch (entry.rank) {
      case 1:
        return const Color(0xFFFFD54F);
      case 2:
        return const Color(0xFFB0BEC5);
      case 3:
        return const Color(0xFFCD8032);
      default:
        return cs.onSurfaceVariant;
    }
  }

  IconData get _trendIcon {
    switch (entry.trend) {
      case 'up':
        return Icons.arrow_upward_rounded;
      case 'down':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.remove_rounded;
    }
  }

  Color get _trendColor {
    switch (entry.trend) {
      case 'up':
        return const Color(0xFF43A047);
      case 'down':
        return const Color(0xFFEF5350);
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _formatPts(int pts) {
    return pts.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: entry.rank <= 3
                  ? _rankColor.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: entry.rank <= 3
                  ? Icon(Icons.emoji_events_rounded,
                      size: 20, color: _rankColor)
                  : Text(
                      '#${entry.rank}',
                      style: tt.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + points
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatPts(entry.points)} pts',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Trend indicator
          if (entry.trendDelta > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _trendColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_trendIcon, size: 12, color: _trendColor),
                  const SizedBox(width: 2),
                  Text(
                    '${entry.trendDelta}',
                    style: tt.labelSmall?.copyWith(
                      color: _trendColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else
            Icon(Icons.remove_rounded,
                size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
        ],
      ),
    );
  }
}
