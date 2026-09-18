import 'package:flutter/material.dart';

import 'report_screen.dart';

/// Help Center & FAQ Screen providing a guided walkthrough of KiwiShare
/// and an interactive knowledge base with Q&A.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = const [
    'All',
    'Meetups & QR',
    'KiwiGold',
    'Selling & AI',
    'Safety',
  ];

  final List<_FaqItem> _faqItems = const [
    _FaqItem(
      category: 'Meetups & QR',
      question: 'What is the Meetup QR code and how does handover work?',
      answer:
          'When meeting your buyer or seller on campus, the buyer opens the Meetup Details screen and taps "Show verification QR". The seller then scans this dynamic QR code using their phone camera. This verifies that both parties are physically present, inspects the item, and completes the safe handover in real time.',
    ),
    _FaqItem(
      category: 'Meetups & QR',
      question: 'What is the "Backup verification code / QR" used for?',
      answer:
          'If the seller\'s phone camera has difficulty scanning the primary QR code (due to low lighting, glare, camera scratches, or low battery), the buyer can tap "Show backup code". This presents an alternative high-contrast backup QR code and alphanumeric verification string that the seller can manually confirm to finish the transaction without delay.',
    ),
    _FaqItem(
      category: 'Meetups & QR',
      question: 'Where is the safest place to meet on campus?',
      answer:
          'We strongly recommend meeting in high-traffic, well-lit campus common areas during daylight hours—such as the University Library entrance, the Student Union Hub, or popular campus cafeterias. Avoid secluded spots or late-night meetups.',
    ),
    _FaqItem(
      category: 'KiwiGold',
      question: 'What is KiwiGold and how do I use it?',
      answer:
          'KiwiGold is KiwiShare\'s campus community rewards balance. Every new user receives 10 KiwiGold upon joining. You can use KiwiGold to promote your listings: spending 5 KiwiGold boosts your listing with a featured badge and top placement in search and discovery feeds for 7 days.',
    ),
    _FaqItem(
      category: 'KiwiGold',
      question: 'How do I earn more KiwiGold?',
      answer:
          'You earn KiwiGold by completing successful campus handovers, listing verified sustainable items that support the circular economy, receiving 5-star ratings from peers, and participating in seasonal campus recycling initiatives.',
    ),
    _FaqItem(
      category: 'Selling & AI',
      question: 'How does the AI listing assistant help me post items?',
      answer:
          'Posting is effortless: simply upload one or more clear photos of your item, and tap "Help me write with AI". The AI analyzes your photos to automatically draft an engaging title, write a structured description highlighting key features, and automatically selects the most accurate category on the form.',
    ),
    _FaqItem(
      category: 'Selling & AI',
      question: 'What qualifies an item as "Sustainable" on KiwiShare?',
      answer:
          'Items that support New Zealand\'s circular economy qualify for the Sustainable badge! This includes pre-loved textbooks passed down to new students, refurbished tech/accessories, durable dorm furniture, reusable kitchenware, and upcycled items. Promoting reusable goods keeps usable resources out of local landfills.',
    ),
    _FaqItem(
      category: 'Selling & AI',
      question: 'Can I delist an item temporarily and relist it later?',
      answer:
          'Yes! In your Profile under "My listings" (or directly inside the chat conversation header menu), you can toggle your listing between Active and Delisted. When delisted, your item is hidden from public discovery feeds but remains saved in your account until you choose to relist it.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'What should I do if I encounter suspicious behaviour?',
      answer:
          'Never pay or transfer funds outside KiwiShare before in-person inspection. If an interaction feels unsafe, uncooperative, or violates campus community standards, tap "Report a safety issue" in the Profile menu or chat screen. Our campus moderation team reviews reports promptly.',
    ),
    _FaqItem(
      category: 'Safety',
      question: 'Can I cancel or reschedule a scheduled meetup?',
      answer:
          'Yes. Before the scheduled meetup time, open the chat conversation with your buyer/seller and tap the meetup card to propose a new time, change the campus location, or cancel the meetup if plans change.',
    ),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_FaqItem> get _filteredFaqs {
    return _faqItems.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq.answer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Help & Guides',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          bottom: TabBar(
            indicatorColor: colors.primary,
            indicatorWeight: 3,
            labelColor: colors.primary,
            unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: const [
              Tab(
                icon: Icon(Icons.explore_outlined, size: 20),
                text: 'How It Works',
              ),
              Tab(
                icon: Icon(Icons.quiz_outlined, size: 20),
                text: 'Q&A & FAQs',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildHowItWorksTab(context, colors, isDark),
            _buildFaqsTab(context, colors, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksTab(BuildContext context, ColorScheme colors, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        // Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF064E3B), const Color(0xFF0F766E)]
                  : [const Color(0xFFECFDF5), const Color(0xFFD1FAE5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
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
                          'Welcome to KiwiShare',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Aotearoa Student Circular Marketplace',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF047857),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'KiwiShare makes it simple and safe for university students to exchange pre-loved textbooks, tech, and dorm essentials directly on campus, keeping useful items in circulation and out of landfills.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '5 Steps to Successful Campus Trading',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),

        // 5 Step Walkthrough Cards
        _buildWorkflowStep(
          stepNumber: 1,
          title: 'Browse & Discover Campus Deals',
          description:
              'Find items listed by students across university campuses. Filter by category, price, distance, or look for the green "Sustainable" badge to support circular items.',
          icon: Icons.search_rounded,
          accentColor: const Color(0xFF3B82F6),
          cardBg: cardBg,
          borderColor: borderColor,
          isDark: isDark,
        ),
        _buildWorkflowStep(
          stepNumber: 2,
          title: 'Chat, Negotiate & Post Easily',
          description:
              'Chat directly with peers to clarify condition, request extra pictures, or propose offers. When selling, use our AI Assistant to write titles and descriptions in one click from your photos.',
          icon: Icons.chat_bubble_outline_rounded,
          accentColor: const Color(0xFF8B5CF6),
          cardBg: cardBg,
          borderColor: borderColor,
          isDark: isDark,
        ),
        _buildWorkflowStep(
          stepNumber: 3,
          title: 'Schedule a Safe Campus Meetup',
          description:
              'Agree on a secure, public landmark on campus—such as the University Library entrance or Student Union Hub. KiwiShare keeps your meetup location and schedule organized.',
          icon: Icons.event_available_rounded,
          accentColor: const Color(0xFFF59E0B),
          cardBg: cardBg,
          borderColor: borderColor,
          isDark: isDark,
        ),
        _buildWorkflowStep(
          stepNumber: 4,
          title: 'Inspect & Verify via Secure QR',
          description:
              'Meet in person to inspect the item. The buyer presents their Meetup QR code (or backup verification code), and the seller scans it to instantly confirm the handover.',
          icon: Icons.qr_code_scanner_rounded,
          accentColor: const Color(0xFF10B981),
          cardBg: cardBg,
          borderColor: borderColor,
          isDark: isDark,
        ),
        _buildWorkflowStep(
          stepNumber: 5,
          title: 'Earn KiwiGold & Promote Listings',
          description:
              'Every completed handover boosts your campus trust score. Use your KiwiGold balance (10 free upon signup) to promote listings for 5 KiwiGold and boost visibility.',
          icon: Icons.workspace_premium_rounded,
          accentColor: const Color(0xFFEAB308),
          cardBg: cardBg,
          borderColor: borderColor,
          isDark: isDark,
        ),

        const SizedBox(height: 20),
        // Safety & Help Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFEF4444),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Campus Safety First',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Encountered suspicious activity or need assistance?',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const ReportScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildWorkflowStep({
    required int stepNumber,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required Color cardBg,
    required Color borderColor,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'STEP $stepNumber',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqsTab(BuildContext context, ColorScheme colors, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final faqs = _filteredFaqs;

    return Column(
      children: [
        // Search and Category Selector
        Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search help questions & answers...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(cat),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDark ? Colors.white : colors.primary)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        selectedColor: colors.primary.withValues(alpha: 0.15),
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        side: BorderSide(
                          color: isSelected ? colors.primary : borderColor,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // FAQ List
        Expanded(
          child: faqs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No answers found for "$_searchQuery"',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching with different keywords or switch categories.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: faqs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = faqs[index];
                    return Material(
                      color: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: borderColor),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: Text(
                            item.question,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              item.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                item.answer,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.category,
    required this.question,
    required this.answer,
  });

  final String category;
  final String question;
  final String answer;
}
