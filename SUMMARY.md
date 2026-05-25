# منصة ناس التعليمية (Naas) — Full Summary

---

## 1. Goal

Build a full-stack online course platform (naas.ly) targeting the Libyan market with:

- **Backend**: Cloudflare Workers (Hono.js) + D1 (SQLite) + R2 (assets) + KV (cache) + Durable Objects (wallet — deferred)
- **Frontend**: Flutter mobile app (Android + iOS) + Flutter Web
- **Currency**: Libyan Dinar (LYD) only
- **Roles**: super_admin, admin, teacher, student
- **Payments**: Manual deposit flow + manual teacher withdrawals
- **Content**: Video (Bunny.net for cheaper CDN), PDF, quizzes, live sessions (deferred)
- **Language**: Arabic RTL
- **Theme**: Dark mode required

---

## 2. Backend — Cloudflare Workers (`workers/`)

### Tech Stack
- **Runtime**: Cloudflare Workers (Edge)
- **Framework**: Hono.js v4
- **Language**: TypeScript
- **Database**: Cloudflare D1 (SQLite)
- **Auth**: `jose` (JWT) + Web Crypto API (PBKDF2) — edge-compatible
- **Validation**: `zod`
- **Deployment**: Wrangler CLI

### Project Structure

```
workers/
├── wrangler.toml              # Cloudflare config (D1, KV, R2, DO, Cron)
├── package.json               # hono, jose, zod, wrangler, typescript
├── tsconfig.json
├── src/
│   ├── index.ts               # App entry — Hono app, routes mounting, CORS
│   ├── cron/
│   │   └── expire_subscriptions.ts  # Daily cron: expire subscriptions + notify
│   ├── db/
│   │   └── schema.sql         # 35 D1 tables + seed data (admin, badges, commissions)
│   ├── middleware/
│   │   └── auth.ts            # authenticate + requireRoles middleware
│   ├── routes/
│   │   ├── auth.ts            # Register, login, refresh, profile, FCM token
│   │   ├── admin.ts           # Dashboard, users, admins, reports, commissions, transactions
│   │   ├── categories.ts      # CRUD categories
│   │   ├── teachers.ts        # Apply, approve/reject, profile, earnings
│   │   ├── courses.ts         # CRUD courses, sections, lessons + enroll
│   │   ├── cart.ts            # Add/remove/checkout cart items
│   │   ├── wallet.ts          # Balance, manual deposit, confirm/reject, refunds
│   │   ├── subscriptions.ts   # My subs, teacher's students
│   │   ├── withdrawals.ts     # Request, list, approve/reject, upload proof
│   │   ├── reviews.ts         # Course reviews + ratings
│   │   ├── notifications.ts   # List, mark read, delete
│   │   ├── wishlist.ts        # Add/remove/wishlist items
│   │   ├── search.ts          # Full-text search courses
│   │   ├── progress.ts        # Course progress tracking
│   │   ├── bundles.ts         # Course bundles
│   │   ├── flash_sales.ts     # Timed discounts
│   │   ├── gamification.ts    # Badges + leaderboard
│   │   ├── referral.ts        # Referral codes + rewards
│   │   ├── live.ts            # Live sessions (stub)
│   │   ├── announcements.ts   # Course announcements
│   │   ├── coupons.ts         # Discount coupons
│   │   ├── reports.ts         # Report content (abuse)
│   │   └── upload.ts          # R2 signed URLs for uploads
│   ├── utils/
│   │   ├── jwt.ts             # Edge-compatible JWT (jose library)
│   │   ├── crypto.ts          # PBKDF2 password hash/verify (Web Crypto API)
│   │   ├── helpers.ts         # formatResponse, generateId, etc.
│   │   └── bunny.ts           # Bunny.net video management (stub)
│   └── durable_objects/
│       └── wallet_do.ts       # WalletDO — atomic wallet transactions (deferred, needs paid plan)
```

### D1 Schema — 35 Tables

