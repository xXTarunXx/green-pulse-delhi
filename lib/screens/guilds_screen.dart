import 'package:flutter/material.dart';

// ─── Mock Guild & Quest Data ─────────────────────────────────────────────────

enum QuestDifficulty { easy, medium, hard }

extension QuestDifficultyMeta on QuestDifficulty {
  String get label {
    switch (this) {
      case QuestDifficulty.easy:
        return 'Easy';
      case QuestDifficulty.medium:
        return 'Medium';
      case QuestDifficulty.hard:
        return 'Hard';
    }
  }

  Color get color {
    switch (this) {
      case QuestDifficulty.easy:
        return const Color(0xFF66BB6A);
      case QuestDifficulty.medium:
        return const Color(0xFFFFA726);
      case QuestDifficulty.hard:
        return const Color(0xFFEF5350);
    }
  }

  IconData get icon {
    switch (this) {
      case QuestDifficulty.easy:
        return Icons.sentiment_satisfied_alt_rounded;
      case QuestDifficulty.medium:
        return Icons.local_fire_department_rounded;
      case QuestDifficulty.hard:
        return Icons.bolt_rounded;
    }
  }
}

class Guild {
  final String name;
  final String tagline;
  final IconData icon;
  final Color color;
  final int memberCount;
  final int weeklyXP;

  const Guild({
    required this.name,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.memberCount,
    required this.weeklyXP,
  });
}

class Quest {
  final String title;
  final String time;
  final String location;
  final String trustReq;
  final IconData icon;
  final Color accentColor;
  final QuestDifficulty difficulty;
  final int xpReward;
  final int spotsLeft;
  final int totalSpots;
  final double progress; // 0.0–1.0 for weekly quest progress

  const Quest({
    required this.title,
    required this.time,
    required this.location,
    required this.trustReq,
    required this.icon,
    required this.accentColor,
    required this.difficulty,
    required this.xpReward,
    required this.spotsLeft,
    required this.totalSpots,
    required this.progress,
  });
}

const List<Guild> _guilds = [
  Guild(
    name: 'Lodhi Guardians',
    tagline: 'Protecting Delhi\'s green lungs',
    icon: Icons.shield_rounded,
    color: Color(0xFF2E7D32),
    memberCount: 142,
    weeklyXP: 12400,
  ),
  Guild(
    name: 'Yamuna Warriors',
    tagline: 'River cleanup & biodiversity',
    icon: Icons.water_drop_rounded,
    color: Color(0xFF0288D1),
    memberCount: 98,
    weeklyXP: 9800,
  ),
  Guild(
    name: 'Solar Pioneers',
    tagline: 'Community solar initiatives',
    icon: Icons.solar_power_rounded,
    color: Color(0xFFF57C00),
    memberCount: 67,
    weeklyXP: 8200,
  ),
];

const List<Quest> _weeklyQuests = [
  Quest(
    title: 'Senior Yoga Circle',
    time: 'Tomorrow, 7:00 AM',
    location: 'Central Lawn, Lodhi Garden',
    trustReq: 'Verified Basic',
    icon: Icons.self_improvement_rounded,
    accentColor: Color(0xFFFF8A65),
    difficulty: QuestDifficulty.easy,
    xpReward: 120,
    spotsLeft: 8,
    totalSpots: 20,
    progress: 0.6,
  ),
  Quest(
    title: 'District 5K Green Run',
    time: 'Sunday, 6:00 AM',
    location: 'Outer Loop Trail, Deer Park',
    trustReq: 'Verified Pro',
    icon: Icons.directions_run_rounded,
    accentColor: Color(0xFF66BB6A),
    difficulty: QuestDifficulty.medium,
    xpReward: 250,
    spotsLeft: 14,
    totalSpots: 50,
    progress: 0.35,
  ),
  Quest(
    title: 'Lake Cleanup Drive',
    time: 'Saturday, 9:00 AM',
    location: 'Hauz Khas Lake',
    trustReq: 'Open to All',
    icon: Icons.cleaning_services_rounded,
    accentColor: Color(0xFF42A5F5),
    difficulty: QuestDifficulty.easy,
    xpReward: 180,
    spotsLeft: 25,
    totalSpots: 40,
    progress: 0.82,
  ),
  Quest(
    title: 'Night Biodiversity Census',
    time: 'Friday, 8:30 PM',
    location: 'Sanjay Van Reserve',
    trustReq: 'Verified Pro',
    icon: Icons.nightlight_round,
    accentColor: Color(0xFFAB47BC),
    difficulty: QuestDifficulty.hard,
    xpReward: 400,
    spotsLeft: 3,
    totalSpots: 12,
    progress: 0.15,
  ),
  Quest(
    title: 'Tree Plantation Rally',
    time: 'Next Monday, 8:00 AM',
    location: 'Ridge Forest, North Delhi',
    trustReq: 'Open to All',
    icon: Icons.park_rounded,
    accentColor: Color(0xFF2E7D32),
    difficulty: QuestDifficulty.easy,
    xpReward: 200,
    spotsLeft: 30,
    totalSpots: 100,
    progress: 0.48,
  ),
];

// ─── Guilds Screen ───────────────────────────────────────────────────────────

class GuildsScreen extends StatefulWidget {
  const GuildsScreen({super.key});

  @override
  State<GuildsScreen> createState() => _GuildsScreenState();
}

