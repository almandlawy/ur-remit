-- Product analytics only. No changes to rates, timestamps, caches or public rate APIs.
create table public.analytics_events (
 id uuid primary key,
 event_name text not null check (event_name in ('app_first_open','app_open','session_start','signup_started','signup_completed','login_completed','logout','home_viewed','rates_viewed','calculator_viewed','offices_viewed','calculator_used','currency_selected','whatsapp_clicked','phone_clicked','website_clicked','office_clicked','map_clicked','app_store_clicked','share_app_clicked','contact_attempted','language_changed','error_occurred')),
 user_id uuid references auth.users(id) on delete set null,
 anonymous_id uuid not null, session_id uuid not null,
 platform text not null check (platform = 'ios'),
 app_version text not null check (length(app_version)<=24),
 build_number text not null check (length(build_number)<=16),
 device_type text not null check (device_type in ('iPhone','iPad','other')),
 os_version text not null check (length(os_version)<=24),
 locale text not null check (length(locale)<=24),
 metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata)='object' and octet_length(metadata::text)<=1024),
 created_at timestamptz not null default now(), received_at timestamptz not null default now()
);
create index analytics_events_name_time_idx on public.analytics_events(event_name,created_at desc);
create index analytics_events_created_at_idx on public.analytics_events(created_at desc);
create index analytics_events_user_id_idx on public.analytics_events(user_id) where user_id is not null;
create index analytics_events_anonymous_id_idx on public.analytics_events(anonymous_id,created_at desc);
create index analytics_events_session_idx on public.analytics_events(session_id,created_at);
create unique index analytics_first_open_once_idx on public.analytics_events(anonymous_id) where event_name='app_first_open';
create unique index analytics_session_once_idx on public.analytics_events(session_id) where event_name='session_start';
alter table public.analytics_events enable row level security;
revoke all on public.analytics_events from public,anon,authenticated;
grant select,insert,delete on public.analytics_events to service_role;
-- No client RLS policies: writes pass through the validating Edge Function only.
create table public.analytics_ingest_limits (bucket text primary key,window_start timestamptz not null,hits integer not null);
alter table public.analytics_ingest_limits enable row level security;
revoke all on public.analytics_ingest_limits from public,anon,authenticated;
grant all on public.analytics_ingest_limits to service_role;
create table public.app_store_download_reports (
 report_date date not null,app_id text not null check(app_id='6815895731'),
 metric text not null check(metric in ('first_time_downloads','redownloads','total_downloads')),
 downloads bigint not null check(downloads>=0),source text not null check(source='app_store_connect'),
 imported_at timestamptz not null default now(), primary key(report_date,app_id,metric)
);
alter table public.app_store_download_reports enable row level security;
revoke all on public.app_store_download_reports from public,anon,authenticated;
grant all on public.app_store_download_reports to service_role;
insert into public.permissions(name) values('analytics.read') on conflict(name) do nothing;
insert into public.role_permissions(role_id,permission_id)
 select r.id,p.id from public.roles r cross join public.permissions p where r.name='SUPER_ADMIN' and p.name='analytics.read' on conflict do nothing;

create function public.analytics_take_quota(p_bucket text,p_limit integer) returns boolean
language plpgsql security invoker set search_path='' as $$
declare n integer;
begin
 if length(p_bucket)>128 or p_limit not between 1 and 1000 then return false; end if;
 insert into public.analytics_ingest_limits as q(bucket,window_start,hits)
 values(p_bucket,date_trunc('hour',now()),1)
 on conflict(bucket) do update set window_start=excluded.window_start,
 hits=case when q.window_start=excluded.window_start then q.hits+1 else 1 end returning hits into n;
 return n<=p_limit;
end $$;
revoke all on function public.analytics_take_quota(text,integer) from public,anon,authenticated;
grant execute on function public.analytics_take_quota(text,integer) to service_role;

