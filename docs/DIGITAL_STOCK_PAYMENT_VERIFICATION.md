# AMANAH Digital Stock & Payment Verification — System Design

## Confirmed operating policy

This design records the user's confirmed policy:

1. Payment verification may be initiated by all three operating entities: Main AMANAH, Branch Operator (BO), and Mobile Stockist (MS).
2. Payment approval is performed by separate, explicitly authorized finance users at all levels. An operating entity does not automatically grant payment-approval authority to every user in that entity.
3. Main AMANAH may allocate digital stock to Branch Operators. Branch Operators may transfer stock to their assigned Mobile Stockists. Any direct Main AMANAH-to-Mobile Stockist transfer must be an explicit company-configured permission.
4. No entity may initiate a payment-verification request for a sale unless it has sufficient available digital stock for every requested product and quantity.
5. Payment approval is distinct from payment initiation. The initiator cannot approve their own payment-verification request.
6. PV is posted only after authorized finance approval of the payment and successful finalization of the stock reservation.

## Roles, organization, and permissions

Keep organizational placement separate from permissions. A user's organization type (Main AMANAH, BO, or MS) describes where the user operates. A permission assignment describes what that user is allowed to do.

Recommended concepts:
- Organization/location types: `main_amanah`, `branch_operator`, `mobile_stockist`.
- User capabilities: `stock_view`, `stock_transfer_create`, `stock_transfer_receive`, `payment_verification_initiate`, `payment_verification_review`, `payment_verification_approve`, `payment_verification_reject`, `reports_view`.
- Finance approvers must be individually assigned the relevant review/approve/reject capability and scoped to one or more authorized locations.
- All three organization types may be assigned `payment_verification_initiate`.
- Approval authority is assigned to separate finance users at Main AMANAH, branch, and mobile-stockist levels according to company policy. Do not grant approval automatically based only on location type.
- Enforce separation of duties: the same user who initiated a payment verification cannot approve or reject that request.
- Consider requiring a second approver for configured high-value transactions or exceptional adjustments.

A future schema should model organizations/stock locations, memberships, permission assignments, and scoped finance authority. Do not overload the current `member_role` enum with all operating and finance functions.

## Digital stock lifecycle

### Main AMANAH to Branch Operator
1. Main AMANAH selects a BO destination, product, and quantity.
2. The system validates central available stock.
3. A pending transfer is created and the stock is reserved for dispatch.
4. The BO confirms receipt.
5. On confirmation, the transfer commits atomically: source stock is reduced and recipient stock is credited.
6. If rejected or cancelled before receipt, the reservation is released and the event remains in the audit history.

### Branch Operator to Mobile Stockist
1. MS may submit a stock request to its assigned BO.
2. BO reviews the request and selects quantities to transfer.
3. The system validates BO available stock and creates a pending transfer.
4. MS confirms receipt.
5. The transfer commits atomically and the MS stock balance is credited.
6. The BO balance is reduced in the same database transaction.

Direct Main AMANAH-to-MS transfers are disabled by default unless an administrator explicitly enables that route.

### Inventory accounting
Track available, reserved, in-transit, and sold quantities. Use an immutable inventory ledger as the source of truth; balances are derived or transactionally maintained and reconciled against the ledger. Never accept client-submitted balances. Prevent negative stock and concurrent over-allocation using database transactions and row-level locking or equivalent concurrency-safe controls.

## Payment verification workflow

1. A user at Main AMANAH, BO, or MS creates an order for a customer/distributor.
2. A trusted server-side operation checks the user's assigned stock location and validates available digital stock for every order line.
3. If any line has insufficient available stock, reject the request before payment verification can be initiated. Display: "INSUFFICIENT DIGITAL STOCK. Please acquire additional stock before initiating payment verification."
4. If sufficient, reserve the stock atomically and create a uniquely referenced payment-verification request.
5. The initiator submits payment method, amount, payment reference/date, and proof where required.
6. The request enters the pending finance review queue for authorized approvers scoped to that location or explicitly delegated authority.
7. An authorized finance user other than the initiator may approve or reject it. Record reviewer identity, timestamp, decision, and reason.
8. On approval, revalidate the reservation, finalize the stock sale, record the verified order, and post eligible PV exactly once.
9. On rejection or cancellation, release the reservation and do not post PV.
10. Refunds and approved reversals create compensating ledger entries; never delete or rewrite historical financial records.

