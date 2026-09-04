/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Superseded by customSelfRegistrationCmdt ("SF Labs: Custom Self Registration").
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. propertyPanelSettings must stay declared
 *                  because the <property> entry in the meta file references it, but nothing reads it.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class customSelfRegistrationCPropEditor extends LightningElement {
    @api propertyPanelSettings;
}
