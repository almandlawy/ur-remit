# Privacy policy revision draft: iPhone app and Meta measurement

**Status: DRAFT for owner review. Not published.** Replaces the section «خصوصية تطبيق UR Global على iPhone» on https://urremit.com/privacy. Revised 2026-10-17. Every statement is tied to code; the conditions for publishing are listed at the end.

## Audit: live policy vs. implementation

| Live policy says | Verified behaviour | Evidence |
|---|---|---|
| Analytics stored in Supabase | Stored in **Cloudflare D1**, `visitor_events` | `hosted-site-source/app/api/native/events/route.ts` |
| Sessions, page views, calculator use, contact taps, OS, device, language | App sends only `app_first_open` and `app_open` with a random installation UUID | `URNativeTelemetry` in `MoreView.swift` |
| May be linked to the account | Stored row has **no account ID** | route above |
| Deleted after 90 days | **Not yet**: a 90-day job is prepared (dry-run default) on the website branch `privacy/visitor-events-retention-90d`, not deployed | `lib/visitor-retention.ts` |
| Turn off in More | Added: More → إعدادات الخصوصية | `URPrivacyConsent.swift` |
| No app events shared with ad platforms | **Still true for release builds**: Meta events are disabled by default (`META_APP_EVENTS_ENABLED = NO`) | `ios/Config/Meta.xcconfig` |

## Version 1: publish with release builds where Meta events stay disabled (recommended now)

### خصوصية تطبيق UR Global على iPhone

التطبيق معلوماتي ولا ينفذ معاملات مالية داخله.

**تحليلات أور الداخلية.** عند فتح التطبيق نرسل إلى خوادمنا حدث «أول فتح» وحدث «فتح التطبيق» مع معرّف تثبيت عشوائي يُنشأ على جهازك. لا نحفظ مع هذه الأحداث اسمك أو رقم هاتفك أو معرّف حسابك، ولا نسجل مبالغ الحاسبة أو كلمات المرور أو رموز OTP أو بيانات بنكية أو محتوى الرسائل. الوصول محصور بالإدارة المخولة، ونحذف هذه الأحداث تلقائياً بعد 90 يوماً. يمكنك إيقاف هذه المشاركة في أي وقت من: المزيد ← إعدادات الخصوصية ← «مشاركة بيانات الاستخدام مع أور».

**الإعلانات.** لا نستخدم معرّف الإعلانات (IDFA) ولا نشارك أحداث التطبيق مع منصات الإعلانات. إذا ثبّت التطبيق بعد مشاهدة إعلان لنا، قد ترسل Apple إلى المنصة الإعلانية إشعار تثبيت مجمّعاً ومجهول الهوية عبر تقنيات Apple لقياس الإعلانات (SKAdNetwork / AdAttributionKit). يتم ذلك من نظام iOS نفسه ولا يتضمن هويتك أو معرّف جهازك.

أول فتح ليس عدداً مطابقاً لتنزيلات App Store.

## Version 2: only if Meta events ship later (requires ATT; owner decision pending)

Replace «الإعلانات» with:

**قياس الإعلانات عبر Meta (اختياري).** لا يعمل Meta SDK ولا يتصل بـ Meta إلا إذا سمحت بالتتبع في نافذة Apple **وفعّلت** «قياس الإعلانات عبر Meta» من إعدادات الخصوصية. عند ذلك يرسل التطبيق إلى Meta أحداث التثبيت وفتح التطبيق مع معرّف عشوائي ينشئه SDK وبيانات تقنية عن الجهاز (الطراز، إصدار النظام، اللغة، المنطقة الزمنية، شركة الاتصالات، حجم الشاشة، إصدار التطبيق)، وتستلم Meta عنوان IP، وقد يرسل SDK تقارير أعطاله التقنية. تستخدم Meta هذه البيانات لقياس إعلاناتنا وقد تربطها ببيانات لديها وفق سياستها. لا نرسل اسمك أو هاتفك أو بريدك أو بيانات حوالاتك أو حسابك. عند الإيقاف يتوقف تسجيل الأحداث وإرسالها فوراً، ونحذف الأحداث غير المرسلة والمعرّف العشوائي من جهازك؛ قد يتصل SDK بـ Meta لجلب إعداداته فقط حتى تعيد فتح التطبيق. البيانات المرسلة سابقاً تحتفظ بها Meta وفق سياستها ولا نملك حذفها من أنظمتها مباشرة؛ راسلنا عبر info@urremit.com لنساعدك في توجيه طلبك.

## English translation of Version 1 (review only)
**UR internal analytics.** When the app opens it sends "first open" and "app open" events with a random installation ID to our servers. We store no name, phone or account ID with them, and no calculator amounts, passwords, OTP codes, bank data or message content. Access is limited to authorised administrators, and these events are deleted automatically after 90 days. Turn this off under More → Privacy settings → "Share usage data with UR".

**Advertising.** We do not use the advertising identifier (IDFA) and do not share app events with advertising platforms. If you install the app after seeing one of our ads, Apple may send the ad platform an aggregated, anonymous install notice through Apple's ad measurement technologies (SKAdNetwork / AdAttributionKit). iOS does this itself, and it contains no identity or device ID.

## Conditions before publishing Version 1
1. The 90-day deletion is deployed and running in `delete` mode (website runbook `docs/VISITOR_EVENTS_RETENTION.md`). Until then, the sentence «نحذف هذه الأحداث تلقائياً بعد 90 يوماً» would be inaccurate.
2. The release build being described has `META_APP_EVENTS_ENABLED = NO`.
3. «المشاركة» section: no change needed for Version 1.
4. Legal review for Iraq, UAE and UK as appropriate.