## PV and sales accounting

- Product PV and price are sourced from administrator-controlled product settings and snapshotted on order items at order creation.
- Line PV = snapshotted unit PV × verified quantity.
- PV is posted only after successful authorized payment approval.
- Credit the purchasing distributor/customer account according to the approved account attribution rule. The seller/stockist receives a sales record and inventory movement, not an automatic duplicate personal-PV credit.
- Keep personal PV, group PV, seller sales volume, stock movement, and commission records separate.
- Prevent duplicate PV posting with unique transaction references and database-enforced idempotency.
- Commission calculations may use only eligible verified product sales, never recruitment fees or stock transfers alone.

## Suggested database building blocks

Design and review normalized tables before implementation:
- `organizations` or `stock_locations`
- `organization_memberships`
- `permission_assignments` (capability + location scope)
- `digital_stock_balances` (transactional projection/cache)
- `stock_transfers`
- `stock_transfer_items`
- `stock_requests`
- `inventory_ledger`
- `orders` and `order_items`
- `payment_verifications`
- `payment_proofs`
- `pv_ledger`
- `sales_ledger`
- `transaction_audit_logs`

Use database constraints, indexes, RLS, and server-only transactional RPCs for stock reservation, transfer commitment, receipt confirmation, payment approval/rejection, PV posting, and refund reversal. Never expose service-role credentials to browser clients.

## Required interface areas

### Main AMANAH
- Central inventory
- Branch operators
- Mobile stockists
- Stock transfer and receipt tracking
- Direct sales and payment verification
- Finance review queue for authorized finance users
- Verified sales, PV ledger, reports, and audit logs

### Branch Operator
- Branch digital stock
- Receive stock from Main AMANAH
- Transfer stock to assigned mobile stockists
- Stock requests
- Direct sales and payment initiation
- Finance review queue only for users with assigned finance permissions
- Verified sales, reports, and stock history

### Mobile Stockist
- Personal digital stock
- Request stock from assigned BO
- Confirm incoming stock
- Direct sales and payment initiation
- Finance review queue only for users with assigned finance permissions
- Verified transactions, PV records, and stock history

## Required status values

Transfers: `requested`, `pending_dispatch`, `in_transit`, `received`, `rejected`, `cancelled`.

Payment verification: `draft`, `awaiting_payment`, `submitted`, `pending_review`, `approved`, `rejected`, `cancelled`, `refunded`.

Inventory movement: `reserved`, `transfer_out`, `transfer_in`, `sale`, `reservation_release`, `refund_return`, `adjustment`.

## Security and acceptance criteria

- A BO cannot transfer stock it does not own or exceed its available quantity.
- An MS can receive stock only from an authorized source/assigned BO, unless a direct-transfer policy is explicitly enabled.
- All three entity types can initiate payment verification when the required stock is available.
- An entity with zero or insufficient stock cannot initiate verification.
- Only individually authorized finance users can approve/reject, within their assigned scope.
- An initiator cannot approve their own request.
- Payment approval, stock finalization, and PV posting are atomic or safely idempotent; partial completion cannot create a paid order without its matching stock and PV records.
- Repeated requests, double-clicks, webhook retries, and concurrent orders cannot double-consume stock or double-credit PV.
- Rejected/cancelled requests release reserved stock.
- Every transfer, approval, rejection, PV posting, adjustment, and reversal is auditable.
- RLS and server-side checks enforce the same rules; hiding a button is not authorization.

## Implementation status

This document is a confirmed system-design specification, not a claim that the feature is implemented. The existing initial schema currently models only admin/distributor profiles and basic paid orders; it does not yet implement the organization hierarchy, digital stock ledger, finance permission scopes, payment-verification workflow, or PV posting workflow. Build these through reviewed migrations and server-side functions, then test in a disposable Supabase environment before production.
