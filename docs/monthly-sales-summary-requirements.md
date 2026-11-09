# Monthly Sales Summary

Salesforce application, built mainly in Apex.

An international company that operates in the United States and Israel. Sales managers want to see a monthly sales summary by salesperson.

## Screen

- The user selects a salesperson from a lookup. The default is the current user. The lookup shows active users only.
- The user can switch the summary between NIS and USD. NIS is the default. A month is still marked red from its ILS total.
- After the selection: a summary of the last 12 months, including the current month, by calendar month.
- For each month: the month name, the year, and the total sales amount.
- A month that had sales, with a total under 1,000 ILS, is marked in red.
  - The business has not closed on this figure. A follow-up requirement will arrive about marking an amount in red. For now, treat 1,000 ILS as written.
- Below the table: the total amount of all 12 months.
- If there are no sales at all: show a toast, and do not show the table.

## Background

The company stores customers as Account records in Salesforce. Each customer has a salesperson, defined as the owner of the Account record. Sales data must be stored in the environment. Each sale is related to a specific customer and contains a date and an amount.

## Business background

- A sale belongs to the customer's current salesperson, even if the customer changed owners in the past.
- The component must work correctly even if a salesperson has hundreds of customers and thousands of sales.

## Currency

- A sale amount is either ILS (NIS) or USD.
- The org uses Salesforce multi-currency. Active currencies are ILS and USD. The corporate currency is confirmed in the org and left unchanged. The summary shows NIS (ILS) or USD, chosen on the screen. NIS is the default.
- Each sale keeps the currency it was entered in, on the standard `CurrencyIsoCode` field. `Amount__c` stays a currency field.

## Assumptions

- A month's total is the sum of its sales after each amount is converted to ILS with the org exchange rate. The screen shows that total in ILS.
- The red highlight compares the converted ILS total with 1,000 ILS.
- Conversion uses the static rate on Currency Type. Dated exchange rates apply to opportunities, so they are not used for this custom object.

## 5. Permissions

Create the appropriate permission structure (Permission Set / Custom Permission) and make sure the component respects it. A salesperson who does not have manager permission cannot change the lookup.

| Role | What they can do |
| --- | --- |
| Salesperson | Sees only their own data. Cannot select another user. |
| Sales manager | Can select any salesperson and see that person's data. |

## 6. Guidelines

- Design and build the data structure that stores the sales.
- Create a test class for every Apex class that is written.
- Use standard components as much as possible.
- Grant System Administrator access to the team.
- Document what was built and where to find the development in the environment.
- If business assumptions were made, state them.
