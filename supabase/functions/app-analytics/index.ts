import { validateEvent, permitted, period } from './contract.ts';
const projectURL = Deno.env.get('SUPABASE_URL')!;
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers = { 'content-type':'application/json', 'cache-control':'no-store', 'access-control-allow-headers':'authorization,apikey,content-type', 'access-control-allow-methods':'GET,POST,OPTIONS' };
function reply(data: unknown,status=200) { return new Response(JSON.stringify(data),{status,headers}); }
async function hash(value:string) {
 const bytes=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(value));
 return Array.from(new Uint8Array(bytes),b=>b.toString(16).padStart(2,'0')).join('');
}
async function rest(path:string,body?:unknown,method='POST') {
 const r=await fetch(`${projectURL}/rest/v1/${path}`,{method,headers:{apikey:serviceKey,authorization:`Bearer ${serviceKey}`,'content-type':'application/json',Prefer:'resolution=ignore-duplicates,return=minimal'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(8000)});
 if (!r.ok) throw new Error(`database_${r.status}`);
 const text=await r.text();return text?JSON.parse(text):null;
}
async function validPublicKey(key:string|null) {
 if (!key || key.length>2048) return false;
 if (key===Deno.env.get('SUPABASE_ANON_KEY')) return true;
 let keys:Record<string,string>={};try{keys=JSON.parse(Deno.env.get('SUPABASE_PUBLISHABLE_KEYS')??'{}');}catch{ /* legacy environment */ }
 if (Object.values(keys).includes(key)) return true;
 // Validate a modern publishable key at the gateway using only a restricted read.
 if (!key.startsWith('sb_publishable_')) return false;
 const r=await fetch(`${projectURL}/auth/v1/settings`,{headers:{apikey:key},signal:AbortSignal.timeout(5000)});
 return r.ok;
}
Deno.serve(async request=>{
 if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
 try {
 const url=new URL(request.url);const route=url.pathname.split('/').filter(Boolean).at(-1);
 if(request.method==='GET' && route==='site-summary') {
 const key=request.headers.get('x-ur-analytics-key')??'';
 if(!/^[A-Za-z0-9_-]{64}$/.test(key))return reply({error:'unauthorized'},401);
 let days;try{days=period(url.searchParams.get('days'));}catch{return reply({error:'invalid_period'},400);}
 const keyHash=await hash(key);
 const valid=await rest(`analytics_service_credentials?key_hash=eq.${keyHash}&revoked_at=is.null&select=key_hash`,undefined,'GET');
 if(!valid?.length)return reply({error:'unauthorized'},401);
 return reply({data:await rest('rpc/analytics_site_summary',{p_key_hash:keyHash,p_days:days})});
 }
 if(request.method==='GET' && (route==='summary'||route==='access')) {
 const token=request.headers.get('authorization')?.replace(/^Bearer /,'')??'';
 if(!/^[A-Za-z0-9_-]{32,256}$/.test(token))return reply({error:'unauthorized'},401);
 const tokenHash=await hash(token);
 const actor=await rest('rpc/admin_authenticate',{p_token_hash:tokenHash});
 if(!actor)return reply({error:'unauthorized'},401);
 if(!permitted(actor))return reply({error:'forbidden'},403);
 if(route==='access')return reply({data:{allowed:true}});
 let days;try{days=period(url.searchParams.get('days'));}catch{return reply({error:'invalid_period'},400);}
 return reply({data:await rest('rpc/analytics_summary',{p_token_hash:tokenHash,p_days:days})});
 }
 if(request.method!=='POST'||route!=='events')return reply({error:'not_found'},404);
 if(!await validPublicKey(request.headers.get('apikey')))return reply({error:'unauthorized'},401);
 if(Number(request.headers.get('content-length')??0)>32768)return reply({error:'too_large'},413);
 const raw=await request.text();if(raw.length>32768)return reply({error:'too_large'},413);
 let input;try{input=JSON.parse(raw);}catch{return reply({error:'invalid_json'},400);}
 if(!Array.isArray(input.events)||input.events.length<1||input.events.length>20)return reply({error:'invalid_batch'},400);
 let events;try{events=input.events.map((e:unknown)=>validateEvent(e));}catch{return reply({error:'invalid_event'},400);}
 if(new Set(events.map((e:Record<string,unknown>)=>e.anonymous_id)).size!==1)return reply({error:'invalid_batch'},400);
 const ip=request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()??'unknown';
 // Salted short-lived abuse bucket, not an analytics field; never store raw IP addresses.
 const bucket=await hash(`${serviceKey}:${ip}`);
 if(!await rest('rpc/analytics_take_quota',{p_bucket:`ip:${bucket}`,p_limit:240})||!await rest('rpc/analytics_take_quota',{p_bucket:`install:${events[0].anonymous_id}`,p_limit:120}))return reply({error:'rate_limited'},429);
 let userID:string|null=null;
 const bearer=request.headers.get('authorization');
 if(bearer && bearer.startsWith('Bearer ') && bearer.length<4096) {
 const r=await fetch(`${projectURL}/auth/v1/user`,{headers:{apikey:serviceKey,authorization:bearer},signal:AbortSignal.timeout(5000)});
 if(r.ok)userID=(await r.json()).id;
 }
 // Never trust client supplied user IDs. Authentication-completion events require a real user.
 if(events.some((e:Record<string,unknown>)=>['signup_completed','login_completed','logout'].includes(e.event_name as string))&&!userID)return reply({error:'authentication_required'},401);
 await rest('analytics_events',events.map((e:Record<string,unknown>)=>({...e,user_id:userID})));
 return reply({data:{accepted:events.length}},202);
 }catch{return reply({error:'service_unavailable'},503);}
});
