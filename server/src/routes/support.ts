import Router from 'koa-router';

const router = new Router();

interface SupportBotRule {
  keywords: string[];
  title: string;
  response: string;
  quickReplies?: string[];
}

const SUPPORT_RULES: SupportBotRule[] = [
  {
    keywords: ['how', 'work', 'steps', 'process', 'guide', 'start', 'trade', 'buy', 'sell'],
    title: 'How KiwiShare Works',
    response:
      'Here is how trading on KiwiShare works:\n\n' +
      '1. 🔍 Browse or List: Discover pre-loved and sustainable goods across New Zealand.\n' +
      '2. 💬 In-App Chat: Message buyers or sellers directly to arrange terms.\n' +
      '3. 🔒 Secure Escrow: The buyer pays through KiwiShare; funds are securely held in escrow.\n' +
      '4. 🤝 In-Person Meetup: Meet safely in a public spot and scan the meetup QR code or tap confirmation.\n' +
      '5. 💰 Dual Confirmation: Both parties confirm receipt & handover, releasing funds directly to the seller!',
    quickReplies: ['Payment & Escrow', 'Meetup & QR', 'Report a Safety Issue']
  },
  {
    keywords: ['contact', 'email', 'support', 'help', 'human', 'team', 'service', 'phone'],
    title: 'Contact Customer Support',
    response:
      'You can reach our KiwiShare Customer Operations Team directly at:\n\n' +
      '📧 Email: customer@kiwishare.online\n' +
      '⏰ Hours: Mon - Fri, 9:00 AM - 6:00 PM NZST\n\n' +
      'We typically respond within 24 hours. For urgent safety concerns, please use the in-app Report button.',
    quickReplies: ['How KiwiShare Works', 'Report an Issue']
  },
  {
    keywords: ['report', 'safety', 'scam', 'suspicious', 'fake', 'block', 'unsafe', 'fraud'],
    title: 'Safety & Reporting on KiwiShare',
    response:
      'Your safety is our top priority! Here is how to protect yourself and report suspicious activity:\n\n' +
      '• Report a Listing: Tap the three dots (⋮) on any item detail screen and choose "Report Item".\n' +
      '• Report a User: Open the user\'s profile or chat options, and select "Report User".\n' +
      '• Urgent Cases: Email customer@kiwishare.online with screenshots and details.\n\n' +
      'KiwiShare monitors all reports 24/7 and takes immediate action against bad actors.',
    quickReplies: ['Contact Support', 'Meetup & QR Safety']
  },
  {
    keywords: ['pay', 'payment', 'money', 'wallet', 'escrow', 'card', 'bank', 'payout', 'refund'],
    title: 'Payments, Escrow & Payouts',
    response:
      'KiwiShare protects all transactions with an Escrow system:\n\n' +
      '• Buyer Protection: When you pay, your money is held in KiwiShare escrow until you meet and inspect the item.\n' +
      '• Seller Payout: After BOTH parties confirm the handover, funds are transferred directly into your saved Wallet debit card or bank account.\n' +
      '• Zero Fraud: Sellers never get charged back unexpectedly, and buyers never lose money to no-shows!',
    quickReplies: ['Wallet Setup', 'How Meetups Work']
  },
  {
    keywords: ['meetup', 'qr', 'scan', 'handover', 'schedule', 'location'],
    title: 'Meetups & QR Handover',
    response:
      'Meetups are easy and verifiable on KiwiShare:\n\n' +
      '• Propose a public, well-lit location (e.g., campus library, mall, train station).\n' +
      '• When meeting, the seller displays the QR code, and the buyer scans it with the in-app scanner.\n' +
      '• Once both tap "Confirm Handover", the transaction completes and 5 credit points are awarded to each user!',
    quickReplies: ['Payment & Escrow', 'Safety Guidelines']
  },
  {
    keywords: ['student', 'uni', 'university', 'ac.nz', 'auckland', 'aut', 'otago', 'canterbury', 'massey', 'victoria', 'waikato'],
    title: 'Verified Student Badges',
    response:
      'KiwiShare offers student verification for NZ university students:\n\n' +
      '• Verify with your official .ac.nz email address in your Profile.\n' +
      '• Get the verified student badge next to your listings and comments.\n' +
      '• Enjoy extra trust in campus peer-to-peer exchanges!',
    quickReplies: ['How KiwiShare Works', 'Contact Support']
  },
  {
    keywords: ['kiwigold', 'vip', 'promote', 'points', 'credit', 'score', 'trust'],
    title: 'KiwiGold, VIP & Trust Scores',
    response:
      'Boost your visibility and reputation:\n\n' +
      '• Trust Score: Completing transactions awards +5 points to both buyer and seller.\n' +
      '• KiwiGold: Used to promote your items to the "TOP" of search and category feeds.\n' +
      '• VIP Membership: Enjoy discounted fees, highlight badges, and priority customer care!',
    quickReplies: ['How KiwiShare Works', 'Contact Support']
  }
];

/**
 * POST /api/support/chat
 * Support Bot QA answering engine
 */
router.post('/support/chat', async (ctx) => {
  const body = (ctx.request.body as Record<string, unknown>) || {};
  const query = String(body.message || '').trim().toLowerCase();

  if (!query) {
    ctx.status = 200;
    ctx.body = {
      status: 'success',
      reply: {
        title: 'Kia Ora! How can we help you today?',
        message:
          'Welcome to KiwiShare Support! You can ask me about:\n\n' +
          '• How KiwiShare works and safe trading\n' +
          '• Payments, escrow protection, and wallet payouts\n' +
          '• Meetups and QR code confirmation\n' +
          '• Safety tips and reporting suspicious behaviour\n\n' +
          'You can also contact our team anytime at customer@kiwishare.online.',
        quickReplies: [
          'How KiwiShare Works',
          'Payment & Escrow',
          'Safety & Reporting',
          'Contact Support'
        ]
      }
    };
    return;
  }

  // Find best matching rule based on keyword hits
  let bestMatch: SupportBotRule | null = null;
  let highestScore = 0;

  for (const rule of SUPPORT_RULES) {
    let score = 0;
    for (const kw of rule.keywords) {
      if (query.includes(kw)) {
        score += 1;
      }
    }
    if (score > highestScore) {
      highestScore = score;
      bestMatch = rule;
    }
  }

  if (bestMatch && highestScore > 0) {
    ctx.status = 200;
    ctx.body = {
      status: 'success',
      reply: {
        title: bestMatch.title,
        message: bestMatch.response,
        quickReplies: bestMatch.quickReplies || [
          'How KiwiShare Works',
          'Contact Support'
        ]
      }
    };
    return;
  }

  // Fallback response
  ctx.status = 200;
  ctx.body = {
    status: 'success',
    reply: {
      title: 'KiwiShare Support Assistant',
      message:
        'Thank you for asking! I might not have the exact answer to your specific query, but our customer support team is always happy to help.\n\n' +
        'Please send us an email at:\n' +
        '📧 customer@kiwishare.online\n\n' +
        'Include your account email and any relevant order or listing IDs, and our team will get back to you within 24 hours.',
      quickReplies: [
        'How KiwiShare Works',
        'Payment & Escrow',
        'Safety & Reporting',
        'Contact Support'
      ]
    }
  };
});

export default router;
