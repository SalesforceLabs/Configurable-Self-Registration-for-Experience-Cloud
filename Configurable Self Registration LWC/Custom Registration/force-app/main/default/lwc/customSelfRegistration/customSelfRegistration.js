/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce) & Ekaterina Coburn (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : Self Registration LWC component for Experience Builder pages
 * SPECIAL NOTES  : Dependency on SiteRegistrationController.js class
 * ===================================================================================================
 * Change History :
 *****************************************************************************************************/

import {LightningElement, api, track, wire} from 'lwc';
import {CurrentPageReference} from 'lightning/navigation';
import registerUser from '@salesforce/apex/SiteRegistrationController.registerUser';
import getCustomConfiguration from '@salesforce/apex/SiteRegistrationController.getCustomConfiguration';
import checkPersonAccount from '@salesforce/apex/SiteRegistrationController.isPersonAccountEnabled';
import isLoggingEnabled from '@salesforce/apex/SiteRegistrationController.isLoggingEnabled';
export default class customSelfRegistration extends LightningElement {
    
    @api buttonLabel;
    
    //These are custom properties in the component configuration within Experience Cloud.
    @api customQuery;
    @api createNotFound;
    @api objectCreateType;
    @api accountId;
    @api personAccountRecordTypeId;
    @api sendEmailConfirmation;
    @api accessLevelMode;
    
    //As above, but these are message configuration properties.
    @api registerButtonSignUpMessage;
    @api registerButtonWaitingMessage;
    @api passwordMatchError;
    @api usernameTakenMessage;
    @api noRecordFoundError;
    @api multipleRecordsFoundError;
    @api errorOnCreate;
    @api portalLoginError;
    @api portalRegistrationError;
    @api portalRegistrationUserExists;
    @api fieldHelpFirstName;
    @api fieldHelpLastName;
    @api fieldHelpUsername;
    @api fieldHelpEmail;
    @api fieldHelpPassword;
    @api fieldHelpConfirmPassword;

    @api results = null; //Results for custom configuration search
    @track formInputs = {}; //Form values submitted. 
    configurationOptions = {};  //LWC Setting values - add to object to pass as one parameter to Apex 

    @api isButtonDisabled = false; 
    @api showSpinner = false;
    @api anyServerError = false;
    @api showComponentError = false;
    @api componentErrorMessage = null;
    @api serverErrorMessage = null;

    //Get the URL Parameters so we can pass any predefined values through to the form and pre-set values.
    currentPageReference = null; 
    urlParameters = null;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.urlParameters = currentPageReference.state;
        }
    }

    connectedCallback() {

        this.handleSubmit(false, this.registerButtonSignUpMessage, false);

        //Checks SOQL query for valid types of Contact or Account, otherwise displays an error.
        let queryParts = this.customQuery.split(" ");
        if(this.customQuery == null || (queryParts[3] != 'Contact' &&  queryParts[3] != 'Account' &&  queryParts[3] != 'Case')) {
           this._setComponentError(true, 'Only Contact, Account or Case objects are supported with the Custom SOQL Query on this component.');
        }

        this.configurationOptions['objectToQuery'] = queryParts[3]; //Pass this through to Apex so we can check data types of fields in the query.

        //Check the custom query for Account, and if the Person Accounts are not enabled then error.
        if(queryParts[3] == 'Account') {
            checkPersonAccount().then((enabled) => {
                if(!enabled) {
                   this._setComponentError(true, 'Person Accounts are not enabled on this org so you cannot use Accounts in a Custom Query.'); 
                } 
            }).catch(error=>{
               console.log(error); 
            })
        }

        //Checks Object Type to Create is set correctly when the component is set to create a new record, otherwise displays an error.        
        if(this.createNotFound && this.objectCreateType == 'N/A') {
            this._setComponentError(true, 'Object Type to Create cannot be "N/A" when the Create Record function is set to TRUE.');
        }

        //Enforces an Account Id to be entered if creating a Contact
        if(this.createNotFound && this.objectCreateType == 'Contact' && this.accountId == '') {
            this._setComponentError(true, 'Please specify an Account Id parameter when creating a Contact.');
        }

        //Enforces an Account Id of 15 or 18 length. 
        if(this.createNotFound && this.objectCreateType == 'Contact' && this.accountId != '' && this.accountId.length != 15 && this.accountId.length != 18) {
            this._setComponentError(true, 'Account Id parameter must be a Salesforce 15 or 18 character reference');
        }

        //Enforces an Account Id which starts with 001. 
        if(this.createNotFound && this.objectCreateType == 'Contact' && this.accountId.substring(0,3) != '001' && (this.accountId.length == 15 || this.accountId.length == 18)) {
            this._setComponentError(true, 'Account Id parameter must start with 001 (Account Object Type).');
        }
        
        //Checks if Person Accounts are enabled on the org if Object Create Type is 'Person Account' and Create If Not Found = TRUE
        if(this.createNotFound && this.objectCreateType == 'Person Account') {
            checkPersonAccount().then((enabled) => {
                if(!enabled) {
                   this._setComponentError(true, 'Person Accounts are not enabled on this org.'); 
                } 
            }).catch(error=>{
               console.log(error); 
            })
        }

        //Enable or disable logging based on a Custom Metadata setting rather than property panel so it can be enabled without re-publishing the whole site.
        isLoggingEnabled().then((enabled) => {
            this.configurationOptions['loggingEnabled'] = enabled;
        }).catch(error=>{
            console.log(error); 
        })
        
        //Check if the Person Account Record Type is set if the Object Create Type is 'Person Account' and Create If Not Found = TRUE
        if(this.createNotFound && this.objectCreateType == 'Person Account' && this.personAccountRecordTypeId == '') {
           this._setComponentError(true, 'Please select a Person Account Record Type from the list to create a Person Account during registration.');  
        } 

        //Gets the customisation records from Custom Metadata. Includes standard/custom fields based on configuration
        getCustomConfiguration({urlParams: JSON.stringify(this.urlParameters)}).then(result=>{
            this.results = JSON.parse(result);
        }).catch(error=>{
            console.log(error);
        })
    }

    _applyInputFormValidity() {
       this._resetServerError();
       this._applyCustomPassportValidity();
    }

    _applyCustomPassportValidity() {
        let passwordCmp = this.template.querySelector('.passwordCmp');
        let passwordValue = passwordCmp.value;

        let confirmPasswordCmp = this.template.querySelector('.confirmPasswordCmp');
        let confirmPasswordValue = confirmPasswordCmp.value;

        if(passwordValue !== confirmPasswordValue){
            passwordCmp.setCustomValidity(this.passwordMatchError);
            confirmPasswordCmp.setCustomValidity(this.passwordMatchError);
        } else {
            passwordCmp.setCustomValidity('');
            confirmPasswordCmp.setCustomValidity('');
        }

        passwordCmp.reportValidity();
        confirmPasswordCmp.reportValidity();
    }

    _areAllInputFieldsValid() {
        return [
            ...this.template.querySelectorAll('lightning-input'),
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
        this.formInputs[event.target.name] = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
    }

    handleSubmit(spinnerState, buttonText, buttonState) {
        this.showSpinner = spinnerState;
        this.buttonLabel = buttonText;
        this.isButtonDisabled = buttonState;
    }

    handleSignUpClick(event) {

        this._applyInputFormValidity();

        //Set the Username to be the email address if not provided on the form.
        if(!this.formInputs['Username'] || this.formInputs['Username'] == '') {
            this.formInputs['Username'] = this.formInputs['Email'];
        }

        //Add LWC configuration to the ConfigurationOptions object to pass to Apex as one parameter.
        this.configurationOptions['customQuery'] = this.customQuery;
        this.configurationOptions['createNotFound'] = this.createNotFound;
        this.configurationOptions['objectCreateType'] = this.objectCreateType;
        this.configurationOptions['accountId'] = this.accountId;
        this.configurationOptions['personAccountRecordTypeId'] = this.personAccountRecordTypeId;
        this.configurationOptions['sendEmailConfirmation'] = this.sendEmailConfirmation;
        this.configurationOptions['accessLevelMode'] = this.accessLevelMode;
        this.configurationOptions['registerButtonSignUpMessage'] = this.registerButtonSignUpMessage;
        this.configurationOptions['registerButtonWaitingMessage'] = this.registerButtonWaitingMessage;
        this.configurationOptions['passwordMatchError'] = this.passwordMatchError;
        this.configurationOptions['usernameTakenMessage'] = this.usernameTakenMessage;
        this.configurationOptions['errorNoRecordFound'] = this.noRecordFoundError;
        this.configurationOptions['errorMultipleRecordsFound'] = this.multipleRecordsFoundError;
        this.configurationOptions['errorOnCreate'] = this.errorOnCreate;
        this.configurationOptions['portalLoginError'] = this.portalLoginError;
        this.configurationOptions['portalRegistrationError'] = this.portalRegistrationError;
        this.configurationOptions['portalRegistrationUserExists'] = this.portalRegistrationUserExists;
        this.configurationOptions['fieldHelpFirstName'] = this.fieldHelpFirstName;
        this.configurationOptions['fieldHelpLastName'] = this.fieldHelpLastName;
        this.configurationOptions['fieldHelpUsername'] = this.fieldHelpUsername;
        this.configurationOptions['fieldHelpEmail'] = this.fieldHelpEmail;
        this.configurationOptions['fieldHelpPassword'] = this.fieldHelpPassword;
        this.configurationOptions['fieldHelpConfirmPassword'] = this.fieldHelpConfirmPassword;

        if(this._areAllInputFieldsValid()) {
            this.handleSubmit(true, this.registerButtonWaitingMessage, true);
            registerUser({formInputs: JSON.stringify(this.formInputs), configurationOptions: JSON.stringify(this.configurationOptions)}).then((pageUrl) => {
                if(pageUrl){
                    window.location.href = pageUrl;
                }
            }).catch((error) => {
                this.handleSubmit(false, this.registerButtonSignUpMessage, false);                            
                this._setServerError(error.body.message);
                event.preventDefault();
            });
        } else {
            this.handleSubmit(false, this.registerButtonSignUpMessage, false);
            event.preventDefault();
        }
    }
}