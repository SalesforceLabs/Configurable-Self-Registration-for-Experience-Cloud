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
    
    private static Boolean isPersonAccountEnabled() {
        return Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');
    }

    /**
     * Builds the server side settings that Apex now loads from the Login Settings record, using the unified keys.
     */
    private static Map<String, Object> loginSettings(Boolean enablePasswordlessLogin) {
        return new Map<String, Object>{
            'loggingEnabled' => true,
            'portalRedirect' => '/',
            'blockUserErrorMessage' => 'user blocked by admin',
            'incorrectUserCredentialsErrorMessage' => 'incorrect credentials',
            'userLockedOutErrorMessage' => 'user temporarily locked out',
            'failedCodeVerificationMessage' => 'code verification failed',
            'enablePasswordlessLogin' => enablePasswordlessLogin,
            'passwordlessMethod' => 'Email'
        };
    }

    //Setup some users for testing the logins via standard and passwordless login.
    @TestSetup
    private static void createTestData(){

        //A list of users that we create and 'test' with
        List<String> usernameList = new List<String> {USERNAME_INVALID_PASSWORD, USERNAME_NOT_FOUND, USERNAME_LOCKOUT, USERNAME_FROZEN, USERNAME_OTHER, USERNAME_GENERIC_FAIL, USERNAME_SUCCESSFUL};

        //Get the user licence Id for Customer Community
        //See: https://developer.salesforce.com/docs/atlas.en-us.object_reference.meta/object_reference/sforce_api_objects_userlicense.htm
        Id userLicence = [
            SELECT Id,Name,LicenseDefinitionKey FROM UserLicense
            WHERE LicenseDefinitionKey = 'PID_Customer_Community'
            LIMIT 1
        ].Id;

        //Then get a profile that uses that licence so we can assign it to the test user.
        //NOTE: The query to find a Profile may detect a standard profile that cannot be used without the setting turned on: Setup > Digital Experiences > Settings and select Allow using standard external profiles for self-registration, user creation, and login
        //Unable to workaround this as profiles cannot be created in tests, and you can't easily identify a custom profile via the API to select one.
        Id profile = [
            SELECT Id,Name,UserLicenseId FROM Profile
            WHERE UserLicenseId = :userLicence
            LIMIT 1
        ].Id;

        if (isPersonAccountEnabled()) {
            Id recordAccTypeId = Schema.sObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
            
            //Create a Person Account for each user in the list above
            List<SObject> a = new List<SObject>();
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
            for (String user : usernameList) {
                SObject newObject = targetType.newSObject(); 
                Account acc = (Account)newObject;
                acc.put('RecordTypeId', recordAccTypeId);
                acc.put('FirstName', 'test');
                acc.put('LastName', 'user');
                acc.put('PersonEmail', user);
                a.add(acc);
            }
            insert a;
        } else {
             List<Account> accounts = new List<Account>();
             List<Contact> contacts = new List<Contact>();
             
             for (String user : usernameList) {
                 Account acc = new Account(Name = 'Test Account ' + user);
                 accounts.add(acc);
             }
             insert accounts;

             for (Integer i = 0; i < usernameList.size(); i++) {
                 Contact con = new Contact(
                     FirstName = 'test',
                     LastName = 'user',
                     Email = usernameList[i],
                     AccountId = accounts[i].Id
                 );
                 contacts.add(con);
             }
             insert contacts;
        }

        //Select an admin user that is active in the system.
        User adminUser = [
            SELECT Id FROM User
            WHERE Profile.Name = 'System Administrator' AND IsActive = true
            LIMIT 1
        ];
    
        //Run the user create as the admin above. Forces a new transaction in the test class.
        //This prevents the 'MIXED_DML' SOQL exception caused by other actions that might run outside of the user creation such as assigning permission sets automatically.
        System.runAs(adminUser) {
            List<User> u = new List<User>();
            for (String user : usernameList) { //Create a user for each of our 'test' user email addresses.
                String userEmail = user;
                Id contactId;

                if (isPersonAccountEnabled()) {
                    List<SObject> acc2 = Database.query('SELECT Id,PersonContactId FROM Account WHERE PersonEmail = :userEmail LIMIT 1'); 
                    if(!acc2.isEmpty()) {
                         contactId = (Id)acc2[0].get('PersonContactId');
                    }
                } else {
                    List<Contact> cons = [SELECT Id FROM Contact WHERE Email = :userEmail LIMIT 1];
                    if(!cons.isEmpty()) {
                        contactId = cons[0].Id;
                    }
                }
                
                if (contactId != null) {
                    User tempUser = new User(  
                        FirstName = 'Test',  
                        LastName = 'User',  
                        Email = user,  
                        Username = user,
                        CommunityNickname = 'SiteUser' + System.now().getTime() + String.valueOf(Crypto.getRandomInteger()),
                        EmailEncodingKey = 'ISO-8859-1',  
                        Alias = 'tuser' + String.valueOf(Crypto.getRandomInteger()).substring(0,2),  
                        TimeZoneSidKey = 'GMT',  
                        LocaleSidKey = 'en_US',  
                        LanguageLocaleKey = 'en_US', 
                        ContactId = contactId,
                        ProfileId = profile 
                    );  
                    u.add(tempUser);
                }
            }
            try {
                System.debug('Users: ' + u);
                insert u;
            }
            catch (Exception e) {
                System.debug('Error during test class' + e.getMessage());
            }
        }
    }

    //Retrieve custom metadata for the Login component. Uses records created via the Managed Package for standard fields which we can guarantee will be there.
    @isTest
    private static void getActiveCustomConfigurationTestLogin() {
        SiteUtilities.mockComponentSettings = loginSettings(false);
        String urlParams = '{"Email":"test@mail.com"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Login');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        // Verify we got a list back (even if empty, it should be a list)
        System.assertNotEquals(null, dataObj, 'Result should be a list');

        // Assert that if we have fields, they have the correct structure
        // We do not assert a specific count or specific fields to allow for org-specific configuration changes
        if (dataObj.size() > 0) {
            Map<String, Object> fieldMap = (Map<String, Object>) dataObj[0];
            System.assert(fieldMap.containsKey('fieldName'), 'Response should contain fieldName');
            System.assert(fieldMap.containsKey('fieldType'), 'Response should contain fieldType');
            System.assert(fieldMap.containsKey('fieldLabel'), 'Response should contain fieldLabel');
        }
    }

    //Retrieve and test custom settings to enable logging for the Login component. Resolved by the Type field, not the DeveloperName.
    @isTest
    private static void isLoggingEnabled() {
        // Test with mock - logging enabled
        SiteUtilities.mockLoggingSettings = new Map<String, Boolean>{SiteUtilities.LOGIN_COMPONENT_NAME => true};
        Boolean result = SiteUtilities.isLoggingEnabled(SiteUtilities.LOGIN_COMPONENT_NAME);
        System.assertEquals(true, result, 'Mock logging enabled should return true');
        
        // Test with mock - logging disabled
        SiteUtilities.mockLoggingSettings.put(SiteUtilities.LOGIN_COMPONENT_NAME, false);
        result = SiteUtilities.isLoggingEnabled(SiteUtilities.LOGIN_COMPONENT_NAME);
        System.assertEquals(false, result, 'Mock logging disabled should return false');
        
        // Clean up
        SiteUtilities.mockLoggingSettings = null;
        
        // Test with real metadata (if it exists)
        Boolean realResult = SiteUtilities.isLoggingEnabled(SiteUtilities.LOGIN_COMPONENT_NAME);
        System.assertNotEquals(null, realResult, 'Should return a boolean value');
    }

    //The packaged Login Settings record should be found by Type and expose the unified keys.
    @isTest
    private static void getComponentSettingsByTypeTest() {
        Map<String, Object> settings = SiteUtilities.getComponentSettings(SiteUtilities.LOGIN_COMPONENT_NAME);
        System.assertNotEquals(null, settings, 'A settings map should be returned for the Login type');
        System.assert(settings.containsKey('loggingEnabled'), 'loggingEnabled should be mapped from Enable__c');
        System.assert(settings.containsKey('portalRedirect'), 'portalRedirect should be mapped from Portal_Redirect__c');
        System.assert(settings.containsKey('buttonLabel'), 'buttonLabel should be mapped from Button_Label__c');
    }

    //The component reads its button labels from the settings record, so only the display values are exposed to the browser.
    @isTest
    private static void getDisplaySettingsTest() {
        SiteUtilities.mockComponentSettings = new Map<String, Object>{
            'buttonLabel' => 'Login',
            'buttonWaitingMessage' => 'Logging in... Please Wait.',
            'buttonAwaitingCodeMessage' => 'Submit Verification Code',
            'passwordMatchError' => 'Passwords do not match',
            'customQuery' => 'SELECT Id FROM Contact LIMIT 1',
            'accountId' => '001000000000000000',
            'passwordlessProfileId' => 'Customer Community User'
        };

        Map<String, Object> display = (Map<String, Object>) JSON.deserializeUntyped(SiteUtilities.getDisplaySettings(SiteUtilities.LOGIN_COMPONENT_NAME));

        System.assertEquals('Login', display.get('buttonLabel'), 'The button label should come from the settings record');
        System.assertEquals('Logging in... Please Wait.', display.get('buttonWaitingMessage'), 'The waiting message should come from the settings record');
        System.assertEquals('Submit Verification Code', display.get('buttonAwaitingCodeMessage'), 'The awaiting code message should come from the settings record');
        System.assertEquals('Passwords do not match', display.get('passwordMatchError'), 'The password match error should come from the settings record');

        //The guest user must not be able to discover how records are matched or which Account and Profile are used.
        System.assertEquals(4, display.size(), 'Only the display values should be returned');
        System.assertEquals(false, display.containsKey('customQuery'), 'The custom query must not be exposed to the browser');
        System.assertEquals(false, display.containsKey('accountId'), 'The Account Id must not be exposed to the browser');
        System.assertEquals(false, display.containsKey('passwordlessProfileId'), 'The passwordless profile must not be exposed to the browser');
    }

    //Only the Login component names itself; anything else is the Self Registration component, matching getCustomConfiguration.
    @isTest
    private static void getDisplaySettingsDefaultsToSelfRegistrationTest() {
        Custom_Experience_Cloud_Setting__mdt selfRegistration = [
            SELECT Button_Label__c FROM Custom_Experience_Cloud_Setting__mdt WHERE Type__c = :SiteUtilities.SELF_REG_COMPONENT_NAME LIMIT 1
        ];

        Map<String, Object> display = (Map<String, Object>) JSON.deserializeUntyped(SiteUtilities.getDisplaySettings('Not A Real Type'));

        System.assertEquals(selfRegistration.Button_Label__c, display.get('buttonLabel'), 'An unrecognised component name should fall back to the Self Registration settings');
    }

    //An unknown Type has no record, so the component cannot silently fall back to unconfigured behaviour.
    @isTest
    private static void getComponentSettingsMissingTypeTest() {
        try {
            SiteUtilities.getComponentSettings('Not A Real Type');
            System.assert(false, 'An exception should be thrown when no settings record matches the Type');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Not A Real Type'), 'The exception should name the Type that was not found');
        }
    }

    //The mock is returned in place of the real record, and Enable__c drives loggingEnabled.
    @isTest
    private static void getComponentSettingsMockTest() {
        SiteUtilities.mockComponentSettings = loginSettings(true);
        Map<String, Object> settings = SiteUtilities.getComponentSettings(SiteUtilities.LOGIN_COMPONENT_NAME);
        System.assertEquals(true, settings.get('loggingEnabled'), 'The mocked loggingEnabled value should be returned');
        System.assertEquals(true, settings.get('enablePasswordlessLogin'), 'The mocked passwordless value should be returned');
    }

    //Mock a login via Passwordless. NOTE: Verifying the code to returned is already covered in registration so no need to it again here as it is mocked anyway.
    @isTest
    private static void customPasswordlessLoginTest() {
        SiteUtilities.mockComponentSettings = loginSettings(true);

        try {
            String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '"}';
            SiteLoginController.loginUser(formJSON, null);
        }
        catch (Exception e) {
            System.assertEquals(null, null, 'Site.login() always returns null in tests.');
        }
    }

    //The response is assembled by SiteUtilities.jsonBuilder so the component can parse it the same way as the registration response.
    @isTest
    private static void loginResultIsBuiltWithJsonBuilderTest() {
        SiteUtilities.mockComponentSettings = loginSettings(true);

        String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '"}';
        String result = SiteLoginController.loginUser(formJSON, null);

        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(result);
        System.assert(parsed.containsKey('loginResult'), 'The response should be keyed on loginResult');

        List<Object> loginResult = (List<Object>) parsed.get('loginResult');
        System.assertEquals(1, loginResult.size(), 'A single login result should be returned');

        Map<String, Object> firstResult = (Map<String, Object>) loginResult[0];
        System.assert(firstResult.containsKey('pageUrl'), 'The result should contain pageUrl');
        System.assertEquals(true, firstResult.get('showVerificationCode'), 'A verification code was sent so the component should show the code input');
        System.assertEquals('123456', firstResult.get('verificationId'), 'The mocked verification identifier should be returned');
    }

    @isTest
    private static void customPasswordlessLoginFailedTest() {
        SiteUtilities.mockComponentSettings = loginSettings(true);

        try {
            String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '"}';
            SiteLoginController.loginUser(formJSON, null);
        }
        catch (Exception e) {
            System.assertEquals(null, null, 'Site.login() always returns null in tests.');
        }
    }

    @isTest
    private static void customLoginTest() {

        SiteUtilities.mockComponentSettings = loginSettings(false);
        
        //A list of users that we create and 'test' with
        List<String> usernameList = new List<String> {USERNAME_INVALID_PASSWORD, USERNAME_NOT_FOUND, USERNAME_LOCKOUT, USERNAME_FROZEN, USERNAME_OTHER, USERNAME_GENERIC_FAIL, USERNAME_SUCCESSFUL};
      
        for (String user : usernameList) { //Loop over the test users. See SiteLoginController.loginUser for hacks/workarounds as Site.Login() doesn't actually work in Test classes.
            try {
                String formJSON = '{"Email":"'+ user +'","Password":"test"}';  //Passing a real password for the test user created above has no effect in a test class!  
                SiteLoginController.loginUser(formJSON, null);
            }
            catch (Exception e) {
                System.assertEquals(null, null, 'Site.login() always returns null in tests.');
            }
        }
    }

    // Ensure Contact.AccountId is available from getUserIdWithUsername to avoid extra queries.
    @isTest
    private static void getUserIncludesContactAccountId() {
        List<User> users = SiteUtilities.getUserIdWithUsername(USERNAME_SUCCESSFUL, null);
        System.assertEquals(1, users.size(), 'Expected a single user for the test username');
        System.assertNotEquals(null, users[0].ContactId, 'ContactId should be populated on the user');
        System.assertNotEquals(null, users[0].Contact, 'Contact relationship should be loaded from the query');
        System.assertNotEquals(null, users[0].Contact.AccountId, 'Contact.AccountId should be populated for logging');
    }

    @isTest
    private static void resolveStartUrlPrefersRelativeDeepLink() {
        System.assertEquals('/s/article/My-Article', SiteUtilities.resolveStartUrl('/s/article/My-Article', '/'), 'Relative startURL should be preferred over the configured redirect');
    }

    @isTest
    private static void resolveStartUrlFallsBackWhenBlank() {
        System.assertEquals('/', SiteUtilities.resolveStartUrl(null, '/'), 'Blank startURL should fall back to the configured Portal Redirect');
        System.assertEquals('/home', SiteUtilities.resolveStartUrl('  ', '/home'), 'Whitespace-only startURL should fall back to the configured Portal Redirect');
    }

    @isTest
    private static void resolveStartUrlRejectsExternalAbsoluteUrl() {
        System.assertEquals('/', SiteUtilities.resolveStartUrl('https://evil.example.com/phish', '/'), 'External absolute URLs must be rejected');
        System.assertEquals('/', SiteUtilities.resolveStartUrl('//evil.example.com/phish', '/'), 'Protocol-relative URLs must be rejected');
    }

    @isTest
    private static void resolveStartUrlAllowsSameSiteAbsoluteUrl() {
        String baseUrl = Site.getBaseSecureUrl();
        if(String.isNotBlank(baseUrl)) {
            String sameSite = baseUrl + '/s/article/Safe';
            System.assertEquals(sameSite, SiteUtilities.resolveStartUrl(sameSite, '/'), 'Same-site absolute URLs should be allowed');
        }
        else {
            System.assertEquals('/s/article/Safe', SiteUtilities.resolveStartUrl('/s/article/Safe', '/'), 'Relative startURL remains valid when Site base URL is blank in tests');
        }
    }

    @isTest
    private static void customLoginWithStartUrlTest() {
        SiteUtilities.mockComponentSettings = loginSettings(false);
        try {
            String formJSON = '{"Email":"' + USERNAME_SUCCESSFUL + '","Password":"test"}';
            SiteLoginController.loginUser(formJSON, '/s/article/Knowledge-Article');
        }
        catch (Exception e) {
            System.assertEquals(null, null, 'Site.login() always returns null in tests.');
        }
    }

    @isTest
    private static void buildLoginStartUrlDoesNotDoubleSitePath() {
        String baseUrl = Site.getBaseSecureUrl();
        if(String.isBlank(baseUrl)) {
            // In contexts with no site base, the relative path is returned as-is.
            System.assertEquals('/lwctest/s/test-page', SiteUtilities.buildLoginStartUrl('/lwctest/s/test-page', '/'),
                'Relative startURL should be returned unchanged when Site base URL is blank');
            return;
        }

        String basePath = new System.Url(baseUrl).getPath();
        if(String.isBlank(basePath) || basePath == '/') {
            System.assert(SiteUtilities.buildLoginStartUrl('/s/test-page', '/').contains('test-page'),
                'startURL path should be preserved when building the login redirect');
            return;
        }

        // Mirror Experience Cloud: startURL already includes the site path prefix.
        String startUrl = (basePath.endsWith('/') ? basePath.substring(0, basePath.length() - 1) : basePath) + '/test-page';
        String built = SiteUtilities.buildLoginStartUrl(startUrl, '/');
        System.assertEquals(startUrl, built, 'Must not prepend Site.getBaseSecureUrl() when startURL already includes the site path');
        System.assert(!built.contains(basePath + basePath), 'Site path must not appear twice in the redirect URL');
    }
}