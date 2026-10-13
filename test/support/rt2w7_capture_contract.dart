const rt2w7CaptureSizes = <String, ({int width, int height})>{
  'rt2w7_home_390x905': (width: 390, height: 905),
  'rt2w7_detail_390x843': (width: 390, height: 843),
  'r5ynd_login_390x844': (width: 390, height: 844),
  'rt2w7_wide_home_720x1280': (width: 720, height: 1280),
  'rt2w7_wide_detail_720x1280': (width: 720, height: 1280),
};

const rt2w7CaptureNotes = <String, Object>{
  'designNodes': {'resources': 'rt2w7', 'login': 'R5YnD'},
  'rendering': 'Real Flutter presentation components; pixelRatio=1.',
  'data': 'Offline examples only; no API client or credential store.',
  'fixtureResourceCount': 3,
  'referenceResourceCount': 12,
  'dataDifference':
      'The fixture has 3 resources: 2 running, 1 stopped. Counts are derived from these real fixture rows, rather than the reference totals 12/8/4.',
  'login':
      'R5YnD 390x844 login with advanced settings collapsed; example 192.168.1.10, root@pam, rememberPassword=true. Fresh logins default to rememberPassword=false.',
  'systemBar':
      'Acceptance-only 52px status-bar illustration with 9:41 and Lucide icons. Production uses the native Android system bar.',
};
