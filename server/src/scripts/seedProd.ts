import 'dotenv/config';
import path from 'path';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import connectDB from '../config/db';
import Category from '../models/Category';
import User from '../models/User';
import Item from '../models/Item';
import Order from '../models/Order';
import QrCode from '../models/QrCode';
import Conversation from '../models/Conversation';
import Message from '../models/Message';
import { DEFAULT_CATEGORIES } from '../config/seed';

// Ensure dotenv loads from server/.env if run from root
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });

async function seedProductionDatabase() {
  const prodUri = process.env.MONGODB_URI;
  if (!prodUri) {
    console.error('❌ MONGODB_URI not defined in .env');
    process.exit(1);
  }

  console.log(`🔄 Connecting to Production MongoDB (${prodUri.split('@')[1] || prodUri})...`);
  await connectDB(prodUri);
  console.log('✅ Connected to Production MongoDB.');

  try {
    // 1. Seed Categories
    for (const cat of DEFAULT_CATEGORIES) {
      await Category.findOneAndUpdate(
        { slug: cat.slug },
        { $set: cat },
        { upsert: true, new: true }
      );
    }
    console.log(`✅ Ensured ${DEFAULT_CATEGORIES.length} default categories in database.`);

    const passwordHash = await bcrypt.hash('password123', 12);

    // 2. Admin User
    const adminEmail = 'admin@kiwishare.online';
    await User.findOneAndUpdate(
      { email: adminEmail },
      {
        $set: {
          email: adminEmail,
          displayName: 'Kiwi Admin',
          role: 'admin',
          trustScore: 100,
          isVerified: true,
          authProvider: 'email_password',
          registrationPlatform: 'web',
          lastUsedPlatform: 'web',
          passwordHash,
          location: {
            city: 'Auckland',
            suburb: 'CBD',
            coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] }
          }
        }
      },
      { upsert: true, new: true }
    );
    console.log(`✅ Admin account ready: ${adminEmail} (password: password123)`);

    // 3. Seller / Developer User (MovieGoer24) - also granted admin
    const moviegoerEmail = 'demo@example.com';
    const moviegoerUser = await User.findOneAndUpdate(
      { email: moviegoerEmail },
      {
        $set: {
          email: moviegoerEmail,
          displayName: 'MovieGoer24',
          role: 'admin',
          trustScore: 100,
          isVerified: true,
          isStudentVerified: true,
          studentInstitution: 'University of Auckland',
          studentIdNumber: 'UOA-734-2026',
          avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
          authProvider: 'email_password',
          registrationPlatform: 'mobile',
          lastUsedPlatform: 'mobile',
          passwordHash,
          location: {
            city: 'Auckland',
            suburb: 'Ponsonby',
            coordinates: { type: 'Point', coordinates: [174.7431, -36.8532] }
          }
        }
      },
      { upsert: true, new: true }
    );
    console.log(`✅ Seller account ready: ${moviegoerEmail} (password: password123)`);

    // 4. Buyer User (Alex Turner)
    const buyerEmail = 'testbuyer@kiwishare.online';
    // Clean up any malformed location first if exists
    await User.collection.updateOne(
      { email: buyerEmail },
      { $unset: { location: "" } }
    );
    const buyerUser = await User.findOneAndUpdate(
      { email: buyerEmail },
      {
        $set: {
          email: buyerEmail,
          displayName: 'Alex Turner',
          role: 'user',
          trustScore: 96,
          isVerified: true,
          isStudentVerified: true,
          studentInstitution: 'University of Auckland',
          studentIdNumber: 'UOA-CS734-ALEX',
          avatarUrl: 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=200&auto=format&fit=crop&q=80',
          authProvider: 'email_password',
          registrationPlatform: 'mobile',
          lastUsedPlatform: 'mobile',
          passwordHash,
          location: {
            city: 'Auckland',
            suburb: 'CBD',
            coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] }
          }
        }
      },
      { upsert: true, new: true }
    );
    console.log(`✅ Buyer account ready: ${buyerEmail} (password: password123)`);

    // 5. Another Community Seller (Sophie Chen)
    const sophieEmail = 'sophie.nz@kiwishare.online';
    await User.collection.updateOne(
      { email: sophieEmail },
      { $unset: { location: "" } }
    );
    const sophieUser = await User.findOneAndUpdate(
      { email: sophieEmail },
      {
        $set: {
          email: sophieEmail,
          displayName: 'Sophie Chen',
          role: 'user',
          trustScore: 98,
          isVerified: true,
          isStudentVerified: true,
          studentInstitution: 'Auckland University of Technology',
          studentIdNumber: 'AUT-2026-SC',
          avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&auto=format&fit=crop&q=80',
          authProvider: 'email_password',
          registrationPlatform: 'web',
          lastUsedPlatform: 'web',
          passwordHash,
          location: {
            city: 'Auckland',
            suburb: 'Takapuna',
            coordinates: { type: 'Point', coordinates: [174.7738, -36.7879] }
          }
        }
      },
      { upsert: true, new: true }
    );
    console.log(`✅ Community account ready: ${sophieEmail} (password: password123)`);

    // 6. Sample Pre-Loved Items
    const sampleItems = [
      {
        title: 'Retro Velvet Armchair',
        description: 'Solid timber frame vintage armchair in forest green velvet. Extremely comfortable, well-cared for in a smoke-free home in Ponsonby.',
        category: 'Furniture',
        condition: 'good',
        price: 6500,
        priceNzd: '65',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: moviegoerUser._id,
        ownerId: moviegoerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Auckland',
          suburb: 'Ponsonby',
          coordinates: { type: 'Point', coordinates: [174.7431, -36.8532] }
        }
      },
      {
        title: 'Dell 27-inch 4K USB-C Monitor',
        description: 'UltraSharp 4K IPS display. USB-C 90W power delivery, HDMI, DisplayPort. Perfect for home office or study.',
        category: 'Electronics',
        condition: 'like_new',
        price: 28000,
        priceNzd: '280',
        currency: 'NZD',
        status: 'active',
        isSustainable: false,
        sellerId: moviegoerUser._id,
        ownerId: moviegoerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1527443224154-c4a3942d3acf?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Auckland',
          suburb: 'CBD',
          coordinates: { type: 'Point', coordinates: [174.7633, -36.8485] }
        }
      },
      {
        title: 'Monstera Deliciosa (Swiss Cheese Plant)',
        description: 'Healthy and thriving indoor plant with large fenestrated leaves. Comes in a stylish terracotta pot.',
        category: 'Plants',
        condition: 'like_new',
        price: 2500,
        priceNzd: '25',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: moviegoerUser._id,
        ownerId: moviegoerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1614594975525-e45190c55d0b?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Wellington',
          suburb: 'Te Aro',
          coordinates: { type: 'Point', coordinates: [174.7762, -41.2865] }
        }
      },
      {
        title: 'Macpac 3-Person Waterproof Tent',
        description: 'Rugged lightweight hiking and camping tent with aluminum poles. Used only twice on the Abel Tasman track.',
        category: 'Outdoor',
        condition: 'good',
        price: 12000,
        priceNzd: '120',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: sophieUser._id,
        ownerId: sophieUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Christchurch',
          suburb: 'Riccarton',
          coordinates: { type: 'Point', coordinates: [172.5855, -43.5321] }
        }
      },
      {
        title: 'Makita 18V Cordless Drill & Driver Kit',
        description: 'Brushless drill with 2x 3.0Ah Li-ion batteries, fast charger, and heavy duty carry case.',
        category: 'Tools',
        condition: 'good',
        price: 9500,
        priceNzd: '95',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: moviegoerUser._id,
        ownerId: moviegoerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Hamilton',
          suburb: 'Frankton',
          coordinates: { type: 'Point', coordinates: [175.2575, -37.7870] }
        }
      },
      {
        title: 'Cast Iron Enamelled Dutch Oven (5.5L)',
        description: 'Heavy duty round casserole pot, excellent heat retention for sourdough bread and stews. Cherry red.',
        category: 'Kitchen',
        condition: 'good',
        price: 4500,
        priceNzd: '45',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: sophieUser._id,
        ownerId: sophieUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1584269600464-37b1b58a9fe7?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Auckland',
          suburb: 'Takapuna',
          coordinates: { type: 'Point', coordinates: [174.7738, -36.7879] }
        }
      },
      {
        title: 'Specialized Sirrus Commuter Hybrid Bike',
        description: 'Medium frame 24-speed commuter bike with disc brakes, rear luggage rack, and mudguards. Serviced last month.',
        category: 'Sports',
        condition: 'good',
        price: 18000,
        priceNzd: '180',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: buyerUser._id,
        ownerId: buyerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1485965120184-e220f721d03e?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Auckland',
          suburb: 'Newmarket',
          coordinates: { type: 'Point', coordinates: [174.7768, -36.8688] }
        }
      },
      {
        title: 'Patagonia Torrentshell 3L Waterproof Jacket',
        description: 'Men Size M, Navy Blue. H2No Performance Standard shell for exceptional waterproof/breathable performance.',
        category: 'Clothing',
        condition: 'like_new',
        price: 11000,
        priceNzd: '110',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: moviegoerUser._id,
        ownerId: moviegoerUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1548883354-7622d03aca27?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1548883354-7622d03aca27?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Queenstown',
          suburb: 'Queenstown CBD',
          coordinates: { type: 'Point', coordinates: [168.6626, -45.0312] }
        }
      },
      {
        title: 'Lord of the Rings 50th Anniversary Hardcover Box Set',
        description: 'Complete 3-volume deluxe hardcover set with fold-out maps of Middle-earth. Pristine collector condition.',
        category: 'Books',
        condition: 'like_new',
        price: 5000,
        priceNzd: '50',
        currency: 'NZD',
        status: 'active',
        isSustainable: true,
        sellerId: sophieUser._id,
        ownerId: sophieUser._id.toString(),
        imageUrl: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=800&auto=format&fit=crop&q=80',
        images: [{ url: 'https://images.unsplash.com/photo-1544947950-fa07a98d237f?w=800&auto=format&fit=crop&q=80', sortOrder: 0 }],
        location: {
          city: 'Wellington',
          suburb: 'Kelburn',
          coordinates: { type: 'Point', coordinates: [174.7672, -41.2889] }
        }
      }
    ];

    const createdItems: any[] = [];
    for (const itemData of sampleItems) {
      const existing = await Item.findOneAndUpdate(
        { title: itemData.title },
        { $set: itemData },
        { upsert: true, new: true }
      );
      createdItems.push(existing);
    }
    console.log(`✅ Upserted ${createdItems.length} community items in database.`);

    // 7. Seed Ready-to-Scan Meetup & QR Code (for Verification Testing)
    // Target Item: Retro Velvet Armchair (Seller: MovieGoer24, Buyer: Alex Turner)
    const testItem = createdItems.find((i) => i.title === 'Retro Velvet Armchair') || createdItems[0];
    const orderNumber = 'ORD_DEMO_MEETUP_2026';

    const orderMeetingTime = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000); // 2 days from now
    orderMeetingTime.setHours(14, 0, 0, 0);

    const testOrder = await Order.findOneAndUpdate(
      { orderNumber },
      {
        $set: {
          orderNumber,
          itemId: testItem._id,
          buyerId: buyerUser._id,
          sellerId: moviegoerUser._id,
          status: 'meeting_scheduled',
          itemSnapshot: {
            title: testItem.title,
            description: testItem.description,
            condition: testItem.condition,
            imageUrl: testItem.imageUrl
          },
          currency: 'NZD',
          itemAmount: testItem.price,
          buyerFeeAmount: 0,
          sellerFeeAmount: 0,
          buyerTotalAmount: testItem.price,
          sellerReceiveAmount: testItem.price,
          meeting: {
            scheduledAt: orderMeetingTime,
            locationName: 'Ponsonby Central, 136 Ponsonby Rd, Ponsonby, Auckland',
            latitude: -36.8532,
            longitude: 174.7431,
            proposedBy: buyerUser._id,
            proposalStatus: 'confirmed',
            note: 'Meeting near the main courtyard entrance by the coffee cart.'
          }
        }
      },
      { upsert: true, new: true }
    );
    console.log(`✅ Test Order ready: #${testOrder.orderNumber} (ID: ${testOrder._id})`);

    // Generate Active QR Code token for this order
    const claimCode = `QR_HANDOVER_TOKEN_${testOrder._id.toString()}_DEMO734`;
    await QrCode.findOneAndUpdate(
      { orderId: testOrder._id },
      {
        $set: {
          orderId: testOrder._id,
          sellerId: moviegoerUser._id,
          buyerId: buyerUser._id,
          tokenHash: claimCode,
          status: 'active',
          expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)
        }
      },
      { upsert: true, new: true }
    );
    console.log(`\n============================================================`);
    console.log(`🎯 [READY FOR QR CODE SCANNING VERIFICATION]`);
    console.log(`  Order Number: ${testOrder.orderNumber}`);
    console.log(`  Order ID:     ${testOrder._id.toString()}`);
    console.log(`  Claim Token:  ${claimCode}`);
    console.log(`  Seller:       ${moviegoerEmail} (p/w: password123) -> Presents QR Code`);
    console.log(`  Buyer:        ${buyerEmail} (p/w: password123) -> Scans QR Code`);
    console.log(`============================================================\n`);

    // 8. Create Conversation & Messages for context
    const conversation = await Conversation.findOneAndUpdate(
      { itemId: testItem._id, buyerId: buyerUser._id, sellerId: moviegoerUser._id },
      {
        $set: {
          itemId: testItem._id,
          orderId: testOrder._id,
          buyerId: buyerUser._id,
          sellerId: moviegoerUser._id,
          status: 'active',
          lastMessageText: '✅ Meetup confirmed! See you at Ponsonby Central.',
          lastMessageAt: new Date(),
          buyerUnreadCount: 0,
          sellerUnreadCount: 0
        }
      },
      { upsert: true, new: true }
    );

    await Message.deleteMany({ conversationId: conversation._id });
    await Message.insertMany([
      {
        conversationId: conversation._id,
        senderId: buyerUser._id,
        receiverId: moviegoerUser._id,
        type: 'text',
        text: 'Kia ora! Is this velvet armchair still available? Would love to inspect and pick it up!',
        status: 'read',
        createdAt: new Date(Date.now() - 3600 * 1000 * 4)
      },
      {
        conversationId: conversation._id,
        senderId: moviegoerUser._id,
        receiverId: buyerUser._id,
        type: 'text',
        text: 'Hi Alex! Yes it is. It is in great condition and ready for handover.',
        status: 'read',
        createdAt: new Date(Date.now() - 3600 * 1000 * 3)
      },
      {
        conversationId: conversation._id,
        senderId: buyerUser._id,
        receiverId: moviegoerUser._id,
        type: 'meetup',
        text: '📅 Proposed meetup: Sat 2:00 PM at Ponsonby Central',
        meetup: {
          orderId: testOrder._id,
          scheduledAt: orderMeetingTime,
          locationName: 'Ponsonby Central, 136 Ponsonby Rd, Ponsonby, Auckland',
          latitude: -36.8532,
          longitude: 174.7431,
          proposalStatus: 'confirmed',
          proposedBy: buyerUser._id,
          note: 'Meeting near the main courtyard entrance.'
        },
        status: 'read',
        createdAt: new Date(Date.now() - 3600 * 1000 * 2)
      },
      {
        conversationId: conversation._id,
        senderId: moviegoerUser._id,
        receiverId: buyerUser._id,
        type: 'text',
        text: 'Confirmed! See you there on Saturday. I will display my QR code when you inspect the chair.',
        status: 'read',
        createdAt: new Date(Date.now() - 3600 * 1000)
      }
    ]);
    console.log(`✅ Seeded chat messages and meetup card for conversation.`);

    // 9. Also seed a reverse order (Buyer: MovieGoer24, Seller: Alex Turner)
    // for Specialized Commuter Bike so MovieGoer24 can also test the Buyer/Scanner role!
    const bikeItem = createdItems.find((i) => i.title.includes('Bike')) || createdItems[1];
    const bikeOrderNumber = 'ORD_DEMO_BIKE_SCANNER_2026';
    const bikeOrder = await Order.findOneAndUpdate(
      { orderNumber: bikeOrderNumber },
      {
        $set: {
          orderNumber: bikeOrderNumber,
          itemId: bikeItem._id,
          buyerId: moviegoerUser._id,
          sellerId: buyerUser._id,
          status: 'meeting_scheduled',
          itemSnapshot: {
            title: bikeItem.title,
            description: bikeItem.description,
            condition: bikeItem.condition,
            imageUrl: bikeItem.imageUrl
          },
          currency: 'NZD',
          itemAmount: bikeItem.price,
          buyerFeeAmount: 0,
          sellerFeeAmount: 0,
          buyerTotalAmount: bikeItem.price,
          sellerReceiveAmount: bikeItem.price,
          meeting: {
            scheduledAt: orderMeetingTime,
            locationName: 'Newmarket Train Station, Station Square, Auckland',
            latitude: -36.8688,
            longitude: 174.7768,
            proposedBy: moviegoerUser._id,
            proposalStatus: 'confirmed',
            note: 'Meet at the ticket gates near the main square.'
          }
        }
      },
      { upsert: true, new: true }
    );

    const bikeClaimCode = `QR_HANDOVER_TOKEN_${bikeOrder._id.toString()}_BIKE734`;
    await QrCode.findOneAndUpdate(
      { orderId: bikeOrder._id },
      {
        $set: {
          orderId: bikeOrder._id,
          sellerId: buyerUser._id,
          buyerId: moviegoerUser._id,
          tokenHash: bikeClaimCode,
          status: 'active',
          expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000)
        }
      },
      { upsert: true, new: true }
    );

    console.log(`\n🚲 [BONUS: BUYER SCANNER TEST ORDER]`);
    console.log(`  Order Number: ${bikeOrder.orderNumber}`);
    console.log(`  Seller:       ${buyerEmail} (Alex) -> Presents QR Code`);
    console.log(`  Buyer:        ${moviegoerEmail} (MovieGoer24) -> Click "Scan QR" in App!`);
    console.log(`  Claim Token:  ${bikeClaimCode}`);
    console.log(`============================================================\n`);

    console.log('🎉 Production database seeding finished successfully!');
    await mongoose.disconnect();
    process.exit(0);
  } catch (err) {
    console.error('❌ Failed to seed Production MongoDB:', err);
    await mongoose.disconnect();
    process.exit(1);
  }
}

seedProductionDatabase();
