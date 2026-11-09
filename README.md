# Monthly Sales Summary

Salesforce app for a monthly sales summary by salesperson. The plan and the test plan are in `docs/`. Where each piece lives in the org is in `HANDOFF.md`.

The target org on this machine is the Developer Edition alias `dev-edition`. Multi-currency is already on, with USD as the corporate currency and ILS at 3.18. Deploy does not turn multi-currency on and does not change those rates.

## Run it

From this folder, as a System Administrator:

```bash
sf project deploy start --source-dir force-app --target-org dev-edition
sf org assign permset --name Sales_Summary_User --name Sales_Manager --target-org dev-edition
sf apex run test \
  --class-names SalesSummaryControllerTest \
  --class-names SalesSummaryServiceTest \
  --class-names SalesSummarySelectorTest \
  --result-format human \
  --wait 10 \
  --target-org dev-edition
sf apex run --file scripts/seed.apex --target-org dev-edition
sf apex run --file scripts/live.apex --target-org dev-edition
sf apex run --file scripts/salesman.apex --target-org dev-edition
```

Then open the Sales app → Sales Summary. On a new org, add the tab once: Setup → App Manager → Sales → Edit → Navigation Items → add Sales Summary → Save.

`scripts/seed.apex` adds two accounts owned by the user who runs it: 500 USD in the current month (1,590.00 ILS at 3.18, not red) and 400 ILS in the previous month (red). `scripts/live.apex` adds seven more customers and sales across the last 12 months, in both currencies, including a return. Running either script again does not add a second set. Sales already in the org stay in the summary.

## Phases

| Phase | What | Status |
| --- | --- | --- |
| 1 | Data model: `Sale__c`, currency rule, Sales tab | Deployed (`0AfjV000006FSN7SAO`) |
| 2 | Permissions | Deployed (`0AfjV000006FP99SAG`) |
| 3 | Summary service | Deployed (`0AfjV000006FS2ASAW`), 20 tests passed (`707jV00000Aifbi`) |
| 4 | Screen | Deployed (`0AfjV000006FWFRSA4`) |
| 5 | Handoff | Seeded on `dev-edition` |

## Deploy phase 1

The target org is the Developer Edition alias `dev-edition`. Multi-currency is already on, with USD as the corporate currency and ILS at 3.18.

```bash
sf project deploy start --source-dir force-app --target-org dev-edition
```

## Deploy phase 2

This adds the custom permission `Select_Any_Salesperson` and the permission sets `Sales_Summary_User` and `Sales_Manager`. `SalesSummaryController` is granted in phase 3. The Sales Summary tab is granted in phase 4.

Assign both sets to the Developer Edition admin so the Sales tab is visible and the lookup permission is present:

```bash
sf project deploy start --source-dir force-app --target-org dev-edition
sf org assign permset --name Sales_Summary_User --name Sales_Manager --target-org dev-edition
```

## Deploy phase 3

This adds the summary Apex, its tests, and the `Sales_Summary_Low_Amount` label (`1000`). Both permission sets can call `SalesSummaryController`.

```bash
sf project deploy start --source-dir force-app --target-org dev-edition
sf apex run test \
  --tests SalesSummaryControllerTest \
  --tests SalesSummaryServiceTest \
  --tests SalesSummarySelectorTest \
  --result-format human \
  --wait 10 \
  --target-org dev-edition
```

## Deploy phase 4

This adds the `salesSummary` screen, the Sales Summary app page, and the Sales Summary tab. Both permission sets can see the tab. The lookup starts on the current user. With `Sales_Manager`, it lists active users.

```bash
sf project deploy start --source-dir force-app --target-org dev-edition
```

Then add the tab to the Sales app: Setup → App Manager → Sales → Edit → Navigation Items → add Sales Summary → Save. App Launcher can also open Sales Summary directly.
