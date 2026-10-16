import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue, notifyRecordUpdateAvailable } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import CATEGORY from '@salesforce/schema/Case.AI_Category__c';
import PRIORITY from '@salesforce/schema/Case.AI_Priority__c';
import SUMMARY from '@salesforce/schema/Case.AI_Summary__c';
import REPLY from '@salesforce/schema/Case.AI_Suggested_Reply__c';
import STATUS from '@salesforce/schema/Case.AI_Status__c';

export default class CaseAiAssistant extends LightningElement {
    @api recordId;
    draft; // agent's edits; undefined until they type

    @wire(getRecord, { recordId: '$recordId', fields: [CATEGORY, PRIORITY, SUMMARY, REPLY, STATUS] })
    record;

    get category() { return getFieldValue(this.record.data, CATEGORY); }
    get priority() { return getFieldValue(this.record.data, PRIORITY); }
    get summary() { return getFieldValue(this.record.data, SUMMARY); }
    get status() { return getFieldValue(this.record.data, STATUS); }
    get reply() { return this.draft ?? getFieldValue(this.record.data, REPLY) ?? ''; }

    get isDone() { return this.status === 'Done'; }
    get isError() { return this.status === 'Error'; }
    get isWaiting() { return !this.isDone && !this.isError; }

    handleEdit(event) { this.draft = event.target.value; }

    // The classifier runs async, so the page doesn't know when it finishes.
    refresh() { notifyRecordUpdateAvailable([{ recordId: this.recordId }]); }

    async copy() {
        try {
            await navigator.clipboard.writeText(this.reply);
            this.dispatchEvent(new ShowToastEvent({ title: 'Reply copied', variant: 'success' }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({ title: 'Copy failed', message: 'Select the text and copy it manually.', variant: 'error' }));
        }
    }
}
