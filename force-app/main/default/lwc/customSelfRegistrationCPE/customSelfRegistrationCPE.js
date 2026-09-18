/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Superseded by customSelfRegistrationCmdt ("SF Labs: Custom Self Registration").
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api properties below must stay declared
 *                  because they are part of the managed package public API, but nothing reads them.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class CustomSelfRegistrationCPE extends LightningElement {
    @api propertyPanelSettings;
    @api results;
    @api buttonLabel;
    @api isButtonDisabled;
    @api showSpinner;
    @api anyServerError;
    @api showComponentError;
    @api componentErrorMessage;
    @api serverErrorMessage;
    @api showVerificationCode;
}
