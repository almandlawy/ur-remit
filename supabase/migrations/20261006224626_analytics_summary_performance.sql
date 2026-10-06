create or replace function public.analytics_summary_core(p_days integer default 30) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare actor jsonb; result jsonb; start_at timestamptz; today timestamptz;
begin
 if p_days not in (0,1,7,30,90) then raise exception 'invalid period'; end if;
 today:=date_trunc('day',now() at time zone 'Asia/Baghdad') at time zone 'Asia/Baghdad';
 start_at:=case when p_days=0 then '-infinity'::timestamptz else today-make_interval(days=>p_days-1) end;
 with scoped as (select * from public.analytics_events where created_at>=start_at and created_at<=now()),
 event_counts as (select event_name,count(*) n from scoped group by event_name),
 starts as (select session_id,min(created_at) as event_at from scoped where event_name='app_open' group by session_id),
 rate_steps as (select e.session_id,min(e.created_at) as event_at from scoped e join starts s on s.session_id=e.session_id where e.event_name='rates_viewed' and e.created_at>=s.event_at group by e.session_id),
 calculation_steps as (select e.session_id,min(e.created_at) as event_at from scoped e join rate_steps r on r.session_id=e.session_id where e.event_name='calculator_used' and e.created_at>=r.event_at group by e.session_id),
 contact_steps as (select e.session_id,min(e.created_at) as event_at from scoped e join calculation_steps c on c.session_id=e.session_id where e.event_name='contact_attempted' and e.created_at>=c.event_at group by e.session_id),
 journey as (select s.session_id,s.event_at opened,r.event_at rates,c.event_at calculated,t.event_at contacted from starts s left join rate_steps r using(session_id) left join calculation_steps c using(session_id) left join contact_steps t using(session_id)),
 daily_data as (
 select (created_at at time zone 'Asia/Baghdad')::date as day,count(*) filter(where event_name='app_open') opens,count(distinct anonymous_id) active,count(*) filter(where event_name='contact_attempted') contacts
 from public.analytics_events where created_at>=today-interval '29 days' and created_at<=now() group by 1
 ), daily as (
 select d::date as day,coalesce(x.opens,0) opens,coalesce(x.active,0) active,coalesce(x.contacts,0) contacts
 from generate_series((today at time zone 'Asia/Baghdad')::date-29,(today at time zone 'Asia/Baghdad')::date,'1 day') d left join daily_data x on x.day=d::date
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

create or replace function public.analytics_summary(p_token_hash text,p_days integer default 30) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare actor jsonb;
begin
 actor:=public.admin_authenticate(p_token_hash);
 if actor is null then raise exception 'unauthorized' using errcode='28000'; end if;
 if actor->>'role'<>'SUPER_ADMIN' and not (coalesce(actor->'permissions','[]'::jsonb) ? 'analytics.read') then raise exception 'forbidden' using errcode='42501'; end if;
 return public.analytics_summary_core(p_days);
end $$;
revoke all on function public.analytics_summary(text,integer) from public,anon,authenticated;
grant execute on function public.analytics_summary(text,integer) to service_role;
