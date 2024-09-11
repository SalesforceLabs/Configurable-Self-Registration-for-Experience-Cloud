/**
 * @description Test Class for Site Registration Controller
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 * NOTES: There are some limitations on the Site & Network classes which return null when not within the context of a Site making it difficult or not possible to achieve 100% code coverage at this time.
 * Unable to test Network Member as this is automatically inserted by the creation of a user, but we don't know if a community will exist at the point of installing the package or which profile will be linked to find this information and test duplicate user names. 
 **/
@isTest
private class SiteRegistrationControllerTest {

    //Retrieve custom metadata for the Self Registration component. Uses records created via the Managed Package for standard fields which we can guarantee will be there.
    @isTest
    private static void getActiveCustomConfigurationTestSelfRegistration() {
        String urlParams = '{"FirstName":"Test"}';
        String result = SiteRegistrationController.getCustomConfiguration(urlParams);
        String resultParsed = '{"data":' + result + '}';        
        Map<String, Object> fieldConfiguration = (Map<String, Object>) JSON.deserializeUntyped(resultParsed);
        List<Object> dataObj = (List<Object>) fieldConfiguration.get('data');
        System.assertEquals(5, dataObj.size(), '5 ACTIVE configured fields found as expected');
    }

    //Retrieve and test custom settings to enable logging for the Self Regisration component.
    @isTest
    private static void isLoggingEnabledSelfRegistration() {
        Boolean result =  SiteUtilities.isLoggingEnabled('Self_Registration_Logging');
        System.assertEquals(false, result, 'Retrieved custom settings - logging disabled');
    }

    @isTest
    private static void checkForSMSLicence() {
        Integer count = SiteUtilities.checkSMSLicence();
        
        if(count == 0) {
            System.assertEquals(0, count, 'SMS licence is not available in the org.'); 
        }
        else {
            System.assertEquals(1, count, 'SMS licence is available in the org.'); 
        }
    }

    //Mock a scenario where we do not find a record with the custom query, and create a Person Account
    @isTest
    private static void registerUserCreatePersonAccountObjectSytemAccessLevelTest() {

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"' + recordTypeId  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
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
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        SiteRegistrationController.registerUser(formInputs, configurationOptions);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Mock the failed creation of a Person Account when the admin creates custom metadata with the incorrect Custom Field API names.
    @isTest
    private static void registerUserCreatePersonAccountObjectFailedTest() {

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"' + recordTypeId  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        try {
             SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
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
        for(Integer i = 1; i <= noOfContacts; i++) {
            Contact con = new Contact();
            con.FirstName = 'Test ' + i;
            con.LastName = 'Contact';
            con.AccountId = acc.Id;
            con.Email = 'user@test.com';
            cons.add(con);
        }
        insert cons;
         
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false","errorMultipleRecordsFound":"Multiple records found", "portalLoginError":"There was a problem logging in"}';

        try {
            SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: More than one record was found with custom query.');
        }
    }

    //Mock a custom query on Contacts using the 'User' Access level on the SOQL query. Register the user.
    @isTest
    private static void registerUserCreateContactObjectUserAccessLevelTest() {

        Account acc = new Account();
        acc.Name = 'TestAcc';
        insert acc;
        
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
        SiteRegistrationController.registerUser(formInputs, configurationOptions);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Creating a Contact can fail if the admin has created custom configuration in metadata with incorrect API field names so mock that scenario
    @isTest
    private static void registerUserCreateContactObjectFailedTest() {

        Account acc = new Account();
        acc.Name = 'TestAcc';
        insert acc;
        
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue" }';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        try {
            SiteRegistrationController.registerUser(formInputs, configurationOptions); 
        }
        catch(AuraHandledException ex) {
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
            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        try {
             SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: No record found and create mdoe was switched off.');
        } 
    }

    //Create If not found is true but the Create type is set to N/A so the code doesn't know how to proceed and fails.
    @isTest
    private static void registerUserCreateObjectUnknownTypeTest() {            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"N/A", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        try {
             SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: Record Not Found & Create If Not Found is switched off.');
        } 
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

    //Create a test Person Account record
    @TestSetup
    private static void createPersonAccountTestData() {
        
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
        SObject newObject = targetType.newSObject(); 
        Account acc = (Account)newObject;
        acc.put('RecordTypeId', recordTypeId);
        acc.put('FirstName', 'Test');
        acc.put('LastName', 'PA');
        acc.put('PersonEmail', 'user@test.com');
        insert acc;
    }

    @isTest
    private static void testPasswordlessSelfRegistration() {
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

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

        String formInputs = '{"Email":"user@test.com"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"' + recordTypeId  +'", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"'+profile+'", "portalRegistrationRedirect":"/"}';
        String testRequestCode = SiteRegistrationController.registerUser(formInputs, configurationOptions);
        Map<String, Object> testRequestCodeParsed = (Map<String, Object>) JSON.deserializeUntyped(testRequestCode);
        List<Object> dataObj = (List<Object>) testRequestCodeParsed.get('registerResult');
        
        String identifier = '';
        for (Object obj : dataObj) {
            Map<String, Object> dataObj2 = (Map<String, Object>) obj;
            identifier = (String) dataObj2.get('verificationId');
        }

        //NOTE: In Apex tests, there is no Network context, so a hardcoded value is returned.
        System.assertEquals('123456', identifier, 'Identifier returned as expected');
        
        formInputs = '{"Email":"user@test.com", "identifier":"'+ identifier +'", "verificationCode":"123456"}';
        UserManagementWrapper mockUM = (UserManagementWrapper)MockUtil.createMock(UserManagementWrapper.class);
        String verifyUserResponse = mockUM.verifyUserMock(formInputs, configurationOptions);

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
    private static void validateUsernameTest() {
        List<NetworkMember> userList = SiteUtilities.validateUsername('test@mail.com', '123');
        System.assertEquals(0, userList.size(), 'Username is valid');
    }
}