/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 15/05/2023
 * @description Apex controller to support custom built UI Custom Self Registration for Experience Cloud
 ***************************************************************************************************************/

public with sharing class SiteRegistrationController {
	public static Map<String, Schema.SObjectField> userObjectMetadata = getMetadataForObject('User');

	@TestVisible
	public static Boolean testPersonAccountStatus;
	private static Boolean orgPersonAccountStatus = Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');

	/**
	 * @description isPersonAccountEnabled tests whether the org currently has Person Accounts enabled. Checks for existence of the isPersonAccount field.
	 * @return returns true/false depending on setup of the org.
	 */
	@AuraEnabled
	public static Boolean isPersonAccountEnabled() {
		return testPersonAccountStatus != null ? testPersonAccountStatus : orgPersonAccountStatus;
	}

	/**
	 * @description pass in metadata for an object, and a field name.
	 * @param objectMetadata the object metadata to check against
	 * @param fieldName the field name to check for existance
	 * @return return true if the field exists, otherwise false.
	 */
	public static Boolean checkFieldExists(Map<String, Schema.SObjectField> objectMetadata, string fieldName) {
		return objectMetadata.containsKey(fieldName);
	}

	/**
	 * @description pass in a map and remove the password elements from any logging for security
	 * @param formJson - pass in a map of JSON to sanitise
	 * @return return the sanitised version of the map by removing information
	 */
	public static Map<String, Object> sanitiseJson(Map<String, Object> formJson) {
		Map<String, Object> newFormJSON = new Map<String, Object>();

		for (String key : formJson.keySet()) {
			if (key == 'password' || key == 'confirmPassword') {
				newFormJSON.put(key, 'HIDDEN');
			} else {
				newFormJSON.put(key, formJson.get(key));
			}
		}

		return newFormJson;
	}

	/**
	 * @description isValidUsername Checks to see if the username supplied by the user on the registration form is available
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 * @return Boolean true if username is taken, otherwise false.
	 */
	public static Boolean isValidUsername(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		Boolean isUsernameValid = true;
		String username = SiteUtilities.convertToString(formInputs.get('Username'));

		//Get the Network Id for the current Experience Cloud Site
		String networkId = Network.getNetworkId();

		//This class runs without sharing as access cannot be granted to the Guest User and the SiteRegisterController runs as a Guest.
		List<NetworkMember> userList = SiteUtilities.validateUsername(username, networkId);

		SiteUtilities.messages.add('Looking for registered user with username ' + username + ' on Site: ' + SiteUtilities.siteName + ' with NetworkId: ' + networkId);

		if (userList.size() >= 1) {
			SiteUtilities.messages.add(
				'User with username ' + username + ' already exists on Site: ' + SiteUtilities.siteName + ' with NetworkId: ' + networkId + '. Username NOT valid.'
			);
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('usernameTakenMessage')));
		}

		SiteUtilities.messages.add('User with username ' + username + ' not found on Site: ' + SiteUtilities.siteName + ' with NetworkId ' + networkId + '. Username valid.');
		return isUsernameValid;
	}

	/**
	 * @description Validates that the submitted password matches the Org's password policy.
	 * @param formJson - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 */
	public static void validatePassword(Map<String, Object> formJson, Map<String, Object> configurationOptions, User user) {
		try {
			if (!Test.isRunningTest()) {
				//NOTE: This method is buggy and always fails during Apex Tests so bypass it! See: https://help.salesforce.com/s/articleView?id=000391105&type=1
				Site.validatePassword(user, SiteUtilities.convertToString(formJson.get('password')), SiteUtilities.convertToString(formJson.get('confirmPassword')));
			}
		} catch (Exception ex) {
			SiteUtilities.messages.add('An error occurred whilst trying to validate the password:' + ex.getMessage() + '\n' + 'Form Inputs: ' + sanitiseJson(formJson));
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(ex.getMessage()); //This is deliberate as the Site.Validate function returns useful information about the password failure
		}
	}

	/**
	 * @description Attempts to register a new user. Looks for existing record first based on configured query. If configured and record not found, new record is created. If record found, registered user is linked to existing Contact/Person Account.
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 * @return String Page URL if login is successful.
	 */
	@AuraEnabled
	public static String registerUser(String formInputs, String configurationOptions) {
		String pageUrl = null;
		String result = '';
		Id recordId = null;
		String userId;
		String identifier;
		Boolean showVerificationCode = false;
		Boolean recordCreated = false;
		Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
		Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);

		//Remove the Password/Confirm Password stored in the Self Registration Logs.
		Map<String, Object> sanitisedFormJson = new Map<String, Object>();
		sanitisedFormJson = sanitiseJson(formJson);

		User user = createUnsavedUser(formJson, lwcSettings);
		formJson.put('Username', user.username);
		isValidUsername(formJson, lwcSettings);

		//No password is required for Passwordless, so don't try to validate it!
		if (!SiteUtilities.convertToBoolean(lwcSettings.get('enablePasswordlessLogin'))) {
			validatePassword(formJson, lwcSettings, user);
		}

		if (String.isNotBlank(SiteUtilities.convertToString(lwcSettings.get('customQuery')))) {
			SiteUtilities.messages.add('Searching for record with query:' + lwcSettings.get('customQuery') + '. Submitted Values: ' + sanitisedFormJson);
			recordId = getObject(sanitisedFormJson, lwcSettings);
			SiteUtilities.messages.add('Record Id found was: ' + recordId);
		}

		if (SiteUtilities.convertToBoolean(lwcSettings.get('createNotFound')) && String.isBlank(recordId)) {
			SiteUtilities.messages.add('About to create new ' + SiteUtilities.convertToString(lwcSettings.get('objectCreateType')));
			recordId = createObject(formJson, lwcSettings);
			recordCreated = true;
			SiteUtilities.messages.add('Created Record Id returned was: ' + recordId);
		}

		if (SiteUtilities.convertToBoolean(lwcSettings.get('enablePasswordlessLogin'))) {
			//Set the resulting contactId on the yet to be saved user
			Id contactId = SiteUtilities.convertToBoolean(lwcSettings.get('enablePasswordlessLogin')) &&
				SiteUtilities.convertToString(lwcSettings.get('objectCreateType')) == 'Person Account'
				? SiteUtilities.getPersonContactId(recordId)
				: recordId;
			new SiteUtilities().setContactId(user, contactId);

			SiteUtilities.messages.add('Sending verification code via ' + SiteUtilities.convertToString(lwcSettings.get('passwordlessMethod')) + ' to User: ' + user);
			try {
				Auth.VerificationMethod method = SiteUtilities.methods.get(SiteUtilities.convertToString(lwcSettings.get('passwordlessMethod')));
				identifier = SiteUtilities.sendVerificationCode(method, user, SiteUtilities.SELF_REG_COMPONENT_NAME);
				showVerificationCode = true;
			} catch (Exception e) {
				SiteUtilities.messages.add('Error sending a verification code. Please try again later.' + ' Error: ' + e.getMessage());

				//Delete the contact if there was a problem sending the code but only if it was the record that was created by the self registration. Don't delete an existing record.
				if (SiteUtilities.convertToBoolean(lwcSettings.get('createNotFound')) && recordCreated) {
					SiteUtilities.messages.add('Deleting created record Id: ' + recordId);
					SiteUtilities.deleteRecord(recordId, SiteUtilities.SELF_REG_COMPONENT_NAME, lwcSettings);
					SiteUtilities.messages.add('Record was successfully deleted with Id: ' + recordId);
				}

				SiteUtilities.createLogEntry(
					SiteUtilities.convertToBoolean(lwcSettings.get('loggingEnabled')),
					String.join(SiteUtilities.messages, '\n'),
					SiteUtilities.ERROR_LOG_TYPE,
					SiteUtilities.SELF_REG_COMPONENT_NAME
				);
				throw new AuraHandledException(SiteUtilities.convertToString(lwcSettings.get('portalErrorSendVerificationCode')));
			}
		} else {
			userId = createExternalUser(formJson, recordId, user, lwcSettings);

			if (Test.isRunningTest()) {
				userId = '123';
			}

			if (String.isNotBlank(userId)) {
				SiteUtilities.messages.add('External User Id created was: ' + userId);
				pageUrl = loginUser(user.Username, SiteUtilities.convertToString(formJson.get('password')), lwcSettings);
			}
		}
		SiteUtilities.createLogEntry(
			SiteUtilities.convertToBoolean(lwcSettings.get('loggingEnabled')),
			String.join(SiteUtilities.messages, '\n'),
			SiteUtilities.INFORMATION_LOG_TYPE,
			SiteUtilities.SELF_REG_COMPONENT_NAME
		);

		Map<String, String> itemsToAdd = new Map<String, String>();
		itemsToAdd.put(
			identifier,
			'{"pageUrl":"' + pageUrl + '","verificationId":"' + identifier + '","showVerificationCode":' + SiteUtilities.convertToString(showVerificationCode) + ' }'
		);
		return SiteUtilities.jsonBuilder('registerResult', itemsToAdd);
	}

	/**
	 * @description createContact description
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 * @return returns a new ContactId on successful creation
	 */
	public static Id createContact(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		Database.SaveResult srList = null;
		Id recordId = null;
		try {
			List<Contact> newContacts = new List<Contact>();

			Contact newContact = new Contact();
			newContact.put('AccountId', SiteUtilities.convertToString(configurationOptions.get('accountId')));
			Map<String, Schema.SObjectField> objectMetadata = getMetadataForObject('Contact');
			formInputs = convertFormDataToCorrectDataType(formInputs, configurationOptions, objectMetadata);

			for (String fieldName : formInputs.keySet()) {
				if (checkFieldExists(objectMetadata, fieldName)) {
					newContact.put(fieldName, formInputs.get(fieldName));
				}
			}

			//Fake up First/Last Name as its a required field when creating a Contact... These aren't typically present if using Passwordless.
			//NOTE: Recommended to capture if using standard Self Registration or use a Login Flow to capture after login.
			if (!newContact.isSet('FirstName')) {
				newContact.put('FirstName', 'Site');
			}

			if (!newContact.isSet('LastName')) {
				newContact.put('LastName', 'User');
			}

			newContacts.add(newContact);
			SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.CREATABLE, newContacts);
			srList = Database.insert(securityDecision.getRecords()[0], false);

			if (srList.isSuccess()) {
				//Return the AccountId if the Contact creation was successful, this is what is used during External User creation not the Contact Id!
				return SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin'))
					? srList.getId()
					: SiteUtilities.convertToString(configurationOptions.get('accountId'));
			} else {
				SiteUtilities.messages.add('Failed to create a new Contact record. API Error: ' + srList.getErrors());
				SiteUtilities.createLogEntry(
					SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
					String.join(SiteUtilities.messages, '\n'),
					SiteUtilities.ERROR_LOG_TYPE,
					SiteUtilities.SELF_REG_COMPONENT_NAME
				);
				throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('errorOnCreate')));
			}
		} catch (Exception e) {
			SiteUtilities.messages.add('Failed to create new a Contact record. API Error: ' + e.getMessage());
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('errorOnCreate')));
		}
	}

	/**
	 * @description createPersonAccount description
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 * @return returns the Account Id (PersonAccount Id) on successful creation
	 */
	public static Id createPersonAccount(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		Database.SaveResult srList = null;
		Id recordId = null;
		try {
			List<Account> newPersonAccounts = new List<Account>();
			Account newPersonAccount = new Account();
			newPersonAccount.put(
				'RecordTypeId',
				Schema.SObjectType.Account.getRecordTypeInfosByName().get(SiteUtilities.convertToString(configurationOptions.get('personAccountRecordTypeId'))).getRecordTypeId()
			);
			Map<String, Schema.SObjectField> objectMetadata = getMetadataForObject('Account');

			formInputs = convertFormDataToCorrectDataType(formInputs, configurationOptions, objectMetadata);

			for (String fieldName : formInputs.keySet()) {
				if (checkFieldExists(objectMetadata, fieldName)) {
					newPersonAccount.put(fieldName, formInputs.get(fieldName));

					if (fieldName == 'Email') {
						//Form field is called Email, map this to the PersonEmail field.
						newPersonAccount.put('PersonEmail', formInputs.get(fieldName));
					}

					if (fieldName == 'Mobile') {
						//Form field is called Mobile, map this to the PersonMobilePhone field.
						newPersonAccount.put('PersonMobilePhone', formInputs.get(fieldName));
					}
				}
			}

			//Fake up First/Last Name as its a required field when creating a Person Account... These aren't typically present if using Passwordless.
			//NOTE: Recommended to capture if using standard Self Registration or use a Login Flow to capture after login.
			if (!newPersonAccount.isSet('FirstName')) {
				newPersonAccount.put('FirstName', 'Site');
			}

			if (!newPersonAccount.isSet('LastName')) {
				newPersonAccount.put('LastName', 'User');
			}

			newPersonAccounts.add(newPersonAccount);
			SiteUtilities.messages.add('Person Account to create: ' + newPersonAccounts);
			SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.CREATABLE, newPersonAccounts);
			srList = Database.insert(securityDecision.getRecords()[0], false);

			if (srList.isSuccess()) {
				return srList.getId();
			} else {
				SiteUtilities.messages.add('Failed to create new Person Account record for registered user with submitted values. API Error: ' + srList.getErrors());
				SiteUtilities.createLogEntry(
					SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
					String.join(SiteUtilities.messages, '\n'),
					SiteUtilities.ERROR_LOG_TYPE,
					SiteUtilities.SELF_REG_COMPONENT_NAME
				);
				throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('errorOnCreate')));
			}
		} catch (Exception e) {
			SiteUtilities.messages.add('Failed to create new Person Account record for registered user with submitted values. API Error: ' + e.getMessage());
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('errorOnCreate')));
		}
	}

	/**
	 * @description Creates a record of type Contact or Person Account based on settings in Experience Builder. Passes in form values.
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
	 * @return Id of the newly created record. Either Contact.AccountId if type is a Contact or Id if Person Account
	 */
	public static Id createObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		switch on SiteUtilities.convertToString(configurationOptions.get('objectCreateType')) {
			when 'Contact' {
				return createContact(formInputs, configurationOptions);
			}
			when 'Person Account' {
				return createPersonAccount(formInputs, configurationOptions);
			}
			when else {
				//Object to create was set to blank which is not valid
				SiteUtilities.messages.add(
					'No record found for specified query. Create If Not found setting enabled but Object Type to Create is blank. Please check settings and change to Person Account or Contact.'
				);
				SiteUtilities.createLogEntry(
					SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
					String.join(SiteUtilities.messages, '\n'),
					SiteUtilities.ERROR_LOG_TYPE,
					SiteUtilities.SELF_REG_COMPONENT_NAME
				);
				throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
			}
		}
	}

	/**
	 * @description Creates a non-persisted User object for an external user which is linked to a Contact/Person Account that is found/created in other methods. Committed when the user verifies via a code.
	 * @param formInputs - JSON String of the submitted form values
	 * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
	 * @return User object
	 */
	public static User createUnsavedUser(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		User user = new User();
		formInputs = convertFormDataToCorrectDataType(formInputs, configurationOptions, userObjectMetadata);

		for (String fieldName : formInputs.keySet()) {
			if (checkFieldExists(userObjectMetadata, fieldName)) {
				user.put(fieldName, formInputs.get(fieldName));
			}
		}
		if (string.isBlank(user.CommunityNickname)) {
			user.CommunityNickname = 'SiteUser' + System.now().getTime();
		}
		user.FirstName = String.isBlank(user.FirstName) ? 'Site' : user.FirstName;
		user.LastName = String.isBlank(user.LastName) ? 'User' + System.now().getTime() : user.LastName;

		String personPhone = SiteUtilities.convertToString(formInputs.get('PersonMobilePhone')); //Map the PersonMobilePhone field to the Mobile field.
		user.MobilePhone = String.isBlank(user.MobilePhone) && String.isNotBlank(personPhone) ? personPhone : user.MobilePhone;

		String personEmail = SiteUtilities.convertToString(formInputs.get('PersonEmail')); //Map the PersonEmail field to the Email field.
		user.Email = String.isBlank(user.Email) && String.isNotBlank(personEmail) ? personEmail : user.Email;

		if (SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin'))) {
			user.Email = String.isBlank(user.Email) ? user.MobilePhone + '@passwordlessexternaluser.com' : user.Email;
			user.MobilePhone = String.isNotBlank(user.MobilePhone)
				? UserManagement.formatPhoneNumber(SiteUtilities.convertToString(formInputs.get('countryCode')), user.MobilePhone)
				: '';
			user.TimeZoneSidKey = UserInfo.getTimezone().getID();
			user.LocaleSidKey = UserInfo.getLocale();
			user.EmailEncodingKey = 'UTF-8';
			user.LanguageLocaleKey = UserInfo.getlanguage();
			user.Alias = 'SUser' + String.valueOf(Crypto.getRandomInteger()).substring(0, 3);
			new SiteUtilities().setProfileId(user, SiteUtilities.convertToString(configurationOptions.get('passwordlessProfileId'))); //Profile selected must be a site member otherwise the user creation fails.
		}

		//Set the Username to be the email address if not provided on the form. If passwordless and using SMS verification, email is also not present but required so it is set to a fake value.
		user.Username = String.isBlank(user.Username) ? user.Email : user.Username;
		return user;
	}

	/**
	 * @description Attempts to create an external user which is linked to a Contact/Person Account that is found/created in other methods.
	 * @param formInputs - JSON String of the submitted form values
	 * @param accountId - this is the AccountId that the External User is linked to.
	 * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
	 * @return String of External User Id created
	 */
	public static String createExternalUser(Map<String, Object> formInputs, Id accountId, User user, Map<String, Object> configurationOptions) {
		String userId = null;

		try {
			userId = Site.createExternalUser(
				user,
				accountId,
				SiteUtilities.convertToString(formInputs.get('password')),
				SiteUtilities.convertToBoolean(configurationOptions.get('sendEmailConfirmation'))
			);
		} catch (Site.ExternalUserCreateException e) {
			//The site class ony throws one type of exception so we have to manually handle error messages here.
			SiteUtilities.messages.add('Failed to create external user for portal.' + ' Error: ' + e.getMessage());
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);

			/* Horrible error message. Show a configuration message instead from the property panel. Captures 2 known errors:
			 * 'portal user already exists for contact': If the matched contact (using the custom query) is already a portal user and therefore can't register again.
			 * '[User already exists]': If a new Contact/Person Account is created because existing record wasn't found and the submitted email address matches a user.
			 */
			if (e.getMessage().containsIgnoreCase('user already exists')) {
				throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('portalRegistrationUserExists')));
			}
			//Anything else, show the generic message.
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('portalRegistrationError')));
		}
		return userId;
	}

	/**
	 * @description Attempts to login the newly registered user. Redirects to the home page on success.
	 * @param username - Passes in the submitted username field from the self registration form.
	 * @param password - Passes in the submitted password field from the self registration form.
	 * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
	 * @return String PageURL to redirect to upon successful login.
	 */
	public static String loginUser(String username, String password, Map<String, Object> configurationOptions) {
		String pageUrl = null;

		//TODO: Get the Site.ExperienceId and add to query params on startURL to retain the value?
		try {
			ApexPages.PageReference homePageRef = new PageReference(
				Site.getBaseSecureUrl() + SiteUtilities.convertToString(configurationOptions.get('portalRegistrationRedirect'))
			);
			String startUrl = homePageRef.getUrl();
			ApexPages.PageReference startPageRef = Site.login(username, password, startUrl);

			if (startPageRef != null) {
				pageUrl = startPageRef.getUrl();
			} else {
				ApexPages.PageReference pageRef = new PageReference(
					Site.getBaseSecureUrl() + SiteUtilities.convertToString(configurationOptions.get('portalRegistrationRedirect'))
				);
				pageUrl = pageRef.getUrl();
			}
		} catch (Exception e) {
			SiteUtilities.messages.add('There was a problem logging the user into the portal.' + ' Error: ' + e.getMessage());
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('portalLoginError')));
		}
		SiteUtilities.messages.add('User successfully registered and was logged in.');
		return pageUrl;
	}

	/**
	 * @description getMetadataForObject pass in the object type to retrieve the metadata for. Returns a map of fields for the specified object.
	 * @param  objectType as a string e.g. Account
	 * @return field map from the specified object
	 */
	private static Map<String, Schema.SObjectField> getMetadataForObject(String objectType) {
		return Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
	}

	/**
	 * @description Process the form inputs to convert strings to relevant data types to prevent SOQL/Create record errors.
	 *  Checks for field existence and returns a new map with converted fields that do exist.
	 *  Dates: https://salesforce.stackexchange.com/questions/285603/invalid-bind-expression-type-of-string-for-column-of-type-date
	 *  Datetimes: https://salesforcecody.com/system-typeexception-invalid-date-time-2021-12-28t092046-0500/
	 *  Times: https://developer.salesforce.com/forums/?id=9062I000000IY7KQAW
	 *  Get Datatype: https://salesforce.stackexchange.com/questions/223323/get-the-type-data-type-of-a-field-in-apex
	 * @param  formInputs a map of the form fields submitted from the registration form.
	 * @param configurationOptions a map of the configuration options from the LWC property panel
	 * @param objectMetadata a map of the metadata for a specified object
	 */
	private static Map<String, Object> convertFormDataToCorrectDataType(
		Map<String, Object> formInputs,
		Map<String, Object> configurationOptions,
		Map<String, Schema.SObjectField> objectMetadata
	) {
		for (String fieldName : formInputs.keySet()) {
			if (checkFieldExists(objectMetadata, fieldName)) {
				String dataType = SiteUtilities.convertToString(objectMetadata.get(fieldName).getDescribe().getType());
				switch on dataType {
					when 'DATE' {
						formInputs.put(fieldName, Date.valueOf(SiteUtilities.convertToString(formInputs.get(fieldName))));
					}
					when 'TIME' {
						String[] strTimeSplit = SiteUtilities.convertToString(formInputs.get(fieldName)).split(':');
						formInputs.put(fieldName, Time.newInstance(Integer.valueOf(strTimeSplit[0]), Integer.valueOf(strTimeSplit[1]), 0, 0));
					}
					when 'DATETIME' {
						formInputs.put(fieldName, (DateTime) JSON.deserialize('"' + SiteUtilities.convertToString(formInputs.get(fieldName)) + '"', DateTime.class));
					}
					when 'BOOLEAN' {
						formInputs.put(fieldName, SiteUtilities.convertToBoolean(formInputs.get(fieldName)));
					}
					when 'DECIMAL' {
						formInputs.put(fieldName, Decimal.valueOf(SiteUtilities.convertToString(formInputs.get(fieldName))));
					}
					when 'INTEGER' {
						formInputs.put(fieldName, Integer.valueOf(SiteUtilities.convertToString(formInputs.get(fieldName))));
					}
					when else {
						//Just return the value in the convertedInputs - it will still be a STRING, PHONE, EMAIL (maybe others, which don't need any special treatment)
						formInputs.put(fieldName, SiteUtilities.convertToString(formInputs.get(fieldName)));
					}
				}
			}
		}
		return formInputs;
	}

	/**
	 * @description Looks for existing record matching the query configured in Experience Builder. Can use values from the form using Bind Variables in the query.
	 * @param formInputs - Map of the submitted form values
	 * @param configurationOptions - Map of the LWC property values from the Experience Builder configration panel
	 * @return Id of record found - either Contact.AccountId if type is a Contact or Id if Person Account
	 * @see https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_bind_var_soql.htm&release=242&type=5
	 */
	private static Id getObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
		List<sObject> recordList = new List<sObject>();

		Map<String, Schema.SObjectField> objectMetadata = getMetadataForObject(SiteUtilities.convertToString(configurationOptions.get('objectToQuery')));
		formInputs = convertFormDataToCorrectDataType(formInputs, configurationOptions, objectMetadata);

		//Configurable via the component config panel. May affect what record is found based on org settings.
		//Default is 'System' which ignores FLS/Object settings. Use 'User' to enforce FLS/Object Sharing Settings for the Guest User within the Org.
		//See: https://developer.salesforce.com/docs/atlas.en-us.apexref.meta/apexref/apex_class_System_AccessLevel.htm
		try {
			recordList = SiteUtilities.getRecords(formInputs, configurationOptions);
		} catch (Exception e) {
			SiteUtilities.messages.add(
				'There was a problem executing the specific query in the Custom Query property. Query used: ' +
				SiteUtilities.convertToString(configurationOptions.get('customQuery') + '. Error: ' + e.getMessage())
			);
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.ERROR_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
		}

		if (!recordList.isEmpty() && recordList.size() == 1) {
			String objectType = recordList.getSObjectType().getDescribe().getName();
			switch on objectType {
				when 'Contact' {
					try {
						return SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin'))
							? (Id) recordList[0].get('Id')
							: (Id) recordList[0].get('AccountId');
					} catch (SObjectException e) {
						SiteUtilities.messages.add(
							'AccountId was not present in the query, and is required when selecting records from the Contact object. Query used: ' +
							SiteUtilities.convertToString(configurationOptions.get('customQuery') + '. Error: ' + e.getMessage())
						);
						SiteUtilities.createLogEntry(
							SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
							String.join(SiteUtilities.messages, '\n'),
							SiteUtilities.ERROR_LOG_TYPE,
							SiteUtilities.SELF_REG_COMPONENT_NAME
						);
						throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
					}
				}
				when 'Case' {
					try {
						return SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin'))
							? (Id) recordList[0].get('ContactId')
							: (Id) recordList[0].get('AccountId');
					} catch (SObjectException e) {
						SiteUtilities.messages.add(
							'AccountId was not present in the query, and is required when selecting records from the Contact object. Query used: ' +
							SiteUtilities.convertToString(configurationOptions.get('customQuery') + '. Error: ' + e.getMessage())
						);
						SiteUtilities.createLogEntry(
							SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
							String.join(SiteUtilities.messages, '\n'),
							SiteUtilities.ERROR_LOG_TYPE,
							SiteUtilities.SELF_REG_COMPONENT_NAME
						);
						throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
					}
				}
				when else {
					return (Id) recordList[0].get('Id');
				}
			}
		} else if (recordList.size() > 1) {
			//More than one record found on specified query
			SiteUtilities.messages.add(
				'Multiple records found for specified query. Please check your custom query configuration. External Message: ' +
					configurationOptions.get('multipleRecordsFoundError') +
					' Form Values: ' +
					formInputs
			);
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.INFORMATION_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('multipleRecordsFoundError')));
		} else if (SiteUtilities.convertToBoolean(configurationOptions.get('createNotFound'))) {
			//CreateIfNotFound = True, thus return Null here so we can go on to create a new record.
			return null;
		} else {
			//No record found on specified query and CreateIfNotFound = False
			SiteUtilities.messages.add(
				'No record found for specified query. Create If Not found setting not enabled. External Message: ' +
					configurationOptions.get('noRecordFoundError') +
					' Form Values: ' +
					formInputs
			);
			SiteUtilities.createLogEntry(
				SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')),
				String.join(SiteUtilities.messages, '\n'),
				SiteUtilities.INFORMATION_LOG_TYPE,
				SiteUtilities.SELF_REG_COMPONENT_NAME
			);
			throw new AuraHandledException(SiteUtilities.convertToString(configurationOptions.get('noRecordFoundError')));
		}
	}
}
