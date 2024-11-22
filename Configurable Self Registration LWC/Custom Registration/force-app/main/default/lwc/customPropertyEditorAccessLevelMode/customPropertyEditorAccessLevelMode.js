import { LightningElement, api } from 'lwc';

export default class customPropertyEditorAccessLevelMode extends LightningElement {
    
    @api value;

    get options() {
        return [
            { label: 'System', value: 'System' },
            { label: 'User', value: 'User' },
        ];
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent("valuechange", 
        {detail: {value: this.value}}));
    }
}