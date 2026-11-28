# سياسة الخصوصية — Lumora Studio

> **الخلاصة في سطر واحد:** لا نجمع أي شيء. لا حسابات، لا تحليلات، لا إعلانات، ولا تتبّع — كل ما تفعله في لومورا يبقى على جهازك.

آخر تحديث: ٢٥ نوفمبر ٢٠٢٦ · تنطبق هذه السياسة على تطبيق **Lumora Studio** (`com.ctodrs.lumora`) وما يصدر عنه من إصدارات رسمية. التطبيق مفتوح المصدر (رخصة MIT) ويمكن لأي شخص تدقيق شيفرة المصدر على [المستودع العام](https://github.com/CTO-DRS/lumora-studio) للتحقق من كل بند هنا.

---

## ١. ما نجمعه: لا شيء

- لا نجمع صورك أو فيديوهاتك أو ملفاتك الصوتية ولا أي نسخة منها.
- لا نجمع بيانات الاستخدام، ولا نعرف من أنت، ولا نعرف أنك تستخدم التطبيق أصلًا.
- لا نستخدم أدوات تحليلات (Analytics)، ولا إعلانات، ولا بصمات أجهزة، ولا أي مكوّن تتبّع تابع لطرف ثالث.
- لا نطلب حسابًا ولا تسجيلًا ولا بريدًا إلكترونيًا؛ التطبيق يعمل كاملًا بلا حساب.

## ٢. ما يبقى على جهازك

كل ما تعمل عليه يُعالَج محليًا على هاتفك ولا يغادر الجهاز أبدًا:

- الصور والفيديوهات والملفات الصوتية التي تفتحها للمحرر.
- جميع عمليات التحرير: الفلاتر، الأقنعة، أدوات الذكاء الاصطناعي (إزالة الخلفية، إزالة العناصر، التحديد باللمسة، تمويه العمق، تنقيح الوجه، تعديل السماء…) — كلها تُنفَّذ بمعالجات داخل الجهاز.
- ملفات مشاريعك وإعداداتك المسبقة وسجل أوامرك ومفضلتك (تُحفظ في تخزين التطبيق الخاص على الجهاز).
- **سجل الأخطاء التشخيصي** يُكتب محليًا فقط، وتراه من: الإعدادات › سجل الأخطاء. لا يُرسل إلينا تلقائيًا أبدًا؛ إن أردت مشاركته معنا فأنت من يرسله بيدك (عبر تذكرة في المستودع مثلًا).

## ٣. الاستخدام الوحيد للشبكة: تنزيل النماذج اختياريًا

المحرر الأساسي يعمل كاملًا **بدون إنترنت ولا يتطلب أي تنزيل**. الاستثناء الوحيد هو **النماذج الذكية الاختيارية** التي تثبّتها بنفسك من «الإعدادات › نماذج الذكاء الاصطناعي» (مثل: التحديد باللمسة، تمويه العمق، إزالة الأشخاص، تنقيح الوجه، تجزئة السماء):

- تُنزَّل من روابط ثابتة الإصدار فقط (Hugging Face، ومرآة مشروعنا على GitHub Releases)، وتُتحقق بصمة **SHA-256** لكل نموذج قبل تثبيته.
- لا تُنزَّل أي نموذج تلقائيًا ولا في الخلفية؛ التنزيل يبدأ فقط حين تختاره.
- **محتوى الاتصال:** الطلب هو تنزيل ملف نموذج فقط — لا يُرفق أي بيانات عنك أو عن صورك، فالصور لا تُرفَع أبدًا إلى أي سحابة ولا إلى أي خدمة معالجة.
- إن لم تنزّل أي نموذج فلا يحدث أي اتصال بالشبكة إطلاقًا، ويمكنك التحقق من ذلك بحجب الإنترنت تمامًا عن التطبيق.

## ٤. الأذونات وسبب كل واحدة

| الإذن | السبب |
|---|---|
| `INTERNET` | تنزيل النماذج الاختيارية فقط (§٣). لا يوجد أي استخدام آخر للشبكة. |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | فتح الصور والفيديو لتحريرها داخل التطبيق. |
| `READ_MEDIA_AUDIO` | فتح ملفات صوتية لإضافتها كأغنية خلفية في محرر الفيديو. |
| `READ_EXTERNAL_STORAGE` (حتى أندرويد ١٢ فقط) | بديل أقدم للسماحين أعلاه على أنظمة أقدم. |
| `WRITE_EXTERNAL_STORAGE` (حتى أندرويد ٩/١٠ فقط) | حفظ الصور والفيديو المعدّلة على الأنظمة القديمة. |

لا يطلب التطبيق: الكاميرا، الميكروفون، الموقع، جهات الاتصال، أو الإشعارات في الخلفية.

## ٥. الأطراف الثالثة

- لا ندمج أي حزمة طرف ثالث ترسل البيانات: لا Firebase، لا Google Play Services الإعلانية، لا SDK تحليلات.
- الأطراف التي تلمسها بشكل غير مباشر: موقع **Hugging Face** و**GitHub** عند تنزيل نموذج اختياري فقط — وهما يران طلب تنزيل ملف عام لا أكثر، ولا نرسل لهما أي بيانات عنك.

## ٦. حماية البيانات

بما أن البيانات لا تترك جهازك أصلًا، فلا يوجد مخزون بيانات عندنا يمكن تسريبه أو استخدامه. ما على جهازك يخضع لأذونات نظام أندرويد نفسه، ويُحفظ في مجلد التطبيق الخاص، ويُحذف بمجرد إلغاء تثبيت التطبيق.

## ٧. خصوصية الأطفال

التطبيق لا يستهدف الأطفال، ولا يجمع أي بيانات من أي شخص — طفلًا كان أم كبيرًا — فلا يوجد ما يخص الأطفال أساسًا.

## ٨. تواصل معنا

- الإبلاغ عن مشكلة أو سؤال عن الخصوصية: افتح [مشكلة (Issue) في المستودع العام](https://github.com/CTO-DRS/lumora-studio/issues).
- الإبلاغ عن ثغرة أمنية: اتبع ما سيُنشر في ملف `SECURITY.md` بالمستودع، وتبنّى الإفصاح المنسّق.

قد نحدّث هذه السياسة عند إصدارات مستقبلية (كإضافة منصات جديدة مثل iOS أو سطح المكتب). أي تغيير يُعلن في هذه الصفحة وفي ملاحظات الإصدار، والتطبيق لا يتغير سلوكه في جمع البيانات: يبقى «لا شيء يُجمع».

---

# Privacy Policy — Lumora Studio

> **One-line summary:** We collect nothing. No accounts, no analytics, no ads, no tracking — everything you do in Lumora stays on your device.

Last updated: 2026-11-25 · Applies to **Lumora Studio** (`com.ctodrs.lumora`) official releases. The app is open source (MIT); anyone can audit the source code at the [public repository](https://github.com/CTO-DRS/lumora-studio) to verify every statement below.

## 1. What we collect: nothing

- We do not collect your photos, videos, audio files, or any copy of them.
- We collect no usage data, do not know who you are, and do not know that you use the app.
- No analytics, no ads, no device fingerprinting, and no third-party tracking components.
- No account, sign-up, or e-mail is required; the app is fully usable without one.

## 2. What stays on your device

Everything you work on is processed locally and never leaves your phone:

- Photos, videos and audio files you open in the editor.
- Every edit: filters, masks, AI tools (background removal, eraser, tap-to-select, depth blur, face retouch, sky edits…) — all run with on-device inference.
- Your projects, presets, command history and favourites (stored in the app's private storage).
- The **diagnostic error log** is written locally only (Settings › Error log) and is never sent to us automatically; if you want to share it, you choose to send it (e.g. via a repository issue).

## 3. The only network use: optional model downloads

The core editor works fully **offline and needs no download at all**. The single exception is the **optional smart models** you install yourself (Settings › AI models) — e.g. tap-to-select, depth blur, person removal, face retouch, sky segmentation, on-device captions (Whisper tiny):

- Models are downloaded from pinned-revision URLs only (Hugging Face and our GitHub Releases mirror), and every model is verified against its **SHA-256** checksum before use.
- No model is ever downloaded automatically or in the background; downloads start only when you pick one.
- The request downloads a model file only — nothing about you or your photos is attached. Photos are never uploaded to any cloud or processing service.
- If you download no models, no network connection is made at all; you can verify this by blocking network access to the app.

## 4. Permissions and why

| Permission | Why |
|---|---|
| `INTERNET` | Optional model downloads only (§3). No other network use exists. |
| `READ_MEDIA_IMAGES` / `READ_MEDIA_VIDEO` | Opening photos and videos to edit inside the app. |
| `READ_MEDIA_AUDIO` | Opening audio files to add as music in the video editor. |
| `READ_EXTERNAL_STORAGE` (≤ Android 12) | Legacy equivalent of the above on older systems. |
| `WRITE_EXTERNAL_STORAGE` (≤ Android 10) | Saving edited photos/videos on older systems. |

The app does **not** request camera, microphone, location, contacts, or background notifications.

## 5. Third parties

- We ship no third-party component that sends data: no Firebase, no ad networks, no analytics SDKs.
- Indirect parties: **Hugging Face** and **GitHub** when you download an optional model — they see a plain file download of a public file and receive nothing about you.

## 6. Data protection

Because data never leaves your device in the first place, there is no data store on our side to leak or misuse. What is on your device is governed by Android's own permission model, stored in the app's private folder, and removed when you uninstall the app.

## 7. Children's privacy

The app is not directed at children — and it collects no data from anyone at all, so there is no child-specific data to govern.

## 8. Contact

- Questions or privacy concerns: open an [issue in the public repository](https://github.com/CTO-DRS/lumora-studio/issues).
- Security vulnerabilities: follow the repository's `SECURITY.md` (coordinated disclosure).

Future releases (e.g. new platforms such as iOS or desktop) may update this policy; any change will be announced on this page and in release notes. The data-collection behaviour never changes: nothing is collected.