class _GuildsScreenState extends State<GuildsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedGuildIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Text(
                'Guilds & Quests',
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
            actions: [
              // Weekly XP badge
              Container(
                margin: const EdgeInsets.only(right: 16, top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      '2,450 XP',
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: cs.onPrimary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  labelStyle: tt.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  dividerHeight: 0,
                  splashBorderRadius: BorderRadius.circular(12),
                  tabs: const [
                    Tab(text: 'My Guilds'),
                    Tab(text: 'Weekly Quests'),
                  ],
                ),
              ),
            ),
          ),

          // ── Tab Body ─────────────────────────────────────────────────
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GuildsTab(
                  selectedIndex: _selectedGuildIndex,
                  onGuildSelected: (i) =>
                      setState(() => _selectedGuildIndex = i),
                ),
                const _QuestsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── My Guilds Tab ───────────────────────────────────────────────────────────

class _GuildsTab extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onGuildSelected;

  const _GuildsTab({
    required this.selectedIndex,
    required this.onGuildSelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // Guild selector cards
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _guilds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final guild = _guilds[index];
              final isSelected = index == selectedIndex;

              return GestureDetector(
                onTap: () => onGuildSelected(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: 160,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              guild.color,
                              guild.color.withValues(alpha: 0.75),
                            ],
                          )
                        : null,
                    color: isSelected ? null : cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: cs.outline.withValues(alpha: 0.2),
                          ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: guild.color.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : guild.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          guild.icon,
                          color: isSelected ? Colors.white : guild.color,
                          size: 22,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        guild.name,
                        style: tt.labelLarge?.copyWith(
                          color: isSelected ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${guild.memberCount} members',
                        style: tt.labelSmall?.copyWith(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Selected guild detail
        _GuildDetailCard(guild: _guilds[selectedIndex]),
        const SizedBox(height: 20),

        // Guild stats
        _GuildStatsRow(guild: _guilds[selectedIndex]),
        const SizedBox(height: 24),

        // Active members section
        Text(
          'Active Members',
          style: tt.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _MembersAvatarRow(),
      ],
    );
  }
}

class _GuildDetailCard extends StatelessWidget {
  final Guild guild;
  const _GuildDetailCard({required this.guild});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: guild.color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: guild.color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: guild.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(guild.icon, color: guild.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      guild.name,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      guild.tagline,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weekly XP progress
          Row(
            children: [
              Text(
                'Weekly XP',
                style: tt.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${guild.weeklyXP.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} XP',
                style: tt.labelMedium?.copyWith(
                  color: guild.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (guild.weeklyXP / 15000).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: guild.color.withValues(alpha: 0.1),
              color: guild.color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Goal: 15,000 XP this week',
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

class _GuildStatsRow extends StatelessWidget {
  final Guild guild;
  const _GuildStatsRow({required this.guild});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      children: [
        _StatTile(
          icon: Icons.people_alt_rounded,
          value: '${guild.memberCount}',
          label: 'Members',
          color: guild.color,
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.emoji_events_rounded,
          value: '#${_guilds.indexOf(guild) + 1}',
          label: 'District Rank',
          color: const Color(0xFFFFA726),
          cs: cs,
          tt: tt,
        ),
        const SizedBox(width: 12),
        _StatTile(
          icon: Icons.eco_rounded,
          value: '${(guild.weeklyXP * 0.02).toInt()} kg',
          label: 'CO₂ Offset',
          color: const Color(0xFF43A047),
          cs: cs,
          tt: tt,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final ColorScheme cs;
  final TextTheme tt;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cs,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: tt.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersAvatarRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final colors = [
      const Color(0xFF43A047),
      const Color(0xFF1E88E5),
      const Color(0xFFF57C00),
      const Color(0xFFAB47BC),
      const Color(0xFFEF5350),
    ];
    final initials = ['AK', 'PS', 'MR', 'DK', 'NS'];

    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          for (int i = 0; i < 5; i++)
            Positioned(
              left: i * 38.0,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                  border: Border.all(color: cs.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: colors[i].withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initials[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 5 * 38.0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.surfaceContainerHighest,
                border: Border.all(color: cs.surface, width: 3),
              ),
              child: Center(
                child: Text(
                  '+137',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Quests Tab ───────────────────────────────────────────────────────

class _QuestsTab extends StatelessWidget {
  const _QuestsTab();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: _weeklyQuests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _QuestCard(quest: _weeklyQuests[index]);
      },
    );
  }
}

class _QuestCard extends StatelessWidget {
  final Quest quest;
  const _QuestCard({required this.quest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: quest.accentColor.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      quest.accentColor.withValues(alpha: 0.15),
                      quest.accentColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child:
                    Icon(quest.icon, color: quest.accentColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quest.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 13, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          quest.time,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Difficulty badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: quest.difficulty.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(quest.difficulty.icon,
                        size: 13, color: quest.difficulty.color),
                    const SizedBox(width: 4),
                    Text(
                      quest.difficulty.label,
                      style: tt.labelSmall?.copyWith(
                        color: quest.difficulty.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Location
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  quest.location,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Quest Progress',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          '${(quest.progress * 100).toInt()}%',
                          style: tt.labelSmall?.copyWith(
                            color: quest.accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: quest.progress,
                        minHeight: 6,
                        backgroundColor:
                            quest.accentColor.withValues(alpha: 0.1),
                        color: quest.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Bottom row: trust badge + spots + Join button
          Row(
            children: [
              // Trust requirement
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user_outlined,
                        size: 13, color: cs.primary),
                    const SizedBox(width: 4),
                    Text(
                      quest.trustReq,
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Spots left
              Text(
                '${quest.spotsLeft}/${quest.totalSpots} spots',
                style: tt.labelSmall?.copyWith(
                  color: quest.spotsLeft <= 5
                      ? const Color(0xFFEF5350)
                      : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              // XP reward + Join
              FilledButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Joined "${quest.title}" 🎉'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: quest.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '+${quest.xpReward} XP',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('Join', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
