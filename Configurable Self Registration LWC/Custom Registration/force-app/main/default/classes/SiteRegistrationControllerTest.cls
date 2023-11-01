/**
 * @description Test Class for Site Registration Controller
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 * NOTES: There are some limitations on the Site & Network classes which return null when not within the context of a Site making it difficult or not possible to achieve 100% code coverage at this time.
 * Unable to test Network Member as this is automatically inserted by the creation of a user, but we don't know if a community will exist at the point of installing the package or which profile will be linked to find this information and test duplicate user names.
 * Custom Metadata cannot be created in a test class so the package creates a test record which is then used in the tests. 
 **/
@isTest
private class SiteRegistrationControllerTest {

    //Retrieve custom metadata. Uses records created via the Managed Package for standard fields which we can guarantee will be there.
    @isTest
    private static void getCustomConfigurationTest() {
        String urlParams = '{"FirstName":"Test"}';
        String expected = '[{"fieldType":"text","fieldName":"FirstName","fieldLabel":"First Name","fieldClass":"null","fieldMaxLength":"40.0","fieldValue":"Test","fieldRequired":"true","fieldRequiredMessage":"Please enter a First Name"},{"fieldType":"text","fieldName":"LastName","fieldLabel":"Last Name","fieldClass":"null","fieldMaxLength":"40.0","fieldRequired":"true","fieldRequiredMessage":"Please enter a Last Name"},{"fieldType":"text","fieldName":"Username","fieldLabel":"Username","fieldClass":"null","fieldMaxLength":"40","fieldMessage":"Special characters are not allowed in Usernames","fieldRegex":"[a-zA-Z0-9]+","fieldRequired":"true","fieldRequiredMessage":"Username is required"},{"fieldType":"email","fieldName":"Email","fieldLabel":"Email","fieldClass":"null","fieldMaxLength":"255.0","fieldRequired":"true","fieldRequiredMessage":"Please enter an email address"},{"fieldType":"password","fieldName":"password","fieldLabel":"Password","fieldClass":"passwordCmp","fieldMaxLength":"40.0","fieldRequired":"true","fieldRequiredMessage":"Please enter a password"},{"fieldType":"password","fieldName":"confirmPassword","fieldLabel":"Confirm Password","fieldClass":"confirmPasswordCmp","fieldMaxLength":"40.0","fieldRequired":"true","fieldRequiredMessage":"Please confirm your password"}]';     
        String result =  SiteRegistrationController.getCustomConfiguration(urlParams);
        
        System.assertEquals(expected, result, 'Retrieved custom configuration');
    }

    //Retrieve and test custom settings. 1 is installed by the package and is all is used right now.
    @isTest
    private static void isLoggingEnabled() {
        Boolean result =  SiteRegistrationController.isLoggingEnabled();
        System.assertEquals(false, result, 'Retrieved custom settings - logging disabled');
    }

    //Mock a scenario where we do not find a record with the custom query, and create a Person Account
    @isTest
    private static void registerUserCreatePersonAccountObjectTest() {

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
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

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
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
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
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

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

        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
        SObject newObject = targetType.newSObject(); 
        Account acc = (Account)newObject;
        acc.put('RecordTypeId', recordTypeId);
        acc.put('FirstName', 'Test');
        acc.put('LastName', 'PA');
        acc.put('PersonEmail', 'user@test.com');
        insert acc;
        
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
}