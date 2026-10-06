create function public.analytics_summary_core(p_days integer default 30) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare actor jsonb; result jsonb; start_at timestamptz; today timestamptz;
begin
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
revoke all on function public.analytics_summary_core(integer) from public,anon,authenticated;
grant execute on function public.analytics_summary_core(integer) to service_role;
create table public.analytics_service_credentials (
 key_hash text primary key check (length(key_hash)=64),
 label text not null, created_at timestamptz not null default now(),revoked_at timestamptz
);
alter table public.analytics_service_credentials enable row level security;
revoke all on public.analytics_service_credentials from public,anon,authenticated;
grant all on public.analytics_service_credentials to service_role;
create function public.analytics_site_summary(p_key_hash text,p_days integer default 30) returns jsonb
language plpgsql security invoker set search_path='' as $$
begin
 if not exists(select 1 from public.analytics_service_credentials where key_hash=p_key_hash and revoked_at is null) then
 raise exception 'unauthorized' using errcode='28000'; end if;
 return public.analytics_summary_core(p_days);
end $$;
revoke all on function public.analytics_site_summary(text,integer) from public,anon,authenticated;
grant execute on function public.analytics_site_summary(text,integer) to service_role;
-- A completion can only count once per real account; auth.users is still the source of registration totals.
create unique index analytics_signup_completed_once_idx on public.analytics_events(user_id) where event_name='signup_completed' and user_id is not null;
