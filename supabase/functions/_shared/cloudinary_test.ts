import { canDeleteReference } from './cloudinary.ts'

const reference = 'cloudinary://authenticated/fixture/payment/bill/proof.png'
function assert(value: unknown): asserts value { if (!value) throw new Error('Assertion failed') }
type Result = { data: { id: string }[] | null; error: { message: string } | null }
function fixture(rows: Record<string, Result>) {
  const reads: string[] = []
  const admin = { from(table: string) {
    reads.push(table)
    return { select(column: string) {
      assert(column === 'id')
      return { eq(column: string, value: string) {
        assert(column === (table === 'payment_transactions' ? 'receipt_path' : 'photo_path'))
        assert(value === reference)
        return { limit(count: number) { assert(count === 1); return Promise.resolve(rows[table]) } }
      } }
    } }
  } }
  return { admin: admin as unknown as Parameters<typeof canDeleteReference>[0], reads }
}
const empty: Result = { data: [], error: null }
const attached: Result = { data: [{ id: 'committed-record' }], error: null }
Deno.test('issued receipt photos remain protected, including voided receipt history', async () => {
  const f = fixture({ payment_transactions: empty, maintenance_reports: empty, issued_payment_receipts: attached })
  assert(!(await canDeleteReference(f.admin, reference)))
})
Deno.test('detached uploads remain eligible for authorized cleanup', async () => {
  const f = fixture({ payment_transactions: empty, maintenance_reports: empty, issued_payment_receipts: empty })
  assert(await canDeleteReference(f.admin, reference))
  assert(f.reads.length === 3)
})
Deno.test('a saved payment reference prevents deletion even after a lost submission reply', async () => {
  const f = fixture({ payment_transactions: attached, maintenance_reports: empty, issued_payment_receipts: empty })
  assert(!(await canDeleteReference(f.admin, reference)))
})
Deno.test('a saved maintenance photo prevents deletion until detached', async () => {
  const f = fixture({ payment_transactions: empty, maintenance_reports: attached })
  assert(!(await canDeleteReference(f.admin, reference)))
})
Deno.test('an incomplete database response cannot authorize evidence deletion', async () => {
  const f = fixture({ payment_transactions: { data: null, error: null }, maintenance_reports: empty, issued_payment_receipts: empty })
  assert(!(await canDeleteReference(f.admin, reference)))
})
for (const table of ['payment_transactions', 'maintenance_reports', 'issued_payment_receipts']) {
  Deno.test(`unavailable ${table} lookup fails closed instead of deleting evidence`, async () => {
    const f = fixture({ payment_transactions: empty, maintenance_reports: empty, issued_payment_receipts: empty,
      [table]: { data: null, error: { message: 'Database unavailable' } } })
    assert(!(await canDeleteReference(f.admin, reference)))
  })
}
