# CarmeLink — Owner & Caretaker Web Dashboard Integration Guide

This guide provides comprehensive technical instructions for connecting a web frontend (React, Next.js, Vue, Svelte, or Flutter Web) to the **CarmeLink** Supabase backend. It covers connection setup, authentication & role authorization, database schemas, Edge Functions, storage buckets, and real-time subscriptions.

---

## 1. System Architecture & Security Model

CarmeLink uses a **single-backend, multi-client** architecture. Both the Flutter mobile application (used by Tenants and Guardians) and the web management application (used by the Owner and Caretaker) connect to the exact same Supabase database.

```text
┌───────────────────────────────────────────────────────────┐
│                     Web Dashboard                         │
│               (Owner & Caretaker Workspaces)              │
└─────────────────────────────┬─────────────────────────────┘
                              │
                    HTTPS / WSS / REST API
                              │
┌─────────────────────────────▼─────────────────────────────┐
│                    Supabase Backend                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌─────────┐  │
│  │  Supabase Auth   │  │ PostgreSQL + RLS │  │ Storage │  │
│  └──────────────────┘  └──────────────────┘  └─────────┘  │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  Edge Functions  │  │ Realtime Engine  │               │
│  └──────────────────┘  └──────────────────┘               │
└───────────────────────────────────────────────────────────┘
```

### Security & Row Level Security (RLS) Rules

1. **Role-Based Access Control (RBAC)**: Roles (`owner`, `caretaker`, `tenant`, `guardian`) are stored in the server-protected `public.profiles` table and are never user-selectable.
2. **Server-Side Authorization**: PostgreSQL RLS policies enforce access. The helper function `public.is_staff()` returns `true` for both `owner` and `caretaker`. `public.is_owner()` returns `true` only for `owner`.
3. **Anon Access Prohibited**: All public/anonymous access to business tables has been revoked (`revoke all on table ... from anon`). Every web request must carry an authenticated user JWT (`Bearer <access_token>`).
4. **Zero Client-Side Secrets**: **NEVER** expose `SUPABASE_SERVICE_ROLE_KEY` on the web frontend. All administrative operations requiring service-role privileges (such as user creation, credential management, and email invites) are mediated through protected **Supabase Edge Functions**.

---

## 2. Supabase Connection & Environment Setup

### Environment Variables

Configure your web application's environment file (e.g., `.env.local` for Next.js/Vite):

```bash
# Supabase Project Credentials
NEXT_PUBLIC_SUPABASE_URL="https://iuplkgvitovzjbmtzpme.supabase.co"
NEXT_PUBLIC_SUPABASE_ANON_KEY="sb_publishable_b5D9jzxkduw55AJj3njOnQ_m1E7cxJP"

# For Vite, prefix with VITE_
# VITE_SUPABASE_URL="https://iuplkgvitovzjbmtzpme.supabase.co"
# VITE_SUPABASE_ANON_KEY="sb_publishable_b5D9jzxkduw55AJj3njOnQ_m1E7cxJP"
```

### Client Initialization (TypeScript / JavaScript)

Install the Supabase JS SDK:
```bash
npm install @supabase/supabase-js
```

Create a central client instance (e.g., `src/lib/supabaseClient.ts`):

```typescript
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.VITE_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.VITE_SUPABASE_ANON_KEY!;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});
```

---

## 3. Authentication & Staff Role Authorization

The web dashboard is restricted to **Staff** (`owner` and `caretaker`). If a tenant or guardian attempts to log in to the web management portal, the app must revoke the session and deny entry.

### Staff Login Flow

```typescript
export type AppRole = 'owner' | 'caretaker' | 'tenant' | 'guardian';

export interface UserProfile {
  id: string;
  full_name: string;
  phone: string;
  role: AppRole;
  created_at: string;
  updated_at: string;
}

export async function staffSignIn(email: string, password: string): Promise<UserProfile> {
  // 1. Authenticate with Supabase Auth
  const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
    email,
    password,
  });

  if (authError || !authData.user) {
    throw new Error(authError?.message || 'Invalid credentials');
  }

  // 2. Fetch server-controlled role from public.profiles
  const { data: profile, error: profileError } = await supabase
    .from('profiles')
    .select('id, full_name, phone, role, created_at, updated_at')
    .eq('id', authData.user.id)
    .single();

  if (profileError || !profile) {
    await supabase.auth.signOut();
    throw new Error('User profile not found.');
  }

  // 3. Enforce Staff Role Guard
  if (profile.role !== 'owner' && profile.role !== 'caretaker') {
    await supabase.auth.signOut();
    throw new Error('Access denied. This dashboard is strictly for Owner and Caretaker accounts.');
  }

  return profile as UserProfile;
}
```

