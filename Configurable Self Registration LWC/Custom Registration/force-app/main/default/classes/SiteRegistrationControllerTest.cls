/**
 * @description Test Class for Site Registration Controller
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 * NOTES: There are some limitations on the Site & Network classes which return null when not within the context of a Site making it difficult or not possible to achieve 100% code coverage at this time.
 * Unable to test Network Member as this is automatically inserted by the creation of a user, but we don't know if a community will exist at the point of installing the package or which profile will be linked to find this information and test duplicate user names.
 **/
@isTest
private class SiteRegistrationControllerTest {
	//Create a test Person Account record
	@TestSetup
	private static void createPersonAccountTestData() {
		Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
		Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
		SObject newObject = targetType.newSObject();
		Account acc = (Account) newObject;
		acc.put('RecordTypeId', recordTypeId);
		acc.put('FirstName', 'Test');
		acc.put('LastName', 'PA');
		acc.put('PersonEmail', 'user@test.com');
		insert acc;
	}

	//Retrieve custom metadata for the Self Registration component. Uses records created via the Managed Package for standard fields which we can guarantee will be there.
	@isTest
	private static void getActiveCustomConfigurationTestSelfRegistration() {
		String urlParams = '{"FirstName":"Test"}';
		String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
		String resultParsed = '{"data":' + result + '}';
		System.debug('resultedParsed: ' + resultParsed);
		Map<String, Object> fieldConfiguration = (Map<String, Object>) JSON.deserializeUntyped(resultParsed);
		List<Object> dataObj = (List<Object>) fieldConfiguration.get('data');
		System.assertEquals(5, dataObj.size(), '5 ACTIVE configured fields found as expected');
	}

	//Retrieve and test custom settings to enable logging for the Self Regisration component.
	@isTest
	private static void isLoggingEnabledSelfRegistration() {
		Boolean result = SiteUtilities.isLoggingEnabled('Self_Registration_Logging');
		if (result) {
			System.assertEquals(true, result, 'Retrieved custom settings - logging enabled');
		} else {
			System.assertEquals(false, result, 'Retrieved custom settings - logging disabled');
		}
	}

	//Mock a scenario where we do not find a record with the custom query, and create a Person Account
	@isTest
	private static void registerUserCreatePersonAccountObjectSytemAccessLevelTest() {
		String formInputs = '{"Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com", "Mobile":"07747687234", "password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"Person Account", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		SiteRegistrationController.registerUser(formInputs, configurationOptions);

		System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
	}

	//Mock a scenario where we do not find a record with the custom query, and create a Contact (uses System Level access on query)
	@isTest
	private static void registerUserCreateContactObjectSytemAccessLevelTest() {
		Account acc = new Account();
		acc.Name = 'TestAcc';
		insert acc;

		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions =
			'{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' +
			acc.Id +
			'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		SiteRegistrationController.registerUser(formInputs, configurationOptions);

		System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
	}

	//Mock the failed creation of a Person Account with an incorrect record type!
	@isTest
	private static void registerUserCreatePersonAccountObjectFailedTest() {
		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue"}';
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"001dadsdsa67gs", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		try {
			SiteRegistrationController.registerUser(formInputs, configurationOptions);
		} catch (AuraHandledException ex) {
			System.assertEquals(null, null, 'Failed: Invalid fields on the person account object.');
		}
	}

	//Mock duplicate contacts, then try to register a user which results in a failure.
	@isTest
	private static void registerUserDuplicateContactsFound() {
		Account acc = new Account();
		acc.Name = 'TestAcc';
		insert acc;

		Integer noOfContacts = 2;
		List<Contact> cons = new List<Contact>();
		for (Integer i = 1; i <= noOfContacts; i++) {
			Contact con = new Contact();
			con.FirstName = 'Test ' + i;
			con.LastName = 'Contact';
			con.AccountId = acc.Id;
			con.Email = 'usercontact@test.com';
			cons.add(con);
		}
		insert cons;

		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"usercontact@test.com", "Email":"usercontact@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions =
			'{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email", "accessLevelMode":"System", "accountId":"' +
			acc.Id +
			'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false","errorMultipleRecordsFound":"Multiple records found", "portalLoginError":"There was a problem logging in"}';

		try {
			SiteRegistrationController.registerUser(formInputs, configurationOptions);
		} catch (AuraHandledException ex) {
			System.assertEquals(null, null, 'Failed: More than one record was found with custom query.');
		}
	}

	//Mock a custom query on Contacts using the 'User' Access level on the SOQL query. Register the user.
	@isTest
	private static void registerUserCreateContactObjectUserAccessLevelTest() {
		Account acc = new Account();
		acc.Name = 'TestAcc';
		insert acc;

		String formInputs = '{"Username":"user_create_contact_success@test.com", "Email":"user_create_contact_success@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions =
			'{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' +
			acc.Id +
			'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		SiteRegistrationController.registerUser(formInputs, configurationOptions);

		System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
	}

