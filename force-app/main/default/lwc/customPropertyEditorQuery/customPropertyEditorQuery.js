/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : DEPRECATED. Custom Property Editor retained for managed package compatibility.
 * SPECIAL NOTES  : This bundle cannot be removed from the managed package, so it is retained as an inert
 *                  component that renders a deprecation notice. The @api properties below must stay declared
 *                  because Experience Builder Custom Property Editors bind to them, but nothing reads them.
 *****************************************************************************************************/

import {LightningElement, api} from 'lwc';

export default class CustomPropertyEditorQuery extends LightningElement {
    @api errors;
    @api value;
}
