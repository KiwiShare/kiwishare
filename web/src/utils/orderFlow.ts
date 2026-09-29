import type { OrderItem } from '../api/client';

const terminalStatuses = new Set([
  'completed',
  'cancelled',
  'refunded',
  'disputed',
  'seller_paid',
]);

export function isCompletedOrder(order?: OrderItem | null): boolean {
  if (!order) return false;
  return ['completed', 'qr_scanned', 'seller_paid'].includes(order.status);
}

export function isRefundedOrder(order?: OrderItem | null): boolean {
  if (!order) return false;
  return order.status === 'refunded' || order.isRefunded === true;
}

export function isOrderPaid(order?: OrderItem | null): boolean {
  if (!order) return false;
  if (typeof order.isPaid === 'boolean') return order.isPaid;
  if (order.paidAt) return true;
  return ['paid', 'completed', 'seller_paid'].includes(order.status);
}

export function isMeetupConfirmed(order?: OrderItem | null): boolean {
  if (!order) return false;
  if (typeof order.isMeetupConfirmed === 'boolean') {
    return order.isMeetupConfirmed;
  }
  const status = order.meeting?.proposalStatus;
  return status === 'confirmed' || status === 'accepted';
}

export function isHandoverReady(order?: OrderItem | null): boolean {
  if (!order) return false;
  if (typeof order.isHandoverReady === 'boolean') {
    return order.isHandoverReady;
  }
  return (
    isOrderPaid(order) &&
    isMeetupConfirmed(order) &&
    !terminalStatuses.has(order.status)
  );
}

export function canPayOrder(order?: OrderItem | null): boolean {
  if (!order) return true;
  if (order.status === 'refunded') return true;
  if (terminalStatuses.has(order.status)) return false;
  return !isOrderPaid(order);
}

export function canArrangeMeetup(order?: OrderItem | null): boolean {
  if (!order) return false;
  return !terminalStatuses.has(order.status);
}
