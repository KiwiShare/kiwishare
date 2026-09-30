import { Resend } from 'resend';
import nodemailer from 'nodemailer';
import { isOutboundEmailDeliveryEnabled } from './emailSafety';

export interface WatchlistPriceEmailOptions {
  to: string;
  recipientName: string;
  itemTitle: string;
  itemId: string;
  oldPriceNzd: string;
  newPriceNzd: string;
  newPriceCents: number;
}

let emailSenderOverride: ((options: WatchlistPriceEmailOptions) => Promise<void>) | null = null;

export function setWatchlistEmailSenderForTests(
  sender: ((options: WatchlistPriceEmailOptions) => Promise<void>) | null
) {
  emailSenderOverride = sender;
}

/**
 * Sends an email notification to a watcher when an item drops in price or becomes free.
 */
export async function sendWatchlistPriceEmail(options: WatchlistPriceEmailOptions): Promise<void> {
  if (emailSenderOverride) {
    return emailSenderOverride(options);
  }

  if (!isOutboundEmailDeliveryEnabled()) return;

  const { to, recipientName, itemTitle, itemId, oldPriceNzd, newPriceNzd, newPriceCents } = options;
  const isFree = newPriceCents === 0 || newPriceNzd === '0' || newPriceNzd === '0.00';
  const priceDisplay = isFree ? 'FREE ($0 NZD)' : `$${newPriceNzd} NZD`;
  const subject = isFree
    ? `[KiwiShare] Great News! "${itemTitle}" in your watchlist is now FREE!`
    : `[KiwiShare] Price Drop Alert: "${itemTitle}" dropped to $${newPriceNzd} NZD!`;

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff; color: #1e293b;">
      <h2 style="color: #059669; margin-top: 0;">Kia ora ${recipientName}!</h2>
      <p style="font-size: 15px; line-height: 1.6;">
        An item in your KiwiShare watchlist has dropped in price:
      </p>
      <div style="background-color: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0; border: 1px solid #e2e8f0;">
        <p style="margin: 0 0 6px 0; font-size: 13px; color: #64748b; font-weight: 600;">SAVED LISTING</p>
        <p style="margin: 0; font-size: 18px; font-weight: bold; color: #0f172a;">${itemTitle}</p>
        <div style="margin-top: 10px; display: flex; align-items: baseline; gap: 8px;">
          <span style="font-size: 14px; color: #94a3b8; text-decoration: line-through;">Was $${oldPriceNzd} NZD</span>
          <span style="font-size: 18px; font-weight: 800; color: ${isFree ? '#059669' : '#047857'}; margin-left: 10px;">
            Now: ${priceDisplay}
          </span>
        </div>
      </div>
      <div style="margin: 24px 0;">
        <a href="https://kiwishare.online/products/${itemId}" style="display: inline-block; background-color: #059669; color: #ffffff; text-decoration: none; padding: 12px 24px; border-radius: 8px; font-weight: bold; font-size: 15px;">
          View Item on KiwiShare
        </a>
      </div>
      <p style="font-size: 14px; color: #64748b; line-height: 1.5;">
        Act fast before someone else claims or purchases it!
      </p>
      <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 24px 0;" />
      <p style="font-size: 12px; color: #94a3b8; margin: 0;">Ngā mihi,<br>The KiwiShare Team</p>
    </div>
  `;

  // 1. Resend API
  const resendApiKey = process.env.RESEND_API_KEY;
  const resendFrom = process.env.RESEND_FROM || 'KiwiShare <onboarding@kiwishare.online>';

  if (resendApiKey) {
    try {
      const resend = new Resend(resendApiKey);
      await resend.emails.send({
        from: resendFrom,
        to,
        subject,
        html
      });
      console.log(`✉️ [Watchlist Price Alert Email] Sent via Resend to ${to}`);
      return;
    } catch (err: any) {
      console.warn(`[Watchlist Email] Resend delivery failed: ${err.message || err}`);
    }
  }

  // 2. SMTP Fallback
  if (process.env.SMTP_HOST) {
    try {
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
        to,
        subject,
        html
      });
      console.log(`✉️ [Watchlist Price Alert Email] Sent via SMTP to ${to}`);
      return;
    } catch (smtpErr: any) {
      console.warn(`[Watchlist Email] SMTP delivery failed: ${smtpErr.message || smtpErr}`);
    }
  }
}
