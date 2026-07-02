/// A compact country list for the profile selector: ISO code, name, flag.
/// Bundled in-app (no dependency, works offline). Easily extended.
class Country {
  const Country(this.code, this.name, this.flag);
  final String code;
  final String name;
  final String flag;
}

const countries = <Country>[
  Country('IN', 'India', '🇮🇳'),
  Country('US', 'United States', '🇺🇸'),
  Country('GB', 'United Kingdom', '🇬🇧'),
  Country('CA', 'Canada', '🇨🇦'),
  Country('AU', 'Australia', '🇦🇺'),
  Country('DE', 'Germany', '🇩🇪'),
  Country('FR', 'France', '🇫🇷'),
  Country('IT', 'Italy', '🇮🇹'),
  Country('ES', 'Spain', '🇪🇸'),
  Country('PT', 'Portugal', '🇵🇹'),
  Country('NL', 'Netherlands', '🇳🇱'),
  Country('SE', 'Sweden', '🇸🇪'),
  Country('NO', 'Norway', '🇳🇴'),
  Country('PL', 'Poland', '🇵🇱'),
  Country('RU', 'Russia', '🇷🇺'),
  Country('UA', 'Ukraine', '🇺🇦'),
  Country('TR', 'Türkiye', '🇹🇷'),
  Country('BR', 'Brazil', '🇧🇷'),
  Country('MX', 'Mexico', '🇲🇽'),
  Country('AR', 'Argentina', '🇦🇷'),
  Country('CL', 'Chile', '🇨🇱'),
  Country('CO', 'Colombia', '🇨🇴'),
  Country('CN', 'China', '🇨🇳'),
  Country('JP', 'Japan', '🇯🇵'),
  Country('KR', 'South Korea', '🇰🇷'),
  Country('ID', 'Indonesia', '🇮🇩'),
  Country('PH', 'Philippines', '🇵🇭'),
  Country('VN', 'Vietnam', '🇻🇳'),
  Country('TH', 'Thailand', '🇹🇭'),
  Country('MY', 'Malaysia', '🇲🇾'),
  Country('SG', 'Singapore', '🇸🇬'),
  Country('PK', 'Pakistan', '🇵🇰'),
  Country('BD', 'Bangladesh', '🇧🇩'),
  Country('LK', 'Sri Lanka', '🇱🇰'),
  Country('NP', 'Nepal', '🇳🇵'),
  Country('AE', 'UAE', '🇦🇪'),
  Country('SA', 'Saudi Arabia', '🇸🇦'),
  Country('IL', 'Israel', '🇮🇱'),
  Country('EG', 'Egypt', '🇪🇬'),
  Country('ZA', 'South Africa', '🇿🇦'),
  Country('NG', 'Nigeria', '🇳🇬'),
  Country('KE', 'Kenya', '🇰🇪'),
  Country('NZ', 'New Zealand', '🇳🇿'),
  Country('IE', 'Ireland', '🇮🇪'),
  Country('CH', 'Switzerland', '🇨🇭'),
  Country('AT', 'Austria', '🇦🇹'),
  Country('BE', 'Belgium', '🇧🇪'),
  Country('GR', 'Greece', '🇬🇷'),
  Country('XX', 'Elsewhere', '🏳️'),
];

Country? countryByCode(String? code) {
  if (code == null) return null;
  for (final c in countries) {
    if (c.code == code) return c;
  }
  return null;
}