### Sign Out & Session Listener

```typescript
export function onAuthStateChange(callback: (profile: UserProfile | null) => void) {
  return supabase.auth.onAuthStateChange(async (event, session) => {
    if (!session?.user) {
      callback(null);
      return;
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.user.id)
      .single();

    if (profile && (profile.role === 'owner' || profile.role === 'caretaker')) {
      callback(profile as UserProfile);
    } else {
      await supabase.auth.signOut();
      callback(null);
    }
  });
}
```

---

## 4. Protected Edge Functions (User & Account Management)

Staff accounts are provisioned and managed securely through dedicated **Supabase Edge Functions** to prevent exposing the service role key.

### A. Create User Account (`create-user`)

* **Endpoint**: `https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/create-user`
* **Authorization**: `Bearer <user_access_token>`
* **Permissions**:
  * **Owner**: Can create accounts for `owner`, `caretaker`, `tenant`, and `guardian`.
  * **Caretaker**: Can create accounts for `tenant` and `guardian` only.

```typescript
export async function createAccount(params: {
  email: string;
  password: string; // minimum 12 characters
  fullName: string;
  phone?: string;
  role: 'tenant' | 'guardian' | 'caretaker' | 'owner';
}) {
  const session = (await supabase.auth.getSession()).data.session;
  if (!session) throw new Error('Unauthenticated');

  const response = await fetch(
    `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/create-user`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify({
        email: params.email,
        password: params.password,
        full_name: params.fullName,
        phone: params.phone || '',
        role: params.role,
      }),
    }
  );

  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.error || 'Failed to create user account');
  }
  return result; // { id, email, role }
}
```

### B. Manage Accounts (`manage-user`)

* **Endpoint**: `https://iuplkgvitovzjbmtzpme.supabase.co/functions/v1/manage-user`
* **Authorization**: `Bearer <user_access_token>`

Supported actions:
1. `list`: Fetches all accounts (with emails) visible to the staff actor.
2. `update`: Updates `full_name`, `phone`, and `email` for a target account.
3. `reset_password`: Triggers a password reset email to the account's registered address.
4. `delete`: Completely removes auth user and cascade-deletes their profile.