create function public.analytics_summary(p_token_hash text,p_days integer default 30) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare actor jsonb; result jsonb; start_at timestamptz; today timestamptz;
begin
 actor:=public.admin_authenticate(p_token_hash);
 if actor is null then raise exception 'unauthorized' using errcode='28000'; end if;
 if actor->>'role'<>'SUPER_ADMIN' and not (coalesce(actor->'permissions','[]'::jsonb) ? 'analytics.read') then
 raise exception 'forbidden' using errcode='42501'; end if;
 if p_days not in (0,1,7,30,90) then raise exception 'invalid period'; end if;
 today:=date_trunc('day',now() at time zone 'Asia/Baghdad') at time zone 'Asia/Baghdad';
 start_at:=case when p_days=0 then '-infinity'::timestamptz else today-make_interval(days=>p_days-1) end;
 with scoped as (select * from public.analytics_events where created_at>=start_at and created_at<=now()),
 event_counts as (select event_name,count(*) n from scoped group by event_name),
 starts as (select session_id,min(created_at) as event_at from scoped where event_name='app_open' group by session_id),
 journey as (
 select s.session_id,s.event_at opened,r.event_at rates,c.event_at calculated,t.event_at contacted from starts s
 left join lateral (select min(created_at) as event_at from scoped where session_id=s.session_id and event_name='rates_viewed' and created_at>=s.event_at) r on true
 left join lateral (select min(created_at) as event_at from scoped where session_id=s.session_id and event_name='calculator_used' and created_at>=r.event_at) c on true
 left join lateral (select min(created_at) as event_at from scoped where session_id=s.session_id and event_name='contact_attempted' and created_at>=c.event_at) t on true
 ),daily as (
 select d::date as day,
 (select count(*) from public.analytics_events e where (e.created_at at time zone 'Asia/Baghdad')::date=d::date and e.event_name='app_open') opens,
 (select count(distinct anonymous_id) from public.analytics_events e where (e.created_at at time zone 'Asia/Baghdad')::date=d::date) active,
 (select count(*) from public.analytics_events e where (e.created_at at time zone 'Asia/Baghdad')::date=d::date and e.event_name='contact_attempted') contacts
 from generate_series((today at time zone 'Asia/Baghdad')::date-29,(today at time zone 'Asia/Baghdad')::date,'1 day') d
 )
 select jsonb_build_object(
 'period_days',p_days,'timezone','Asia/Baghdad','retention_days',90,'generated_at',now(),
 'registered', (select jsonb_build_object('total',count(*),'today',count(*) filter(where created_at>=today),'last7',count(*) filter(where created_at>=today-interval '6 days'),'last30',count(*) filter(where created_at>=today-interval '29 days'),'confirmed',count(*) filter(where email_confirmed_at is not null or phone_confirmed_at is not null),'incomplete',count(*) filter(where email_confirmed_at is null and phone_confirmed_at is null)) from auth.users where not coalesce(is_anonymous,false) and deleted_at is null),
 'active', (select jsonb_build_object('today',count(distinct anonymous_id) filter(where created_at>=today),'last7',count(distinct anonymous_id) filter(where created_at>=today-interval '6 days'),'last30',count(distinct anonymous_id) filter(where created_at>=today-interval '29 days'),'selected',count(distinct anonymous_id) filter(where created_at>=start_at)) from public.analytics_events where created_at<=now()),
 'events',coalesce((select jsonb_object_agg(event_name,n) from event_counts),'{}'::jsonb),
 'top_pages',coalesce((select jsonb_agg(x) from (select event_name,count(*) views from scoped where event_name in ('home_viewed','rates_viewed','calculator_viewed','offices_viewed') group by event_name order by views desc) x),'[]'::jsonb),
 'daily', (select jsonb_agg(daily order by day) from daily),
 'funnel',(select jsonb_build_object('opened',count(*),'rates',count(rates),'calculated',count(calculated),'contacted',count(contacted)) from journey),
 'downloads',jsonb_build_object('status',case when exists(select 1 from public.app_store_download_reports) then 'connected' else 'not_connected' end,'first_time_downloads',(select sum(downloads) from public.app_store_download_reports where metric='first_time_downloads' and report_date>=(start_at at time zone 'Asia/Baghdad')::date),'source','App Store Connect','app_id','6815895731')
 ) into result;
 return result;
end $$;
revoke all on function public.analytics_summary(text,integer) from public,anon,authenticated;
grant execute on function public.analytics_summary(text,integer) to service_role;

create function public.analytics_prune() returns void language sql security invoker set search_path='' as $$
 delete from public.analytics_events where received_at<now()-interval '90 days';
 delete from public.analytics_ingest_limits where window_start<now()-interval '2 days';
$$;
revoke all on function public.analytics_prune() from public,anon,authenticated;
grant execute on function public.analytics_prune() to service_role;
-- Schedule only when pg_cron is already available; otherwise run from a server scheduler.
do $$ begin
 if exists(select 1 from pg_extension where extname='pg_cron') then
 perform cron.schedule('ur-product-analytics-retention','17 2 * * *','select public.analytics_prune()');
 end if;
end $$;