All tables defined in `workers/src/db/schema.sql`. Key tables:
- `users` — auth, roles, wallet balance
- `teachers` — teacher profiles, IBAN, commission rates, approval status
- `categories` — course categories
- `courses` — course metadata, pricing, ratings
- `sections` — course sections/chapters
- `lessons` — videos, PDFs, quizzes
- `quizzes` / `quiz_questions` / `quiz_attempts` / `quiz_answers` — quiz system
- `cart_items` / `wishlist_items` — shopping
- `subscriptions` — course enrollment with expiry
- `transactions` — all financial transactions (deposits, purchases, withdrawals)
- `withdrawals` — teacher withdrawal requests
- `reviews` — course ratings/reviews
- `coupons` / `notifications` / `announcements`
- `watch_history` / `notes` — learning progress
- `referrals` / `badges` / `user_badges` — gamification
- `reports` — content abuse reports
- `live_sessions` — live streaming (stub)
- `commission_rules` — platform commission settings
- `refund_requests` — student refund requests
- `bundles` / `bundle_courses` — course bundles
- `flash_sales` — time-limited discounts
- `admin_logs` — admin action audit trail
- `course_progress` — per-student lesson completion

### Seed Data
- Default super_admin: `admin@naas.ly` / `admin123`
- 8 achievement badges
- 1 default commission rule (10% fixed, 0% variable)
- **Note**: The schema.sql has a bug in the `lessons` table: `video_status DEFAULT 'pending'` but CHECK constraint only allows `'uploading', 'processing', 'ready', 'failed'`. Fixed locally (added 'pending' to CHECK), but fix needs to be applied to remote DB or inserts must include explicit `video_status`.

### Key Backend Decisions
- **Auth**: `jose` for JWT + PBKDF2 via Web Crypto API (replaced `jsonwebtoken` + `bcryptjs` for edge compatibility)
- **No Durable Objects** on free plan — WalletDO commented out, wallet uses D1 directly
- **Token expiry**: Access token = 24h, Refresh token = 30 days
- **Password hashing**: PBKDF2 (not bcrypt) — compatible with Workers runtime

### Deployed Worker
- **URL**: `https://naas-api.tahamax028.workers.dev`
- **Worker name**: `naas-api`
- **Status**: ✅ Live and responding (verified: health, categories, courses, auth endpoints)
- **Cron**: Daily at midnight UTC (`0 0 * * *`) — subscription expiry + notifications
- **Current version**: `120c352e-386e-43cd-b459-47638f15548e`

---

## 3. Frontend — Flutter (`naas_app/`)

### Tech Stack
- **Framework**: Flutter 3.29.3 (Dart SDK ^3.7.2)
- **State Management**: flutter_bloc 9.x + bloc 9.x
- **Routing**: go_router (defined but not yet fully connected)
- **HTTP Client**: dio 5.x with auto-refresh interceptor
- **Storage**: shared_preferences (replaced flutter_secure_storage for web compatibility)
- **Image Caching**: cached_network_image
- **Video**: video_player
- **UI Shimmer**: shimmer

### Project Structure

```
naas_app/
├── pubspec.yaml
├── lib/
│   ├── main.dart                        # Entry point, AuthGateway, MainNavigation (5 tabs)
│   ├── core/
│   │   ├── api/
│   │   │   └── api_client.dart          # Dio singleton + AuthInterceptor (auto refresh)
│   │   ├── constants/
│   │   │   └── api_constants.dart       # All API endpoints
│   │   ├── storage/
│   │   │   └── local_storage.dart       # Theme, locale, role persistence
│   │   └── theme/
│   │       └── app_theme.dart           # Light/Dark theme + colors
│   ├── models/
│   │   ├── user_model.dart              # User + wallet balance
│   │   ├── course_model.dart            # Course + Section + Lesson
│   │   ├── subscription_model.dart
│   │   └── transaction_model.dart
│   ├── repositories/                    # (empty — can add data layer)
│   ├── widgets/                         # (empty — shared widgets)
│   ├── features/
│   │   ├── auth/bloc/                   # AuthBloc — login, register, check, logout, update
│   │   ├── home/pages/home_page.dart    # Home — categories, popular courses, role cards
│   │   ├── search/pages/search_page.dart
│   │   ├── subscriptions/pages/...
│   │   ├── cart/pages/cart_page.dart
│   │   ├── profile/pages/profile_page.dart
│   │   ├── course_detail/pages/...
│   │   ├── player/pages/...
│   │   ├── teacher/bloc/ + pages/
│   │   ├── teacher_dashboard/pages/...
│   │   ├── settings/pages/...
│   │   ├── wallet/pages/...
│   │   ├── wishlist/pages/...
│   │   ├── notifications/pages/...
│   │   ├── bundles/pages/...
│   │   ├── live/pages/...
│   │   ├── gamification/pages/...
│   │   ├── referral/pages/...
│   │   ├── admin/pages/...             # Admin dashboard, users, withdrawals, refunds
│   │   └── ...
│   └── l10n/                            # Localization (Arabic)
```

