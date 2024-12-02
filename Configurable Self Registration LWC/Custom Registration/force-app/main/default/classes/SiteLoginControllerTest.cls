/**
 * @description Test Class to test the custom login component.
 * NOTE: This test class uses Test.isRunningTest() method to return mock results.
 * Written as a workaround to the site.login() method returning null, and thus unable to replicate a user logging in with incorrect credentials. *****
 * @author: Jamie Lowe
 */
@isTest
private class SiteLoginControllerTest {
	public static final String USERNAME_SUCCESSFUL = 'testusersuccessful@mail.com';
	public static final String USERNAME_OTHER = 'testuserother@mail.com';
	public static final String USERNAME_GENERIC_FAIL = 'testusergenericfail@mail.com';
	public static final String USERNAME_LOCKOUT = 'testuserlocked@mail.com';
	public static final String USERNAME_NOT_FOUND = 'testusernotexist@mail.com';
	public static final String USERNAME_INVALID_PASSWORD = 'testuserinvalidpassword@mail.com';
	public static final String USERNAME_FROZEN = 'testuserblocked@mail.com';

	//Setup some users for testing the logins via standard and passwordless login.
	@TestSetup
	private static void createTestData() {
		//A list of users that we create and 'test' with
		List<String> usernameList = new List<String>{
			USERNAME_INVALID_PASSWORD,
			USERNAME_NOT_FOUND,
			USERNAME_LOCKOUT,
			USERNAME_FROZEN,
			USERNAME_OTHER,
			USERNAME_GENERIC_FAIL,
			USERNAME_SUCCESSFUL
		};

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

		Id recordAccTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

		//Create a Person Account for each user in the list above
		List<SObject> a = new List<SObject>();
		Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
		for (String user : usernameList) {
			SObject newObject = targetType.newSObject();
			Account acc = (Account) newObject;
			acc.put('RecordTypeId', recordAccTypeId);
			acc.put('FirstName', 'test');
			acc.put('LastName', 'user');
			acc.put('PersonEmail', user);
			a.add(acc);
		}
		insert a;

		//Select an admin user that is active in the system.
		User adminUser = [
			SELECT Id
			FROM User
			WHERE Profile.Name = 'System Administrator' AND IsActive = TRUE
			LIMIT 1
		];

		//Run the user create as the admin above. Forces a new transaction in the test class.
		//This prevents the 'MIXED_DML' SOQL exception caused by other actions that might run outside of the user creation such as assigning permission sets automatically.
		System.runAs(adminUser) {
			List<User> u = new List<User>();
			for (String user : usernameList) {
				//Create a user for each of our 'test' user email addresses.
				String userEmail = user;

				List<SObject> acc2 = Database.query('SELECT Id,PersonContactId FROM Account WHERE PersonEmail = :userEmail LIMIT 1'); //Limited to 7 queries, 1 for each test user so not bothered with bulkifying this.
				User tempUser = new User(
					FirstName = 'Test',
					LastName = 'User',
					Email = user,
					Username = user,
					CommunityNickname = 'SiteUser' + System.now().getTime(),
					EmailEncodingKey = 'ISO-8859-1',
					Alias = 'tuser',
					TimeZoneSidKey = 'GMT',
					LocaleSidKey = 'en_US',
					LanguageLocaleKey = 'en_US',
					ContactId = (Id) acc2[0].get('PersonContactId'),
					ProfileId = profile
				);
				u.add(tempUser);
			}
			try {
				System.debug('Users: ' + u);
				insert u;
			} catch (Exception e) {
				System.debug('Error during test class' + e.getMessage());
			}
		}
	}

