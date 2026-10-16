# Privacy policy revision draft: iPhone app and Meta measurement

**Status: DRAFT for owner review. Not published.** Replaces the section «خصوصية تطبيق UR Global على iPhone» on https://urremit.com/privacy. Revised 2026-10-16 after a code and backend audit; every statement below is tied to source code.

## Audit: live policy vs. shipped app 1.2.1 (+ PR #21)

| Live policy says | Verified behaviour | Evidence |
|---|---|---|
| Analytics stored in **Supabase** | Stored in **Cloudflare D1**, table `visitor_events` | `hosted-site-source/app/api/native/events/route.ts` |
| Records sessions, page views, calculator use, contact taps, OS, device type, language | The app sends only `app_first_open` and `app_open` with a random installation UUID. The server stores the UUID, event name, time and fixed labels (`/app`, `ur-ios`, `ios_app`); the endpoint also accepts `app_remittance_open` and `app_contact`, but the app doesn't send them | `URNativeTelemetry` in `MoreView.swift`; route above |
| Events may be linked to the account | The stored row has **no account ID** | route above |
| Events deleted after 90 days | **No deletion exists** for `visitor_events`. The 90-day pg_cron job exists only for Supabase `analytics_events` on the unmerged `codex/ur-global-1-1-analytics` branch | grep of site source; migration `20261006224010_analytics_retention_scheduler.sql` on that branch |
| Usage data can be turned off in More | Added in PR #21: More → إعدادات الخصوصية | `URPrivacyConsent.swift` |
| No app events shared with ad platforms | Remains true unless the user opts in to Meta measurement | `URMetaMeasurement` |

**Retention needs an owner decision** (see options at the end). The draft below has a placeholder `[مدة الاحتفاظ]`.

## Proposed Arabic text (replacement section)

### خصوصية تطبيق UR Global على iPhone

التطبيق معلوماتي ولا ينفذ معاملات مالية داخله.

**تحليلات أور الداخلية.** عند فتح التطبيق نرسل إلى خوادمنا حدث «أول فتح» وحدث «فتح التطبيق» مع معرّف تثبيت عشوائي يُنشأ على جهازك. لا نحفظ مع هذه الأحداث اسمك أو رقم هاتفك أو معرّف حسابك، ولا نسجل مبالغ الحاسبة أو كلمات المرور أو رموز OTP أو بيانات بنكية أو محتوى الرسائل. الوصول محصور بالإدارة المخولة، ونحتفظ بهذه الأحداث [مدة الاحتفاظ]. يمكنك إيقاف هذه المشاركة في أي وقت من: المزيد ← إعدادات الخصوصية ← «مشاركة بيانات الاستخدام مع أور».

**قياس الإعلانات عبر Meta (اختياري ومتوقف افتراضياً).** لا يعمل Meta SDK ولا يتصل بـ Meta إلا إذا فعّلت «قياس الإعلانات عبر Meta» من إعدادات الخصوصية. عند التفعيل يرسل التطبيق إلى Meta أحداث التثبيت وفتح التطبيق لقياس أداء إعلانات تثبيت التطبيق، مع معرّف عشوائي ينشئه SDK على جهازك وبيانات تقنية عن الجهاز (الطراز، إصدار النظام، اللغة، المنطقة الزمنية، شركة الاتصالات، حجم الشاشة، إصدار التطبيق)، كما تستلم Meta عنوان IP عند الاتصال، وقد يرسل SDK إلى Meta تقارير أعطاله التقنية. لا نجمع معرّف الإعلانات (IDFA)، ولا نطلب إذن التتبع من Apple، ولا نرسل إلى Meta اسمك أو رقم هاتفك أو بريدك أو بيانات حوالاتك أو حسابك. تعالج Meta هذه البيانات وفق سياسة الخصوصية الخاصة بها.

عند إيقاف الخيار يتوقف تسجيل الأحداث وإرسالها فوراً، ونحذف الأحداث التي لم تُرسل بعد من جهازك. قد يتصل SDK بـ Meta لجلب إعداداته فقط حتى تغلق التطبيق وتعيد فتحه، ثم يتوقف تماماً. البيانات التي أُرسلت قبل الإيقاف تحتفظ بها Meta وفق سياستها، ولا نملك حذفها من أنظمة Meta مباشرة؛ يمكنك مراسلتنا عبر info@urremit.com وسنساعدك في توجيه الطلب.

**قياس Apple المجمّع (SKAdNetwork).** إذا ثبّت التطبيق بعد مشاهدة إعلان على منصات Meta، قد ترسل Apple إلى Meta إشعار تثبيت مجمّعاً ومجهول الهوية عبر SKAdNetwork. يتم ذلك من نظام iOS نفسه، ولا يتضمن هويتك أو معرّف جهازك، ولا يتحكم فيه خيار Meta داخل التطبيق.

أول فتح ليس عدداً مطابقاً لتنزيلات App Store.

## Change elsewhere in the policy
- «المشاركة»: add «ومع Meta لقياس الإعلانات عند موافقتك داخل التطبيق».

## English translation (review only)
**UR internal analytics.** When the app opens it sends a "first open" and an "app open" event with a random installation ID to our servers. We store no name, phone or account ID with these events, and no calculator amounts, passwords, OTP codes, bank data or message content. Access is limited to authorised administrators, and we keep these events [retention period]. You can turn this off under More → Privacy settings → "Share usage data with UR".

**Ad measurement via Meta (optional, off by default).** The Meta SDK does not run or contact Meta unless you turn on "Ad measurement via Meta". When on, the app sends install and app-open events to Meta to measure app-install ads. These include a random ID created by the SDK and technical device data (model, OS version, language, time zone, carrier, screen size, app version). Meta also receives your IP address on connection, and the SDK may send Meta reports of its own crashes. We do not collect the advertising identifier (IDFA), do not request Apple's tracking permission, and send Meta no name, phone, email, remittance or account data. Meta processes this data under its own policy.

When you turn it off, logging and sending stop immediately and events not yet sent are deleted from your device. Until you close and reopen the app, the SDK may still contact Meta, but only to fetch its settings; after that it stops completely. Data sent before you turned it off is held by Meta under its policy, and we cannot delete it from Meta's systems directly. You can write to info@urremit.com and we will help direct your request.

**Apple aggregated measurement (SKAdNetwork).** If you install the app after seeing an ad on Meta platforms, Apple may send Meta an aggregated, anonymous install notice via SKAdNetwork. This is done by iOS itself, contains no identity or device ID, and is not controlled by the in-app Meta setting.

## Owner decision: retention of UR app events (`visitor_events`)
| Option | Policy text | Work needed | Consequence |
|---|---|---|---|
| **A. Add automatic deletion (e.g. 90 days)** | «ونحذفها تلقائياً بعد 90 يوماً» | A scheduled delete in the Cloudflare site, a separate repo outside PR #21 | Matches today's promise; older trends are lost after 90 days |
| B. Keep indefinitely | «ونحتفظ بها ما دامت لازمة لتحليل الخدمة» | None | Honest, but weaker; regulators prefer defined periods |
| C. Aggregate after N days | «ونحتفظ بها N يوماً ثم نحولها إلى إحصاءات مجمّعة» | Aggregation job + delete | Keeps trends without per-install rows |

Option A matches what users were told. Note that existing rows already exceed what the live policy promised if any are older than 90 days. I did not query production to check this.