### Key Flutter Decisions
- **Replaced `flutter_secure_storage` with `shared_preferences`** — web-compatible
- **API client**: Singleton Dio with AuthInterceptor (auto token refresh on 401)
- **Bloc pattern**: AuthBloc handles all auth states (initial, loading, authenticated, unauthenticated, error)
- **Navigation**: 5-tab bottom nav (Home, Search, MyCourses, Cart, Profile) + role-based action cards
- **Login/Register**: Bottom sheet modals in AuthGateway
- **RTL**: Arabic-first UI

### Current API Base URL
- `https://naas-api.tahamax028.workers.dev/api`

---

## 4. Deployment — Cloudflare Resources

### Created Resources
| Resource | Name | ID / URL |
|---|---|---|
| **Worker** | `naas-api` | `https://naas-api.tahamax028.workers.dev` |
| **D1 Database** | `naas-db` | `ebaa120d-a462-4dea-8db4-565867375540` |
| **KV Namespace** | `CACHE` | `059af5b8a394426297574fea214874c1` |
| **R2 Bucket** | `naas-assets` | — |
| **Pages Project** | `naas` | `naas-24m.pages.dev` ← **NOT YET DEPLOYED** |

### Environment Variables (on Worker)
- `JWT_SECRET`: `naas-jwt-secret-prod`
- `REFRESH_SECRET`: `naas-refresh-secret-prod`
- `BUNNY_API_KEY`: `""` (empty — needs setup)
- `BUNNY_LIBRARY_ID`: `""` (empty — needs setup)
- `BUNNY_CDN_HOSTNAME`: `""` (empty — needs setup)

### GitHub CI/CD
- `.github/workflows/deploy.yml` — Auto-deploy Worker on push to main
- `.github/workflows/flutter_ci.yml` — Flutter analyze CI

---

## 5. Current Data in D1 (Seeded)

| Table | Records |
|---|---|
| `users` | 2 (admin@naas.ly + teacher@naas.ly) |
| `teachers` | 1 (أحمد علي — approved) |
| `courses` | 5 courses |
| `sections` | 7 sections |
| `lessons` | 15 lessons |
| `categories` | 8 categories |

### Courses Seeded
1. **تطوير مواقع الويب من الصفر** — 149.99 LYD, 3 sections, 7 lessons, rating 4.7
2. **أساسيات علوم البيانات** — FREE, 1 section, 2 lessons, rating 4.5
3. **تطوير تطبيقات Flutter** — 249.99 LYD, 1 section, 2 lessons, rating 4.9
4. **مقدمة في الذكاء الاصطناعي** — FREE (30-day subscription), 1 section, 2 lessons, rating 4.6
5. **تعلم Figma للمبتدئين** — 99.99 LYD, 1 section, 2 lessons, rating 4.8

### Categories Seeded
تطوير الويب, علوم البيانات, تطوير التطبيقات, التصميم, الأعمال, الذكاء الاصطناعي, الشهادات الاحترافية, تطوير الألعاب

---

## 6. What Works ✅

- [x] **Worker API deployed** and responding to all major endpoints
- [x] **Health check**: `GET /api/health` → `{"success": true}`
- [x] **Auth**: Register, login, refresh, me — all working
- [x] **Admin login**: `admin@naas.ly` / `admin123` — role: `super_admin`
- [x] **Categories**: 8 categories seeded
- [x] **Courses**: 5 courses with sections and lessons
- [x] **Flutter web build**: `flutter build web --release` succeeds
- [x] **TypeScript**: `tsc --noEmit` passes with 0 errors
- [x] **`flutter analyze`** passes with 0 errors, 0 warnings
- [x] **Cloudflare Pages project** created (`naas-24m.pages.dev`)
- [x] **Auth middleware** updated to use `jose` (async verify)
- [x] **Admin route** updated to use crypto.ts instead of bcryptjs

---

## 7. What's BLOCKED / Not Working ❌

