import {LightningElement, api, track} from 'lwc';
import loginUser from '@salesforce/apex/SiteLoginController.loginUser';
import isLoggingEnabled from '@salesforce/apex/SiteUtilities.isLoggingEnabled';

export default class CustomLogin extends LightningElement {

	//Username Options from the property panel
	@api userNameField_fieldIconName
	@api userNameField_fieldIconClass
	@api userNameField_fieldLabel
	@api userNameField_fieldLabelVariant
	@api userNameField_fieldClass
	@api userNameField_fieldHelpText
	@api userNameField_fieldPlaceholder
	@api userNameField_fieldRequiredMessage;
    @api userNameField_fieldPatternMatch;
    @api userNameField_fieldPatternMismatchMessage;

	//Password field options
	@api fieldShowPasswordVisibility
	@api passwordField_fieldIconClass
	@api passwordField_fieldLabelVariant
	@api passwordField_fieldLabel
	@api passwordField_fieldHelpText
	@api passwordField_fieldPlaceholder
	@api passwordField_fieldClass;
	@api passwordField_fieldRequiredMessage;

	//Button label text
	@api buttonLabel;
	@api loginButtonLoginMessage;
    @api loginButtonWaitingMessage;

	//Configurable Error Messages from the Component Property Panel
	@api blockUserErrorMessage;
	@api incorrectUserCredentialsErrorMessage;
	@api userLockedOutErrorMessage;

	//Other settings
	@api portalLoginRedirect;

	@api isButtonDisabled = false;
	@api showSpinner = false;
    @api anyServerError = false;
    @api serverErrorMessage = null;
    @api passwordFieldShowIcon;
    @api passwordFieldHideIcon;
	showPassword = false;

	@track formInputs = {}; //Form values submitted.
	configurationOptions = {};  //LWC Setting values - add to object to pass as one parameter to Apex 

	get passwordIcon() {
        return this.showPassword ? this.passwordFieldHideIcon : this.passwordFieldShowIcon;
    }
    
    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }
    
    togglePassword() {
        this.showPassword = !this.showPassword;
    }

	connectedCallback() {
		this.handleSubmit(false, this.loginButtonLoginMessage, false);

		//Enable or disable logging based on a Custom Metadata setting rather than property panel so it can be enabled without re-publishing the whole site.
        isLoggingEnabled({settingName: 'Login_Logging'}).then((enabled) => {
            this.configurationOptions['loggingEnabled'] = enabled;
        }).catch(error=>{
            console.log(error); 
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

	_setServerError(errorMessage) {
        this.anyServerError = true;
        this.serverErrorMessage = errorMessage;
    }

    handleSignUpClick(event) {
		this._resetServerError();

		this.configurationOptions['blockUserErrorMessage'] = this.blockUserErrorMessage;
		this.configurationOptions['userLockedOutErrorMessage'] = this.userLockedOutErrorMessage;
		this.configurationOptions['incorrectUserCredentialsErrorMessage'] = this.incorrectUserCredentialsErrorMessage;
		this.configurationOptions['portalLoginRedirect'] = this.portalLoginRedirect;

		if(this._areAllInputFieldsValid()) {
            this.handleSubmit(true, this.loginButtonWaitingMessage, true);
            loginUser({username: this.formInputs['Email'], password: this.formInputs['Password'], configurationOptions: this.configurationOptions}).then((pageUrl) => {
                if(pageUrl){
                    window.location.href = pageUrl;
                }
            }).catch((error) => {
                this.handleSubmit(false, this.loginButtonLoginMessage, false);                            
                this._setServerError(error.body.message);
                event.preventDefault();
            });
        } else {
            this.handleSubmit(false, this.loginButtonLoginMessage, false);
            event.preventDefault();
        }
	}
}