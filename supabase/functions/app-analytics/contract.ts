export const EVENTS = new Set(['app_first_open','app_open','session_start','signup_started','signup_completed','login_completed','logout','home_viewed','rates_viewed','calculator_viewed','offices_viewed','calculator_used','currency_selected','whatsapp_clicked','phone_clicked','website_clicked','office_clicked','map_clicked','app_store_clicked','share_app_clicked','contact_attempted','language_changed','error_occurred']);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const metadataRules: Record<string, RegExp> = {
 context: /^(home|rates|calculator|offices|support|more|account|external|privacy|terms)$/,
 source_currency: /^[A-Z]{3}$/, destination_currency: /^[A-Z]{3}$/,
 office_id: uuid, language: /^(ar|en)$/, provider: /^(apple|google|email)$/,
 error_code: /^(auth_failed|offices_unavailable|invalid_link|share_failed)$/,
 channel: /^(whatsapp|phone|website|map)$/
};
export function validateEvent(value: unknown, now = Date.now()) {
 if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('invalid_event');
 const e = value as Record<string, unknown>;
 const allowed = new Set(['id','event_name','anonymous_id','session_id','platform','app_version','build_number','device_type','os_version','locale','metadata','created_at']);
 if (Object.keys(e).some(k => !allowed.has(k))) throw new Error('unknown_field');
 for (const k of ['id','anonymous_id','session_id']) if (typeof e[k] !== 'string' || !uuid.test(e[k] as string)) throw new Error('invalid_id');
 if (!EVENTS.has(e.event_name as string) || e.platform !== 'ios') throw new Error('invalid_event');
 for (const [k,max] of [['app_version',24],['build_number',16],['os_version',24],['locale',24]] as const)
 if (typeof e[k] !== 'string' || !(e[k] as string).length || (e[k] as string).length > max || !/^[A-Za-z0-9_. -]+$/.test(e[k] as string)) throw new Error('invalid_device');
 if (!['iPhone','iPad','other'].includes(e.device_type as string)) throw new Error('invalid_device');
 const at = typeof e.created_at === 'string' ? Date.parse(e.created_at) : NaN;
 if (!Number.isFinite(at) || at < now - 86400000 || at > now + 300000) throw new Error('invalid_time');
 const m = e.metadata ?? {};
 if (!m || typeof m !== 'object' || Array.isArray(m) || Object.entries(m).some(([k,v]) => typeof v !== 'string' || !metadataRules[k]?.test(v))) throw new Error('unsafe_metadata');
 return {...e, metadata:m, created_at:new Date(Math.min(at,now)).toISOString()};
}
export function permitted(actor: {role?:string;permissions?:string[]} | null) {
 return !!actor && (actor.role === 'SUPER_ADMIN' || actor.permissions?.includes('analytics.read') === true);
}
export function period(value: string | null) {
 const n = Number(value ?? '30');
 if (!['0','1','7','30','90'].includes(String(n))) throw new Error('invalid_period');
 return n;
}
