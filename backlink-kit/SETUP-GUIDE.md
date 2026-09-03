# دليل بناء Backlink من GitHub إلى موقعك 🚀

> **الهدف:** ربط `https://www.triggerworkflow.com` من أكثر من موضع في حسابك `WilliamAyad` على GitHub، بالطريقة الذكية (وليس الحشو العشوائي).

## ⚠️ معلومة مهمة قبل البدء

روابط GitHub في الـ README والمواضيع تكون `nofollow` — أي أنها **لا تمرّر قوة الترتيب مباشرة**، لكنها قيّمة جداً لأنها:

1. تساعد Google على **اكتشاف وأرشفة** صفحات موقعك أسرع.
2. تجلب **زواراً حقيقيين** مهتمين (Referral Traffic).
3. تعزز **العلامة التجارية والثقة** (إشارة Brand/Citation).

الرابط الوحيد **dofollow الحقيقي** هو من **GitHub Pages** (الخطوة 2 أدناه) لأنك تتحكم فيه بالكامل.

---

## 📁 محتويات المجموعة

| الملف | الوظيفة |
|---|---|
| `profile-README.md` | محتوى ملفك الشخصي (يظهر في `github.com/WilliamAyad`) |
| `pages/index.html` | صفحة الهبوط على `williamayad.github.io` (رابط dofollow) |
| `deploy-backlinks.sh` | سكربت ينفّذ كل شيء تلقائياً |
| `SETUP-GUIDE.md` | هذا الدليل |

---

## ⚡ الطريقة السريعة (سكربت واحد)

على جهازك (بعد تثبيت `gh` وتسجيل الدخول بحسابك `gh auth login`):

```bash
cd /home/user/n8n-workflow-blueprints/backlink-kit   # أو مكان المجلد عندك
chmod +x deploy-backlinks.sh
./deploy-backlinks.sh
```

---

## 🧭 الطريقة اليدوية (خطوة بخطوة)

### 1) الملف الشخصي (Profile README)

1. أنشئ مستودعاً جديداً اسمه **`WilliamAyad`** (نفس اسم المستخدم تماماً) واجعله **Public** مع تحديد "Add a README file".
   - مباشرة من هنا: `https://github.com/new` ثم في خانة Repository name اكتب `WilliamAyad`.
2. افتح `README.md` في المستودع الجديد → اضغط زر التعديل (✏️) → **احذف كل المحتوى** → الصق محتوى ملف `profile-README.md` → Commit.

✅ النتيجة: كل من يزور `github.com/WilliamAyad` يرى ملفاً شخصياً احترافياً فيه روابط موقعك.

### 2) صفحة GitHub Pages (الرابط dofollow)

1. أنشئ مستودعاً جديداً اسمه **`williamayad.github.io`** (Public).
   - مباشرة من هنا: `https://github.com/new` واكتب `williamayad.github.io`.
2. ارفع ملف `pages/index.html` إلى جذر المستودع:
   - زر "uploading an existing file" أو عبر git.
3. فعّل الصفحة: **Settings → Pages → Source: Deploy from a branch → main → / (root) → Save**.
4. انتظر دقيقة وافتح: `https://williamayad.github.io`

✅ النتيجة: صفحة مستقلة على نطاق `github.io` فيها رابط dofollow حقيقي لموقعك.

### 3) إعدادات "About" للمستودع الحالي

1. افتح `github.com/WilliamAyad/n8n-workflow-blueprints` → اضغط ⚙️ (Settings) → **General**.
2. في خانة **Website** اكتب: `https://www.triggerworkflow.com` → Save.
3. ارجع لصفحة المستودع → اضغط ⚙️ بجانب **About** → أضف المواضيع (Topics):
   `n8n`, `workflow-automation`, `ai-automation`, `mcp`, `no-code`, `templates`, `blueprints`.

✅ النتيجة: رابط موقعك يظهر في الشريط الجانبي، والمواضيع تحسّن ظهور المستودع في بحث GitHub وGoogle.

---

## ✅ كيف تتحقق من النجاح

| الفحص | الطريقة |
|---|---|
| الملف الشخصي ظاهر | افتح `github.com/WilliamAyad` |
| الصفحة منشورة | افتح `williamayad.github.io` |
| المواضيع والرابط | افتح صفحة المستودع واطلع على الشريط الجانبي الأيمن |
| أرشفة الصفحة | بعد يومين ابحث في Google عن `williamayad.github.io` |

## 📝 نصيحة للمدى الطويل

- أبقِ الملف الشخصي محدّثاً عند نشر أي مقال جديد (أضف سطراً في قسم "Latest").
- كل مستودع جديد تنشئه ضع فيه رابط موقعك في About + المواضيع.
- قدّم **محتوى مفيداً** في مستودعات الآخرين (PRs حسنة النية) — هذا يبني الروابط الأقوى على المدى الطويل.
