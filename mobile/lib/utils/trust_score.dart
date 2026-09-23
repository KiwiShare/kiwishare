import 'package:flutter/material.dart';

const int publicTrustScoreCeiling = 200;

String formatPublicTrustScore(int score) {
  return score > publicTrustScoreCeiling
      ? '$publicTrustScoreCeiling+'
      : score.toString();
}

enum TrustScoreLevel {
  exceptional,
  veryGood,
  good,
  needsImprovement,
  criticalRisk,
}

class TrustScoreInfo {
  final TrustScoreLevel level;
  final String label;
  final String description;
  final Color lightColor;
  final Color darkColor;
  final Color lightBg;
  final Color darkBg;

  const TrustScoreInfo({
    required this.level,
    required this.label,
    required this.description,
    required this.lightColor,
    required this.darkColor,
    required this.lightBg,
    required this.darkBg,
  });
}

/// Returns trust score tier information based on KiwiShare criteria:
/// - 185 - 200+: Exceptional Trust (信用极好)
/// - 150 - 184: Very Good Trust (优良)
/// - 100 - 149: Good Standing (初始基础良好, baseline 100)
/// - 90 - 99: Needs Improvement (信用较差)
/// - < 90: Critical Risk (信用危险)
TrustScoreInfo getTrustScoreInfo(int score) {
  if (score >= 185) {
    return const TrustScoreInfo(
      level: TrustScoreLevel.exceptional,
      label: 'Exceptional Trust',
      description: 'Top-tier verified member with outstanding trading history.',
      lightColor: Color(0xFF047857),
      darkColor: Color(0xFF34D399),
      lightBg: Color(0xFFD1FAE5),
      darkBg: Color(0xFF064E3B),
    );
  } else if (score >= 150) {
    return const TrustScoreInfo(
      level: TrustScoreLevel.veryGood,
      label: 'Very Good Trust',
      description:
          'Highly reliable member with consistent successful transactions.',
      lightColor: Color(0xFF059669),
      darkColor: Color(0xFF6EE7B7),
      lightBg: Color(0xFFECFDF5),
      darkBg: Color(0xFF065F46),
    );
  } else if (score >= 100) {
    return const TrustScoreInfo(
      level: TrustScoreLevel.good,
      label: 'Good Standing',
      description: 'Standard verified baseline member in good standing.',
      lightColor: Color(0xFF2563EB),
      darkColor: Color(0xFF93C5FD),
      lightBg: Color(0xFFEFF6FF),
      darkBg: Color(0xFF1E3A8A),
    );
  } else if (score >= 90) {
    return const TrustScoreInfo(
      level: TrustScoreLevel.needsImprovement,
      label: 'Needs Improvement',
      description: 'Below baseline score. Caution advised during transactions.',
      lightColor: Color(0xFFD97706),
      darkColor: Color(0xFFFCD34D),
      lightBg: Color(0xFFFEF3C7),
      darkBg: Color(0xFF78350F),
    );
  } else {
    return const TrustScoreInfo(
      level: TrustScoreLevel.criticalRisk,
      label: 'Critical Risk',
      description:
          'High transaction risk due to reported disputes or violations.',
      lightColor: Color(0xFFDC2626),
      darkColor: Color(0xFFF87171),
      lightBg: Color(0xFFFEE2E2),
      darkBg: Color(0xFF7F1D1D),
    );
  }
}

/// Opens a bottom sheet explaining the user's Kiwi Trust Score and all tiers.
Future<void> showKiwiTrustScoreSheet(BuildContext context, int score) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _KiwiTrustScoreSheet(score: score),
  );
}

class _KiwiTrustScoreSheet extends StatelessWidget {
  final int score;

  const _KiwiTrustScoreSheet({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final info = getTrustScoreInfo(score);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181715) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kiwi Trust Score',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Decentralized peer-to-peer trust ratings',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Current Score Hero Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [info.lightBg, Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? info.darkColor : info.lightColor)
                        .withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      formatPublicTrustScore(score),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: isDark ? info.darkColor : info.lightColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? info.darkBg : info.lightBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        info.label,
                        style: TextStyle(
                          color: isDark ? info.darkColor : info.lightColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      info.description,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tier Breakdown
              Text(
                'Trust Score Tiers',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _buildTierRow(
                range: '185 – 200+',
                label: 'Exceptional Trust',
                description:
                    'Top-tier verified member with outstanding trading history.',
                color: const Color(0xFF047857),
                isCurrent: score >= 185,
                isDark: isDark,
              ),
              _buildTierRow(
                range: '150 – 184',
                label: 'Very Good Trust',
                description:
                    'Consistently positive handovers and prompt response.',
                color: const Color(0xFF059669),
                isCurrent: score >= 150 && score < 185,
                isDark: isDark,
              ),
              _buildTierRow(
                range: '100 – 149',
                label: 'Good Standing',
                description:
                    'Initial starting baseline score (100) for all members.',
                color: const Color(0xFF2563EB),
                isCurrent: score >= 100 && score < 150,
                isDark: isDark,
              ),
              _buildTierRow(
                range: '90 – 99',
                label: 'Needs Improvement',
                description: 'Below standard baseline. Trade with caution.',
                color: const Color(0xFFD97706),
                isCurrent: score >= 90 && score < 100,
                isDark: isDark,
              ),
              _buildTierRow(
                range: '< 90',
                label: 'Critical Risk',
                description:
                    'High transaction risk due to reported disputes or violations.',
                color: const Color(0xFFDC2626),
                isCurrent: score < 90,
                isDark: isDark,
              ),
              const SizedBox(height: 18),

              // How to earn score
              Text(
                'How Trust Score Works',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _buildRuleRow(
                icon: Icons.flag_outlined,
                title: 'Initial Starting Score: 100 pts',
                subtitle:
                    'Every new account starts in Good Standing with 100 base points.',
                isDark: isDark,
              ),
              _buildRuleRow(
                icon: Icons.handshake_outlined,
                title: '+5 pts per Completed Handover',
                subtitle:
                    'Both buyer and seller earn 5 points upon mutual delivery confirmation.',
                isDark: isDark,
              ),
              _buildRuleRow(
                icon: Icons.school_outlined,
                title: '+15 pts for NZ Student Verification',
                subtitle:
                    'Instantly verify your .ac.nz student email to boost your trust level.',
                isDark: isDark,
              ),
              _buildRuleRow(
                icon: Icons.warning_amber_rounded,
                title: 'Penalties for Misconduct',
                subtitle:
                    'Unresolved disputes, order cancellations, or policy breaches deduct points.',
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierRow({
    required String range,
    required String label,
    required String description,
    required Color color,
    required bool isCurrent,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isCurrent
            ? color.withOpacity(isDark ? 0.2 : 0.1)
            : (isDark ? const Color(0xFF232220) : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? color : (isDark ? Colors.white10 : Colors.black12),
          width: isCurrent ? 1.5 : 0.8,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              range,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Current',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF059669)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : Colors.black54,
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
