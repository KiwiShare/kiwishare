import { Resend } from 'resend';

interface ReportConfirmationEmailOptions {
  email: string;
  displayName: string;
  reportId: string;
  submittedAt: Date;
  reason: string;
  details: string;
  listingTitle?: string;
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[character]!));
}

function formatReason(reason: string): string {
  const words = reason.replace(/_/g, ' ');
  return words.charAt(0).toUpperCase() + words.slice(1);
}

export async function sendReportConfirmationEmail(
  options: ReportConfirmationEmailOptions
): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) return;

  const resend = new Resend(apiKey);
  const from = process.env.RESEND_FROM || 'KiwiShare <onboarding@resend.dev>';
  const submittedAt = options.submittedAt.toISOString();
  const displayName = options.displayName || 'KiwiShare member';
  const name = escapeHtml(displayName);
  const reporterEmail = escapeHtml(options.email);
  const reference = escapeHtml(options.reportId);
  const reason = formatReason(options.reason);
  const escapedReason = escapeHtml(reason);
  const details = escapeHtml(options.details);
  const listingText = options.listingTitle
    ? [`Item: ${options.listingTitle}`]
    : [];
  const listingHtml = options.listingTitle
    ? `<dt style="font-weight: 600;">Item</dt><dd style="margin: 0 0 12px;">${escapeHtml(options.listingTitle)}</dd>`
    : '';
  const { error } = await resend.emails.send(
    {
      from,
      to: options.email,
      subject: '[KiwiShare] We received your report',
      text: [
        `Kia ora ${options.displayName || 'KiwiShare member'},`,
        '',
        'Thanks for helping keep KiwiShare safe. We received your report and will review it.',
        '',
        `Reported by: ${displayName} (${options.email})`,
        ...listingText,
        `Reason: ${reason}`,
        'Details:',
        options.details,
        '',
        `Report reference: ${options.reportId}`,
        `Submitted: ${submittedAt}`,
        '',
        'This confirmation does not indicate an outcome. Please do not reply to this email.',
        '',
        'Ngā mihi,',
        'The KiwiShare Team'
      ].join('\n'),
      html: `
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; color: #1f2933;">
          <h2 style="color: #006b57;">Kia ora ${name},</h2>
          <p>Thanks for helping keep KiwiShare safe. We received your report and will review it.</p>
          <dl style="margin: 24px 0;">
            <dt style="font-weight: 600;">Reported by</dt>
            <dd style="margin: 0 0 12px;">${name} (${reporterEmail})</dd>
            ${listingHtml}
            <dt style="font-weight: 600;">Reason</dt>
            <dd style="margin: 0 0 12px;">${escapedReason}</dd>
            <dt style="font-weight: 600;">Details</dt>
            <dd style="margin: 0; white-space: pre-wrap;">${details}</dd>
          </dl>
          <p><strong>Report reference:</strong> ${reference}<br><strong>Submitted:</strong> ${submittedAt}</p>
          <p>This confirmation does not indicate an outcome. Please do not reply to this email.</p>
          <p>Ngā mihi,<br>The KiwiShare Team</p>
        </div>
      `
    },
    { idempotencyKey: `report-confirmation/${options.reportId}` }
  );

  if (error) {
    throw new Error(error.message);
  }
}
