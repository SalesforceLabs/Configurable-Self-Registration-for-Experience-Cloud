import { LightningElement, api } from 'lwc';

export default class customPropertyEditorCreateType extends LightningElement {
    
    @api value;

    get options() {
        return [
            { label: 'Contact', value: 'Contact' },
            { label: 'Person Account', value: 'Person Account' },
        ];
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent("valuechange", 
        {detail: {value: this.value}}));
    }
}