import { LightningElement, wire, api } from 'lwc';
import getPersonAccountRecordTypes from '@salesforce/apex/SiteUtilities.getPersonAccountRecordTypes';

export default class customPropertyEditorRecordTypes extends LightningElement {
    
    @api value;

    objectType = 'Account';
    rt;
    jsonString;

    @wire(getPersonAccountRecordTypes, {objectType: 'Account'})
    wiredRecordTypes({error, data}) {
        if(data) {
            this.jsonString = JSON.parse(data);
            this.rt = this.jsonString.recordTypes;
        }
    }
    
    get options() {
        return this.rt;
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent("valuechange", 
        {detail: {value: this.value}}));
    }
}