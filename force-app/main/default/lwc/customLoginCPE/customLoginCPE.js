import { LightningElement, api, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";
import loginUser from "@salesforce/apex/SiteLoginController.loginUser";
import isLoggingEnabled from "@salesforce/apex/SiteUtilities.isLoggingEnabled";
import getCustomConfiguration from "@salesforce/apex/SiteUtilities.getCustomConfiguration";
import verifyUser from "@salesforce/apex/SiteUtilities.verifyUser";

//TODO: Setting the experience Id is required for Dynamic Branding. However, the Site.setExperienceId method doesn't appear to be working properly.
//The browser cookie does not get updated when the expid parameter changes, causing inconsistent behaviour.
//import setExperienceId from '@salesforce/apex/SiteUtilities.setExperienceId';

export default class CustomLogin extends LightningElement {
	//Button label text
	@api buttonLabel;
	@api loginButtonLoginMessage;
	@api loginButtonWaitingMessage;
	@api loginButtonAwaitingCodeMessage;
	@api failedCodeVerificationMessage;
	@api portalErrorSendVerificationCode;
	@api showVerificationCode = false;
	loginResults = null;
	pageUrl;

	//Configurable Error Messages from the Component Property Panel
	@api blockUserErrorMessage;
	@api incorrectUserCredentialsErrorMessage;
	@api userLockedOutErrorMessage;

	//Other settings
	@api portalLoginRedirect;
	@api enablePasswordlessLogin;
	@api passwordlessMethod;

	@api isButtonDisabled = false;
	@api showSpinner = false;
	@api anyServerError = false;
	@api serverErrorMessage = null;

	@api results = null; //Results for custom configuration search
	@track formInputs = {}; //Form values submitted.
	configurationOptions = {}; //LWC Setting values - add to object to pass as one parameter to Apex

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
		event.currentTarget.parentNode.querySelector("lightning-input").type = fieldType;
	}

	renderedCallback() {
		//Add keypress "enter" listener to the last element on the page to allow for submitting the form with the keyboard
		if (this.template.querySelector("lightning-input[data-last=true]")) {
			this.template.querySelector("lightning-input[data-last=true]").addEventListener("keydown", (e) => {
				this.handleEnter(e);
			});
		}

		//Dispatch a change event on the Id field so it is submitted back to Salesforce.
		if (this.template.querySelector("lightning-input[data-id=identifier")) {
			this.template.querySelector("lightning-input[data-id=identifier]").dispatchEvent(new Event("change"));
		}
	}

	connectedCallback() {
		this.handleSubmit(false, this.loginButtonLoginMessage, false);

		//Enable or disable logging based on a Custom Metadata setting rather than property panel so it can be enabled without re-publishing the whole site.
		isLoggingEnabled({ settingName: "Login_Logging" })
			.then((enabled) => {
				this.configurationOptions["loggingEnabled"] = enabled;
			})
			.catch((error) => {
				console.log(error);
			});

		//Gets the customisation records from Custom Metadata. Includes standard/custom fields based on configuration
		getCustomConfiguration({ urlParams: JSON.stringify(this.urlParameters), componentName: "Login" })
			.then((result) => {
				this.results = JSON.parse(result);
				for (let i = 0; i <= this.results.length; i++) {
					//Ensure that all fields are submitted, even if there are blank values.
					this.formInputs[this.results[i].fieldName] = this.results[i].fieldType == "checkbox" ? this.results[i].fieldChecked : this.results[i].fieldValue;
				}
			})
			.catch((error) => {
				console.log(error);
			});
	}

	handleOnChange(event) {
		this.formInputs[event.target.name] = event.target.value;
	}

	handleEnter(event) {
		if (event.keyCode === 13) {
			this.handleSignUpClick(event);
		}
	}

	handleSubmit(spinnerState, buttonText, buttonState) {
		this.showSpinner = spinnerState;
		this.buttonLabel = buttonText;
		this.isButtonDisabled = buttonState;
	}

	_areAllInputFieldsValid() {
		return [...this.template.querySelectorAll("lightning-input:not(.slds-hide)")].reduce((validSoFar, inputCmp) => {
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

		this.configurationOptions["blockUserErrorMessage"] = this.blockUserErrorMessage;
		this.configurationOptions["userLockedOutErrorMessage"] = this.userLockedOutErrorMessage;
		this.configurationOptions["incorrectUserCredentialsErrorMessage"] = this.incorrectUserCredentialsErrorMessage;
		this.configurationOptions["failedCodeVerificationMessage"] = this.failedCodeVerificationMessage;
		this.configurationOptions["portalLoginRedirect"] = this.portalLoginRedirect;
		this.configurationOptions["enablePasswordlessLogin"] = this.enablePasswordlessLogin;
		this.configurationOptions["passwordlessMethod"] = this.passwordlessMethod;

		if (this._areAllInputFieldsValid()) {
			this.handleSubmit(true, this.loginButtonWaitingMessage, true);

			//Different behaviour for Passwordless vs Password registration.
			//Initial page load, user requests a verification code which shows an input to enter the code and then login.
			if (this.enablePasswordlessLogin && this.showVerificationCode) {
				//Verify the code received and login.
				verifyUser({ formInputs: JSON.stringify(this.formInputs), configurationOptions: JSON.stringify(this.configurationOptions), componentName: "Login" })
					.then((result) => {
						this.registerResults = JSON.parse(result);
						console.log("registerResults:" + this.registerResults);
						this.pageUrl = this.registerResults.registerResult[0].pageUrl;
						window.location.href = this.pageUrl;
					})
					.catch((error) => {
						this.handleSubmit(false, this.loginButtonAwaitingCodeMessage, false);
						this._setServerError(error.body.message);
						event.preventDefault();
					});
			} else {
				loginUser({ formInputs: JSON.stringify(this.formInputs), configurationOptions: this.configurationOptions })
					.then((result) => {
						this.loginResults = JSON.parse(result);
						this.showVerificationCode = this.loginResults.loginResult[0].showVerificationCode;
						this.pageUrl = this.loginResults.loginResult[0].pageUrl;

						if (this.showVerificationCode) {
							//Verification code should have been sent by the configured method - Email or SMS.
							this.template.querySelector("lightning-input[data-id=identifier").value = this.loginResults.loginResult[0].verificationId; //Dynamically set the value of the Verification Id field.
							this.template.querySelector(".verificationCode").classList.remove("slds-hide"); //Dynamically show the input to the user by removing the slds-hide class.
							this.handleSubmit(false, this.loginButtonAwaitingCodeMessage, false);
						} else {
							//Standard username/password login.
							window.location.href = this.pageUrl;
						}
					})
					.catch((error) => {
						this.handleSubmit(false, this.loginButtonLoginMessage, false);
						this._setServerError(error.body.message);
						event.preventDefault();
					});
			}
		} else {
			this.handleSubmit(false, this.loginButtonLoginMessage, false);
			event.preventDefault();
		}
	}
}
