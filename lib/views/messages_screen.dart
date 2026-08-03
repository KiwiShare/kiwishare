import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock chats seed data
    final mockChats = [
      {
        'name': 'Jenny Yin',
        'lastMessage': 'Kia ora! Is the Monstera plant still available?',
        'time': '10:30 AM',
        'unreadCount': 2,
        'isOnline': true,
      },
      {
        'name': 'Rui Wang',
        'lastMessage': 'I can pick up the armchair from Wellington tomorrow at noon.',
        'time': 'Yesterday',
        'unreadCount': 0,
        'isOnline': false,
      },
      {
        'name': 'Yixuan Sun',
        'lastMessage': 'Awesome, see you at the safe meeting zone.',
        'time': '2 days ago',
        'unreadCount': 0,
        'isOnline': true,
      },
      {
        'name': 'Xinru Cui',
        'lastMessage': 'Sent you the QR code for transaction verification.',
        'time': '3 days ago',
        'unreadCount': 0,
        'isOnline': false,
      }
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFD9E6F8), // Sky Blue background
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Messages',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1F2D5B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.mark_chat_read_outlined, color: Color(0xFF1F2D5B)),
                    onPressed: () {},
                    tooltip: 'Mark all read',
                  ),
                ],
              ),
            ),

            // Live Connection Info Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F0D9), // Light Green
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA2D091).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt, color: Color(0xFF3E8E41), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Direct connection to Firestore active. Enjoy zero-latency chat streams and real-time updates.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF1F2D5B),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chat List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: mockChats.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final chat = mockChats[index];
                  final isUnread = (chat['unreadCount'] as int) > 0;

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1F2D5B).withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: const Color(0xFFFAFBFF), // Cream
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFB4A7E5), // Lavender
                            radius: 26,
                            child: Text(
                              (chat['name'] as String).substring(0, 1),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          if (chat['isOnline'] as bool)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            chat['name'] as String,
                            style: GoogleFonts.inter(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                              color: const Color(0xFF1F2D5B),
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            chat['time'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF6E7FBF),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                chat['lastMessage'] as String,
                                style: GoogleFonts.inter(
                                  color: isUnread ? const Color(0xFF1F2D5B) : const Color(0xFF6E7FBF),
                                  fontSize: 13,
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3F6FD9), // Cobalt
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  chat['unreadCount'].toString(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      onTap: () {},
                    ),
                  ),
                );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
