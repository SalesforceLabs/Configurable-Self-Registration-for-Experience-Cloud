/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 02/09/2026
 * PURPOSE        : Login LWC for Experience Builder pages.
 * SPECIAL NOTES  : Replaces customLoginCPE. Every setting is read from the "Login Settings" record of the
 *                  Custom Experience Cloud Setting metadata type, so this component exposes no Experience
 *                  Builder properties.
 *****************************************************************************************************/

import {LightningElement, track, wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import loginUser from '@salesforce/apex/SiteLoginController.loginUser';
import getCustomConfiguration from '@salesforce/apex/SiteUtilities.getCustomConfiguration';
import verifyUser from '@salesforce/apex/SiteUtilities.verifyUser';
import getDisplaySettings from '@salesforce/apex/SiteUtilities.getDisplaySettings';

//TODO: Setting the experience Id is required for Dynamic Branding. However, the Site.setExperienceId method doesn't appear to be working properly. 
//The browser cookie does not get updated when the expid parameter changes, causing inconsistent behaviour.
//import setExperienceId from '@salesforce/apex/SiteUtilities.setExperienceId';

const COMPONENT_NAME = 'Login';

export default class CustomLoginCmdt extends LightningElement {

    buttonLabel;
    isButtonDisabled = false;
    showSpinner = false;
    anyServerError = false;
    serverErrorMessage = null;
    showVerificationCode = false;

    results = null; //Results for custom configuration search
    @track formInputs = {}; //Form values submitted.
    displaySettings = {}; //Button labels loaded from the Login Settings record.

    loginResults = null;
    registerResults = null;
    pageUrl;

    //Get the URL Parameters so we can pass any predefined values through to the form and pre-set values.
    currentPageReference = null;
    urlParameters = null;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.urlParameters = currentPageReference.state;

            //TODO: Set the Experience Id for driving dynamic branding.
            /*if(currentPageReference.state.expid) {
                setExperienceId({expId: currentPageReference.state.expid}).catch(error=>{
                    console.log('There was a problem setting the site experience id: ' , error);
                    this._setServerError('Unable to set the Site Experience Id. Please try again later.'); 
                })
            }*/
        }
    }

    toggle = true;
    toggleFieldTypeAndIcon(event) {
        this.toggle = !this.toggle;
        event.currentTarget.iconName = this.toggle ? event.currentTarget.dataset.startingicon : event.currentTarget.dataset.toggleicon;
        var fieldType = this.toggle ? event.currentTarget.dataset.startingtype : event.currentTarget.dataset.toggletype;
        event.currentTarget.parentNode.querySelector('lightning-input').type = fieldType;
    }

    renderedCallback() {
        //Add keypress "enter" listener to the last element on the page to allow for submitting the form with the keyboard
        if(this.template.querySelector('lightning-input[data-last=true]')) {
            this.template.querySelector('lightning-input[data-last=true]').addEventListener("keydown", (e) => {this.handleEnter(e)});
        }

        //Dispatch a change event on the Id field so it is submitted back to Salesforce.
        if(this.template.querySelector('lightning-input[data-id=identifier')) {
            this.template.querySelector('lightning-input[data-id=identifier]').dispatchEvent(new Event("change"));
        }
    }

    connectedCallback() {

        //Button labels come from the settings record. Only these display values are exposed to the browser; the passwordless method and
        //the redirect stay server side.
        getDisplaySettings({componentName: COMPONENT_NAME}).then(result=>{
            this.displaySettings = JSON.parse(result);
            this.handleSubmit(false, this.displaySettings.buttonLabel, false);
        }).catch(error=>{
            this._setServerError(error.body ? error.body.message : 'There was a problem loading the login form. Please try again later.');
        })

        //Gets the customisation records from Custom Metadata. Includes standard/custom fields based on configuration.
        //Also validates the Login Settings record server side, so a missing or invalid configuration surfaces here.
        getCustomConfiguration({urlParams: JSON.stringify(this.urlParameters), componentName: COMPONENT_NAME}).then(result=>{
            this.results = JSON.parse(result);
            for (let i = 0; i < this.results.length; i++) {  //Ensure that all fields are submitted, even if there are blank values.
                this.formInputs[this.results[i].fieldName] = this.results[i].fieldType == 'checkbox' ? this.results[i].fieldChecked : this.results[i].fieldValue;
            }
        }).catch(error=>{
            this._setServerError(error.body ? error.body.message : 'There was a problem loading the login form. Please try again later.');
        })
    }

    handleOnChange(event) {
        this.formInputs[event.target.name] = event.target.value;
    }

    handleEnter(event){
        if(event.keyCode === 13){
            this.handleSignUpClick(event);
        }
    }

    handleSubmit(spinnerState, buttonText, buttonState) {
        this.showSpinner = spinnerState;
        this.buttonLabel = buttonText;
        this.isButtonDisabled = buttonState;
    }

    _areAllInputFieldsValid() {
        return [
           ...this.template.querySelectorAll('lightning-input:not(.slds-hide)'),
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);
    }

    _resetServerError() {
        this.anyServerError = false;
        this.serverErrorMessage = null;
    }

    _setServerError(errorMessage) {
        this.anyServerError = true;
        this.serverErrorMessage = errorMessage;
    }

    handleSignUpClick(event) {
        this._resetServerError();

        if(this._areAllInputFieldsValid()) {
            this.handleSubmit(true, this.displaySettings.buttonWaitingMessage, true);

            // Prefer Experience Cloud startURL (or startUrl) so deep links resume after login; Apex validates and falls back to Portal Redirect.
            const startUrl = this._getStartUrl();

            //Different behaviour for Passwordless vs Password registration.
            //showVerificationCode is only set by the server after a code has been sent, so it alone determines which call to make.
            if(this.showVerificationCode) { //Verify the code received and login.
                verifyUser({formInputs: JSON.stringify(this.formInputs), componentName: COMPONENT_NAME, startUrl: startUrl}).then((result) => {
                    this.registerResults = JSON.parse(result);
                    this.pageUrl = this.registerResults.registerResult[0].pageUrl;
                    window.location.href = this.pageUrl;
                }).catch((error) => {
                    this.handleSubmit(false, this.displaySettings.buttonAwaitingCodeMessage, false);
                    this._setServerError(error.body.message);
                    event.preventDefault();
                });
            }
            else {
                loginUser({formInputs: JSON.stringify(this.formInputs), startUrl: startUrl}).then((result) => {
                    this.loginResults = JSON.parse(result);
                    this.showVerificationCode = this.loginResults.loginResult[0].showVerificationCode;
                    this.pageUrl = this.loginResults.loginResult[0].pageUrl;

                    if(this.showVerificationCode) { //Verification code should have been sent by the configured method - Email or SMS.
                        this.template.querySelector('lightning-input[data-id=identifier').value = this.loginResults.loginResult[0].verificationId; //Dynamically set the value of the Verification Id field.
                        this.template.querySelector('.verificationCode').classList.remove('slds-hide'); //Dynamically show the input to the user by removing the slds-hide class.
                        this.handleSubmit(false, this.displaySettings.buttonAwaitingCodeMessage, false);
                    }
                    else { //Standard username/password login.
                        window.location.href = this.pageUrl;
                    }
                }).catch((error) => {
                    this.handleSubmit(false, this.displaySettings.buttonLabel, false);
                    this._setServerError(error.body.message);
                    event.preventDefault();
                });
            }
        } else {
            this.handleSubmit(false, this.displaySettings.buttonLabel, false);
            event.preventDefault();
        }
    }

    // Read at submit time so CurrentPageReference has had a chance to populate (same race as form field URL params).
    _getStartUrl() {
        if(!this.urlParameters) {
            return null;
        }
        return this.urlParameters.startURL || this.urlParameters.startUrl || null;
    }
}
