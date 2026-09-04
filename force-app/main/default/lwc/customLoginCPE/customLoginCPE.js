/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Superseded by customLoginCmdt ("SF Labs: Custom Login").
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api properties below must stay declared
 *                  because the <property> entries in the meta file reference them, but nothing reads them.
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
}
