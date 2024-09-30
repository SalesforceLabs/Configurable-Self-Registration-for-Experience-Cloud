import { LightningElement, wire, api } from 'lwc';
import getNetworkGroupMembers from '@salesforce/apex/SiteUtilities.getProfileMembers';

export default class customPropertyEditorProfiles extends LightningElement {
    
    @api value;

    profiles;
    jsonString;

    getCookie(name) {
        var nameEQ = name + "=";
        var ca = document.cookie.split(';');

        for(var i=0;i < ca.length;i++) {
            var c = ca[i];
            while (c.charAt(0)==' ') c = c.substring(1,c.length);
            if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
        }
        return '';
    }

    //In CPE context, importing the site Id returns null/error in Exp. Builder. 
    //Get the SiteId from the cookies as a workaround
    @api cookie = this.getCookie('lastSiteId');

    @wire(getNetworkGroupMembers, {networkId: '$cookie'})
    wiredProfiles({error, data}) {
        if(data) {
            this.jsonString = JSON.parse(data);
            this.profiles = Object.values(this.jsonString.memberProfiles);            
        }
    }
    
    get options() {
        return this.profiles;
    }

    handleChange(event) {
        this.value = event.detail.value;
        this.dispatchEvent(new CustomEvent("valuechange", 
        {detail: {value: this.value}}));
    }
}