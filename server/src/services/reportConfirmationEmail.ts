import { Resend } from 'resend';

interface ReportConfirmationEmailOptions {
  email: string;
  displayName: string;
  reportId: string;
  submittedAt: Date;
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

export async function sendReportConfirmationEmail(
  options: ReportConfirmationEmailOptions
): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  if (!apiKey) return;

  const resend = new Resend(apiKey);
  const from = process.env.RESEND_FROM || 'KiwiShare <onboarding@resend.dev>';
  const submittedAt = options.submittedAt.toISOString();
  const name = escapeHtml(options.displayName || 'KiwiShare member');
  const reference = escapeHtml(options.reportId);
  const { error } = await resend.emails.send(
    {
      from,
      to: options.email,
      subject: '[KiwiShare] We received your report',
      text: [
        `Kia ora ${options.displayName || 'KiwiShare member'},`,
        '',
        'Thanks for helping keep KiwiShare safe. We received your report and will review it.',
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
