BEGIN;

-- Seeds new UAE bank/deposit and money-transfer-network routes requested by the product team.
-- These are represented as "fee-only" routes (buy/sell NULL, fee_fixed set), the same pattern
-- already used by the existing "الحوالات البنكية (سويفت)" route — no schema change required.
--
-- SAFETY: every seeded `rates` row is inserted with `is_active = false` and a placeholder
-- `fee_fixed = 0`. The routes will NOT be visible to end users (store.listRates filters on
-- rates.is_active) until an admin enters a real fee/price and activates it from the admin
-- panel. This migration must be reviewed and deployed manually — it is not applied
-- automatically by this session.

WITH route_data(name_ar,name_en) AS (VALUES
  ('إيداع بنك أبوظبي الإسلامي (ADIB)','Deposit - Abu Dhabi Islamic Bank (ADIB)'),
  ('إيداع بنك ويو (Wio Bank)','Deposit - Wio Bank'),
  ('إيداع بنك أبوظبي الأول (FAB)','Deposit - First Abu Dhabi Bank (FAB)'),
  ('إيداع بنك المشرق (Mashreq Bank)','Deposit - Mashreq Bank'),
  ('موني جرام','MoneyGram'),
  ('ويسترن يونيون','Western Union'),
  ('فودافون كاش','Vodafone Cash')
), origin AS (
  SELECT c.id country_id, ci.id city_id FROM countries c JOIN cities ci ON ci.country_id=c.id
  WHERE c.iso_code='IQ' AND ci.name_en='Baghdad'
), dest AS (
  SELECT id FROM countries WHERE iso_code='AE'
)
INSERT INTO rate_routes(origin_country_id,origin_city_id,destination_country_id,destination_city_id,source_currency,destination_currency,name_ar,name_en)
SELECT o.country_id, o.city_id, d.id, NULL, 'USD','USD', r.name_ar, r.name_en
FROM route_data r CROSS JOIN origin o CROSS JOIN dest d
WHERE NOT EXISTS (SELECT 1 FROM rate_routes x WHERE x.name_en=r.name_en AND x.source_currency='USD' AND x.destination_currency='USD');

INSERT INTO rates(route_id,buy,sell,fee_fixed,valid_from,source_timestamp,version,is_active)
SELECT rr.id, NULL, NULL, 0, now(), now(), 1, false
FROM rate_routes rr
WHERE rr.name_en IN (
  'Deposit - Abu Dhabi Islamic Bank (ADIB)','Deposit - Wio Bank','Deposit - First Abu Dhabi Bank (FAB)',
  'Deposit - Mashreq Bank','MoneyGram','Western Union','Vodafone Cash'
)
AND NOT EXISTS (SELECT 1 FROM rates r WHERE r.route_id=rr.id AND r.version=1);

COMMIT;
