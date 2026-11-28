# Contributing to SariSafe
**Repository:** `[https://github.com/xyllannel-bit/sarisafe-app.git](https://github.com/xyllannel-bit/sarisafe-app.git)`  
**Team:** SariSafe Navigators (Ardita, Dumanillo, Lagare, Tabita)  

---

## 1. Branching Strategy
We follow a **Feature Branch Workflow** with `main` protected as our stable, deployable release branch (automatically deployed to Vercel at `[https://sarisafe.vercel.app/](https://sarisafe.vercel.app/)`):

* **`main`** — Always runnable, clean, and verified. Direct pushes of untested code are avoided; changes enter via reviewed Pull Requests.
* **`feature/<short-kebab-name>`** — New features or requirement implementations (e.g., `feature/offline-db-sync`, `feature/shift-reconciliation`, `feature/cashout-pending-queue`).
* **`fix/<defect-id-or-topic>`** — Bug fixes traced to test cases or defect reports (e.g., `fix/df-01-duplicate-tail-index`, `fix/csv-date-filter`).
* **`docs/<topic>`** — Documentation, style guide, README, and testing artifacts (e.g., `docs/style-guide-testing`, `docs/readme-privacy`).

### Creating a Branch

    git checkout main
    git pull origin main
    git checkout -b feature/<short-kebab-name>

---

## 2. Commit Message Conventions
Write clear, imperative commit messages that describe **what changed** and reference relevant **SRS requirement IDs**, **test case IDs**, or **defect IDs**:

    <type>(<scope>): <imperative summary> [Ref/Req/Defect ID]

### Allowed Types
* `feat`: New feature or functional requirement (`feat(counter): add 5-digit duplicate tail lookup [FR-001, FR-002]`)
* `fix`: Bug fix or defect resolution (`fix(shift): warn tender of pending cash-outs before closing [DF-03, FR-011]`)
* `sec`: Security, privacy, or RLS update (`sec(supabase): enforce write-only tender RPC and owner RLS [NFR-006]`)
* `style`: CSS/UI adjustments without logic changes (`style(receipt): format auto-popup thermal receipt layout`)
* `docs`: README, style guide, or testing documentation (`docs(testing): add LW11 test plan and Run 1 results`)
* `chore`: Service worker cache bump or config updates (`chore(sw): bump cache version to sarisafe-v24`)

### History Integrity Rule
* **Do not rewrite shared Git history.** Never use `git push --force` on `main` or delete commit history. Every team member must commit under their own GitHub account.

---

## 3. Pull Request & Peer-Review Workflow
1. Push your feature or fix branch to GitHub (`git push -u origin <branch-name>`).
2. Open a **Pull Request (PR)** targeting `main` with:
   * A short summary of changes and affected files.
   * The SRS requirement IDs (`FR-001`–`FR-012`, `NFR-001`–`NFR-006`) or Defect IDs (`DF-01`+) addressed.
   * Confirmation that the app was tested offline and on mobile/desktop viewports.
3. Assign **at least one teammate** to review the PR using the **Peer-Review Checklist** below.
4. Resolve all review comments, merge into `main`, and verify the live Vercel preview.

---

## 4. Peer-Review Checklist
Reviewers must verify every item below before approving a Pull Request:

- [ ] **1. Requirement Traceability:** Does the code cite the SRS requirement IDs (`FR-001`–`FR-012`, `NFR-001`–`NFR-006`) in section comments or PR notes?
- [ ] **2. Offline-First Reliability (`FR-004`, `NFR-004`):** Does the feature work completely offline via IndexedDB (`SariSafeDB`) without failing when `navigator.onLine` is `false`?
- [ ] **3. Data Privacy & Security (`NFR-006`, RA 10173):** Are customer names, phone numbers, and signatures protected against XSS (`esc()`, `safeSig()`), CSV injection (`qs()`), and unauthorized tender `SELECT` queries?
- [ ] **4. Financial Immutability (`FR-010`, `BR-003`):** Are confirmed `OK` transactions locked against edits/deletions, allowing reversals only via offsetting `Correction` entries with a reason?
- [ ] **5. Clean Repository Hygiene:** Are `.env` files, real passwords, private keys, and exported customer `.csv`/`.json` files excluded from the commit?
- [ ] **6. Code Style & Formatting:** Does the code follow `STYLE_GUIDE.md` (`camelCase` JS, `UPPER_SNAKE_CASE` constants, `kebab-case` CSS, 2-space indentation, `"use strict"`)?
- [ ] **7. Service Worker Cache Bump:** If `index.html`, `styles.css`, `manifest.json`, or `icon.svg` changed, was `CACHE` incremented in `sw.js`?

---

## Local Testing & Offline Verification
* **IndexedDB Check:** Before opening a Pull Request, verify that Cash-In and Cash-Out entries persist after refreshing the browser while offline.
* **Duplicate Reference Guard:** Test entering an existing GCash reference number to confirm the warning modal blocks duplicate logging.
* **Branch Hygiene:** Keep each Pull Request focused on a single feature, style refinement, or documentation update with descriptive commit messages.