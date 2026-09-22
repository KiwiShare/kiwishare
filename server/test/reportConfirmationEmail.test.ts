jest.mock('resend', () => {
  const send = jest.fn();
  return {
    Resend: jest.fn().mockImplementation(() => ({ emails: { send } })),
    mockSend: send
  };
});

import { sendReportConfirmationEmail } from '../src/services/reportConfirmationEmail';
import { Resend } from 'resend';

const { mockSend } = jest.requireMock('resend') as { mockSend: jest.Mock };
const MockedResend = Resend as jest.MockedClass<typeof Resend>;
const originalApiKey = process.env.RESEND_API_KEY;
const originalFrom = process.env.RESEND_FROM;

describe('report confirmation email', () => {
  beforeEach(() => {
    mockSend.mockReset();
    MockedResend.mockImplementation(() => ({
      emails: { send: mockSend }
    }) as unknown as Resend);
    process.env.RESEND_API_KEY = 'test-resend-key';
    process.env.RESEND_FROM = 'KiwiShare <reports@kiwishare.online>';
  });

  afterAll(() => {
    if (originalApiKey === undefined) delete process.env.RESEND_API_KEY;
    else process.env.RESEND_API_KEY = originalApiKey;
    if (originalFrom === undefined) delete process.env.RESEND_FROM;
    else process.env.RESEND_FROM = originalFrom;
  });

  test('sends a private listing receipt with report context and escaped HTML', async () => {
    mockSend.mockResolvedValue({ data: { id: 'email-1' }, error: null });

    await sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful <Buyer>',
      reportId: 'report-123',
      submittedAt: new Date('2026-09-15T01:02:03.000Z'),
      reason: 'misleading_information',
      details: 'The listing contains <script>alert("unsafe")</script>.',
      listingTitle: 'Road Bike & Helmet'
    });

    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'KiwiShare <reports@kiwishare.online>',
        to: 'reporter@example.com',
        subject: '[KiwiShare] We received your report',
        text: expect.stringContaining('Reported by: Careful <Buyer> (reporter@example.com)'),
        html: expect.stringContaining('Careful &lt;Buyer&gt;')
      }),
      { idempotencyKey: 'report-confirmation/report-123' }
    );
    const message = mockSend.mock.calls[0][0] as { text: string; html: string };
    expect(message.text).toContain('Item: Road Bike & Helmet');
    expect(message.text).toContain('Reason: Misleading information');
    expect(message.text).toContain(
      'Details:\nThe listing contains <script>alert("unsafe")</script>.'
    );
    expect(message.html).toContain('Road Bike &amp; Helmet');
    expect(message.html).toContain(
      'The listing contains &lt;script&gt;alert(&quot;unsafe&quot;)&lt;/script&gt;.'
    );
  });

  test('omits the item row for a non-listing report', async () => {
    mockSend.mockResolvedValue({ data: { id: 'email-2' }, error: null });

    await sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: 'report-456',
      submittedAt: new Date('2026-09-15T01:02:03.000Z'),
      reason: 'harassment_or_abusive_behaviour',
      details: 'The other member repeatedly sent threatening messages.'
    });

    const message = mockSend.mock.calls[0][0] as { text: string; html: string };
    expect(message.text).toContain('Reason: Harassment or abusive behaviour');
    expect(message.text).not.toContain('Item:');
    expect(message.html).not.toContain('>Item</dt>');
  });

  test('does nothing when Resend is not configured', async () => {
    delete process.env.RESEND_API_KEY;

    await sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: 'report-123',
      submittedAt: new Date(),
      reason: 'other',
      details: 'A sufficiently detailed safety concern.'
    });

    expect(mockSend).not.toHaveBeenCalled();
  });

  test('surfaces an error returned by Resend', async () => {
    mockSend.mockResolvedValue({ data: null, error: { message: 'Email rejected' } });

    await expect(sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: 'report-123',
      submittedAt: new Date(),
      reason: 'other',
      details: 'A sufficiently detailed safety concern.'
    })).rejects.toThrow('Email rejected');
  });
});
