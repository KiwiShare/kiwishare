import mongoose from 'mongoose';
import { Resend } from 'resend';
import nodemailer from 'nodemailer';
import PushDevice from '../models/PushDevice';
import User from '../models/User';
import { configuredFirebaseApp } from './pushNotification';

export type AdminNotificationEventType =
  | 'transferred_to_user'
  | 'transferred_from_user'
  | 'item_revoked'
  | 'item_reactivated'
  | 'item_deleted';

export interface AdminNotificationOptions {
  userId: string | mongoose.Types.ObjectId;
  userEmail?: string;
  userName?: string;
  eventType: AdminNotificationEventType;
  itemTitle: string;
  itemId: string;
  itemPriceNzd?: string;
}

interface NotificationContent {
  pushTitle: string;
  pushBody: string;
  emailSubject: string;
  emailHtml: string;
}

function generateContent(options: AdminNotificationOptions, recipientName: string): NotificationContent {
  const { eventType, itemTitle, itemPriceNzd } = options;
  const priceDisplay = itemPriceNzd ? `$${itemPriceNzd} NZD` : '';

  switch (eventType) {
    case 'transferred_to_user':
      return {
        pushTitle: 'Listing Assigned to You',
        pushBody: `"${itemTitle}" has been assigned to your KiwiShare profile.`,
        emailSubject: `[KiwiShare] A listing has been assigned to your account: "${itemTitle}"`,
        emailHtml: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; color: #1e293b;">
            <h2 style="color: #059669; margin-top: 0;">Kia ora ${recipientName}!</h2>
            <p style="font-size: 15px; line-height: 1.6;">
              A pre-loved listing, <strong>"${itemTitle}"</strong>, has been assigned and transferred to your KiwiShare account by our administration team.
            </p>
            <div style="background-color: #f8fafc; padding: 16px; border-radius: 8px; margin: 20px 0; border: 1px solid #e2e8f0;">
              <p style="margin: 0 0 6px 0; font-size: 13px; color: #64748b; font-weight: 600;">LISTING DETAILS</p>
              <p style="margin: 0; font-size: 16px; font-weight: bold; color: #0f172a;">${itemTitle}</p>
              ${priceDisplay ? `<p style="margin: 4px 0 0 0; font-size: 14px; color: #059669; font-weight: 600;">${priceDisplay}</p>` : ''}
            </div>
            <p style="font-size: 14px; color: #475569; line-height: 1.5;">
              This product is now active in the community marketplace under your profile and student credentials. You can view, edit, or manage this item anytime in KiwiShare.
            </p>
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      };

    case 'transferred_from_user':
      return {
        pushTitle: 'Listing Transferred',
        pushBody: `"${itemTitle}" has been transferred to another member.`,
        emailSubject: `[KiwiShare] Ownership update for "${itemTitle}"`,
        emailHtml: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; color: #1e293b;">
            <h2 style="color: #2563eb; margin-top: 0;">Kia ora ${recipientName}!</h2>
            <p style="font-size: 15px; line-height: 1.6;">
              The listing <strong>"${itemTitle}"</strong> previously on your account has been transferred to another member by KiwiShare administration.
            </p>
            <p style="font-size: 14px; color: #475569; line-height: 1.5;">
              If you have any questions regarding this transfer, please reach out to our support team.
            </p>
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      };

    case 'item_revoked':
      return {
        pushTitle: 'Listing Taken Down',
        pushBody: `Your listing "${itemTitle}" was taken down by the moderation team.`,
        emailSubject: `[KiwiShare] Moderation Notice: "${itemTitle}" taken down`,
        emailHtml: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #fecaca; border-radius: 12px; background-color: #fef2f2; color: #1e293b;">
            <h2 style="color: #b91c1c; margin-top: 0;">Listing Moderation Notice</h2>
            <p style="font-size: 15px; line-height: 1.6;">
              Kia ora ${recipientName},<br><br>
              Your listing <strong>"${itemTitle}"</strong> has been taken down / revoked by the KiwiShare moderation team.
            </p>
            <p style="font-size: 14px; color: #475569; line-height: 1.5;">
              This item is no longer visible to buyers. If you believe this action was taken in error, or if you would like to update the listing to align with KiwiShare community standards, please contact our support team.
            </p>
            <hr style="border: none; border-top: 1px solid #fecaca; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      };

    case 'item_reactivated':
      return {
        pushTitle: 'Listing Reactivated',
        pushBody: `Your listing "${itemTitle}" is now live again on KiwiShare.`,
        emailSubject: `[KiwiShare] Listing Reactivated: "${itemTitle}" is now live`,
        emailHtml: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #bbf7d0; border-radius: 12px; background-color: #f0fdf4; color: #1e293b;">
            <h2 style="color: #15803d; margin-top: 0;">Listing Reactivated</h2>
            <p style="font-size: 15px; line-height: 1.6;">
              Kia ora ${recipientName},<br><br>
              Great news! Your listing <strong>"${itemTitle}"</strong> has been reviewed and reactivated by our moderation team.
            </p>
            <p style="font-size: 14px; color: #475569; line-height: 1.5;">
              It is now live and searchable on KiwiShare.
            </p>
            <hr style="border: none; border-top: 1px solid #bbf7d0; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      };

    case 'item_deleted':
    default:
      return {
        pushTitle: 'Listing Removed',
        pushBody: `Your listing "${itemTitle}" was removed by KiwiShare administration.`,
        emailSubject: `[KiwiShare] Listing Notice: "${itemTitle}" has been removed`,
        emailHtml: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; color: #1e293b;">
            <h2 style="color: #64748b; margin-top: 0;">Listing Removed</h2>
            <p style="font-size: 15px; line-height: 1.6;">
              Kia ora ${recipientName},<br><br>
              Your listing <strong>"${itemTitle}"</strong> has been permanently removed by KiwiShare administration.
            </p>
            <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
            <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
          </div>
        `
      };
  }
}

/**
 * Sends both Email and Push Notification to a user following an administrative action
 * (such as transferring a listing, taking down an item, or reactivating it).
 */
export async function sendAdminItemNotification(options: AdminNotificationOptions): Promise<void> {
  try {
    let email = options.userEmail;
    let name = options.userName;

    // Resolve user details if not provided
    if (!email || !name) {
      const userDoc = await User.findById(options.userId).select('email displayName').lean() as any;
      if (userDoc) {
        email = email || userDoc.email;
        name = name || userDoc.displayName || 'Kiwi Member';
      }
    }

    const recipientName = name || 'Kiwi Member';
    const content = generateContent(options, recipientName);

    // 1. Send Email Notification via Resend (with SMTP fallback)
    if (email) {
      try {
        let sent = false;
        const resendApiKey = process.env.RESEND_API_KEY;
        const resendFrom = process.env.RESEND_FROM || 'KiwiShare <onboarding@kiwishare.online>';

        if (resendApiKey) {
          try {
            const resend = new Resend(resendApiKey);
            await resend.emails.send({
              from: resendFrom,
              to: email,
              subject: content.emailSubject,
              html: content.emailHtml
            });
            console.log(`✉️ [Admin Notification Email] Sent to ${email} for event ${options.eventType}`);
            sent = true;
          } catch (resendErr: any) {
            console.warn(`[Admin Notification] Resend delivery failed: ${resendErr.message || resendErr}`);
          }
        }

        // SMTP Fallback
        if (!sent && process.env.SMTP_HOST) {
          const transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST,
            port: parseInt(process.env.SMTP_PORT || '587'),
            secure: process.env.SMTP_SECURE === 'true',
            auth: {
              user: process.env.SMTP_USER,
              pass: process.env.SMTP_PASS
            }
          });
          await transporter.sendMail({
            from: process.env.SMTP_FROM || 'KiwiShare <notifications@kiwishare.online>',
            to: email,
            subject: content.emailSubject,
            html: content.emailHtml
          });
          console.log(`✉️ [Admin Notification Email (SMTP)] Sent to ${email}`);
        }
      } catch (emailErr: any) {
        console.warn(`[Admin Notification] Email dispatch error for ${email}:`, emailErr.message || emailErr);
      }
    }

    // 2. Send Push Notification via Firebase Cloud Messaging
    try {
      const devices = await PushDevice.find({
        userId: options.userId,
        active: true
      })
        .select('+token')
        .sort({ lastSeenAt: -1 })
        .limit(20)
        .lean();

      const tokens = devices
        .map((d: any) => d.token)
        .filter((t: unknown): t is string => typeof t === 'string' && t.trim().length > 0);

      if (tokens.length > 0) {
        const app = await configuredFirebaseApp();
        if (app) {
          const { getMessaging } = await import('firebase-admin/messaging');
          const response = await getMessaging(app).sendEachForMulticast({
            tokens,
            notification: {
              title: content.pushTitle,
              body: content.pushBody
            },
            data: {
              type: 'admin_moderation_notice',
              eventType: options.eventType,
              itemId: options.itemId,
              itemTitle: options.itemTitle
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                icon: 'ic_notification',
                color: '#1976D2'
              }
            },
            apns: {
              payload: { aps: { sound: 'default', contentAvailable: true } }
            }
          });

          // Clean up invalid tokens
          const invalidTokens = response.responses.flatMap((result, index) => {
            const code = result.error?.code;
            return code === 'messaging/registration-token-not-registered' ||
              code === 'messaging/invalid-registration-token'
              ? [tokens[index]]
              : [];
          });

          if (invalidTokens.length > 0) {
            await PushDevice.deleteMany({ token: { $in: invalidTokens } });
          }

          console.log(
            `📱 [Admin Push Notification] Sent to ${response.successCount}/${tokens.length} devices for user ${options.userId}`
          );
        }
      }
    } catch (pushErr: any) {
      console.warn(`[Admin Notification] Push dispatch error for user ${options.userId}:`, pushErr.message || pushErr);
    }
  } catch (error: any) {
    // Non-blocking best-effort execution
    console.warn('[Admin Notification] Failed to process notification:', error.message || error);
  }
}
