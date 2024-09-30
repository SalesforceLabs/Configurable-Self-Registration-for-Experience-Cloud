/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : Self Registration LWC component for Experience Builder pages
 * SPECIAL NOTES  : Dependency on SiteRegistrationController.js class
 * ===================================================================================================
 * Change History :
 *****************************************************************************************************/

import {LightningElement, api, track, wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import registerUser from '@salesforce/apex/SiteRegistrationController.registerUser';
import verifyUser from '@salesforce/apex/SiteUtilities.verifyUser';
import getCustomConfiguration from '@salesforce/apex/SiteUtilities.getCustomConfiguration';
import checkPersonAccount from '@salesforce/apex/SiteRegistrationController.isPersonAccountEnabled';
import isLoggingEnabled from '@salesforce/apex/SiteUtilities.isLoggingEnabled';

//TODO: Setting the experience Id is required for Dynamic Branding. However, the Site.setExperienceId method doesn't appear to be working properly. 
//The browser cookie does not get updated when the expid parameter changes, causing inconsistent behaviour.
//import setExperienceId from '@salesforce/apex/SiteUtilities.setExperienceId';

export default class customSelfRegistration extends LightningElement {
    @api propertyPanelSettings;
    parsedSettings;
    
    @api results = null; //Results for custom configuration search
    @track formInputs = {}; //Form values submitted.  

    @api buttonLabel;
    @api isButtonDisabled = false; 
    @api showSpinner = false;
    @api anyServerError = false;
    @api showComponentError = false;
    @api componentErrorMessage = null;
    @api serverErrorMessage = null;

    //Get the URL Parameters so we can pass any predefined values through to the form and pre-set values.
    currentPageReference = null; 
    urlParameters = null;
    showPassword = false;
    @api showVerificationCode = false;
    registerResults;
    parsedRegisterResults;
    pageUrl;

    get passwordIcon() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }
    
    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }
    
    togglePassword() {
        this.showPassword = !this.showPassword;
    }

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
        if(this.propertyPanelSettings) {
            this.parsedSettings = JSON.parse(this.propertyPanelSettings);
            this.handleSubmit(false, this.parsedSettings.registerButtonSignUpMessage, false);
            
            //Tries to remove spaces from the field list in the SOQL query to prevent errors with parsing.
            let queryParts = this.parsedSettings.customQuery.split("SELECT ");
            let queryPartsFields = queryParts[1].split(" FROM");
            let queryPartsRemoveSpacesFromFields = queryPartsFields[0].replace(" ", "");
            this.parsedSettings['customQuery'] = 'SELECT ' + queryPartsRemoveSpacesFromFields + ' FROM' + queryPartsFields[1];

            let newQueryParts = this.parsedSettings.customQuery.split(" ");

            //Checks SOQL query for valid types of Contact or Account, otherwise displays an error.
            if(this.parsedSettings.customQuery == null || (newQueryParts[3] != 'Contact' &&  newQueryParts[3] != 'Account' &&  newQueryParts[3] != 'Case')) {
                this._setComponentError(true, 'Only Contact, Account or Case objects are supported with a Custom Query on this component.');
            }

            this.parsedSettings['objectToQuery'] = newQueryParts[3]; //Pass this through to Apex so we can check data types of fields in the query.

            //Check the custom query for Account, and if the Person Accounts are not enabled then error.
            if(newQueryParts[3] == 'Account') {
                checkPersonAccount().then((enabled) => {
                    if(!enabled) {
                        this._setComponentError(true, 'Person Accounts are not enabled on this org so you cannot use Accounts in a Custom Query.'); 
                    } 
                }).catch(error=>{
                    console.log(error); 
                })
            }

            //Checks Object Type to Create is set correctly when the component is set to create a new record, otherwise displays an error.        
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'N/A') {
                this._setComponentError(true, 'Object Type to Create cannot be "N/A" when the Create Record function is set to TRUE.');
            }

            //Enforces an Account Id to be entered if creating a Contact
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'Contact' && this.parsedSettings.accountId == '') {
                this._setComponentError(true, 'Please specify an Account Id parameter when creating a Contact.');
            }

            //Enforces an Account Id of 15 or 18 length. 
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'Contact' && this.parsedSettings.accountId != '' && this.parsedSettings.accountId.length != 15 && this.parsedSettings.accountId.length != 18) {
                this._setComponentError(true, 'Account Id parameter must be a Salesforce 15 or 18 character reference');
            }

            //Enforces an Account Id which starts with 001. 
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'Contact' && this.parsedSettings.accountId.substring(0,3) != '001' && (this.parsedSettings.accountId.length == 15 || this.parsedSettings.accountId.length == 18)) {
                this._setComponentError(true, 'Account Id parameter must start with 001 (Account Object Type).');
            }
            
            //Checks if Person Accounts are enabled on the org if Object Create Type is 'Person Account' and Create If Not Found = TRUE
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'Person Account') {
                checkPersonAccount().then((enabled) => {
                    if(!enabled) {
                        this._setComponentError(true, 'Person Accounts are not enabled on this org.'); 
                    } 
                }).catch(error=>{
                    console.log(error); 
                })
            }

            //Enable or disable logging based on a Custom Metadata setting rather than property panel so it can be enabled without re-publishing the whole site.
            isLoggingEnabled({settingName: 'Self_Registration_Logging'}).then((enabled) => {
                this.parsedSettings['loggingEnabled'] = enabled;
            }).catch(error=>{
                console.log(error); 
            })
            
            //Check if the Person Account Record Type is set if the Object Create Type is 'Person Account' and Create If Not Found = TRUE
            if(this.parsedSettings.createNotFound && this.parsedSettings.objectCreateType == 'Person Account' && this.parsedSettings.personAccountRecordTypeId == '') {
                this._setComponentError(true, 'Please select a Person Account Record Type from the list to create a Person Account during registration.');  
            }
            
            //Gets the customisation records from Custom Metadata. Includes standard/custom fields based on configuration
            getCustomConfiguration({urlParams: JSON.stringify(this.urlParameters), componentName: 'Self Registration'}).then(result=>{
                this.results = JSON.parse(result);
                for (let i = 0; i <= this.results.length; i++) {  //Ensure that all fields are submitted, even if there are blank values.
                    this.formInputs[this.results[i].fieldName] = this.results[i].fieldType == 'checkbox' ? this.results[i].fieldChecked : this.results[i].fieldValue;
                }
            }).catch(error=>{
                console.log(error);
            })
        }
    }

    comparePasswordValues(sourceInput, inputToCompare) {
        if(sourceInput.target.value !== inputToCompare.value){
            sourceInput.target.setCustomValidity(this.parsedSettings.passwordMatchError);
            inputToCompare.setCustomValidity(this.parsedSettings.passwordMatchError);
        } else {
            sourceInput.target.setCustomValidity('');
            inputToCompare.setCustomValidity('');
        }
        sourceInput.target.reportValidity();
        inputToCompare.reportValidity('');
    }

    //NOTE: Validate the form inputs to make sure all validation requirements are met.
    //Excludes hidden fields from this to prevent an issue with form submission.
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

    _setServerError(errorMessage){
        this.anyServerError = true;
        this.serverErrorMessage = errorMessage;
    }

    _setComponentError(showError, message){
        this.showComponentError = showError;
        this.componentErrorMessage = message;
    }

    handleOnChange(event) {        
        this.formInputs[event.target.name] = event.target.type === 'checkbox' ? event.target.checked : event.target.value.trim();        
        //Password validation to compare Password > Confirm Password to make sure they match, otherwise display an error.
        if(event.target.className.includes('passwordCmp')) { 
            let valueToCompare = this.template.querySelector('.confirmPasswordCmp');
            this.comparePasswordValues(event, valueToCompare);
        }

        if(event.target.className.includes('confirmPasswordCmp')) {
            let valueToCompare = this.template.querySelector('.passwordCmp');
            this.comparePasswordValues(event, valueToCompare);
        }
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

    handleSignUpClick(event) {

        this._resetServerError();       

        if(this._areAllInputFieldsValid()) {
            this.handleSubmit(true, this.parsedSettings.registerButtonWaitingMessage, true);
            
            //Different behaviour for Passwordless vs Password registration.
            //Initial page load, user requests a verification code which shows an input to enter the code and then login.
            if(this.parsedSettings.enablePasswordlessLogin && this.showVerificationCode) { //Verify the code received and login.
                verifyUser({formInputs: JSON.stringify(this.formInputs), configurationOptions: JSON.stringify(this.parsedSettings), componentName: 'Self Registration'}).then((result) => {
                    this.registerResults = JSON.parse(result);
                    this.parsedRegisterResults = Object.values(this.registerResults.registerResult);
                    this.pageUrl = this.parsedRegisterResults[0].pageUrl;
                    window.location.href = this.pageUrl; 
                }).catch((error) => {
                    this.handleSubmit(false, this.parsedSettings.registerButtonAwaitingCodeMessage, false);                            
                    this._setServerError(error.body.message);
                    event.preventDefault();
                });
            }
            else { 
                registerUser({formInputs: JSON.stringify(this.formInputs), configurationOptions: JSON.stringify(this.parsedSettings)}).then((result) => {
                    this.registerResults = JSON.parse(result);
                    this.parsedRegisterResults = Object.values(this.registerResults.registerResult);
                    this.showVerificationCode = this.parsedRegisterResults[0].showVerificationCode;
                    this.pageUrl = this.parsedRegisterResults[0].pageUrl;
                    
                    if(this.showVerificationCode) { //Verification code should have been sent by the configured method - Email or SMS.                      
                        this.template.querySelector('lightning-input[data-id=identifier').value = this.parsedRegisterResults[0].verificationId; //Dynamically set the value of the Verification Id field.
                        this.template.querySelector('.verificationCode').classList.remove('slds-hide'); //Dynamically show the input to the user by removing the slds-hide class.
                        this.handleSubmit(false, this.parsedSettings.registerButtonAwaitingCodeMessage, false);
                    }
                    else { //Standard username/password registration.
                        window.location.href = this.pageUrl;
                    }
                }).catch((error) => {
                    this.handleSubmit(false, this.parsedSettings.registerButtonSignUpMessage, false);                            
                    this._setServerError(error.body.message);
                    event.preventDefault();
                });
            }  
        } else {
            this.handleSubmit(false, this.parsedSettings.registerButtonSignUpMessage, false);
            event.preventDefault();
        }
    }
}