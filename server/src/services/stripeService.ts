import User from '../models/User';

const STRIPE_API_BASE = 'https://api.stripe.com/v1';

function getStripeApiKey(): string {
  return process.env.STRIPE_PAYMENT_API_KEY || '';
}

export interface StripePaymentMethodCard {
  id: string;
  brand: string;
  last4: string;
  expMonth: number;
  expYear: number;
  isDefault?: boolean;
}

/**
 * Execute an authenticated HTTP request to Stripe REST API.
 */
async function stripeRequest<T = any>(
  endpoint: string,
  method: 'GET' | 'POST' | 'DELETE' = 'GET',
  params?: Record<string, string | number | boolean | undefined>
): Promise<T> {
  const apiKey = getStripeApiKey();
  if (!apiKey) {
    throw new Error('STRIPE_PAYMENT_API_KEY is not configured on the server.');
  }

  const url = `${STRIPE_API_BASE}${endpoint}`;
  const headers: Record<string, string> = {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/x-www-form-urlencoded'
  };

  let body: string | undefined;
  if (params && (method === 'POST' || method === 'DELETE')) {
    const searchParams = new URLSearchParams();
    for (const [key, value] of Object.entries(params)) {
      if (value !== undefined) {
        searchParams.append(key, String(value));
      }
    }
    body = searchParams.toString();
  }

  const response = await fetch(url, {
    method,
    headers,
    body
  });

  const json = (await response.json()) as any;
  if (!response.ok) {
    const message = json?.error?.message || `Stripe API error (${response.status})`;
    throw new Error(message);
  }

  return json as T;
}

/**
 * Find or create a Stripe Customer for the given user.
 */
export async function getOrCreateStripeCustomer(
  userId: string,
  email: string,
  displayName?: string
): Promise<string> {
  const user = await User.findById(userId);
  if (!user) {
    throw new Error('User not found.');
  }

  if (user.stripeCustomerId) {
    return user.stripeCustomerId;
  }

  // Create new customer in Stripe
  const customer = await stripeRequest<{ id: string }>(
    '/customers',
    'POST',
    {
      email,
      name: displayName || user.displayName,
      'metadata[userId]': userId
    }
  );

  user.stripeCustomerId = customer.id;
  await user.save();
  return customer.id;
}

/**
 * Create a Stripe PaymentIntent for an order.
 */
export async function createStripePaymentIntent(options: {
  amountCents: number;
  currency?: string;
  orderId?: string;
  orderNumber?: string;
  customerId?: string;
  description?: string;
  metadata?: Record<string, string>;
}): Promise<{
  clientSecret: string;
  paymentIntentId: string;
  amountCents: number;
}> {
  const {
    amountCents,
    currency = 'nzd',
    orderId,
    orderNumber,
    customerId,
    description,
    metadata
  } = options;

  const params: Record<string, string | number | undefined> = {
    amount: amountCents,
    currency: currency.toLowerCase(),
    'payment_method_types[0]': 'card',
    description: description || (orderNumber ? `KiwiShare Order ${orderNumber}` : 'KiwiShare Payment')
  };

  if (orderId) {
    params['metadata[orderId]'] = orderId;
  }
  if (orderNumber) {
    params['metadata[orderNumber]'] = orderNumber;
  }
  if (metadata) {
    for (const [key, value] of Object.entries(metadata)) {
      params[`metadata[${key}]`] = value;
    }
  }

  if (customerId) {
    params.customer = customerId;
  }

  const intent = await stripeRequest<{
    id: string;
    client_secret: string;
    amount: number;
  }>('/payment_intents', 'POST', params);

  return {
    paymentIntentId: intent.id,
    clientSecret: intent.client_secret,
    amountCents: intent.amount
  };
}

/**
 * Confirm a PaymentIntent with a payment method.
 */
export async function confirmStripePaymentIntent(
  paymentIntentId: string,
  paymentMethodId?: string
): Promise<{
  id: string;
  status: string;
  amountCents: number;
}> {
  const params: Record<string, string | undefined> = {};
  if (paymentMethodId) {
    params.payment_method = paymentMethodId;
  }

  const confirmed = await stripeRequest<{
    id: string;
    status: string;
    amount: number;
  }>(`/payment_intents/${paymentIntentId}/confirm`, 'POST', params);

  return {
    id: confirmed.id,
    status: confirmed.status,
    amountCents: confirmed.amount
  };
}

/**
 * List saved payment cards for a Stripe customer.
 */
export async function listCustomerCards(
  customerId: string
): Promise<StripePaymentMethodCard[]> {
  try {
    const res = await stripeRequest<{
      data: Array<{
        id: string;
        card: {
          brand: string;
          last4: string;
          exp_month: number;
          exp_year: number;
        };
      }>;
    }>(`/customers/${customerId}/payment_methods?type=card`, 'GET');

    return (res.data || []).map((pm, index) => ({
      id: pm.id,
      brand: pm.card.brand,
      last4: pm.card.last4,
      expMonth: pm.card.exp_month,
      expYear: pm.card.exp_year,
      isDefault: index === 0
    }));
  } catch (err) {
    console.warn('[StripeService] Error listing customer cards:', err);
    return [];
  }
}

/**
 * Attach a PaymentMethod to a customer and save.
 */
export async function attachCustomerCard(
  paymentMethodId: string,
  customerId: string
): Promise<StripePaymentMethodCard> {
  const pm = await stripeRequest<{
    id: string;
    card: {
      brand: string;
      last4: string;
      exp_month: number;
      exp_year: number;
    };
  }>(`/payment_methods/${paymentMethodId}/attach`, 'POST', {
    customer: customerId
  });

  return {
    id: pm.id,
    brand: pm.card.brand,
    last4: pm.card.last4,
    expMonth: pm.card.exp_month,
    expYear: pm.card.exp_year,
    isDefault: false
  };
}

/**
 * Detach / delete a saved PaymentMethod.
 */
export async function detachCustomerCard(paymentMethodId: string): Promise<boolean> {
  await stripeRequest(`/payment_methods/${paymentMethodId}/detach`, 'POST');
  return true;
}

/**
 * Create a Stripe PaymentMethod using server-side secret key.
 * This avoids Stripe publishable key tokenization restrictions (integration_surface_not_supported).
 */
export async function createStripePaymentMethod(card: {
  number: string;
  expMonth: number;
  expYear: number;
  cvc: string;
}): Promise<string> {
  const pm = await stripeRequest<{ id: string }>(
    '/payment_methods',
    'POST',
    {
      type: 'card',
      'card[number]': card.number.replace(/\s+/g, ''),
      'card[exp_month]': card.expMonth,
      'card[exp_year]': card.expYear,
      'card[cvc]': card.cvc,
    }
  );
  return pm.id;
}

/**
 * Creates a refund for a Stripe PaymentIntent.
 */
export async function createStripeRefund(params: {
  paymentIntentId: string;
  amountCents?: number;
  reason?: 'duplicate' | 'fraudulent' | 'requested_by_customer';
}): Promise<{ id: string; status: string; amount: number }> {
  const payload: Record<string, string | number | boolean | undefined> = {
    payment_intent: params.paymentIntentId,
  };
  if (params.amountCents !== undefined && params.amountCents > 0) {
    payload.amount = params.amountCents;
  }
  if (params.reason) {
    payload.reason = params.reason;
  }

  const refund = await stripeRequest<{ id: string; status: string; amount: number }>(
    '/refunds',
    'POST',
    payload
  );
  return refund;
}