- [ ] **Cloudflare Pages deployment**: Upload hangs at "Uploading... (0/33)". The wrangler pages deploy command gets stuck. Alternative: use direct API upload, or fix the pages deploy issue.
- [ ] **Teacher login**: teacher@naas.ly has password `placeholder` (invalid). The teacher was inserted via raw SQL with a fake hash. Need to register via API or generate a proper PBKDF2 hash.
- [ ] **No real video content**: All video URLs are NULL. Need Bunny.net integration.
- [ ] **No payment integration**: Manual deposit flow only (app generates reference, admin confirms screenshot).
- [ ] **Durable Objects**: WalletDO disabled (needs paid Cloudflare plan).
- [ ] **schema.sql bug**: `lessons.video_status` CHECK constraint doesn't include `'pending'` (the default value). Fixed in local schema.sql but remote DB still has the broken constraint.
- [ ] **Bunny.net** env vars are empty strings — not configured.
- [ ] **Flutter mobile build**: Cannot build Android/iOS on this machine (no Android SDK, no Xcode).

---

## 8. Architecture & Key Code Details

### Auth Flow
```
Register/Login → API returns {accessToken, refreshToken} 
                → stored in SharedPreferences
                → AuthInterceptor attaches Bearer token to all requests
                → On 401: interceptor auto-refreshes using refresh token
                → If refresh fails: clear tokens → redirect to AuthGateway
```

### Wallet Flow (Manual)
```
Student: Deposit page → enters amount → submits → system generates reference number
        → student transfers LYD to platform bank account
        → student uploads transfer screenshot/receipt
        → enters reference in app

Admin: Deposit management page → sees pending deposits
      → clicks Confirm → money added to student's wallet
      → OR clicks Reject → deposit cancelled

Student: Buys course → wallet debited → subscription created
Teacher: Requests withdrawal → enters amount + IBAN
Admin: Sees pending withdrawal → processes bank transfer → uploads proof screenshot
      → clicks Confirm → withdrawal marked complete
```

### Refund Flow
```
Student: Request refund (within 24h of purchase) → reason required
Admin: Reviews → Approves (refund + revoke subscription) or Rejects
```

---

## 9. Flutter App Pages Status

### Built & Connected
- AuthGateway (Login/Register bottom sheets)
- HomePage (categories + popular courses + role cards)
- SearchPage (stub)
- SubscriptionsPage (stub)
- CartPage (stub)
- ProfilePage (stub)

### Built but May Need Polish
- CourseDetailPage
- VideoPlayerPage
- TeacherDashboard
- CreateCourse / ManageLessons
- WalletPage / DepositPage
- WithdrawalRequest
- WishlistPage
- NotificationsPage
- SettingsPage
- AdminDashboard, AdminUsers, AdminWithdrawals, AdminRefunds
- BundlesPage, LivePage, GamificationPage, ReferralPage
- TeacherApplication

### Not Started
- Firebase Cloud Messaging (push notifications)
- Offline download
- AI recommendations
- DRM / watermark

---

## 10. Environment & Tools on This Machine

| Tool | Version | Status |
|---|---|---|
| OS | macOS 15.6.1 (arm64) | ✅ |
| Flutter | 3.29.3 (stable) | ✅ |
| Dart SDK | ^3.7.2 | ✅ |
| Node.js | 18.20.8 (system default) | ⚠️ Upgrade to 20 |
| Node.js | 20.20.2 (via brew) | ✅ (installed) |
| wrangler | 3.114.17 | ✅ |
| TypeScript | 5.6 | ✅ |
| Android SDK | — | ❌ Not installed |
| Xcode | — | ❌ Not installed |
| CocoaPods | — | ❌ Not installed |

---

## 11. What to Do Next (Priority Order)

### P0 — Immediate
1. **Deploy Flutter Web to Pages**: Fix the `wrangler pages deploy` hang. Try:
   - Use the Cloudflare API directly for upload
   - Or decrease build size (tree-shaking is already enabled)
   - Or use `--commit-dirty=true` with a proper Git commit
   - The Pages URL will be `https://naas-24m.pages.dev`

2. **Fix teacher login**: Register teacher@naas.ly through the API with proper password:
   ```bash
   curl -X POST https://naas-api.tahamax028.workers.dev/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"teacher@naas.ly","password":"teacher123","full_name":"أحمد علي"}'
   ```
   Then promote to `teacher` role and create the `teachers` record.

### P1 — Core Functionality
3. **Connect remaining Flutter pages**: Search, subscriptions, cart, wallet, teacher dashboard, admin pages — wire up the Blocs and API calls properly.

4. **Configure Bunny.net**: Sign up at Bunny.net, create a video library, set env vars:
   - `BUNNY_API_KEY` → Bunny API key
   - `BUNNY_LIBRARY_ID` → Video library ID
   - `BUNNY_CDN_HOSTNAME` → CDN hostname

5. **Fix schema bug**: Add `'pending'` to the `lessons.video_status` CHECK constraint in the remote D1. Either recreate the table or run a migration.

