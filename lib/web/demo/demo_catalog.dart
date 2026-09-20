import 'package:flutter/material.dart';

enum DemoFieldKind { text, email, phone, paragraph, number, date, choice, reference }

class DemoField {
  const DemoField(this.key, this.label,
      {this.kind = DemoFieldKind.text,
      this.isRequired = true,
      this.options = const [],
      this.reference,
      this.hint = ''});

  final String key;
  final String label;
  final DemoFieldKind kind;
  final bool isRequired;
  final List<String> options;
  final String? reference;
  final String hint;
}

class DemoModule {
  const DemoModule(this.id, this.title, this.subtitle, this.icon, this.fields,
      {this.ownerOnly = false,
      this.allowCreate = true,
      this.allowDelete = true,
      this.statusOptions = const []});

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<DemoField> fields;
  final bool ownerOnly;
  final bool allowCreate;
  final bool allowDelete;
  final List<String> statusOptions;

  String get displayKey => fields.first.key;
  List<DemoField> get visibleFields => fields.take(5).toList();
}

/// Modules mirror the operational AREAS of the owner/caretaker mobile shells.
/// The records below are local simulations, not Supabase-backed mobile CRUD.
abstract final class DemoCatalog {
  static const modules = <DemoModule>[
    DemoModule('rooms', 'Rooms', 'Room inventory and bed capacity', Icons.bed_outlined, [
      DemoField('name', 'Room number'),
      DemoField('floor', 'Floor', kind: DemoFieldKind.choice, options: ['Ground', 'Second', 'Third']),
      DemoField('capacity', 'Bed capacity', kind: DemoFieldKind.number),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Open', 'Maintenance', 'Closed']),
      DemoField('notes', 'Room notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ]),
    DemoModule('tenants', 'Tenants', 'Resident directory and assignments', Icons.groups_outlined, [
      DemoField('name', 'Full name'),
      DemoField('email', 'Email', kind: DemoFieldKind.email),
      DemoField('phone', 'Phone', kind: DemoFieldKind.phone),
      DemoField('room', 'Assigned room', kind: DemoFieldKind.reference, reference: 'rooms', isRequired: false),
      DemoField('bed', 'Bed number', kind: DemoFieldKind.choice, options: ['1', '2', '3', '4'], isRequired: false),
      DemoField('guardian', 'Linked guardian', kind: DemoFieldKind.reference, reference: 'guardians', isRequired: false),
      DemoField('status', 'Resident status', kind: DemoFieldKind.choice, options: ['Active', 'Pending', 'Moved out']),
    ]),
    DemoModule('guardians', 'Guardians', 'Guardian profiles and tenant links', Icons.family_restroom_outlined, [
      DemoField('name', 'Full name'),
      DemoField('email', 'Email', kind: DemoFieldKind.email),
      DemoField('phone', 'Phone', kind: DemoFieldKind.phone),
      DemoField('relationship', 'Relationship', kind: DemoFieldKind.choice, options: ['Mother', 'Father', 'Guardian', 'Other']),
    ]),
    DemoModule('accounts', 'User accounts', 'Manage sample role-based accounts', Icons.manage_accounts_outlined, [
      DemoField('name', 'Display name'),
      DemoField('email', 'Email', kind: DemoFieldKind.email),
      DemoField('role', 'Role', kind: DemoFieldKind.choice, options: ['Tenant', 'Guardian', 'Caretaker', 'Owner']),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Active', 'Pending', 'Disabled']),
    ]),
    DemoModule('payments', 'Payments', 'Rent, utilities, penalties and verification', Icons.payments_outlined, [
      DemoField('name', 'Invoice label'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('category', 'Category', kind: DemoFieldKind.choice, options: ['Rent', 'Utilities', 'Penalty', 'Damage']),
      DemoField('amount', 'Amount (PHP)', kind: DemoFieldKind.number),
      DemoField('due', 'Due date', kind: DemoFieldKind.date),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Due', 'Pending verification', 'Verified', 'Rejected']),
      DemoField('reference', 'Receipt/reference', isRequired: false),
      DemoField('notes', 'Review notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ], statusOptions: ['Due', 'Pending verification', 'Verified', 'Rejected']),
    DemoModule('utilities', 'Utilities', 'Room electricity and water records', Icons.bolt_outlined, [
      DemoField('name', 'Billing period'),
      DemoField('room', 'Room', kind: DemoFieldKind.reference, reference: 'rooms'),
      DemoField('type', 'Utility', kind: DemoFieldKind.choice, options: ['Electricity', 'Water', 'Other']),
      DemoField('amount', 'Amount (PHP)', kind: DemoFieldKind.number),
      DemoField('due', 'Due date', kind: DemoFieldKind.date),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Due', 'Pending verification', 'Paid']),
    ], statusOptions: ['Due', 'Pending verification', 'Paid']),
    DemoModule('maintenance', 'Maintenance', 'Repair requests and progress', Icons.handyman_outlined, [
      DemoField('name', 'Issue title'),
      DemoField('tenant', 'Reported by', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('location', 'Location'),
      DemoField('priority', 'Urgency', kind: DemoFieldKind.choice, options: ['Low', 'Medium', 'High', 'Urgent']),
      DemoField('details', 'Description', kind: DemoFieldKind.paragraph),
      DemoField('assignee', 'Assigned to', isRequired: false),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Pending', 'In progress', 'Resolved', 'Closed']),
    ], statusOptions: ['Pending', 'In progress', 'Resolved', 'Closed']),
    DemoModule('announcements', 'Announcements', 'Publish updates for residents', Icons.campaign_outlined, [
      DemoField('name', 'Headline'),
      DemoField('audience', 'Audience', kind: DemoFieldKind.choice, options: ['All', 'Tenants', 'Guardians', 'Staff']),
      DemoField('details', 'Announcement body', kind: DemoFieldKind.paragraph),
      DemoField('date', 'Date', kind: DemoFieldKind.date),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Draft', 'Published', 'Archived']),
    ], statusOptions: ['Draft', 'Published', 'Archived']),
    DemoModule('curfew', 'Curfew requests', 'Request approval and return arrangements', Icons.schedule_outlined, [
      DemoField('name', 'Request title'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('type', 'Request type', kind: DemoFieldKind.choice, options: ['Late return', 'Overnight', 'Early exit', 'Other']),
      DemoField('date', 'Request date', kind: DemoFieldKind.date),
      DemoField('return', 'Expected return (local time)'),
      DemoField('details', 'Reason', kind: DemoFieldKind.paragraph),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Pending', 'Approved', 'Rejected', 'Completed']),
    ], statusOptions: ['Pending', 'Approved', 'Rejected', 'Completed']),
    DemoModule('presence', 'Geofence presence', 'MANUAL simulated presence only', Icons.location_on_outlined, [
      DemoField('name', 'Presence note'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('location', 'Presence', kind: DemoFieldKind.choice, options: ['Inside', 'Outside', 'Unknown']),
      DemoField('time', 'Recorded at (local time)'),
      DemoField('source', 'Source', kind: DemoFieldKind.choice, options: ['Manual demo', 'Simulated check']),
    ]),
    DemoModule('gate', 'Gate activity', 'Manually recorded entry and exit', Icons.door_front_door_outlined, [
      DemoField('name', 'Log label'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('direction', 'Direction', kind: DemoFieldKind.choice, options: ['Entry', 'Exit']),
      DemoField('time', 'Recorded at (local time)'),
      DemoField('notes', 'Notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ]),
    DemoModule('visitors', 'Visitor requests', 'Visitor applications and approval', Icons.badge_outlined, [
      DemoField('name', 'Visitor name'),
      DemoField('tenant', 'Visiting tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('relationship', 'Relationship'),
      DemoField('date', 'Visit date', kind: DemoFieldKind.date),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Pending', 'Approved', 'Rejected', 'Completed']),
    ], statusOptions: ['Pending', 'Approved', 'Rejected', 'Completed']),
    DemoModule('confidential', 'Confidential reports', 'Owner-only private issue review', Icons.lock_outline, [
      DemoField('name', 'Private report title'),
      DemoField('tenant', 'Reported by', kind: DemoFieldKind.reference, reference: 'tenants', isRequired: false),
      DemoField('details', 'Details', kind: DemoFieldKind.paragraph),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['New', 'Reviewing', 'Resolved']),
      DemoField('notes', 'Owner notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ], ownerOnly: true, statusOptions: ['New', 'Reviewing', 'Resolved']),
    DemoModule('discipline', 'Disciplinary records', 'Owner-only conduct documentation', Icons.gavel_outlined, [
      DemoField('name', 'Incident title'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('date', 'Incident date', kind: DemoFieldKind.date),
      DemoField('details', 'Incident details', kind: DemoFieldKind.paragraph),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Open', 'Under review', 'Closed']),
    ], ownerOnly: true, statusOptions: ['Open', 'Under review', 'Closed']),
    DemoModule('appeals', 'Appeals', 'Review requests concerning disciplinary actions', Icons.assignment_turned_in_outlined, [
      DemoField('name', 'Appeal subject'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('details', 'Appeal statement', kind: DemoFieldKind.paragraph),
      DemoField('date', 'Submitted date', kind: DemoFieldKind.date),
      DemoField('status', 'Decision', kind: DemoFieldKind.choice, options: ['Pending', 'Under review', 'Approved', 'Rejected']),
    ], ownerOnly: true, statusOptions: ['Pending', 'Under review', 'Approved', 'Rejected']),
    DemoModule('contracts', 'Contracts', 'Owner-only lease and expiry tracker', Icons.description_outlined, [
      DemoField('name', 'Contract label'),
      DemoField('tenant', 'Tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('start', 'Start date', kind: DemoFieldKind.date),
      DemoField('end', 'End date', kind: DemoFieldKind.date),
      DemoField('amount', 'Monthly rent (PHP)', kind: DemoFieldKind.number),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Draft', 'Awaiting signature', 'Active', 'Expired']),
    ], ownerOnly: true, statusOptions: ['Draft', 'Awaiting signature', 'Active', 'Expired']),
    DemoModule('expenses', 'Income and expenses', 'Owner-only expense records', Icons.account_balance_wallet_outlined, [
      DemoField('name', 'Expense description'),
      DemoField('category', 'Category', kind: DemoFieldKind.choice, options: ['Utilities', 'Maintenance', 'Supplies', 'Other']),
      DemoField('amount', 'Amount (PHP)', kind: DemoFieldKind.number),
      DemoField('date', 'Date', kind: DemoFieldKind.date),
      DemoField('notes', 'Notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ], ownerOnly: true),
    DemoModule('messages', 'Messages', 'Local conversation log; no messages delivered', Icons.forum_outlined, [
      DemoField('name', 'Subject'),
      DemoField('recipient', 'Recipient', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('details', 'Message', kind: DemoFieldKind.paragraph),
      DemoField('date', 'Date', kind: DemoFieldKind.date),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['Draft', 'Simulated sent']),
    ], statusOptions: ['Draft', 'Simulated sent']),
    DemoModule('notifications', 'Guardian notifications', 'Preview alerts only; nothing is delivered', Icons.notifications_active_outlined, [
      DemoField('name', 'Alert title'),
      DemoField('guardian', 'Guardian', kind: DemoFieldKind.reference, reference: 'guardians'),
      DemoField('tenant', 'Related tenant', kind: DemoFieldKind.reference, reference: 'tenants'),
      DemoField('type', 'Alert type', kind: DemoFieldKind.choice, options: ['Curfew', 'Gate activity', 'Announcement', 'Other']),
      DemoField('details', 'Message text', kind: DemoFieldKind.paragraph),
      DemoField('status', 'Demo state', kind: DemoFieldKind.choice, options: ['Draft', 'Simulated queued', 'Acknowledged']),
    ], statusOptions: ['Draft', 'Simulated queued', 'Acknowledged']),
    DemoModule('contacts', 'Emergency contacts', 'Important local contact directory', Icons.contact_phone_outlined, [
      DemoField('name', 'Contact name'),
      DemoField('relationship', 'Type'),
      DemoField('phone', 'Phone', kind: DemoFieldKind.phone),
      DemoField('notes', 'Notes', kind: DemoFieldKind.paragraph, isRequired: false),
    ]),
    DemoModule('inquiries', 'Inquiries', 'Sample inquiries; no public form submissions', Icons.mark_email_unread_outlined, [
      DemoField('name', 'Enquirer name'),
      DemoField('email', 'Email', kind: DemoFieldKind.email),
      DemoField('phone', 'Phone', kind: DemoFieldKind.phone, isRequired: false),
      DemoField('details', 'Inquiry', kind: DemoFieldKind.paragraph),
      DemoField('status', 'Status', kind: DemoFieldKind.choice, options: ['New', 'Contacted', 'Closed']),
    ], statusOptions: ['New', 'Contacted', 'Closed']),
  ];

  static DemoModule byId(String id) => modules.firstWhere((m) => m.id == id);
  static List<DemoModule> forRole(String role) => modules
      .where((module) => role == 'Owner' || !module.ownerOnly)
      .toList(growable: false);
}
