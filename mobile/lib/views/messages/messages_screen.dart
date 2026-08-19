import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/chat_list_tile.dart';

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
        'lastMessage':
            'I can pick up the armchair from Wellington tomorrow at noon.',
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
      },
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                      color: const Color(0xFF2E5E4E), // Sage Green Header
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.mark_chat_read_outlined,
                      color: Color(0xFF2E5E4E),
                    ),
                    onPressed: () {},
                    tooltip: 'Mark all read',
                  ),
                ],
              ),
            ),

            // Live Connection Info Banner (Sage Green and Leaf Green details)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F0D9), // Light Green background
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF7BAA7A).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt,
                      color: Color(0xFF2E5E4E),
                      size: 24,
                    ), // Sage Green Icon
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Direct connection to Firestore active. Enjoy zero-latency chat streams and real-time updates.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF1F1F1F), // Charcoal
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: mockChats.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final chat = mockChats[index];

                  return ChatListTile(
                    name: chat['name'] as String,
                    lastMessage: chat['lastMessage'] as String,
                    time: chat['time'] as String,
                    unreadCount: chat['unreadCount'] as int,
                    isOnline: chat['isOnline'] as bool,
                    onTap: () {},
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
