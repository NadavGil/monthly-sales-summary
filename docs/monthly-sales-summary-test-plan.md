# Monthly Sales Summary — Test Plan

Source: [monthly-sales-summary-plan.md](./monthly-sales-summary-plan.md)

The brief requires a test class for every Apex class. The result types live inside `SalesSummaryService`, so they do not get a test class of their own. The screen has no Apex of its own, so it is checked in the org rather than with an Apex test.

The service builds the 12 months from a given date. Tests pass a fixed date so they do not depend on the clock.

## How the team runs the tests

From the repository, after deploy:

```bash
sf apex run test \
  --tests SalesSummaryControllerTest \
  --tests SalesSummaryServiceTest \
  --tests SalesSummarySelectorTest \
  --result-format human \
  --wait 10
```

These classes create their own users, accounts, and sales. They do not depend on `scripts/seed.apex`.

The checks in the org come after the seed. The running user needs `Sales_Summary_User` and `Sales_Manager`.

## Apex tests

### `SalesSummaryControllerTest`

- A salesperson can load their own summary.
- A salesperson requesting another user is rejected with "You can only view your own sales summary."
- A salesperson requesting a null id is rejected with "Select an active user."
- A sales manager can load an active user.
- A sales manager requesting an inactive user, a null id, or an unknown id is rejected with "Select an active user."

### `SalesSummaryServiceTest`

- The payload is 12 months, oldest first, including the current month, for a fixed date.
- Names are English.
- A month with no sales is `0.00` and is not highlighted.
- No sales in the window returns `hasSales` false and no month rows.
- ILS and USD sales in one month are converted, rounded to 2 decimal places, and the total equals the sum of the 12 months.
- A rounded amount below the label is highlighted. An amount equal to the label is not.
- A sale counts for the Account’s current owner after the owner changes.
- A sale dated before the 12-month window is excluded.
- A sale on the first day of the oldest month is included. A sale on the last day of the current month is included. A sale on the day after the current month is excluded.
- Two amounts in one month are added before rounding. `0.004 + 0.004` becomes `0.01`.
- A raw month total that rounds up to `1000.00` is not highlighted.
- A negative amount is included. That month had sales and is highlighted.
- USD display converts the month, then rounds. The highlight still uses the ILS total. `400` ILS is `125.79` USD at rate `3.18` and stays red. `500` USD stays `500.00` and is not red, because `1,590.00` ILS is not below the label. `NIS` is accepted as ILS. Any other currency is rejected with "Select NIS or USD."

### `SalesSummarySelectorTest`

- The grouped query returns year, month, currency, and sum for the owner and the date window.
- Sales for another Account owner are not included.
- A sale whose record owner is someone else is included when the Account owner is the selected user.

## Checks in the org

These use the Sales Summary tab. An empty org shows the toast "No sales in the last 12 months." Sale records have to be created before the table appears.

- A salesperson opens Sales Summary, sees their own months, and cannot change the lookup.
- A sales manager selects another active user and sees that person's months.
- A month under the label is red. A month with no sales is `0.00` and is not red. The total is never red.
- A salesperson with no sales in the window gets the info toast and no table.
- A rejected request shows an error toast with the Apex message, not the empty-sales toast.
- A sale in a currency other than ILS or USD cannot be saved.
- An Account that has a sale cannot be deleted.
- An Account with no sales can be deleted.

## Where the test classes are

Setup → Apex Classes:

- `SalesSummaryControllerTest`
- `SalesSummaryServiceTest`
- `SalesSummarySelectorTest`
