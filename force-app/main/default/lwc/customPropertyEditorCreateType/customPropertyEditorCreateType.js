/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Custom Property Editor retained for managed package compatibility.
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api value property must stay declared
 *                  because Experience Builder Custom Property Editors bind to it, but nothing reads it.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class customPropertyEditorCreateType extends LightningElement {
    @api value;
}
