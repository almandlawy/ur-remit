# Deployment

Production requires separate PostgreSQL databases and secrets for development, staging, and production. Apply migrations in numeric order and deploy the API before the admin dashboard or iOS release.

Required backend secrets:

- `DATABASE_URL`
- `LOOKUP_HASH_KEY`
- `ADMIN_SESSION_HASH_KEY`
- `ADMIN_MFA_ENCRYPTION_KEY` (base64-encoded 32 bytes)

The production API origin is `https://api.urremit.com`; staging is `https://api-staging.urremit.com`. TLS termination, HSTS, DDoS/WAF controls, database backups, metrics, alerts, and secret rotation are infrastructure requirements.

TestFlight upload requires an Apple Distribution identity, provisioning for `com.urremit.mobile`, and App Store Connect API credentials with the minimum required role. None are committed to this repository.

## ربط لوحة الإدارة بدومين حقيقي (خطوات يدوية مطلوبة منك)

هذا الجزء لا يمكن للمساعد تنفيذه تلقائياً لأنه يتطلب الوصول لحساباتك الخارجية (استضافة + DNS)، وهذا ممنوع أمنياً بدون إذنك المباشر وحضورك الفعلي. الخطوات:

1. **اختر مزوّد استضافة** لتطبيق Next.js (لوحة الإدارة) مثل Vercel أو Netlify أو Fly.io. الأسهل لمبتدئ: Vercel.
2. **انشر مجلد `admin/`** على المزوّد (عادة بربط مستودع GitHub، ثم "Deploy").
3. **أضف متغيرات البيئة على المنصة** (وليس بالكود):
   - `UR_BACKEND_URL` = رابط الـ backend المنشور (مثال: `https://api.urremit.com`)
   - يجب نشر مجلد `backend/` أولاً على منصة تدعم Node.js طويلة التشغيل (مثل Fly.io أو Railway)، وربط قاعدة Supabase عبر `DATABASE_URL` بنفس الطريقة المستخدمة محلياً.
4. **اربط الدومين**: من إعدادات المشروع بالمنصة، أضف الدومين الذي تملكه، وستعطيك المنصة سجلات DNS (CNAME/A) تضيفها عند مسجّل الدومين (مثل Namecheap/GoDaddy).
5. بعد الربط، تصفح الدومين مباشرة بدل `localhost:3001`.

⚠️ لا تشارك أي مفتاح API أو `DATABASE_URL` أو كلمة مرور بالمحادثة — أدخلها فقط داخل لوحة تحكم المنصة نفسها.

