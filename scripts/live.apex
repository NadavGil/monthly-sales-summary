// A year of customers and sales for the running user, Dec through the current month.
// Running this again does not add a second set. Existing sales stay.

String timeZoneSid = [SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey;
Date orgToday = Date.valueOf(System.now().format('yyyy-MM-dd', timeZoneSid));
Id ownerId = UserInfo.getUserId();
List<String> names = new List<String>{
    'Carmel Retail',
    'Tel Aviv Medical',
    'Desert Logistics',
    'Haifa Electronics',
    'Blue Coast Hotels',
    'Negev Solar',
    'Jordan Valley Foods'
};
List<String> rows = new List<String>{
    'Carmel Retail|2025-12-04|180|ILS',
    'Desert Logistics|2025-12-16|120|USD',
    'Carmel Retail|2026-01-12|2500|ILS',
    'Tel Aviv Medical|2026-01-20|800|USD',
    'Blue Coast Hotels|2026-01-05|1500|ILS',
    'Haifa Electronics|2026-02-11|420|ILS',
    'Jordan Valley Foods|2026-02-03|150|ILS',
    'Carmel Retail|2026-03-18|960|ILS',
    'Tel Aviv Medical|2026-03-02|1500|USD',
    'Negev Solar|2026-03-25|210|ILS',
    'Desert Logistics|2026-04-09|75|USD',
    'Haifa Electronics|2026-04-21|200|ILS',
    'Carmel Retail|2026-05-06|3200|ILS',
    'Desert Logistics|2026-05-19|450|USD',
    'Blue Coast Hotels|2026-05-27|220|USD',
    'Tel Aviv Medical|2026-06-11|2100|ILS',
    'Tel Aviv Medical|2026-06-25|-150|ILS',
    'Jordan Valley Foods|2026-06-02|480|USD',
    'Carmel Retail|2026-07-22|890|ILS',
    'Desert Logistics|2026-07-08|600|USD',
    'Negev Solar|2026-07-30|1400|ILS',
    'Haifa Electronics|2026-08-14|90|ILS',
    'Jordan Valley Foods|2026-08-22|60|USD',
    'Carmel Retail|2026-09-09|430|ILS',
    'Tel Aviv Medical|2026-09-16|1750|USD',
    'Negev Solar|2026-09-02|80|USD',
    'Desert Logistics|2026-10-07|120|ILS',
    'Jordan Valley Foods|2026-10-28|85|USD',
    'Carmel Retail|2026-11-03|750|ILS',
    'Blue Coast Hotels|2026-11-08|300|USD'
};

List<Account> existing = [
    SELECT Id
    FROM Account
    WHERE OwnerId = :ownerId AND Name IN :names
];

if (existing.isEmpty()) {
    List<Account> accounts = new List<Account>();
    for (String name : names) {
        accounts.add(new Account(Name = name, OwnerId = ownerId));
    }
    insert accounts;

    Map<String, Id> accountIds = new Map<String, Id>();
    for (Account account : accounts) {
        accountIds.put(account.Name, account.Id);
    }

    List<Sale__c> sales = new List<Sale__c>();
    for (String row : rows) {
        List<String> parts = row.split('\\|');
        Date saleDate = Date.valueOf(parts[1]);
        if (saleDate > orgToday) {
            continue;
        }
        sales.add(
            new Sale__c(
                Account__c = accountIds.get(parts[0]),
                SaleDate__c = saleDate,
                Amount__c = Decimal.valueOf(parts[2]),
                CurrencyIsoCode = parts[3]
            )
        );
    }
    insert sales;
    System.debug('Live sample created ' + accounts.size() + ' accounts and ' + sales.size() + ' sales.');
} else {
    System.debug('Live sample accounts already exist for this user. No new records were created.');
}
