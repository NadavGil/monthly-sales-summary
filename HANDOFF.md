# Monthly Sales Summary — Handoff

The project folder is `~/Desktop/monthly-sales-summary`. Requirements, the plan, and the test plan are in `docs/`. Deploy and test commands are in `README.md`.

## This org

| | |
| --- | --- |
| Alias | `dev-edition` |
| Username | `nadav.gilron.e1572ad0756b@agentforce.com` |
| Org ID | `00DjV000008CSTlUAO` |
| Instance | `https://orgfarm-cff7fcde60-dev-ed.develop.my.salesforce.com` |
| CLI | `@salesforce/cli/2.157.8` |

This user is a System Administrator and is assigned `Sales_Summary_User` and `Sales_Manager`. `scripts/review-admin.apex` creates a second System Administrator for the reviewing team. `scripts/salesman.apex` creates Sample Salesperson.

Multi-currency is on. The corporate currency is **USD**, conversion rate **1**. **ILS** is active, conversion rate **3.18** (1 USD = 3.18 ILS), set 9 Nov 2026. Advanced Currency Management is off. Dated rates are not used. Deploy does not change these rates. Totals on the screen are still converted to ILS with the current static rate, so a later rate change updates past months.

`Sales_Summary_Low_Amount` is **1000**.

## Deploys

| Phase | Deploy ID |
| --- | --- |
| Data model | `0AfjV000006FSN7SAO` |
| Permissions | `0AfjV000006FP99SAG` |
| Summary service | `0AfjV000006FS2ASAW` |
| Screen | `0AfjV000006FWFRSA4` |
| Account Sales related list | `0AfjV000006FVUgSAO` |

Apex tests passed in run `707jV00000Aifbi` (20 tests). The screen has no Apex tests. The org checks are in `docs/monthly-sales-summary-test-plan.md`.

## Where to find it

| What was built | Where it is in the org |
| --- | --- |
| Sale object, fields, auto-number `SAL-{0000}` starting at 1 | Setup → Object Manager → Sale |
| `AmountNumber__c` | Sale → Fields. Number formula equal to `Amount__c`. The grouped query sums this because a grouped sum of the currency field is returned in USD. |
| Currency rule | Sale → Validation Rules → `Currency_Is_ILS_Or_USD` |
| Sales tab | Sales app, and App Launcher → Sales |
| Sales on a customer | Account page → Related → Sales. Deployed on the Account, Sales, Support, and Marketing layouts (`0AfjV000006FVUgSAO`). |
| Summary screen | Sales app → Sales Summary |
| App page and component | Setup → Lightning App Builder → Sales Summary. Component `salesSummary`. |
| Who can open the screen | Setup → Permission Sets → Sales Summary User |
| Who can change the lookup | Setup → Permission Sets → Sales Manager |
| Lookup permission | Setup → Custom Permissions → Select Any Salesperson |
| Red-amount threshold | Setup → Custom Labels → Sales Summary Low Amount (`1000`) |
| Summary logic | Apex classes `SalesSummaryController`, `SalesSummaryService`, `SalesSummarySelector` |
| Test classes | `SalesSummaryControllerTest`, `SalesSummaryServiceTest`, `SalesSummarySelectorTest` |

The Sales Summary tab was added to the standard Sales app in App Manager. That navigation is not in the repository. On another org, after deploy: Setup → App Manager → Sales → Edit → Navigation Items → add Sales Summary → Save.

## Access

The team can sign in as **Review Administrator**, a System Administrator created by `scripts/review-admin.apex`. The username is `review.admin.00DjV000008CSTlUAO@agentforce.com` and the password is `Review2026`. The email is the admin's email. The script also assigns `Sales_Summary_User` and `Sales_Manager`, so the salesperson lookup is editable. Running it again does not reset the password.

```bash
sf apex run --file scripts/review-admin.apex --target-org dev-edition
```

`scripts/salesman.apex` creates one sample salesperson when you run it.

A System Administrator does not receive `Select_Any_Salesperson` from the profile. Assign both permission sets to each admin who should use the screen:

```bash
sf org assign permset --name Sales_Summary_User --name Sales_Manager --target-org dev-edition
```

A salesperson receives `Sales_Summary_User` only. A sales manager receives both. Permission sets add access. They cannot remove access a profile already grants.

## Sample data

`scripts/seed.apex` creates two accounts owned by the user who runs it, and one sale on each:

- **Seed Harbor**, 15th of the current org month, 500 USD. At 3.18 that month is 1,590.00 ILS and is not red.
- **Seed Inland**, 15th of the previous month, 400 ILS. That month is red.

```bash
sf apex run --file scripts/seed.apex --target-org dev-edition
```

Running it again does not create a second pair. Sales already in the org stay. On this org, Nadav's existing November sale remains in his summary together with the seed.

`scripts/live.apex` adds seven customers and thirty sales from December 2025 through November 2026, in ILS and USD, including one return. At 3.18, December, February, April, August, and October stay under 1,000 ILS.

```bash
sf apex run --file scripts/live.apex --target-org dev-edition
```

`scripts/salesman.apex` creates **Sample Salesperson**, a Standard User with `Sales_Summary_User` only. The username is `sample.salesperson.00DjV000008CSTlUAO@agentforce.com` and the password is `Sales2026`. The email is the admin's email. This user owns Galilee Produce, Eilat Dive Center, and Jerusalem Stone. At 3.18, September and October are the red months. Select this user in the Salesperson lookup to see that book. Logging in as this user leaves the lookup on Sample Salesperson and disables it.

```bash
sf apex run --file scripts/salesman.apex --target-org dev-edition
sf apex run --file scripts/salesman.apex --target-org dev-edition
```

The first run creates the user. The second run adds the customers and sales. A user and an account cannot be created in one execution.

An empty window shows the info toast "No sales in the last 12 months." and no table.

## Assumptions

- A sale belongs to the customer's current Account owner, including after an owner change.
- Month totals are shown in NIS or USD, chosen on the screen. NIS is the default. Each sale is converted with the current static exchange rate. A later rate change updates past months. A month is red from its ILS total, including when the screen shows USD.
- The 12 months follow the organization timezone. Month names are English.
- Each month is rounded half up to 2 decimal places. The total is the sum of those 12 amounts.
- A month is red only when it had sales and its rounded amount is below `Sales_Summary_Low_Amount`. The total is never red. A month of exactly 1,000.00 ILS is not red. A month with no sales is 0.00 and is not red.
- No sales in the window shows a toast and no table. A rejected request shows an error toast with the Apex message.
- Negative amounts are allowed and are included in the month total.
- Deleting an Account that still has sales is blocked. An Account with no sales can be deleted. Reparenting a sale is allowed by editing `Account__c`.
- A salesperson sees only their own summary. A sales manager can select any active user.