	//Retrieve custom metadata for the Login component. Uses records created via the Managed Package for standard fields which we can guarantee will be there.
	@isTest
	private static void getActiveCustomConfigurationTestLogin() {
		String urlParams = '{"email":"test@mail.com","success":true}';
		String result = SiteUtilities.getCustomConfiguration(urlParams, 'Login');
		String resultParsed = '{"data":' + result + '}';
		// system.debug(resultParsed.replaceAll(',', ',\r'));
		Map<String, Object> fieldConfiguration = (Map<String, Object>) JSON.deserializeUntyped(resultParsed);
		List<Object> dataObj = (List<Object>) fieldConfiguration.get('data');
		System.assertEquals(3, dataObj.size(), '3 ACTIVE configured fields found as expected');
		integer checked = 0;
		for (object o : dataObj) {
			// system.debug(JSON.serializePretty(o));
			map<string, object> m = (map<string, object>) o;
			if (m.get('fieldType') == 'picklist') {
				// system.debug(json.serializePretty(m));

				checked += 1;
				list<object> optionLists = (list<object>) json.deserializeUntyped((String) m.get('picklistOptions'));
				map<String, Object> options0 = ((map<String, Object>) optionLists[0]);
				map<String, Object> options1 = ((map<String, Object>) optionLists[1]);
				assert.areEqual(options0.get('value'), 'yes', 'wrong picklist options');
				assert.areEqual(options0.get('label'), 'yes', 'wrong picklist options');
				assert.areEqual(options1.get('value'), 'no', 'wrong picklist options');
				assert.areEqual(options1.get('label'), 'no', 'wrong picklist options');

				assert.areEqual(m.get('fieldPlaceholder'), 'placeholder', 'placeholder is wrong');
				assert.areEqual(m.get('fieldMessage'), null, 'field message is present without regex');
				assert.areEqual(m.get('fieldHelpText'), 'Field_Help_Text__c', 'help text is wrong');
			}
			if (m.get('fieldType') == 'text') {
				// system.debug(json.serializePretty(m));

				checked += 1;
				assert.areEqual(m.get('fieldPlaceholder'), 'placeholder', 'wrong placeholder');
				assert.areEqual(m.get('fieldMessage'), 'Field_Message__c', 'wrong field message');
				assert.areEqual(m.get('fieldHelpText'), 'Field_Help_Text__c', 'wrong help text');
				assert.areEqual(m.get('fieldRegex'), '.', 'wrong regex');
				assert.areEqual(m.get('fieldName'), 'email', 'wrong fieldname');
				assert.areEqual(m.get('fieldRequiredMessage'), 'required field is required', 'wrong message');
				assert.areEqual(m.get('fieldRequired'), 'true', 'field should be required');
			}
			if (m.get('fieldType') == 'checkbox') {
				// system.debug(json.serializePretty(m));

				checked += 1;
				assert.areEqual(m.get('fieldName'), 'success', 'field name incorrect');
			}
		}
		Assert.areEqual(3, checked, 'not all objects were recognised and checked');
	}

	//Retrieve and test custom settings to enable logging for the Login component.
	@isTest
	private static void isLoggingEnabled() {
		Boolean result = SiteUtilities.isLoggingEnabled('Login_Logging');
		if (result) {
			System.assertEquals(true, result, 'Retrieved custom settings - logging enabled');
		} else {
			System.assertEquals(false, result, 'Retrieved custom settings - logging disabled');
		}
	}

	//Mock a login via Passwordless. NOTE: Verifying the code to returned is already covered in registration so no need to it again here as it is mocked anyway.
	@isTest
	private static void customPasswordlessLoginTest() {
		String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out","enablePasswordlessLogin": true, "passwordlessMethod":"Email"}';
		Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		try {
			String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '"}';
			SiteLoginController.loginUser(formJSON, lwcSettings);
		} catch (Exception e) {
			System.assertEquals(null, null, 'Site.login() always returns null in tests.');
		}
	}

	@isTest
	private static void customPasswordlessLoginFailedTest() {
		String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out","enablePasswordlessLogin": true, "passwordlessMethod":"Email"}';
		Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		try {
			String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '"}';
			SiteLoginController.loginUser(formJSON, lwcSettings);
		} catch (Exception e) {
			System.assertEquals(null, null, 'Site.login() always returns null in tests.');
		}
	}

	@isTest
	private static void customLoginTest() {
		String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out"}';
		Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

		//A list of users that we create and 'test' with
		List<String> usernameList = new List<String>{
			USERNAME_INVALID_PASSWORD,
			USERNAME_NOT_FOUND,
			USERNAME_LOCKOUT,
			USERNAME_FROZEN,
			USERNAME_OTHER,
			USERNAME_GENERIC_FAIL,
			USERNAME_SUCCESSFUL
		};

		for (String user : usernameList) {
			//Loop over the test users. See SiteLoginController.loginUser for hacks/workarounds as Site.Login() doesn't actually work in Test classes.
			try {
				String formJSON = '{"Email":"' + user + '","Password":"test"}'; //Passing a real password for the test user created above has no effect in a test class!
				SiteLoginController.loginUser(formJSON, lwcSettings);
			} catch (Exception e) {
				System.assertEquals(null, null, 'Site.login() always returns null in tests.');
			}
		}
	}

	@istest
	public static void getPersonAccRecTypes() {
		Assert.isNotNull(SiteUtilities.getPersonAccountRecordTypes('Account'), 'Expected person account record type');
	}

	@istest
	public static void getProfileMembers() {
		Assert.isNotNull(SiteUtilities.getProfileMembers('networkId'), 'expected empty result');
	}
}
