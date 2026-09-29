export function isZeroValueOrder(order: any): boolean {
  return (order?.itemAmount ?? 0) === 0 && (order?.buyerTotalAmount ?? 0) === 0;
}

export function isOrderPaid(order: any): boolean {
  return Boolean(order?.paidAt) || isZeroValueOrder(order);
}

export function isMeetupConfirmed(order: any): boolean {
  const status = order?.meeting?.proposalStatus;
  return status === 'confirmed' || status === 'accepted';
}

export function isTerminalOrderStatus(status: unknown): boolean {
  return ['completed', 'cancelled', 'refunded', 'disputed', 'seller_paid'].includes(
    String(status ?? '')
  );
}

export function isHandoverReady(order: any): boolean {
  return (
    isOrderPaid(order) &&
    isMeetupConfirmed(order) &&
    !isTerminalOrderStatus(order?.status)
  );
}

export function statusAfterMeetupProposal(order: any): 'paid' | 'pending_payment' {
  return isOrderPaid(order) ? 'paid' : 'pending_payment';
}

export function statusAfterMeetupConfirmed(
  order: any
): 'meeting_scheduled' | 'pending_payment' {
  return isOrderPaid(order) ? 'meeting_scheduled' : 'pending_payment';
}

export function statusAfterPayment(order: any): 'meeting_scheduled' | 'paid' {
  return isMeetupConfirmed(order) ? 'meeting_scheduled' : 'paid';
}
