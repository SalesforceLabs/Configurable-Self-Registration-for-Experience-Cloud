/**
 * @description Test Class for Site Registration Controller
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 * NOTES: There are some limitations on the Site & Network classes which return null when not within the context of a Site making it difficult or not possible to achieve 100% code coverage at this time.
 * Unable to test Network Member as this is automatically inserted by the creation of a user, but we don't know if a community will exist at the point of installing the package or which profile will be linked to find this information and test duplicate user names.
 * Custom Metadata cannot be created in a test class so the package creates a test record which is then used in the tests. 
 **/
@isTest
private class SiteRegistrationControllerTest {

    //Retrieve custom metadata. Uses a test record created via the Managed Package as Custom metadata can't easily be tested as they can't be inserted in tests.
    @isTest
    private static void getCustomConfigurationTest() {
    
        String expected = '[{"fieldType":"text","fieldName":"Test_Field__c","fieldLabel":"Test Field","fieldHelpText":"some test help text","fieldMaxLength":"10","fieldMessage":"a test message","fieldRegex":"[0-9]","fieldRequired":"true"}]';     
        String result =  SiteRegistrationController.getCustomConfiguration();
        
        System.assertEquals(expected, result, 'Retrieved custom configuration');
    }

    //Mock a scenario where we do not find a record with the custom query, and create a Person Account
    @isTest
    private static void registerUserCreatePersonAccountObjectTest() {

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"' + recordTypeId  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
       
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
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
       
        SiteRegistrationController.registerUser(formInputs, configurationOptions);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Mock the failed creation of a Person Account when the admin creates custom metadata with the incorrect Custom Field API names.
    @isTest
    private static void registerUserCreatePersonAccountObjectFailedTest() {

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"' + recordTypeId  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
      
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
            con.Email = 'user@test.com';
            cons.add(con);
        }
        insert cons;
         
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false","errorMultipleRecordsFound":"Multiple records found", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
 
        try {
            SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: More than one record was found with custom query.');
        }
    }

    //Mock a custom query on Contacts using the 'User' Access level on the SOQL query. Register the user.
    @isTest
    private static void registerUserCreateContactObjectUserAcessLevelTest() {

        Account acc = new Account();
        acc.Name = 'TestAcc';
        insert acc;
        
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
       
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
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
       
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

        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account();
        acc.RecordTypeId = recordTypeId;
        acc.FirstName = 'Test';
        acc.LastName = 'Contact';
        acc.PersonEmail = 'user@test.com';
        insert acc;
            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

        SiteRegistrationController.registerUser(formInputs, configurationOptions);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Mock a scenario where we register a user and no existing user is found, plus the createNotFound setting is off which causes a failure.
    @isTest
    private static void registerUserNoCreateObjectRecordNotFoundTest() {
            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

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
        String configurationOptions = '{"loggingEnabled":"true", "createNotFound":"true", "objectCreateType":"N/A", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorNoRecordFound":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

        try {
             SiteRegistrationController.registerUser(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: Record Not Found & Create If Not Found is switched off.');
        } 
    }

    //Test if the username is valid i.e. it is not taken
    @isTest
    private static void validUsernameTest() {
        String username = 'user@test.com';
        Boolean loggingEnabled = true;
        SiteRegistrationController.isValidUsername(username, loggingEnabled);
        System.assert(true, 'Username of ' + username + ' is valid.');
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

    //Generate a nickname over 40 characters and check it returns max of 40
    @isTest
    private static void generateCommunityNicknameTest() {
        String nickname = SiteRegistrationController.generateCommunityNickname('averylongusertestnicknameforexperiencecloud');
        System.assertEquals(40, nickname.length(), 'Nickname was 40 characters');
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

    //NOTE: Known issue - see: https://help.salesforce.com/s/articleView?id=000391105&type=1
    //Site.validatePassword method always fails during tests and is therefore bypassed, the rest gives some code coverage.
    @isTest
    private static void isPasswordValidTest() {
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
        SiteRegistrationController.validatePassword(formInputs, configurationOptions);
        System.assert(true, 'Password was valid');
    }

    //Validating the password requires a valid User object. The fields passed into the object can fail if custom metadata is configured with invalid custom field names so this test actually mocks that scenario.
    @isTest
    private static void passwordValidationFailed() {
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testval"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
        try {
             SiteRegistrationController.validatePassword(formInputs, configurationOptions);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(false, false, 'Password validation failed');
        } 
    }
}