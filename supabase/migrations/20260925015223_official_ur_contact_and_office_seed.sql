BEGIN;

INSERT INTO countries (iso_code, name_ar, name_en) VALUES
  ('IQ', 'العراق', 'Iraq'),
  ('AE', 'الإمارات العربية المتحدة', 'United Arab Emirates')
ON CONFLICT (iso_code) DO UPDATE SET
  name_ar = EXCLUDED.name_ar,
  name_en = EXCLUDED.name_en,
  is_active = true,
  updated_at = now();

INSERT INTO cities (country_id, name_ar, name_en)
SELECT id, 'بغداد', 'Baghdad' FROM countries WHERE iso_code = 'IQ'
ON CONFLICT (country_id, name_en) DO UPDATE SET name_ar = EXCLUDED.name_ar, is_active = true;

INSERT INTO cities (country_id, name_ar, name_en)
SELECT id, 'دبي', 'Dubai' FROM countries WHERE iso_code = 'AE'
ON CONFLICT (country_id, name_en) DO UPDATE SET name_ar = EXCLUDED.name_ar, is_active = true;

INSERT INTO offices (
  public_code, country_id, city_id, name_ar, name_en, address_ar, address_en,
  phone, whatsapp, services, is_verified, is_active
)
SELECT
  'UR-IQ-BGD-001', countries.id, cities.id,
  'نقطة تمويل أور - بغداد', 'UR Funding Point - Baghdad',
  'حي البلديات، شارع الصحفيين، بغداد',
  'Al-Baladiyat District, Al-Sahafiyin Street, Baghdad',
  '+9647704583730', '+9647704583730',
  '["customer_support", "remittance_information"]'::jsonb, true, true
FROM countries JOIN cities ON cities.country_id = countries.id
WHERE countries.iso_code = 'IQ' AND cities.name_en = 'Baghdad'
ON CONFLICT (public_code) DO UPDATE SET
  address_ar = EXCLUDED.address_ar,
  address_en = EXCLUDED.address_en,
  phone = EXCLUDED.phone,
  whatsapp = EXCLUDED.whatsapp,
  services = EXCLUDED.services,
  is_verified = true,
  is_active = true,
  updated_at = now();

INSERT INTO offices (
  public_code, country_id, city_id, name_ar, name_en, address_ar, address_en,
  phone, whatsapp, services, is_verified, is_active
)
SELECT
  'UR-AE-DXB-001', countries.id, cities.id,
  'المكتب الإداري - دبي', 'Administrative Office - Dubai',
  'داماك ريزيدنس 4، الوحدة 2405، دبي مارينا، دبي',
  'DAMAC Residence 4, Unit 2405, Dubai Marina, Dubai',
  '+971551754032', '+971551754032',
  '["administration", "customer_support"]'::jsonb, true, true
FROM countries JOIN cities ON cities.country_id = countries.id
WHERE countries.iso_code = 'AE' AND cities.name_en = 'Dubai'
ON CONFLICT (public_code) DO UPDATE SET
  address_ar = EXCLUDED.address_ar,
  address_en = EXCLUDED.address_en,
  phone = EXCLUDED.phone,
  whatsapp = EXCLUDED.whatsapp,
  services = EXCLUDED.services,
  is_verified = true,
  is_active = true,
  updated_at = now();

INSERT INTO app_config (key, value, is_public) VALUES
  ('support', '{"email":"info@urremit.com","iraqWhatsApp":["+9647704583730","+9647902300984"],"uaeWhatsApp":"+971551754032"}'::jsonb, true),
  ('officialChannels', '{"website":"https://www.urremit.com","instagram":"https://www.instagram.com/urremit.official"}'::jsonb, true),
  ('featureFlags', '{"priceAlerts":false,"officeQR":true,"map":true,"tracking":true,"calculator":true,"socialLogin":true}'::jsonb, true),
  ('maintenanceMode', 'false'::jsonb, true)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, is_public = EXCLUDED.is_public, updated_at = now();

COMMIT;
;
