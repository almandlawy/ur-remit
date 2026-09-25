BEGIN;

ALTER TABLE rates DROP CONSTRAINT rates_check;
ALTER TABLE rates ADD CONSTRAINT rates_has_value
  CHECK (buy IS NOT NULL OR sell IS NOT NULL OR fee_fixed IS NOT NULL OR fee_percent IS NOT NULL);

INSERT INTO countries (iso_code, name_ar, name_en) VALUES
  ('SA','السعودية','Saudi Arabia'),('KW','الكويت','Kuwait'),('QA','قطر','Qatar'),
  ('OM','سلطنة عمان','Oman'),('BH','البحرين','Bahrain'),('JO','الأردن','Jordan'),
  ('LB','لبنان','Lebanon'),('EG','مصر','Egypt'),('IR','إيران','Iran'),
  ('TR','تركيا','Türkiye'),('CN','الصين','China'),('GB','بريطانيا','United Kingdom'),
  ('DE','ألمانيا','Germany'),('FR','فرنسا','France'),('IT','إيطاليا','Italy'),
  ('CA','كندا','Canada'),('HR','كرواتيا','Croatia')
ON CONFLICT (iso_code) DO UPDATE SET name_ar=EXCLUDED.name_ar,name_en=EXCLUDED.name_en,is_active=true,updated_at=now();

WITH city_data(iso,name_ar,name_en) AS (VALUES
  ('IQ','أربيل','Erbil'),('IQ','السليمانية','Sulaymaniyah'),('IQ','دهوك','Duhok'),
  ('IQ','الموصل','Mosul'),('IQ','زاخو','Zakho'),('IQ','كركوك','Kirkuk'),
  ('IQ','تكريت','Tikrit'),('IQ','كربلاء','Karbala'),('IQ','النجف','Najaf'),
  ('IQ','البصرة','Basra'),('IQ','الناصرية','Nasiriyah'),('IQ','العمارة','Amarah'),
  ('IQ','الكوت','Kut'),('IQ','الحلة','Hillah'),('IQ','الديوانية','Diwaniyah'),
  ('IR','طهران','Tehran'),('IR','مشهد','Mashhad'),('IR','قم','Qom')
)
INSERT INTO cities(country_id,name_ar,name_en)
SELECT c.id,d.name_ar,d.name_en FROM city_data d JOIN countries c ON c.iso_code=d.iso
ON CONFLICT(country_id,name_en) DO UPDATE SET name_ar=EXCLUDED.name_ar,is_active=true;

