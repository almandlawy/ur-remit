# تقرير UR Global 1.1

نُفذت إضافة Analytics ولوحات المراقبة وربط الموقع. **إصدار iOS ليس جاهزاً للإطلاق بعد**: لم ينفذ Build أو اختبار محاكي أو Archive، لأن البيئة Linux بلا Xcode وGitHub منع بدء المهام بسبب مشكلة فوترة الحساب.

| # | المطلوب | النتيجة |
|---|---|---|
| 1 | Version | 1.1 في project.yml |
| 2 | Build | 12 حسب تعليماتك عند استخدام 11 سابقاً؛ يلزم إعادة فحص عدم استخدام 12 لنفس الإصدار 1.1 قبل أي رفع مستقبلي |
| 3 | الملفات المعدلة | ملفات Analytics الجديدة، Auth للأحداث، Root/Home/Calculator/More، شاشة الإدارة، manifest الخصوصية، project.yml، لوحة الويب وCI؛ القائمة الكاملة في UR-GLOBAL-1.1-RELEASE.md |
| 4 | migrations | خمس migrations جديدة، مطبقة في Supabase الإنتاجي؛ القائمة أدناه |
| 5 | Events | جميع 23 حدثاً لها تعريف ومسار تسجيل في الكود؛ استقبال السيرفر وصلاحياته مختبران، تسجيلها من iOS يحتاج تشغيل البناء |
| 6 | المستخدمون | 5 إجمالاً، 1 اليوم، 3 آخر 7 أيام، 5 آخر 30 يوم، 5 مؤكدون، 0 غير مؤكدين، بتوقيت بغداد؛ المصدر Supabase Auth للمشروع وقد يشمل حسابات من خارج iOS |
| 7 | Dashboard | لوحة Web جديدة وواجهة iOS: Cards، فترات، Chart 30 يوم، Funnel مرتب. HTTPS summary يعمل ويعيد الأرقام الحقيقية؛ التحقق من لوحة الويب بجلسة SUPER_ADMIN ومن واجهة الموبايل لم يكتمل |
| 8 | الموقع يعرض التطبيق | نُشر تحديث موقع urremit.com بالنسخة 110، مع الشعار ولقطة حقيقية والنص المعتمد وزر App Store |
| 9 | App Store link | جميع روابط التطبيق الجديدة تشير إلى ID 6815895731؛ تعذر جلب صفحة Apple هنا، لذلك نجاح الفتح والتوفر بكل البلدان غير مؤكدين |
| 10 | Smart App Banner | أضيف مرة واحدة عبر itunes metadata، وتحقق كود Framework من إخراج meta الصحيحة؛ العرض الفعلي في Safari يحتاج اختباراً |
| 11 | Build | Backend TypeScript وAdmin production build وWebsite production build نجحت؛ iOS Build لم يبدأ |
| 12 | الاختبارات | 28 Backend + 4 Analytics contract + 12 Website نجحت. RLS ومنع القراءة العامة وingress auth وFunnel اختبرت. اختبارات جهاز iPhone والدخول/التسجيل/الخروج وWhatsApp وShare Sheet وRTL/Light/Dark لم تنفذ |
| 13 | Archive | لم يُنشأ. توجد خطوات CI وسكربت Mac لإنشاء Archive غير موقّع فقط؛ Archive موزّع موقّع يحتاج شهادة وProfile على Mac |
| 14 | Apple credentials | لتنزيلات Apple الرسمية: Issuer ID وKey ID ومفتاح Team API بصلاحية Sales and Reports وملف .p8 في Secret على السيرفر. تفعيل التقرير أول مرة قد يحتاج مسؤولاً مخولاً. لا تضعه في التطبيق أو GitHub أو الدردشة |
| 15 | App Privacy | قبل الإرسال: Identifiers/Device ID + User ID، Usage Data/Product Interaction، Diagnostics/Other Diagnostic Data؛ Analytics، Linked نعم، Tracking لا. راجع أيضاً إفصاحات تسجيل الدخول السابقة. manifest لا يعدل أجوبة App Store Connect تلقائياً |
| 16 | خطوات يدوية | حل فوترة GitHub وإعادة CI، أو تشغيل سكربت Mac؛ اختبار iPhone فعلي والدخول ولوحة الإدارة، التحقق من Build والتوفر الإقليمي، توقيع Archive وتحديث Privacy بعد مراجعتك؛ ربط تقارير Apple لاحقاً |
| 17 | الأسعار | لم تتغير ملفات الأسعار أو API أو Cache أو التاريخ أو محدث الآن أو sourceTimestamp/updatedAt أو البيع/الشراء؛ 8 ملفات محمية بفحص SHA256 |
| 18 | Add for Review | لم يُضغط |
| 19 | Submit for Review | لم يُضغط، ولم يُرفع أي Build إلى Apple |