	//Creating a Contact can fail if the admin has created custom configuration in metadata with incorrect API field names so mock that scenario
	@isTest
	private static void registerUserCreateContactObjectFailedTest() {
		Account acc = new Account();
		acc.Name = 'TestAcc';
		insert acc;

		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_create_contact_fail@test.com", "Email":"user_create_contact_fail@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue" }';
		String configurationOptions =
			'{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' +
			acc.Id +
			'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		try {
			SiteRegistrationController.registerUser(formInputs, configurationOptions);
		} catch (AuraHandledException ex) {
			System.assertEquals(null, null, 'Failed: Could not create a Contact due to invalid fields');
		}
	}

	//Mock a scenario where we register a user and do not create a new record because an existing record is found.
	@isTest
	private static void registerUserNoCreateObjectRecordFoundTest() {
		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		SiteRegistrationController.registerUser(formInputs, configurationOptions);
		System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
	}

	//Mock a scenario where we register a user and no existing user is found, plus the createNotFound setting is off which causes a failure.
	@isTest
	private static void registerUserNoCreateObjectRecordNotFoundTest() {
		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_no_create@test.com", "Email":"user_no_create@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		try {
			SiteRegistrationController.registerUser(formInputs, configurationOptions);
		} catch (AuraHandledException ex) {
			System.assertEquals(null, null, 'Failed: No record found and create mdoe was switched off.');
		}
	}

	//Create If not found is true but the Create type is set to blank so the code doesn't know how to proceed and fails.
	@isTest
	private static void registerUserCreateObjectUnknownTypeTest() {
		String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_create_unknown@test.com", "Email":"user_create_unknown@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

		try {
			SiteRegistrationController.registerUser(formInputs, configurationOptions);
		} catch (AuraHandledException ex) {
			System.assertEquals(null, null, 'Failed: Record Not Found & Create If Not Found is switched off.');
		}
	}

	//Requesting too many codes for the same email/mobile during passwordless registration causes a failure and the Person Account created should be deleted.
	@isTest
	private static void deleteRecordTest() {
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in", "portalErrorSendVerificationCode": "testfailure"}';
		Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		Account acc = new Account();
		acc.Name = 'TestAcc';
		insert acc;

		Contact con = new Contact();
		con.FirstName = 'Test';
		con.LastName = 'Contact';
		con.AccountId = acc.Id;
		con.Email = 'usercontact_to_delete@test.com';
		insert con;

		//Test exception.
		try {
			SiteUtilities.deleteRecord(acc.Id, 'WrongType', 'Self Registration', configurationOptionsObject);
		} catch (Exception e) {
			System.assertEquals('Script-thrown exception', e.getMessage(), 'Incorrect type passed, exception generated');
		}

		SiteUtilities.deleteRecord(con.Id, 'Contact', 'Self Registration', configurationOptionsObject);
		SiteUtilities.deleteRecord(acc.Id, 'Account', 'Self Registration', configurationOptionsObject);

		Integer conCount = [SELECT COUNT() FROM Contact WHERE Id = :con.Id];
		Integer accCount = [SELECT COUNT() FROM Account WHERE Id = :acc.Id];

		System.assertEquals(conCount, 0, 'Contact was created and deleted successfully');
		System.assertEquals(accCount, 0, 'Account was created and deleted successfully');
	}

	//Test that person accounts are enabled
	@isTest
	private static void isPersonAccountEnabledTest() {
		SiteRegistrationController.testPersonAccountStatus = true;
		Boolean enabled = SiteRegistrationController.isPersonAccountEnabled();
		System.assertEquals(enabled, true, 'Person Accounts are enabled in this org.');
	}

	//Test if person accounts are disabled
	@isTest
	private static void isPersonAccountNotEnabledTest() {
		SiteRegistrationController.testPersonAccountStatus = false;
		Boolean enabled = SiteRegistrationController.isPersonAccountEnabled();
		System.assertEquals(enabled, false, 'Person Accounts are NOT enabled in this org.');
	}

	//Test the login works once a user is created.
	@isTest
	private static void loginUserTest() {
		String username = 'user@test.com';
		String password = 'Test098!';
		String configurationOptions = '{"loggingEnabled":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1"}';
		Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		String result = SiteRegistrationController.loginUser(username, password, configurationOptionsObject);
		System.assert(result == '', 'Site.login() always returns empty pageRef in tests.');
	}

	@isTest
	private static void testPasswordlessSelfRegistration() {
		//Get the user licence Id for Customer Community
		//See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userlicense.htm
		Id userLicence = [
			SELECT Id, Name, LicenseDefinitionKey
			FROM UserLicense
			WHERE LicenseDefinitionKey = 'PID_Customer_Community'
			LIMIT 1
		]
		.Id;

		//Then get a profile that uses that licence so we can assign it to the test user.
		//NOTE: The query to find a Profile may detect a standard profile that cannot be used without the setting turned on: Setup > Digital Experiences > Settings and select Allow using standard external profiles for self-registration, user creation, and login
		//Unable to workaround this as profiles cannot be created in tests, and you can't easily identify a custom profile via the API to select one.
		String profile = [
			SELECT Id, Name, UserLicenseId
			FROM Profile
			WHERE UserLicenseId = :userLicence
			LIMIT 1
		]
		.Name;

		String formInputs = '{"Email":"user@test.com"}';
		String configurationOptions =
			'{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"Person Account", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"' +
			profile +
			'", "portalRegistrationRedirect":"/"}';
		String testRequestCode = SiteRegistrationController.registerUser(formInputs, configurationOptions);
		Map<String, Object> testRequestCodeParsed = (Map<String, Object>) JSON.deserializeUntyped(testRequestCode);
		List<Object> dataObj = (List<Object>) testRequestCodeParsed.get('registerResult');

		String verificationId = null;
		for (Object obj : dataObj) {
			Map<String, Object> objMap = (Map<String, Object>) obj;
			verificationId = (String) objMap.get('verificationId');
		}

		//NOTE: In Apex tests, there is no Network context, so a hardcoded value is returned.
		System.assertEquals('123456', verificationId, 'Identifier returned as expected');

		formInputs = '{"Email":"user@test.com", "identifier":"' + verificationId + '", "verificationCode":"123456"}';
		UserManagementWrapper mockUM = (UserManagementWrapper) Test.createStub(UserManagementWrapper.class, new MockProvider());
		String verifyUserResponse = mockUM.verifyUser(formInputs, configurationOptions, SiteUtilities.SELF_REG_COMPONENT_NAME);

		Map<String, Object> verifyUserResponseJSON = (Map<String, Object>) JSON.deserializeUntyped(verifyUserResponse);
		List<Object> dataVerifyUser = (List<Object>) verifyUserResponseJSON.get('registerResult');

		String pageUrl = '';
		Boolean verificationSuccess = false;
		for (Object obj : dataVerifyUser) {
			Map<String, Object> dataObj2 = (Map<String, Object>) obj;
			pageUrl = (String) dataObj2.get('pageUrl');
			verificationSuccess = (Boolean) dataObj2.get('verificationSuccess');
		}

		System.assertEquals('https://www.google.com', pageUrl, 'Page Redirect as expected');
		System.assertEquals(true, verificationSuccess, 'Verification successful');
	}

	@isTest
	private static void getUserTest() {
		//Get the user licence Id for Customer Community
		//See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userlicense.htm
		Id userLicence = [
			SELECT Id, Name, LicenseDefinitionKey
			FROM UserLicense
			WHERE LicenseDefinitionKey = 'PID_Customer_Community'
			LIMIT 1
		]
		.Id;

		//Then get a profile that uses that licence so we can assign it to the test user.
		//NOTE: The query to find a Profile may detect a standard profile that cannot be used without the setting turned on: Setup > Digital Experiences > Settings and select Allow using standard external profiles for self-registration, user creation, and login
		//Unable to workaround this as profiles cannot be created in tests, and you can't easily identify a custom profile via the API to select one.
		Id profile = [
			SELECT Id, Name, UserLicenseId
			FROM Profile
			WHERE UserLicenseId = :userLicence
			LIMIT 1
		]
		.Id;

		String email = 'user@test.com';
		String query = 'SELECT Id,PersonContactId,PersonEmail FROM Account WHERE PersonEmail = :email LIMIT 1';
		sObject acc2 = Database.query(query);

		User uCreate = new User(
			FirstName = 'Admin Test',
			LastName = 'User',
			Email = 'user@test.com',
			MobilePhone = '07774567891',
			Username = 'user@test.com',
			CommunityNickname = 'SiteUser',
			EmailEncodingKey = 'ISO-8859-1',
			Alias = 'atuser',
			TimeZoneSidKey = 'GMT',
			LocaleSidKey = 'en_US',
			LanguageLocaleKey = 'en_US',
			ProfileId = profile,
			ContactId = (Id) acc2.get('PersonContactId'),
			IsActive = true
		);
		insert uCreate;

		List<User> u = SiteUtilities.getUserIdWithUsername('user@test.com', '');
		System.assertEquals(true, String.isNotBlank(u[0].Username), 'User found by username');

		List<User> u2 = SiteUtilities.getUserIdWithUsername('', '07774567891');
		System.assertEquals(true, String.isNotBlank(u2[0].MobilePhone), 'User found by phone');
	}

	//Try and login somebody that hasn't registered yet.
	@isTest
	private static void loginNonExistantUserTest() {
		String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"N/A", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
		Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		UserManagementWrapper mockUM = (UserManagementWrapper) Test.createStub(UserManagementWrapper.class, new MockProvider());
		String verifyLoginResponse = mockUM.loginUser('test', 'testpw', lwcSettings);

		System.assertEquals(verifyLoginResponse, 'Failed Login', 'Site.login() always returns empty pageRef in tests so the test is mocked.');
	}

	@isTest
	private static void validateUsernameTest() {
		List<NetworkMember> userList = SiteUtilities.validateUsername('test@mail.com', '123');
		System.assertEquals(0, userList.size(), 'Username is valid');
	}
}
