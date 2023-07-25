/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : Self Registration LWC component for Experience Builder pages
 * SPECIAL NOTES  : Dependency on SiteRegistrationController.js class
 * ===================================================================================================
 * Change History :
 *****************************************************************************************************/

import { LightningElement, api, track} from 'lwc';
import validatePassword from '@salesforce/apex/SiteRegistrationController.validatePassword';
import isValidUsername from '@salesforce/apex/SiteRegistrationController.isValidUsername';
import registerUser from '@salesforce/apex/SiteRegistrationController.registerUser';
import getCustomConfiguration from '@salesforce/apex/SiteRegistrationController.getCustomConfiguration';

export default class customSelfRegistration extends LightningElement {
    
    @api fieldSetObjectNameParam = 'User'; //Hardcoded to User, the fields that we map to on the registration form go here as per the out of box solution.
    @api buttonLabel = 'Sign Up'; //Default Button label
    
    //These are custom properties in the component configuration within Experience Cloud.
    @api customQuery;
    @api createNotFound;
    @api objectCreateType;
    @api accountId;
    @api personAccountRecordTypeId;
    @api enableCustomisation; 
    @api sendEmailConfirmation;
    @api accessLevelMode;
    @api loggingEnabled;
    
    //As above, but these are message configuration properties.
    @api registerButtonSignUpMessage;
    @api registerButtonWaitingMessage;
    @api passwordMatchError;
    @api usernameTakenMessage;
    @api noRecordFoundError;
    @api errorOnCreate;
    @api portalLoginError;
    @api fieldHelpFirstName;
    @api fieldHelpLastName;
    @api fieldHelpUsername;
    @api fieldHelpEmail;
    @api fieldHelpPassword;

    @api results = null; //Results for custom configuration search
    @track formInputs = {}; //Form values submitted. 
    configurationOptions = {};  //LWC Setting values - add to object to pass as one parameter to Apex 

    @api isButtonDisabled = false; 
    @api showSpinner = false;
    @api anyServerError = false;
    @api showComponentError = false;
    @api componentErrorMessage = null;
    @api serverErrorMessage = null;

    connectedCallback() {

        //Check validity of various settings before showing the component to the user.

        //Checks SOQL query for valid types of Contact or Account, otherwise displays an error.
        let queryParts = this.customQuery.split(" ");
        if(this.customQuery == null || (queryParts[3] != 'Contact' &&  queryParts[3] != 'Account')) {
           this._setComponentError(true, 'Only Contact or Account objects are supported with the Custom SOQL Query on this component.');
        }

        //Checks Object Type to Create is set correctly when the component is set to create a new record, otherwise displays an error.        
        if(this.createNotFound && this.objectCreateType == 'N/A') {
            this._setComponentError(true, 'Object Type to Create cannot be "N/A" when Create Record function is set to TRUE.');
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
         
        //Gets the customisation records from Custom Metadata if setting is enabled 
        if(this.enableCustomisation && this.fieldSetObjectNameParam) {
            getCustomConfiguration({sObjectName: this.fieldSetObjectNameParam}).then(result=>{
                this.results = JSON.parse(result);
            }).catch(error=>{
                console.log(error);
            })
        }
    }

    _applyInputFormValidity() {
        this._resetServerError();
        this._applyCustomValidation();
    }

    _applyCustomValidation() {
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
        this.formInputs[event.target.name] = event.target.value; 
    }

    handleSubmit(spinnerState, buttonText, buttonState) {
        this.showSpinner = spinnerState;
        this.buttonLabel = buttonText;
        this.isButtonDisabled = buttonState;
    }

    handleSignUpClick(event) {

        this._applyInputFormValidity();

        //Add LWC configuration to the ConfigurationOptions object to pass to Apex as one parameter.
        this.configurationOptions['customQuery'] = this.customQuery;
        this.configurationOptions['createNotFound'] = this.createNotFound;
        this.configurationOptions['objectCreateType'] = this.objectCreateType;
        this.configurationOptions['accountId'] = this.accountId;
        this.configurationOptions['personAccountRecordTypeId'] = this.personAccountRecordTypeId, 
        this.configurationOptions['enableCustomisation'] = this.enableCustomisation;
        this.configurationOptions['sendEmailConfirmation'] = this.sendEmailConfirmation;
        this.configurationOptions['accessLevelMode'] = this.accessLevelMode;
        this.configurationOptions['loggingEnabled'] = this.loggingEnabled;
        this.configurationOptions['registerButtonSignUpMessage'] = this.registerButtonSignUpMessage;
        this.configurationOptions['registerButtonWaitingMessage'] = this.registerButtonSignUpMessage;
        this.configurationOptions['passwordMatchError'] = this.passwordMatchError;
        this.configurationOptions['usernameTakenMessage'] = this.usernameTakenMessage;
        this.configurationOptions['errorNoRecordFound'] = this.noRecordFoundError;
        this.configurationOptions['errorOnCreate'] = this.errorOnCreate;
        this.configurationOptions['portalLoginError'] = this.portalLoginError;
        this.configurationOptions['fieldHelpFirstName'] = this.fieldHelpFirstName;
        this.configurationOptions['fieldHelpLastName'] = this.fieldHelpLastName;
        this.configurationOptions['fieldHelpUsername'] = this.fieldHelpUsername;
        this.configurationOptions['fieldHelpEmail'] = this.fieldHelpEmail;
        this.configurationOptions['fieldHelpPassword'] = this.fieldHelpPassword;

        if(this._areAllInputFieldsValid()) {
            this.handleSubmit(true, this.registerButtonWaitingMessage, true);
            isValidUsername({
                username: this.formInputs.Username,
                loggingEnabled: this.loggingEnabled
            })
            .then((isValid) => {
                if(isValid === true) {
                    validatePassword({
                        formInputs: JSON.stringify(this.formInputs),
                        configurationOptions: JSON.stringify(this.configurationOptions)
                    })
                    .then(() => {
                        registerUser({ 
                            formInputs: JSON.stringify(this.formInputs),
                            configurationOptions: JSON.stringify(this.configurationOptions)
                        })
                        .then((pageUrl) => {
                            if(pageUrl){
                                window.location.href = pageUrl;
                            }
                        })
                        .catch((error) => {
                            this.handleSubmit(false, this.registerButtonSignUpMessage, false);                            
                            this._setServerError(error.body.message);
                            event.preventDefault();
                        });
                    })
                    .catch((error) => {
                        this.handleSubmit(false, this.registerButtonSignUpMessage, false);
                        this._setServerError(error.body.message);
                    });
                } else { 
                    this.handleSubmit(false, this.registerButtonSignUpMessage, false);
                    this._setServerError(this.usernameTakenMessage);
                    event.preventDefault();
                }
            })
            .catch((error) => {
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