WITH route_data(dest_iso,dest_city,src,dst,name_ar,name_en,buy,sell,fee,stamp) AS (VALUES
  ('IQ','Baghdad','USD','IQD','الدولار مقابل الدينار العراقي','USD to Iraqi Dinar',1568::numeric,1573::numeric,NULL::numeric,'2026-09-24T00:00:00+03:00'::timestamptz),
  ('AE','Dubai','USD','USD','دبي - تسليم بنفس اليوم','Dubai - Same Day',NULL,NULL,12,'2026-09-24T00:00:00+03:00'),
  ('AE','Dubai','USD','USD','الحوالات البنكية (سويفت)','Bank Transfers (SWIFT)',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('SA',NULL,'USD','USD','السعودية','Saudi Arabia',NULL,NULL,17,'2026-09-24T00:00:00+03:00'),
  ('QA',NULL,'USD','USD','قطر','Qatar',NULL,NULL,17,'2026-09-24T00:00:00+03:00'),
  ('OM',NULL,'USD','USD','سلطنة عمان','Oman',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('JO',NULL,'USD','USD','الأردن','Jordan',NULL,NULL,50,'2026-09-24T00:00:00+03:00'),
  ('LB',NULL,'USD','USD','لبنان','Lebanon',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('EG',NULL,'USD','USD','مصر','Egypt',NULL,NULL,65,'2026-09-24T00:00:00+03:00'),
  ('KW',NULL,'USD','USD','الكويت','Kuwait',NULL,NULL,100,'2026-09-24T00:00:00+03:00'),
  ('BH',NULL,'USD','USD','البحرين','Bahrain',NULL,NULL,50,'2026-09-24T00:00:00+03:00'),
  ('IR','Tehran','USD','USD','طهران','Tehran',NULL,NULL,20,'2026-09-24T00:00:00+03:00'),
  ('IR','Mashhad','USD','USD','مشهد','Mashhad',NULL,NULL,18,'2026-09-24T00:00:00+03:00'),
  ('IR','Qom','USD','USD','قم','Qom',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('IR',NULL,'IQD','IRR','تومان (بالحساب)','Toman (To Account)',NULL,23200000,NULL,'2026-09-24T00:00:00+03:00'),
  ('TR',NULL,'USD','USD','تركيا','Türkiye',NULL,NULL,10,'2026-09-24T00:00:00+03:00'),
  ('CN',NULL,'USD','CNY','الصين (يوان)','China (Yuan)',NULL,7,NULL,'2026-09-23T00:00:00+03:00'),
  ('DE',NULL,'USD','USD','ألمانيا','Germany',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),
  ('FR',NULL,'USD','USD','فرنسا','France',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),
  ('IT',NULL,'USD','USD','إيطاليا','Italy',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),
  ('GB',NULL,'USD','USD','بريطانيا','United Kingdom',NULL,NULL,-200,'2026-09-23T00:00:00+03:00'),
  ('CA',NULL,'USD','USD','كندا','Canada',NULL,NULL,-200,'2026-09-23T00:00:00+03:00'),
  ('HR',NULL,'USD','USD','كرواتيا','Croatia',NULL,NULL,-170,'2026-09-23T00:00:00+03:00'),
  ('IQ','Erbil','USD','USD','أربيل','Erbil',NULL,NULL,-15,'2026-09-24T00:00:00+03:00'),
  ('IQ','Sulaymaniyah','USD','USD','السليمانية','Sulaymaniyah',NULL,NULL,-15,'2026-09-24T00:00:00+03:00'),
  ('IQ','Duhok','USD','USD','دهوك','Duhok',NULL,NULL,-10,'2026-09-24T00:00:00+03:00'),
  ('IQ','Mosul','USD','USD','الموصل','Mosul',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Zakho','USD','USD','زاخو','Zakho',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),
  ('IQ','Kirkuk','USD','USD','كركوك','Kirkuk',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),
  ('IQ','Tikrit','USD','USD','تكريت','Tikrit',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),
  ('IQ','Karbala','USD','USD','كربلاء','Karbala',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Najaf','USD','USD','النجف','Najaf',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Basra','USD','USD','البصرة','Basra',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Nasiriyah','USD','USD','الناصرية','Nasiriyah',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Amarah','USD','USD','العمارة','Amarah',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Kut','USD','USD','الكوت','Kut',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Hillah','USD','USD','الحلة','Hillah',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Diwaniyah','USD','USD','الديوانية','Diwaniyah',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('IQ','Baghdad','USD','USD','بغداد','Baghdad',NULL,NULL,5,'2026-09-24T00:00:00+03:00')
), origin AS (SELECT c.id country_id,ci.id city_id FROM countries c JOIN cities ci ON ci.country_id=c.id WHERE c.iso_code='IQ' AND ci.name_en='Baghdad')
INSERT INTO rate_routes(origin_country_id,origin_city_id,destination_country_id,destination_city_id,source_currency,destination_currency,name_ar,name_en)
SELECT o.country_id,o.city_id,dc.id,dci.id,r.src,r.dst,r.name_ar,r.name_en
FROM route_data r CROSS JOIN origin o JOIN countries dc ON dc.iso_code=r.dest_iso
LEFT JOIN cities dci ON dci.country_id=dc.id AND dci.name_en=r.dest_city
WHERE NOT EXISTS (SELECT 1 FROM rate_routes x WHERE x.name_en=r.name_en AND x.source_currency=r.src AND x.destination_currency=r.dst);

WITH price_data(name_en,src,dst,buy,sell,fee,stamp) AS (VALUES
  ('USD to Iraqi Dinar','USD','IQD',1568::numeric,1573::numeric,NULL::numeric,'2026-09-24T00:00:00+03:00'::timestamptz),
  ('Dubai - Same Day','USD','USD',NULL,NULL,12,'2026-09-24T00:00:00+03:00'),('Bank Transfers (SWIFT)','USD','USD',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('Saudi Arabia','USD','USD',NULL,NULL,17,'2026-09-24T00:00:00+03:00'),('Qatar','USD','USD',NULL,NULL,17,'2026-09-24T00:00:00+03:00'),('Oman','USD','USD',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('Jordan','USD','USD',NULL,NULL,50,'2026-09-24T00:00:00+03:00'),('Lebanon','USD','USD',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),('Egypt','USD','USD',NULL,NULL,65,'2026-09-24T00:00:00+03:00'),
  ('Kuwait','USD','USD',NULL,NULL,100,'2026-09-24T00:00:00+03:00'),('Bahrain','USD','USD',NULL,NULL,50,'2026-09-24T00:00:00+03:00'),
  ('Tehran','USD','USD',NULL,NULL,20,'2026-09-24T00:00:00+03:00'),('Mashhad','USD','USD',NULL,NULL,18,'2026-09-24T00:00:00+03:00'),('Qom','USD','USD',NULL,NULL,15,'2026-09-24T00:00:00+03:00'),
  ('Toman (To Account)','IQD','IRR',NULL,23200000,NULL,'2026-09-24T00:00:00+03:00'),('Türkiye','USD','USD',NULL,NULL,10,'2026-09-24T00:00:00+03:00'),('China (Yuan)','USD','CNY',NULL,7,NULL,'2026-09-23T00:00:00+03:00'),
  ('Germany','USD','USD',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),('France','USD','USD',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),('Italy','USD','USD',NULL,NULL,-150,'2026-09-23T00:00:00+03:00'),
  ('United Kingdom','USD','USD',NULL,NULL,-200,'2026-09-23T00:00:00+03:00'),('Canada','USD','USD',NULL,NULL,-200,'2026-09-23T00:00:00+03:00'),('Croatia','USD','USD',NULL,NULL,-170,'2026-09-23T00:00:00+03:00'),
  ('Erbil','USD','USD',NULL,NULL,-15,'2026-09-24T00:00:00+03:00'),('Sulaymaniyah','USD','USD',NULL,NULL,-15,'2026-09-24T00:00:00+03:00'),('Duhok','USD','USD',NULL,NULL,-10,'2026-09-24T00:00:00+03:00'),
  ('Mosul','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Zakho','USD','USD',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),('Kirkuk','USD','USD',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),
  ('Tikrit','USD','USD',NULL,NULL,7,'2026-09-24T00:00:00+03:00'),('Karbala','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Najaf','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('Basra','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Nasiriyah','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Amarah','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),
  ('Kut','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Hillah','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Diwaniyah','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00'),('Baghdad','USD','USD',NULL,NULL,5,'2026-09-24T00:00:00+03:00')
)
INSERT INTO rates(route_id,buy,sell,fee_fixed,valid_from,source_timestamp,version)
SELECT rr.id,p.buy,p.sell,p.fee,p.stamp,p.stamp,1 FROM price_data p JOIN rate_routes rr ON rr.name_en=p.name_en AND rr.source_currency=p.src AND rr.destination_currency=p.dst
WHERE NOT EXISTS (SELECT 1 FROM rates r WHERE r.route_id=rr.id AND r.version=1);

COMMIT;
