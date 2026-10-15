'use strict';

/**
 * Seed data for the support-resource directory and the emergency/quick-support
 * function (sections 3.9 secondary features and 3.8).
 *
 * In a real deployment this content would be maintained by the institution.
 * Values below are representative placeholders for the Ugandan university
 * context and must be confirmed with the partner institution before a pilot.
 */

const SUPPORT_RESOURCES = [
  {
    id: 'resource-dean-of-students',
    title: 'Dean of Students Office',
    category: 'Institutional',
    description:
      'Receives student welfare concerns, including harassment complaints, and can open a formal complaint file.',
    contact: '+256 000 000 001',
    availability: 'Mon-Fri, 08:00-17:00',
    walkIn: true,
  },
  {
    id: 'resource-safeguarding-officer',
    title: 'University Safeguarding Officer',
    category: 'Institutional',
    description:
      'Designated officer responsible for handling sexual-harassment allegations confidentially under institutional policy.',
    contact: '+256 000 000 002',
    availability: 'Mon-Fri, 08:00-17:00',
    walkIn: true,
  },
  {
    id: 'resource-counselling',
    title: 'Student Counselling Centre',
    category: 'Psychosocial',
    description:
      'Free, confidential counselling. You may speak to a counsellor before deciding whether to submit a formal complaint.',
    contact: '+256 000 000 003',
    availability: 'Mon-Sat, 08:00-18:00',
    walkIn: true,
  },
  {
    id: 'resource-medical',
    title: 'University Health Centre',
    category: 'Medical',
    description:
      'Medical examination, post-exposure care and documentation of physical injuries. Attend as soon as possible if you are able.',
    contact: '+256 000 000 004',
    availability: '24 hours',
    walkIn: true,
  },
  {
    id: 'resource-security',
    title: 'Campus Security Control Room',
    category: 'Security',
    description: 'Immediate on-campus response and escort services.',
    contact: '+256 000 000 005',
    availability: '24 hours',
    walkIn: false,
  },
  {
    id: 'resource-womens-association',
    title: 'University Women\'s Association',
    category: 'Student-led',
    description:
      'Student-run peer support, accompaniment when reporting, and awareness activities.',
    contact: 'women@university.example',
    availability: 'Mon-Fri, 10:00-16:00',
    walkIn: true,
  },
  {
    id: 'resource-reporting-guidance',
    title: 'How to report: step by step',
    category: 'Guidance',
    description:
      '1) Record what happened as soon as possible. 2) Preserve messages or screenshots. 3) Choose identified, confidential or anonymous reporting. 4) Submit through HERVOICE and keep your case reference. 5) Track the case status in the app.',
    contact: null,
    availability: 'Always available',
    walkIn: false,
  },
  {
    id: 'resource-evidence-guidance',
    title: 'What counts as supporting evidence?',
    category: 'Guidance',
    description:
      'Screenshots of messages, emails, photographs, documents and permitted recordings. Recordings must only be captured and shared where this is lawful and permitted by institutional policy. A report without evidence can still be recorded.',
    contact: null,
    availability: 'Always available',
    walkIn: false,
  },
  {
    id: 'resource-self-care',
    title: 'Looking after yourself',
    category: 'Psychosocial',
    description:
      'You do not have to decide everything at once. Save a draft, share only what you are ready to share, and use the emergency support button if you feel unsafe.',
    contact: null,
    availability: 'Always available',
    walkIn: false,
  },
];

const EMERGENCY_CONTACTS = [
  {
    id: 'emergency-security',
    label: 'Campus Security (24h)',
    contact: '+256 000 000 005',
    type: 'PHONE',
    note: 'Fastest on-campus response.',
  },
  {
    id: 'emergency-safeguarding',
    label: 'Safeguarding Officer on call',
    contact: '+256 000 000 002',
    type: 'PHONE',
    note: 'Confidential institutional support.',
  },
  {
    id: 'emergency-medical',
    label: 'University Health Centre (24h)',
    contact: '+256 000 000 004',
    type: 'PHONE',
    note: 'Medical care and documentation.',
  },
  {
    id: 'emergency-womens-association',
    label: 'Women\'s Association helpline',
    contact: '+256 000 000 006',
    type: 'PHONE',
    note: 'Peer support and accompaniment.',
  },
  {
    id: 'emergency-sms-fallback',
    label: 'SMS fallback to Safeguarding Officer',
    contact: '+256 000 000 002',
    type: 'SMS',
    note: 'Used when there is no mobile data. Messages are kept deliberately short.',
  },
];

const EMERGENCY_DISCLAIMER =
  'HERVOICE does not replace emergency services or university security procedures. '
  + 'In immediate danger, contact campus security or the national emergency number directly.';

module.exports = { SUPPORT_RESOURCES, EMERGENCY_CONTACTS, EMERGENCY_DISCLAIMER };
