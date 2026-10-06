-- Daily retention without any client credential or server secret in a cron command.
create extension if not exists pg_cron with schema pg_catalog;
select cron.schedule('ur-product-analytics-retention','17 2 * * *','select public.analytics_prune()');
