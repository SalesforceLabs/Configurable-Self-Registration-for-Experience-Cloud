@istest
public without sharing class TestUtilities {
	public static List<SObject> getTestMetadata(string type) {
		list<Custom_Login_Configuration__mdt> retMetadata = new List<Custom_Login_Configuration__mdt>();
		// if (type == SiteUtilities.LOGIN_COMPONENT_NAME) {
		Custom_Login_Configuration__mdt picklist = new Custom_Login_Configuration__mdt();
		picklist.Field_Type__c = 'picklist';
		picklist.Field_Picklist_Options__c = '[{"label":"yes","value":"yes"},{"label":"no","value":"no"}]';
		picklist.Field_Placeholder__c = 'placeholder';
		picklist.Field_Message__c = 'Field_Message__c';
		picklist.Field_Help_Text__c = 'Field_Help_Text__c';
		picklist.Active__c = true;
		picklist.Portal_API_Name__c = 'ALL';
		picklist.Display_Order__c = 1;

		Custom_Login_Configuration__mdt text = new Custom_Login_Configuration__mdt();
		text.Field_Type__c = 'text';
		text.Field_Placeholder__c = 'placeholder';
		text.Field_Message__c = 'Field_Message__c';
		text.Field_Help_Text__c = 'Field_Help_Text__c';
		text.Field_Validation_REGEX__c = '.';
		text.Field_Name__c = 'email';
		text.Field_Required_Message__c = 'required field is required';
		text.Field_Required__c = true;
		text.Active__c = true;
		text.Portal_API_Name__c = 'ALL';
		Custom_Login_Configuration__mdt checkbox = new Custom_Login_Configuration__mdt();
		checkbox.Field_Type__c = 'checkbox';
		checkbox.Active__c = true;
		checkbox.Portal_API_Name__c = 'ALL';
		checkbox.Field_Name__c = 'success';

		retMetadata.add(picklist);
		retMetadata.add(text);
		retMetadata.add(checkbox);
		// }
		return retMetadata;
	}
}
