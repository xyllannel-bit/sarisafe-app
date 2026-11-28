# SariSafe
**GCash Transaction Recording and Verification System for Sari-Sari Stores in Brgy. Sumilihon, Butuan City**  
CSC 106 – Software Engineering 1 · Caraga State University – College of Computing and Information Sciences  
Pilot Store: **Fuentez Store** | Live Deployment: [https://sarisafe.vercel.app/](https://sarisafe.vercel.app/)

---

## 1. Overview
SariSafe is an offline-first Progressive Web Application (PWA) developed for sari-sari store tenders and owners in Brgy. Sumilihon, Butuan City (piloted at Fuentez Store) to record and verify GCash Cash-In and Cash-Out transactions. Handwritten logbooks make it slow and error-prone to detect reused or fabricated GCash reference numbers, calculate bracketed service fees (*patong*), track expected physical cash against GCash wallet balances, and reconcile end-of-shift totals. SariSafe solves these problems through instant local duplicate-reference checking, automated service-fee calculation, digital customer signature capture, Cash-Out pending confirmation queues, shift Z-reading reconciliation, and role-isolated automatic cloud synchronization across store devices.

---

## 2. Features (Implemented)
* **Real-Time Duplicate Reference Verification (`FR-001`, `FR-002`, `NFR-001`):** Checks entered GCash reference numbers (configured to the last 5 digits via `REF_DIGITS = 5`, or full 13 digits) against local IndexedDB indexes (`ref` and `tail`) in milliseconds, showing an inline status indicator and triggering a warning modal to cancel, log as a `Duplicate` attempt, or override if verified as a separate receipt.
* **GCash Transaction Recording & Input Validation (`FR-003`):** Records `Cash-In` and `Cash-Out` entries with quick-amount chips (`₱100`, `₱200`, `₱500`, `₱1,000`), customer name, optional address, 11-digit Philippine mobile number validation (`09XXXXXXXXX`), and a mandatory customer accuracy & Privacy Policy confirmation checkbox.
* **Offline-First Storage & Quota Health (`FR-004`, `NFR-004`, `NFR-005`):** Persists all transactions, shifts, and settings locally in IndexedDB (`SariSafeDB`, schema v2) with a network-first Service Worker (`sw.js`) for full offline operation and a storage quota bar that warns the owner at 80% capacity.
* **Role-Based Access Control (`FR-005`, `FR-007`):** Separates the app into a **Store Tender** view (`Counter` and `Shift` tabs) and a **Store Owner** view (`Counter`, `Shift`, `Summary`, `Log`, `Fees`, and `Backup` tabs) secured with a SHA-256 hashed 4-digit PIN.
* **CSV Export & JSON Backup/Restore (`FR-006`, `FR-012`):** Exports formula-sanitized comma-separated transaction logs (`.csv`, filterable by specific date or all dates, with confirmed `OK` summary totals for Excel/Google Sheets) and full system snapshots (`.json`, containing transactions, signatures, shifts, and fee tiers) with non-destructive merge restore.
* **Digital Customer Signatures & Printable Receipts (`FR-008`):** Captures touch/pointer signatures on an HTML5 `<canvas>` pad, displays an automatic transaction receipt popup after saving, and stores signatures inside a searchable, printable transaction history log.
* **Automated Service Fee (*Patong*) Tiers (`FR-009`):** Includes 100 pre-configured brackets covering `₱1` to `₱50,000` (`₱10` per `₱500` bracket, up to `₱1,000`), with per-transaction manual overrides and owner tier editing/reset controls.
* **Transaction Status Rules & Offsetting Corrections (`FR-010`, `BR-003`):** Automatically sets `Cash-In` entries to `OK` and locks `Cash-Out` entries to `Pending` until the tender verifies receipt of funds and taps **Mark OK**. Saved records cannot be edited or deleted; confirmed `OK` errors are reversed using offsetting `Correction` entries with a required explanation note.
* **Shift & Cash Float Reconciliation (`FR-011`):** Tracks starting physical cash and GCash wallet balances per shift, updates expected balances live (with a show/hide privacy toggle), warns if `Pending` transactions remain before closing, and produces a shift Z-reading summary (`Balanced`, `Over`, or `Short`).
  
* **Zero-Login Tender Auto-Sync & Owner-Only Full Read (`NFR-006`, RA 10173):** Tender devices automatically upload new transactions, status confirmations, and shift updates in the background via a write-only Supabase RPC (`sarisafe_tender_sync`) with zero `SELECT` access to store-wide records. Only the authenticated Store Owner (`role = 'owner'`) can download and view all store transactions across devices, and the Owner cloud session clears automatically when locking Owner view.

---

## 3. Technologies and Versions
* **Frontend:** HTML5, CSS3 (`styles.css`), Vanilla ES6+ JavaScript (`"use strict"`, HTML5 Canvas API, Web Crypto API `SHA-256`)
* **Local Storage & Offline PWA:** IndexedDB (`SariSafeDB`, schema v2), Service Worker API (`sw.js`, cache `sarisafe-v24`), Web App Manifest (`manifest.json`, `icon.svg`)
* **Cloud Backend:** Supabase (PostgreSQL with Row-Level Security, `sarisafe_touch` immutability triggers, security-definer write-only RPC `sarisafe_tender_sync`, Auth REST API v1, PostgREST v1 — schema in `supabase-setup.sql`)
* **Hosting & Tools:** Vercel Static Hosting (`vercel.json`), Python 3.x (`http.server`) or VS Code Live Server for local testing, Git & GitHub

---

## 4. Installation and Setup

### 4.1 Requirements
- A modern web browser supporting IndexedDB and Service Workers (Chrome 90+, Edge 90+, Firefox 90+, or Safari 15+).
- **For local testing:** Python 3.x (or VS Code Live Server). *Note: IndexedDB and Service Workers require `http://localhost` and will not work if opened directly via `file://`.*

### 4.2 Download / Clone

  git clone https://github.com/xyllannel-bit/sarisafe-app.git
    cd sarisafe-app

### 4.3 Configuration (Local vs. Cloud Sync)
- **Offline / Local Mode (Zero Setup Required):** SariSafe works out of the box with no `.env` file or server configuration. All records are stored locally in the browser's `SariSafeDB` IndexedDB database.
- **Optional Supabase Cloud Backend Setup:** The repository includes `supabase-setup.sql` containing the complete PostgreSQL table definitions, Row-Level Security (RLS) policies, immutability triggers, and the `sarisafe_tender_sync` RPC function. To connect your own Supabase instance:
  1. Create a new Supabase project and run `supabase-setup.sql` in the **SQL Editor**.
  2. Create a Store Owner user in **Authentication -> Users** and link their `user_id` with `role = 'owner'` in `public.sarisafe_profiles` (see Step 15 of `supabase-setup.sql`).
  3. Replace `SUPABASE_URL` and `SUPABASE_KEY` (publishable anon key) in `index.html` with your project's public credentials. *Never place a Supabase `service_role` key in client-side code.*

### 4.4 How to Start the Application
1. From the `sarisafe-app` folder, start a local static HTTP server:

       python3 -m http.server 8080

   *(On Windows, use `python -m http.server 8080`.)*
2. Open a browser and navigate to:

       http://localhost:8080

3. Alternatively, access the live deployed PWA directly at `[https://sarisafe.vercel.app/](https://sarisafe.vercel.app/)` (supports offline mode after first load and "Install App" prompt).

---

## 5. Sample Accounts / Test Data
* **Store Tender / Customer Counter View:** No login required; opens directly on the **Counter** tab. To start recording:
  1. Open the **Shift** tab, enter a sample Tender Name (e.g., `Tender Ana`), Starting Cash (`5000`), and Starting GCash Wallet (`10000`), then tap **Start shift**.
  2. Return to **Counter** and enter sample test data:
     * **GCash Reference (last 5 digits):** `48291`
     * **Type:** `Cash-In` (or `Cash-Out` to test the `Pending` confirmation queue)
     * **Amount:** `500` (auto-fills `₱10` service fee)
     * **Customer Name:** `Juan Dela Cruz`
     * **Phone:** `09123456789`
     * Draw a sample signature on the canvas pad, tick the accuracy & Privacy Policy checkbox, and tap **Save transaction**.
  3. Re-enter `48291` in the reference field to verify the instant duplicate warning modal.
* **Store Owner View (Local PIN):**
  * Tap **Owner login** in the top-right header and enter the default 4-digit PIN: **`1234`** (can be changed under **Fees -> Change owner PIN**).
* **Owner Cloud Sync (Optional):**
  * Requires an authenticated Supabase Owner account (`role = 'owner'` in `sarisafe_profiles`). Evaluators without Owner cloud credentials can test all Owner features (`Summary`, `Log`, `Fees`, `Backup` CSV/JSON export & restore) using local IndexedDB data.

---

## 6. Running the Tests
SariSafe uses a structured manual and browser DevTools test suite documented in `docs/testing/` (Lab Worksheet 11):
1. Start the local server (`python3 -m http.server 8080`) and open `http://localhost:8080` in Chrome/Edge.
2. Open **DevTools (`F12`)**:
   * **Application -> IndexedDB -> SariSafeDB:** Inspect `transactions`, `shifts`, and `settings` object stores, plus the `ref` and `tail` indexes.
   * **Application -> Service Workers / Network -> Offline:** Toggle **Offline** mode and reload the page to verify offline PWA shell loading and offline transaction recording (`FR-004`, `NFR-004`).
   * **Console:** Verify zero uncaught JavaScript errors during duplicate lookup, signature capture, shift closing, and CSV/JSON export.
3. Execute test cases `TC-01` through `TC-18` in `docs/testing/` (covering unit validation/fee math, integration with IndexedDB/Supabase RPC, system workflows, and acceptance scenarios).

---

## 7. Project Structure

    sarisafe-app/
    ├── index.html           # Main PWA entry point: Counter, Shift, and Owner views, IndexedDB & sync logic
    ├── styles.css           # Responsive GCash-inspired styling, PIN keypad, modals, and print receipt layout
    ├── sw.js                # Network-first Service Worker for offline caching of the app shell
    ├── manifest.json        # PWA manifest configuration (name, theme color, standalone display, icon)
    ├── icon.svg             # Vector shield-checkmark application icon
    ├── supabase-setup.sql   # PostgreSQL schema, immutability triggers, write-only tender RPC, and RLS policies
    ├── vercel.json          # Vercel security headers (nosniff, X-Frame-Options DENY, no-referrer) & SW cache rules
    ├── .gitignore           # Excludes environment files, OS metadata, and exported customer CSV/JSON backups
    ├── .gitattributes       # Enforces automatic LF line-ending normalization
    ├── README.md            # Project overview, setup instructions, test data, and final build metadata
    ├── STYLE_GUIDE.md       # Team coding, naming, formatting, and security standards
    ├── CONTRIBUTING.md      # Feature branch workflow, commit conventions, and peer-review checklist
    └── docs/
        └── testing/         # Lab Worksheet 11: Software Test Plan, Test Cases, Results, and Defect Reports

---

## 8. Team (SariSafe Navigators – Section ABJQ1 / BDLR1)
* **Tabita, Steward C.** — Project Leader, Shift Reconciliation & QA / Testing Lead
* **Lagare, Xyll Anne M.** — Lead Developer & Software Release Lead (Core PWA, IndexedDB, Supabase Sync & Deployment)
* **Ardita, Jeneth Diaz** — Frontend / UX Developer & Compilation Lead (UI/CSS, Signature Pad, Privacy Policy & Documentation)
* **Dumanillo, Dillian B.** — Frontend / Data Developer & Evidence Custodian (Fee Tiers, Owner PIN, CSV/JSON Backup & Storage Health)

---

## 9. Known Limitations
- **Last-5-digit reference matching (`REF_DIGITS=5`):** The system matches only the last 5 digits of the 13-digit GCash reference number to speed up counter verification. Rare collisions with different receipts sharing the same last 5 digits require using the *"Different receipt – continue"* override and manually checking the full 13-digit number on the customer's GCash screen.
  
* **No Direct GCash / e-Wallet API Integration:** In accordance with project scope exclusions (no official GCash partner merchant API access), SariSafe records and verifies reference numbers entered at the counter rather than automatically querying GCash servers or transferring funds.
  
* **Single-Store Scope:** The database schema and UI are tailored for a single store (`Fuentez Store`) and do not include multi-branch inventory or *utang* (credit) ledger tracking.
  
* **Browser Storage Volatility if Cleared Manually:** Because offline records live in browser IndexedDB (`SariSafeDB`), clearing browser site data on a device that has not synced to Supabase or exported a JSON backup will erase un-synced local records.

---

## 10. Final Version
* **Repository:** [https://github.com/xyllannel-bit/sarisafe-app.git](https://github.com/xyllannel-bit/sarisafe-app.git)
* **Live URL:** [https://sarisafe.vercel.app/](https://sarisafe.vercel.app/)

---


## 11. Store Tender Daily Quick Checklist
* **Before Shift Start:** Verify the offline indicator shows `Ready` and confirm opening physical cash on hand matches the previous shift's Z-reading.
* **During Transactions:** Always enter the exact GCash reference number before releasing cash or completing a Cash-In transfer so duplicate detection triggers immediately.
* **End of Shift:** Export a CSV backup to the local device before running shift reconciliation and syncing pending records online.