### P2 — Polish
6. **Complete the go_router setup** for all named routes.
7. **Add proper error handling** and loading states in all pages.
8. **Implement local notifications** for subscription expiry.
9. **L10n**: Complete Arabic translations in all pages.

### P3 — Production
10. **Android build**: Install Android Studio or set up CI/CD to build APK.
11. **iOS build**: Set up Xcode or use Codemagic for iOS builds.
12. **Setup custom domain** (naas.ly) on Cloudflare.
13. **Configure production secrets**: JWT_SECRET, REFRESH_SECRET → strong random values.
14. **Set up payment gateway** (if moving beyond manual deposits).

---

## 12. Critical Technical Notes

### Edge Compatibility
- ❌ `jsonwebtoken` — uses Node.js `crypto` module (not available in Workers)
- ❌ `bcryptjs` — uses Node.js `Buffer` and other APIs
- ✅ `jose` — edge-compatible JWT library
- ✅ Web Crypto API (`crypto.subtle`) — edge-compatible PBKDF2

### Durable Objects Limitation
- Free Cloudflare plan requires `new_sqlite_classes` migration for Durable Objects
- Commented out WalletDO; wallet transactions handled via D1 directly
- To re-enable: uncomment `[[durable_objects.bindings]]` and `[[migrations]]` in `wrangler.toml`, change `new_classes` to `new_sqlite_classes`

### CORS
- Configured via `hono/cors` middleware — allows all origins in development
- Should restrict in production

### Node.js Version Issue
- System defaults to Node 18.20.8
- wrangler requires Node 20+
- Solution: `export PATH="/opt/homebrew/opt/node@20/bin:$PATH"` before running wrangler

### D1 Console Access
- Can execute SQL directly: `npx wrangler d1 execute naas-db --remote --command="SQL here"`
- Can run from SQL file: `npx wrangler d1 execute naas-db --remote --file=./file.sql`

---

## 13. Key Commands Reference

```bash
# === Backend ===
cd workers

# Dev server (local)
npm run dev

# Deploy worker
export PATH="/opt/homebrew/opt/node@20/bin:$PATH"
export CLOUDFLARE_API_TOKEN="cfut_npJBz6msZYpX4pGCJI5cuVqNVi1YKeRg2uE968Kpaa6d5e56"
export CLOUDFLARE_ACCOUNT_ID="3f8a5a318c4a88ced23b6850c9019652"
npm run deploy

# TypeScript check
npx tsc --noEmit

# D1 queries
npx wrangler d1 execute naas-db --remote --command="SELECT * FROM users;"
npx wrangler d1 execute naas-db --remote --file=./src/db/schema.sql

# === Flutter ===
cd naas_app

# Build web
flutter build web --release

# Run locally (Chrome)
flutter run -d chrome

# Analyze
flutter analyze

# Deploy web to Pages
export PATH="/opt/homebrew/opt/node@20/bin:$PATH"
npx wrangler pages deploy build/web --project-name naas --commit-dirty=true --branch main

# === GitHub ===
git add -A && git commit -m "message" && git push origin main
```

---

## 14. Cloudflare Credentials (Stored)

| Credential | Value |
|---|---|
| Account ID | `3f8a5a318c4a88ced23b6850c9019652` |
| API Token | `cfut_npJBz6msZYpX4pGCJI5cuVqNVi1YKeRg2uE968Kpaa6d5e56` |
| D1 DB ID | `ebaa120d-a462-4dea-8db4-565867375540` |
| KV ID | `059af5b8a394426297574fea214874c1` |
| GitHub Repo | `https://github.com/Tahamahia/naas.git` |
| Worker URL | `https://naas-api.tahamax028.workers.dev` |
| Pages URL | `naas-24m.pages.dev` (not yet deployed) |

---

## 15. Where We Stopped

**We were deploying Flutter Web to Cloudflare Pages.** The `flutter build web --release` succeeded. The Cloudflare Pages project `naas` was created. But `wrangler pages deploy` hangs at "Uploading... (0/33)" — likely a network timeout or Node.js version issue. The API is live and working with seeded data (categories + courses).

**Next agent should:**
1. Read this file at `SUMMARY.md`.
2. Fix the Pages deployment (try direct API upload or run `npx wrangler pages deploy` with Node 20 and longer timeout).
3. Once deployed, verify the site works at `https://naas-24m.pages.dev`.
4. Then proceed with the "What to Do Next" list above.