## الأحداث

`app_first_open`, `app_open`, `session_start`, `signup_started`, `signup_completed`, `login_completed`, `logout`, `home_viewed`, `rates_viewed`, `calculator_viewed`, `offices_viewed`, `calculator_used`, `currency_selected`, `whatsapp_clicked`, `phone_clicked`, `website_clicked`, `office_clicked`, `map_clicked`, `app_store_clicked`, `share_app_clicked`, `contact_attempted`, `language_changed`, `error_occurred`.

Language Changed يرصد تغيير اللغة/Locale فعلياً عند التنشيط القادم؛ لا يضيف ترجمة إنجليزية إلى الواجهات الحالية. الأحداث لا تسجل المبالغ أو نتائج الحاسبة أو أرقام التواصل أو نصوص الأخطاء الخام. محاولات التواصل لا تعني اكتمال المكالمة أو المحادثة. بعض أزرار الدعم الحالية تفتح صفحة التواصل، لذلك تُحسب Website Click وليست مكالمة هاتفية.

First Opens هو أول تشغيل **مرصود** لكل تثبيت عند إضافة Analytics، وقد يشمل المستخدمين الذين حدّثوا التطبيق. لا يطابق تنزيلات App Store. التنزيلات الرسمية تعرض «غير مربوط» وقيمتها null، لا صفراً وهمياً. النشطون تثبيتات فريدة وليسوا بالضرورة أشخاصاً فريدين. «الكل» يشمل الأحداث المحتفظ بها خلال 90 يوماً.

## migrations

- `20261006223007_app_product_analytics.sql`
- `20261006223511_analytics_site_bridge.sql`
- `20261006224010_analytics_retention_scheduler.sql`
- `20261006224626_analytics_summary_performance.sql`
- `20261006225046_analytics_auth_aggregate_access.sql`

لا توجد migrations جديدة لأسعار الموقع. جدولة حذف الأحداث فعالة يومياً بعد 90 يوماً. الجداول غير قابلة للقراءة أو الكتابة المباشرة من العملاء. المفتاح المخصص لربط مراقبة الموقع محفوظ كـ Secret في إعدادات السيرفر، ولا توجد Secrets جديدة في المصدر.

## اختبار Mac وArchive

```bash
bash scripts/build-ios-1-1.sh
```

يتطلب Xcode وxcodegen، وينفذ Tests وArchive غير موقّع فقط. لا ينفذ Upload أو Add for Review أو Submit.

## What's New — مقترح ولم يُرسل

تحسينات على تجربة الاستخدام والحاسبة، إضافة تحسينات في التواصل والوصول إلى خدمات UR، وتحسينات في الأداء والاستقرار.

## حدود التحقق

خدمة المراقبة تعيد HTTPS 200 و30 يوماً وبيانات Auth الصحيحة. اختبارات SQL التجريبية نُفذت داخل معاملات جرى Rollback لها: **لم تحفظ أحداث وهمية**. جمع الأحداث الحقيقية يبدأ عندما يشغّل المستخدمون الإصدار المحدّث.

نجاح نشر الموقع أكدته خدمة الاستضافة مع الحفاظ على الدومين والجمهور العام. الوصول من شبكة التنفيذ إلى urremit.com أعاد HTTP 403 / error 1010، لذلك لم أفحص HTML المنشور أو لوحة SUPER_ADMIN بجلسة فعلية. فحص TypeScript الشامل للموقع لديه أخطاء سابقة تتعلق بـ Cloudflare/Expo وملفات غير مرتبطة؛ production build واختباراته نجحا.

التغييرات محفوظة في Draft PR #17، ولم تُدمج في main. لا توجد نتيجة تؤكد خلو تطبيق iOS من Crash قبل تنفيذ الاختبارات المتبقية. لم أستخدم git reset أو restore أو stash.
