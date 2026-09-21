/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Superseded by customLoginCmdt ("SF Labs: Custom Login").
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api properties below must stay declared
 *                  because they are part of the managed package public API, but nothing reads them.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class CustomLogin extends LightningElement {
    @api loginButtonLoginMessage;
    @api loginButtonWaitingMessage;
    @api loginButtonAwaitingCodeMessage;
    @api failedCodeVerificationMessage;
    @api portalErrorSendVerificationCode;
    @api portalLoginRedirect;
    @api enablePasswordlessLogin;
    @api passwordlessMethod;
    @api blockUserErrorMessage;
    @api incorrectUserCredentialsErrorMessage;
    @api userLockedOutErrorMessage;
    @api buttonLabel;
    @api showVerificationCode;
    @api isButtonDisabled;
    @api showSpinner;
    @api anyServerError;
    @api serverErrorMessage;
    @api results;
}
