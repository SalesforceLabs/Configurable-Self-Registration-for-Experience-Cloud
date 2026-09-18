/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Custom Property Editor retained for managed package compatibility.
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api properties below must stay declared
 *                  because they are part of the managed package public API. Experience Builder Custom
 *                  Property Editors bind to value, but nothing reads either property.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class customPropertyEditorProfiles extends LightningElement {
    @api value;
    @api cookie;
}
