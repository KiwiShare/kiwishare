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

  test('sends a private receipt with the report id as its idempotency key', async () => {
    mockSend.mockResolvedValue({ data: { id: 'email-1' }, error: null });

    await sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful <Buyer>',
      reportId: 'report-123',
      submittedAt: new Date('2026-09-15T01:02:03.000Z')
    });

    expect(mockSend).toHaveBeenCalledWith(
      expect.objectContaining({
        from: 'KiwiShare <reports@kiwishare.online>',
        to: 'reporter@example.com',
        subject: '[KiwiShare] We received your report',
        text: expect.stringContaining('Report reference: report-123'),
        html: expect.stringContaining('Careful &lt;Buyer&gt;')
      }),
      { idempotencyKey: 'report-confirmation/report-123' }
    );
  });

  test('does nothing when Resend is not configured', async () => {
    delete process.env.RESEND_API_KEY;

    await sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: 'report-123',
      submittedAt: new Date()
    });

    expect(mockSend).not.toHaveBeenCalled();
  });

  test('surfaces an error returned by Resend', async () => {
    mockSend.mockResolvedValue({ data: null, error: { message: 'Email rejected' } });

    await expect(sendReportConfirmationEmail({
      email: 'reporter@example.com',
      displayName: 'Careful Buyer',
      reportId: 'report-123',
      submittedAt: new Date()
    })).rejects.toThrow('Email rejected');
  });
});
