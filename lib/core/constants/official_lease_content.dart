class OfficialLeaseRule {
  const OfficialLeaseRule(
      {required this.title, required this.details, this.consequence});
  final String title;
  final String details;
  final String? consequence;
}

/// Clauses transcribed from the client-provided three-page lease agreement.
class OfficialLeaseContent {
  const OfficialLeaseContent._();

  static const title = "Carmelita's Girls-Only Dormitory Lease Agreement";
  static const lessorName = 'Mark Anthony B. Nisperos';
  static const address =
      '0415 Dr. Luis Reyes St., Brgy. Concepcion, Baliuag, Bulacan';
  static const visitorHours = '9:00 AM-9:00 PM';
  static const curfew = '11:00 PM';
  static const quietHours = '10:00 PM-6:00 AM';

  static const requiredDocuments = <String>[
    'Photocopy of school ID or employee ID.',
    "Photocopy of the parent/guardian's valid ID.",
    'A printed copy of the above photocopies signed three times by the tenant and parent/guardian for verification.',
  ];

  static const rules = <OfficialLeaseRule>[
    OfficialLeaseRule(
        title: 'Girls-only policy',
        details: 'No male persons are allowed inside dorm rooms at any time.',
        consequence: 'PHP 3,000 and possible eviction'),
    OfficialLeaseRule(
        title: 'Visitors',
        details:
            'Visitors are allowed only from 9:00 AM to 9:00 PM and must be logged at reception.',
        consequence: 'PHP 1,000 per offense'),
    OfficialLeaseRule(
        title: 'Curfew',
        details:
            'Tenants must be inside the dorm by 11:00 PM. The time may vary for employees.',
        consequence:
            '1st offense: warning; 2nd: PHP 500; 3rd: PHP 1,000 or eviction'),
    OfficialLeaseRule(
        title: 'Monthly room checks',
        details:
            'Rooms are inspected monthly. Written notice is given at least three days before each inspection, and tenants must allow access.',
        consequence: 'Non-cooperation: PHP 1,000 or lease termination'),
    OfficialLeaseRule(
        title: 'No pets',
        details: 'No animals or pets of any kind are allowed on the premises.',
        consequence: 'PHP 1,500 and removal of the pet'),
    OfficialLeaseRule(
        title: 'No cooking inside rooms',
        details:
            'Hot plates, rice cookers, ovens, and other heating appliances are prohibited inside rooms.',
        consequence: 'PHP 2,000 and confiscation of the appliance'),
    OfficialLeaseRule(
        title: 'Private-room cleanliness',
        details: 'Rooms must be clean and organized at all times.',
        consequence: 'PHP 500 per offense during monthly inspection'),
    OfficialLeaseRule(
        title: 'Shared pantry and comfort rooms',
        details:
            'Tenants must clean up after themselves. Do not leave trash or dirty dishes.',
        consequence:
            'PHP 500 per offense; repeated offenses may lead to eviction'),
    OfficialLeaseRule(
        title: 'Maintenance of fixtures',
        details:
            'Tenants must maintain cabinets, faucets, air-conditioning units, windows, and other fixtures.',
        consequence:
            'Damage caused by negligence is charged to the tenant and deducted from the deposit'),
    OfficialLeaseRule(
        title: 'No smoking',
        details: 'Smoking is prohibited inside rooms and common areas.',
        consequence: 'PHP 2,000 per offense'),
    OfficialLeaseRule(
        title: 'Noise and quiet hours',
        details:
            'Quiet hours are 10:00 PM to 6:00 AM. Avoid loud music or disturbances at all times.',
        consequence: 'PHP 1,000 per violation'),
    OfficialLeaseRule(
        title: 'No subleasing or unauthorized occupants',
        details: 'Subleasing and unauthorized occupants are prohibited.',
        consequence: 'Immediate eviction and no refund of deposit'),
    OfficialLeaseRule(
        title: 'Respect for staff and co-tenants',
        details:
            'Aggressive, rude, or inappropriate behavior is not tolerated.',
        consequence:
            'PHP 1,000-PHP 5,000 depending on severity, or lease termination'),
  ];

  static const depositConditions = <String>[
    'No damage to property or appliances.',
    'No unpaid rent or penalties.',
    'Proper 30-day move-out notice was given.',
    'The room is left in clean and acceptable condition.',
  ];
  static const terminationReasons = <String>[
    'Repeated or serious rule violations.',
    'Unauthorized individuals in the dormitory.',
    'Refusal to comply with inspections or payment responsibilities.',
  ];
  static const miscellaneous = <String>[
    'Tenants are responsible for their belongings; the dormitory is not liable for lost or stolen items.',
    'The owner is not responsible for providing or lending personal belongings such as glasses, plates, cookware, or electric fans.',
    'Drilling, nailing, and unauthorized changes to walls or fixtures are prohibited.',
    'Monthly inspections are mandatory and non-negotiable.',
    'All tenants must regularly clean the shared pantry and comfort rooms.',
  ];
  static const ownerContact =
      'Contact the owner only for real emergencies such as fire, flood, break-in, power outage, or sudden fixture damage. Avoid calls or messages from 9:00 PM to 8:00 AM unless it is a serious emergency.';
}
