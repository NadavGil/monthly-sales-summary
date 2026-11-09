import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';
import canSelectAnySalesperson from '@salesforce/customPermission/Select_Any_Salesperson';
import getSummary from '@salesforce/apex/SalesSummaryController.getSummary';

const EMPTY_MESSAGE = 'No sales in the last 12 months.';

export default class SalesSummary extends LightningElement {
    salespersonId = Id;
    currencyCode = 'ILS';
    displayCurrency = 'ILS';
    loading = false;
    hasSales = false;
    total;
    rows = [];
    requestSerial = 0;

    currencyOptions = [
        { label: 'NIS', value: 'ILS' },
        { label: 'USD', value: 'USD' }
    ];

    userFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };

    get columns() {
        return [
            { label: 'Month', fieldName: 'name', type: 'text' },
            { label: 'Year', fieldName: 'year', type: 'text' },
            {
                label: 'Amount',
                fieldName: 'amount',
                type: 'currency',
                typeAttributes: {
                    currencyCode: this.displayCurrency,
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                },
                cellAttributes: { class: { fieldName: 'amountClass' } }
            }
        ];
    }

    get pickerDisabled() {
        return !canSelectAnySalesperson;
    }

    get showTable() {
        return this.hasSales && !this.loading;
    }

    connectedCallback() {
        this.loadSummary(this.salespersonId);
    }

    handleSalespersonChange(event) {
        const userId = event.detail.recordId;
        if (userId === this.salespersonId) {
            return;
        }
        this.salespersonId = userId;
        if (!userId) {
            this.requestSerial += 1;
            this.loading = false;
            this.clearSummary();
            return;
        }
        this.loadSummary(userId);
    }

    handleCurrencyChange(event) {
        const currencyCode = event.detail.value;
        if (currencyCode === this.currencyCode) {
            return;
        }
        this.currencyCode = currencyCode;
        if (!this.salespersonId) {
            return;
        }
        this.loadSummary(this.salespersonId);
    }

    async loadSummary(userId) {
        const serial = ++this.requestSerial;
        this.loading = true;
        this.clearSummary();
        try {
            const summary = await getSummary({ userId, currencyCode: this.currencyCode });
            if (serial !== this.requestSerial) {
                return;
            }
            this.displayCurrency = summary.currencyCode;
            this.hasSales = summary.hasSales;
            this.total = summary.total;
            this.rows = (summary.months || []).map((month) => ({
                key: `${month.year}-${month.name}`,
                name: month.name,
                year: String(month.year),
                amount: month.amount,
                amountClass: month.highlight ? 'slds-text-color_error' : ''
            }));
            if (!summary.hasSales) {
                this.toast(EMPTY_MESSAGE, 'info');
            }
        } catch (error) {
            if (serial !== this.requestSerial) {
                return;
            }
            this.clearSummary();
            this.toast(this.messageFrom(error), 'error');
        } finally {
            if (serial === this.requestSerial) {
                this.loading = false;
            }
        }
    }

    clearSummary() {
        this.hasSales = false;
        this.total = null;
        this.rows = [];
    }

    messageFrom(error) {
        const body = error && error.body;
        if (Array.isArray(body)) {
            return body.map((item) => item.message).join(', ');
        }
        if (body && typeof body.message === 'string') {
            return body.message;
        }
        return 'The sales summary could not be loaded.';
    }

    toast(message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Sales Summary',
                message,
                variant
            })
        );
    }
}