```typescript
export async function manageUserAction(payload: {
  action: 'list' | 'update' | 'reset_password' | 'delete';
  id?: string;
  full_name?: string;
  phone?: string;
  email?: string;
}) {
  const session = (await supabase.auth.getSession()).data.session;
  if (!session) throw new Error('Unauthenticated');

  const response = await fetch(
    `${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/manage-user`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${session.access_token}`,
      },
      body: JSON.stringify(payload),
    }
  );

  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.error || `Operation ${payload.action} failed`);
  }
  return result;
}
```

---

## 5. Core Operational Modules & Database Integration

### Module A: Rooms, Bed Spaces & Occupancy Monitoring

#### Schema
* `rooms` (`id`, `room_number`, `floor`, `capacity`, `description`)
* `bed_spaces` (`id`, `room_id`, `label`, `status`)
  * `status` values: `'available'`, `'reserved'`, `'maintenance'`, `'unavailable'`
* `tenant_assignments` (`id`, `tenant_id`, `bed_space_id`, `starts_on`, `ends_on`, `status`)
  * `status` values: `'active'`, `'ended'`, `'cancelled'`

#### Fetch Rooms with Bed Spaces and Occupant Info
```typescript
export async function fetchDormitoryRooms() {
  const { data, error } = await supabase
    .from('rooms')
    .select(`
      id,
      room_number,
      floor,
      capacity,
      description,
      bed_spaces (
        id,
        label,
        status,
        tenant_assignments (
          id,
          starts_on,
          status,
          profiles:tenant_id (
            id,
            full_name,
            phone
          )
        )
      )
    `)
    .order('room_number', { ascending: true });

  if (error) throw error;
  return data;
}
```

#### Assign Tenant to Bed Space
```typescript
export async function assignTenantToBed(tenantId: string, bedSpaceId: string) {
  // 1. Insert active assignment
  const { data, error } = await supabase
    .from('tenant_assignments')
    .insert({
      tenant_id: tenantId,
      bed_space_id: bedSpaceId,
      status: 'active',
      starts_on: new Date().toISOString().split('T')[0],
    })
    .select()
    .single();

  if (error) throw error;

  // 2. Mark bed space as occupied
  await supabase
    .from('bed_spaces')
    .update({ status: 'unavailable' })
    .eq('id', bedSpaceId);

  return data;
}
```

---

### Module B: Payments & Billing Verification

#### Schema
* `payments` (`id`, `tenant_id`, `title`, `category`, `amount`, `due_date`, `status`, `payment_method`, `reference_number`, `receipt_path`, `paid_at`, `reviewed_by`, `reviewed_at`, `review_notes`)
  * `category` values: `'rent'`, `'utility'`, `'deposit'`, `'penalty'`, `'other'`
  * `status` values: `'due'`, `'pending_verification'`, `'verified'`, `'rejected'`
  * `payment_method` values: `'GCash'`, `'Maya'`, `'Bank transfer'`, `'Cash'`, `'Other'`

#### Fetch All Payments with Tenant & Room Details
```typescript
export async function fetchPaymentsList(statusFilter?: string) {
  let query = supabase
    .from('payments')
    .select(`
      id,
      tenant_id,
      title,
      category,
      amount,
      due_date,
      status,
      payment_method,
      reference_number,
      receipt_path,
      paid_at,
      reviewed_by,
      reviewed_at,
      review_notes,
      created_at,
      profiles:tenant_id (
        id,
        full_name,
        phone,
        tenant_assignments (
          bed_spaces (
            label,
            rooms (room_number)
          )
        )
      )
    `)
    .order('created_at', { ascending: false });

  if (statusFilter && statusFilter !== 'all') {
    query = query.eq('status', statusFilter);
  }

  const { data, error } = await query;
  if (error) throw error;
  return data;
}
```

#### Issue a New Invoice
```typescript
export async function issueInvoice(params: {
  tenantId: string;
  title: string;
  category: 'rent' | 'utility' | 'deposit' | 'penalty' | 'other';
  amount: number;
  dueDate: string; // 'YYYY-MM-DD'
}) {
  const { data, error } = await supabase
    .from('payments')
    .insert({
      tenant_id: params.tenantId,
      title: params.title.trim(),
      category: params.category,
      amount: params.amount,
      due_date: params.dueDate,
      status: 'due',
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

#### Approve / Verify Payment Proof
```typescript
export async function approvePayment(paymentId: string) {
  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data, error } = await supabase
    .from('payments')
    .update({
      status: 'verified',
      reviewed_by: staffUser.id,
      reviewed_at: new Date().toISOString(),
      review_notes: 'Verified and approved by dormitory staff.',
    })
    .eq('id', paymentId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

#### Reject Payment Proof with Required Reason
```typescript
export async function rejectPayment(paymentId: string, rejectionReason: string) {
  if (!rejectionReason.trim()) throw new Error('Rejection reason is required');

  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data, error } = await supabase
    .from('payments')
    .update({
      status: 'rejected',
      reviewed_by: staffUser.id,
      reviewed_at: new Date().toISOString(),
      review_notes: rejectionReason.trim(),
    })
    .eq('id', paymentId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

#### Record In-Person Cash Payment
```typescript
export async function recordCashPayment(paymentId: string, notes?: string) {
  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data, error } = await supabase
    .from('payments')
    .update({
      status: 'verified',
      payment_method: 'Cash',
      paid_at: new Date().toISOString(),
      reviewed_by: staffUser.id,
      reviewed_at: new Date().toISOString(),
      review_notes: notes || 'Cash received in person at dormitory office.',
    })
    .eq('id', paymentId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

---

### Module C: Maintenance Management & Triage

#### Schema
* `maintenance_reports` (`id`, `tenant_id`, `room_id`, `category`, `urgency`, `description`, `status`, `photo_path`, `staff_notes`, `handled_by`, `resolved_at`, `location_x`, `location_y`, `created_at`)
  * `category` values: `'electrical'`, `'plumbing'`, `'carpentry'`, `'appliance'`, `'structural'`, `'other'`
  * `urgency` values: `'low'`, `'medium'`, `'high'`, `'urgent'`
  * `status` values: `'pending'`, `'in_progress'`, `'resolved'`, `'cancelled'`
* `maintenance_staff_history` (`id`, `report_id`, `actor_id`, `actor_name`, `previous_status`, `next_status`, `notes`, `created_at`)

#### Fetch Maintenance Reports for Staff Triage
```typescript
export async function fetchMaintenanceReports(statusFilter?: string) {
  let query = supabase
    .from('maintenance_reports')
    .select(`
      id,
      tenant_id,
      room_id,
      category,
      urgency,
      description,
      status,
      photo_path,
      staff_notes,
      handled_by,
      resolved_at,
      location_x,
      location_y,
      created_at,
      profiles:tenant_id (
        id,
        full_name,
        phone
      ),
      rooms:room_id (
        id,
        room_number,
        floor
      ),
      staff:handled_by (
        id,
        full_name
      )
    `)
    .order('created_at', { ascending: false });

  if (statusFilter && statusFilter !== 'all') {
    query = query.eq('status', statusFilter);
  }

  const { data, error } = await query;
  if (error) throw error;
  return data;
}
```

#### Update Maintenance Status & Record Audit History
```typescript
export async function updateMaintenanceStatus(params: {
  reportId: string;
  previousStatus: string;
  nextStatus: 'pending' | 'in_progress' | 'resolved' | 'cancelled';
  staffNotes: string;
  assignedStaffId?: string;
}) {
  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data: staffProfile } = await supabase
    .from('profiles')
    .select('full_name')
    .eq('id', staffUser.id)
    .single();

  const isResolved = params.nextStatus === 'resolved';

  // 1. Update report
  const { data: updatedReport, error: updateError } = await supabase
    .from('maintenance_reports')
    .update({
      status: params.nextStatus,
      staff_notes: params.staffNotes,
      handled_by: params.assignedStaffId || staffUser.id,
      resolved_at: isResolved ? new Date().toISOString() : null,
    })
    .eq('id', params.reportId)
    .select()
    .single();

  if (updateError) throw updateError;

  // 2. Insert audit log in maintenance_staff_history
  await supabase
    .from('maintenance_staff_history')
    .insert({
      report_id: params.reportId,
      actor_id: staffUser.id,
      actor_name: staffProfile?.full_name || 'Dormitory Staff',
      previous_status: params.previousStatus,
      next_status: params.nextStatus,
      notes: params.staffNotes,
    });

  return updatedReport;
}
```

---

### Module D: Curfew & Overnight Leave System

#### Schema
* `curfew_requests` (`id`, `tenant_id`, `request_type`, `destination`, `reason`, `departure_time`, `expected_return_time`, `status`, `guardian_id`, `guardian_decision`, `guardian_remarks`, `guardian_decided_at`, `staff_id`, `staff_decision`, `staff_notes`, `gate_instructions`, `staff_decided_at`, `created_at`)
  * `request_type`: `'late_return'` (direct to staff) | `'overnight_leave'` (requires guardian first)
  * `status`: `'pending_guardian'`, `'pending_staff'`, `'approved'`, `'rejected'`, `'cancelled'`, `'completed'`

#### Fetch Curfew Requests Awaiting Staff Decision
```typescript
export async function fetchCurfewRequestsForStaff() {
  const { data, error } = await supabase
    .from('curfew_requests')
    .select(`
      id,
      tenant_id,
      request_type,
      destination,
      reason,
      departure_time,
      expected_return_time,
      status,
      guardian_decision,
      guardian_remarks,
      guardian_decided_at,
      staff_decision,
      staff_notes,
      gate_instructions,
      staff_decided_at,
      created_at,
      profiles:tenant_id (
        id,
        full_name,
        phone,
        tenant_assignments (
          bed_spaces (rooms (room_number))
        )
      ),
      guardian:guardian_id (
        id,
        full_name,
        phone
      )
    `)
    .in('status', ['pending_staff', 'approved', 'rejected'])
    .order('departure_time', { ascending: false });

  if (error) throw error;
  return data;
}
```

#### Staff Final Decision (Approve / Reject)
```typescript
export async function decideCurfewRequest(params: {
  requestId: string;
  decision: 'approved' | 'rejected';
  gateInstructions?: string;
  staffNotes?: string;
}) {
  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data, error } = await supabase
    .from('curfew_requests')
    .update({
      status: params.decision,
      staff_decision: params.decision,
      staff_id: staffUser.id,
      staff_notes: params.staffNotes || '',
      gate_instructions: params.gateInstructions || '',
      staff_decided_at: new Date().toISOString(),
    })
    .eq('id', params.requestId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

---

### Module E: Visitor Management

#### Schema
* `visitor_requests` (`id`, `tenant_id`, `visitor_name`, `relationship`, `purpose`, `schedule`, `status`, `created_at`)
  * `status`: `'pending'`, `'approved'`, `'rejected'`, `'cancelled'`, `'completed'`

#### Staff Visitor Decision
```typescript
export async function decideVisitorRequest(requestId: string, status: 'approved' | 'rejected') {
  const { data, error } = await supabase
    .from('visitor_requests')
    .update({ status })
    .eq('id', requestId)
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

---

### Module F: Announcements Board

#### Schema
* `announcements` (`id`, `author_id`, `title`, `body`, `category`, `audience`, `is_pinned`, `fcm_sent`, `created_at`, `updated_at`)
  * `category`: `'general'`, `'maintenance'`, `'utility'`, `'billing'`, `'emergency'`, `'event'`
  * `audience`: `'all'`, `'tenants'`, `'guardians'`, `'staff'`

#### Create Announcement (Staff Only)
```typescript
export async function createAnnouncement(params: {
  title: string;
  body: string;
  category: 'general' | 'maintenance' | 'utility' | 'billing' | 'emergency' | 'event';
  audience: 'all' | 'tenants' | 'guardians' | 'staff';
  isPinned?: boolean;
}) {
  const staffUser = (await supabase.auth.getUser()).data.user;
  if (!staffUser) throw new Error('Unauthenticated');

  const { data, error } = await supabase
    .from('announcements')
    .insert({
      author_id: staffUser.id,
      title: params.title.trim(),
      body: params.body.trim(),
      category: params.category,
      audience: params.audience,
      is_pinned: params.isPinned || false,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

---

### Module G: Guardian-to-Tenant Links (Owner Only)

#### Schema
* `guardian_tenant_links` (`id`, `guardian_id`, `tenant_id`, `relationship`, `is_primary`, `created_at`)

```typescript
export async function linkGuardianToTenant(params: {
  guardianId: string;
  tenantId: string;
  relationship: string;
  isPrimary: boolean;
}) {
  const { data, error } = await supabase
    .from('guardian_tenant_links')
    .insert({
      guardian_id: params.guardianId,
      tenant_id: params.tenantId,
      relationship: params.relationship,
      is_primary: params.isPrimary,
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

---

## 6. Storage Buckets & Image Display

All photo attachments uploaded via mobile or web are saved in private Supabase Storage buckets:

| Bucket Name | Purpose | Upload Path Format | Privacy |
|---|---|---|---|
| `payment_receipts` | Tenant payment proof screenshots | `${tenantId}/${timestamp}_${fileName}` | Private (`public: false`) |
| `maintenance_photos` | Issue photos and damage evidence | `${tenantId}/${timestamp}_${fileName}` | Private (`public: false`) |

### Rendering Private Images in the Web Browser

Because both buckets are private, public URLs will return `403 Forbidden`. The web dashboard must create a short-lived **Signed URL** to display receipts and photos:

```typescript
export async function getSignedReceiptUrl(receiptPath: string): Promise<string> {
  if (!receiptPath) return '';

  // If already an absolute HTTP URL (e.g., Cloudinary), return directly
  if (receiptPath.startsWith('http://') || receiptPath.startsWith('https://')) {
    return receiptPath;
  }

  const { data, error } = await supabase.storage
    .from('payment_receipts')
    .createSignedUrl(receiptPath, 3600); // 1-hour expiration

  if (error || !data?.signedUrl) {
    console.error('Failed to generate signed URL:', error);
    return '';
  }

  return data.signedUrl;
}

export async function getSignedMaintenancePhotoUrl(photoPath: string): Promise<string> {
  if (!photoPath) return '';
  if (photoPath.startsWith('http://') || photoPath.startsWith('https://')) {
    return photoPath;
  }

  const { data, error } = await supabase.storage
    .from('maintenance_photos')
    .createSignedUrl(photoPath, 3600);

  return data?.signedUrl || '';
}
```

---

## 7. Realtime Dashboard Subscriptions

Keep the web dashboard in sync without page reloads using **Supabase Realtime**. The tables below are already included in the `supabase_realtime` publication:

* `payments`
* `maintenance_reports`
* `curfew_requests`
* `announcements`
* `rooms` / `bed_spaces` / `tenant_assignments`

### Example: Live Payments & Maintenance Subscription

```typescript
export function subscribeToStaffUpdates(callbacks: {
  onPaymentChange?: () => void;
  onMaintenanceChange?: () => void;
  onCurfewChange?: () => void;
}) {
  const channel = supabase
    .channel('staff_web_realtime')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'payments' },
      () => callbacks.onPaymentChange?.()
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'maintenance_reports' },
      () => callbacks.onMaintenanceChange?.()
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'curfew_requests' },
      () => callbacks.onCurfewChange?.()
    )
    .subscribe();

  return () => {
    supabase.removeChannel(channel);
  };
}
```

---

## 8. Role Permission Matrix (Owner vs. Caretaker)

| Feature / Action | Owner | Caretaker | Enforcement Layer |
|---|:---:|:---:|---|
| **View Dashboard Metrics** | Full | Operational | Frontend & RLS |
| **Manage Rooms & Beds** | Full CRUD | Full CRUD | RLS `is_staff()` |
| **Triage Maintenance** | Full CRUD | Full CRUD | RLS `is_staff()` |
| **Verify Payment Proofs** | Yes | Yes | RLS `is_staff()` |
| **Issue Invoices / Record Cash** | Yes | Yes | RLS `is_staff()` |
| **Review Curfew & Late Return** | Yes | Yes | RLS `is_staff()` |
| **Visitor Request Approvals** | Yes | Yes | RLS `is_staff()` |
| **Publish Announcements** | Yes | Yes | RLS `is_staff()` |
| **Create Tenant / Guardian Accounts** | Yes | Yes | Edge Function `create-user` |
| **Create Owner / Caretaker Accounts** | Yes | **No** | Edge Function `create-user` |
| **Edit / Reset / Delete Staff** | Yes | **No** | Edge Function `manage-user` |
| **Manage Guardian-Tenant Links** | Yes | **No** | RLS `guardian_tenant_links` |
| **Financial Ledger & Analytics** | Full | Restricted | Future RLS / Policy |

---

## 9. Error Handling & Common Pitfalls

1. **Error Code `42501` (`permission denied for table`)**:
   * Occurs if the user session has expired or the signed-in user's role is not recognized by `public.is_staff()`.
   * **Fix**: Ensure the user has completed login, token refresh succeeds, and `profiles.role` is `'owner'` or `'caretaker'`.
2. **Expired Access Tokens on Web**:
   * Web dashboards running for hours may experience token expiry. Always use `supabase.auth.getSession()` or set up an interceptor with `supabase.auth.onAuthStateChange` to refresh the session token before initiating Edge Function calls.
3. **CORS on Edge Functions**:
   * All Edge Functions (`create-user`, `manage-user`) are equipped with permissive CORS headers (`Access-Control-Allow-Origin: *`). If you experience CORS errors, verify that your client passes `Authorization: Bearer <token>` and `apikey: <anon_key>` correctly.
4. **Dates and Timezones**:
   * Store and read dates using ISO-8601 (`timestamptz`). When filtering date columns such as `due_date` (PostgreSQL `date`), use the `'YYYY-MM-DD'` string format.

