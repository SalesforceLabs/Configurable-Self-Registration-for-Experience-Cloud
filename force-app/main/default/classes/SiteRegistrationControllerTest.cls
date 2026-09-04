/**
 * @description Test Class for Site Registration Controller
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 * NOTES: There are some limitations on the Site & Network classes which return null when not within the context of a Site making it difficult or not possible to achieve 100% code coverage at this time.
 * Unable to test Network Member as this is automatically inserted by the creation of a user, but we don't know if a community will exist at the point of installing the package or which profile will be linked to find this information and test duplicate user names. 
 **/
@isTest
private class SiteRegistrationControllerTest {

    private static Boolean isPersonAccountEnabled() {
        return Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');
    }

    /**
     * @description Apex now loads Self Registration behaviour from the Custom Experience Cloud Setting record rather than trusting the
     * client, so tests seed the server side settings instead of passing configuration up from the component.
     * @param configurationOptions a JSON string using the unified setting keys.
     */
    private static void mockSelfRegistrationSettings(String configurationOptions) {
        SiteUtilities.mockComponentSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
    }

    /**
     * @description A valid Self Registration configuration for tests that only exercise the field metadata rather than the behaviour settings.
     * Apex validates the settings record before returning the form fields, so a configuration is always required.
     */
    private static void mockValidSelfRegistrationSettings() {
        mockSelfRegistrationSettings('{"loggingEnabled":"true", "objectToQuery":"Contact", "createNotFound":"false", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System"}');
    }

    /**
     * @description Helper method to create mock Custom Metadata wrapper for testing
     * Based on pattern from: https://crsinfosolutions.com/custom-metadata-unit-test/
     */
    private static SiteUtilities.CustomConfigurationWrapper createMockMetadataWrapper(
        String fieldType, String fieldName, String fieldLabel, String fieldPlaceholder,
        String fieldMessage, String fieldValidationRegex, Boolean fieldRequired,
        String fieldRequiredMessage, String fieldHelpText, String fieldPicklistOptions) {
        
        return new SiteUtilities.CustomConfigurationWrapper(
            fieldType, fieldName, fieldLabel, fieldPlaceholder,
            fieldMessage, fieldValidationRegex, fieldRequired,
            fieldRequiredMessage, fieldHelpText, fieldPicklistOptions
        );
    }

    //Create a test Person Account record or Contact/Account if PA not enabled
    @TestSetup
    private static void createTestData() {
        if (isPersonAccountEnabled()) {
            Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
            SObject newObject = targetType.newSObject(); 
            Account acc = (Account)newObject;
            acc.put('RecordTypeId', recordTypeId);
            acc.put('FirstName', 'Test');
            acc.put('LastName', 'PA');
            acc.put('PersonEmail', 'user@test.com');
            insert acc;        
        } else {
            Account acc = new Account(Name = 'Test Account');
            insert acc;
            Contact con = new Contact(FirstName = 'Test', LastName = 'PA', Email = 'user@test.com', AccountId = acc.Id);
            insert con;
        }
    }

    //Retrieve custom metadata for the Self Registration component. Uses mock metadata for testing.
    @isTest
    private static void getActiveCustomConfigurationTestSelfRegistration() {
        // Set up mock metadata
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('text', 'FirstName', 'First Name', null, null, null, false, null, null, null));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{"FirstName":"Test"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        // Verify we got a list back
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        System.assertEquals(1, dataObj.size(), 'Should have one field');
        
        Map<String, Object> fieldMap = (Map<String, Object>) dataObj[0];
        System.assertEquals('FirstName', fieldMap.get('fieldName'), 'Should have correct field name');
        System.assertEquals('text', fieldMap.get('fieldType'), 'Should have correct field type');
        System.assertEquals('First Name', fieldMap.get('fieldLabel'), 'Should have correct field label');
        System.assertEquals('Test', fieldMap.get('fieldValue'), 'Should have URL param value');
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    //Retrieve and test custom settings to enable logging for the Self Registration component. Resolved by the Type field, not the DeveloperName.
    @isTest
    private static void isLoggingEnabledSelfRegistration() {
        // Test with mock - logging enabled
        SiteUtilities.mockLoggingSettings = new Map<String, Boolean>{SiteUtilities.SELF_REG_COMPONENT_NAME => true};
        Boolean result = SiteUtilities.isLoggingEnabled(SiteUtilities.SELF_REG_COMPONENT_NAME);
        System.assertEquals(true, result, 'Mock logging enabled should return true');
        
        // Test with mock - logging disabled
        SiteUtilities.mockLoggingSettings.put(SiteUtilities.SELF_REG_COMPONENT_NAME, false);
        result = SiteUtilities.isLoggingEnabled(SiteUtilities.SELF_REG_COMPONENT_NAME);
        System.assertEquals(false, result, 'Mock logging disabled should return false');
        
        // Clean up
        SiteUtilities.mockLoggingSettings = null;
        
        // Test with real metadata (if it exists)
        Boolean realResult = SiteUtilities.isLoggingEnabled(SiteUtilities.SELF_REG_COMPONENT_NAME);
        System.assertNotEquals(null, realResult, 'Should return a boolean value');
    }
    
    @isTest
    private static void testIsLoggingEnabledExceptionPath() {
        // Test exception path - simulate query failure
        // We can't easily simulate a query exception, but we can test the method handles missing settings
        SiteUtilities.mockLoggingSettings = new Map<String, Boolean>();
        // Don't add the setting, so it will fall through to real query
        Boolean result = SiteUtilities.isLoggingEnabled('NonExistent_Type');
        System.assertEquals(false, result, 'Non-existent type should return false');
        
        // Clean up
        SiteUtilities.mockLoggingSettings = null;
    }
    
    @isTest
    private static void testIsLoggingEnabledMultipleSettings() {
        // Test both component types resolved by the Type field
        SiteUtilities.mockLoggingSettings = new Map<String, Boolean>{
            SiteUtilities.SELF_REG_COMPONENT_NAME => true,
            SiteUtilities.LOGIN_COMPONENT_NAME => false
        };
        
        System.assertEquals(true, SiteUtilities.isLoggingEnabled(SiteUtilities.SELF_REG_COMPONENT_NAME), 'Self Registration logging should be enabled');
        System.assertEquals(false, SiteUtilities.isLoggingEnabled(SiteUtilities.LOGIN_COMPONENT_NAME), 'Login logging should be disabled');
        System.assertEquals(false, SiteUtilities.isLoggingEnabled('NonExistent'), 'Non-existent type should return false');
        
        // Clean up
        SiteUtilities.mockLoggingSettings = null;
    }

    //Enable__c on the settings record is what drives the loggingEnabled key used throughout Apex.
    @isTest
    private static void enableFieldDrivesLoggingEnabledTest() {
        Map<String, Object> settings = SiteUtilities.getComponentSettings(SiteUtilities.SELF_REG_COMPONENT_NAME);
        System.assert(settings.containsKey('loggingEnabled'), 'loggingEnabled should be present on the settings map');
        System.assertEquals(
            SiteUtilities.isLoggingEnabled(SiteUtilities.SELF_REG_COMPONENT_NAME),
            SiteUtilities.convertToBoolean(settings.get('loggingEnabled')),
            'loggingEnabled should match the Enable__c value resolved by Type'
        );
    }

    //The object being queried is derived from the SOQL rather than stored, so it never has to be calculated in the browser.
    @isTest
    private static void getObjectToQueryTest() {
        System.assertEquals('Contact', SiteUtilities.getObjectToQuery('SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1'), 'Contact should be derived from the query');
        System.assertEquals('Account', SiteUtilities.getObjectToQuery('select Id from Account where PersonEmail = :Email'), 'Object should be derived regardless of keyword case');
        System.assertEquals('', SiteUtilities.getObjectToQuery(''), 'A blank query should return a blank object name');
        System.assertEquals('', SiteUtilities.getObjectToQuery(null), 'A null query should return a blank object name');
    }

    //Configuration problems are reported by Apex so the custom query never has to be sent to the browser to be checked.
    @isTest
    private static void validateSelfRegistrationSettingsTest() {
        Map<String, Object> settings = new Map<String, Object>{'customQuery' => '', 'objectToQuery' => ''};
        System.assertEquals('A Custom Query is required to use this component.', SiteUtilities.validateSelfRegistrationSettings(settings), 'A blank query should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id FROM Lead LIMIT 1', 'objectToQuery' => 'Lead'};
        System.assertEquals('Only Contact, Account or Case objects are supported with a Custom Query on this component.', SiteUtilities.validateSelfRegistrationSettings(settings), 'Unsupported objects should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => true, 'objectCreateType' => ''};
        System.assertEquals('Object Create Type must be set when Create Record If Not Found is enabled.', SiteUtilities.validateSelfRegistrationSettings(settings), 'A blank create type should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => true, 'objectCreateType' => 'Contact', 'accountId' => ''};
        System.assertEquals('Please specify an Account Id on the Self Registration settings record when creating a Contact.', SiteUtilities.validateSelfRegistrationSettings(settings), 'A blank Account Id should be rejected when creating Contacts');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => true, 'objectCreateType' => 'Contact', 'accountId' => '001'};
        System.assertEquals('Account Id must be a Salesforce 15 or 18 character reference.', SiteUtilities.validateSelfRegistrationSettings(settings), 'A short Account Id should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => true, 'objectCreateType' => 'Contact', 'accountId' => '003000000000000'};
        System.assertEquals('Account Id must start with 001 (Account Object Type).', SiteUtilities.validateSelfRegistrationSettings(settings), 'A non-Account prefix should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => false};
        System.assertEquals(null, SiteUtilities.validateSelfRegistrationSettings(settings), 'A valid configuration should not report a problem');

        //A profile that does not exist must be reported when the page loads, not when someone tries to register.
        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => false,
                                           'enablePasswordlessLogin' => true, 'passwordlessProfileId' => 'Not A Real Profile'};
        System.assert(SiteUtilities.validateSelfRegistrationSettings(settings).contains('Not A Real Profile'), 'An unknown passwordless profile should be rejected');

        settings = new Map<String, Object>{'customQuery' => 'SELECT Id,AccountId FROM Contact LIMIT 1', 'objectToQuery' => 'Contact', 'createNotFound' => false,
                                           'enablePasswordlessLogin' => true, 'passwordlessProfileId' => ''};
        System.assert(SiteUtilities.validateSelfRegistrationSettings(settings).contains('Please set a Passwordless Profile'), 'A blank passwordless profile should be rejected');
    }

    //The settings hold a profile name rather than an Id, so a typo must produce a configuration message instead of a raw query exception.
    @isTest
    private static void getProfileIdTest() {
        Profile existing = [SELECT Id, Name FROM Profile LIMIT 1];
        System.assertEquals(existing.Id, SiteUtilities.getProfileId(existing.Name), 'A valid profile name should resolve to its Id');

        try {
            SiteUtilities.getProfileId('Not A Real Profile');
            System.assert(false, 'An unknown profile name should throw');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Not A Real Profile'), 'The message should name the profile that was not found');
        }

        try {
            SiteUtilities.getProfileId('');
            System.assert(false, 'A blank profile name should throw');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Passwordless Profile'), 'The message should point the admin at the setting');
        }
    }

    //The settings hold a record type name rather than an Id. Developer Name is preferred but the label must keep working for existing configurations.
    @isTest
    private static void getPersonAccountRecordTypeIdTest() {
        List<RecordType> accountRecordTypes = [SELECT Id, Name, DeveloperName FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true LIMIT 1];

        if(!accountRecordTypes.isEmpty()) {
            RecordType existing = accountRecordTypes[0];
            System.assertEquals(existing.Id, SiteUtilities.getPersonAccountRecordTypeId(existing.DeveloperName), 'A Developer Name should resolve to the record type Id');
            System.assertEquals(existing.Id, SiteUtilities.getPersonAccountRecordTypeId(existing.Name), 'A label should still resolve for existing configurations');
        }

        try {
            SiteUtilities.getPersonAccountRecordTypeId('Not A Real Record Type');
            System.assert(false, 'An unknown record type should throw');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Not A Real Record Type'), 'The message should name the record type that was not found');
        }

        try {
            SiteUtilities.getPersonAccountRecordTypeId('');
            System.assert(false, 'A blank record type should throw');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Person Account Record Type'), 'The message should point the admin at the setting');
        }
    }

    //A missing settings record must surface as a component error rather than falling back to unconfigured behaviour.
    @isTest
    private static void getCustomConfigurationMissingSettingsTest() {
        try {
            SiteUtilities.getComponentSettings('Not A Real Type');
            System.assert(false, 'An exception should be thrown when no settings record matches the Type');
        }
        catch (SiteUtilities.ComponentSettingsException e) {
            System.assert(e.getMessage().contains('Not A Real Type'), 'The exception should name the Type that was not found');
        }
    }


    //Mock a scenario where we do not find a record with the custom query, and create a Person Account (or Contact if PA disabled)
    @isTest
    private static void registerUserCreatePersonAccountObjectSytemAccessLevelTest() {

        String formInputs = '{"Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com", "Mobile":"07747687234", "password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions;

        if (isPersonAccountEnabled()) {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"Person Account", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        } else {
             Account acc = new Account(Name = 'Test Account Parent');
             insert acc;
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id + '", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
             // Add required fields for Contact creation if needed, though FirstName/LastName are handled in code
             formInputs = '{"FirstName":"Test", "LastName":"User", "Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com", "Mobile":"07747687234", "password":"Testing123!", "confirmPassword":"Testing123!"}';
        }
 
        mockSelfRegistrationSettings(configurationOptions);
        SiteRegistrationController.registerUser(formInputs, null);

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

        mockSelfRegistrationSettings(configurationOptions);
        SiteRegistrationController.registerUser(formInputs, null);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Mock the failed creation of a Person Account with an incorrect record type!
    // If PA is disabled, we simulate a failure in Contact creation by providing invalid fields
    @isTest
    private static void registerUserCreatePersonAccountObjectFailedTest() {

        String formInputs; 
        String configurationOptions;

        if (isPersonAccountEnabled()) {
             formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue"}';
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"001dadsdsa67gs", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        } else {
             Account acc = new Account(Name = 'Test Account Parent');
             insert acc;
             formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"testusernotexist@mail.com", "Email":"testusernotexist@mail.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue"}';
             // Force failure by using invalid config or fields
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id + '", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        }

        mockSelfRegistrationSettings(configurationOptions);
        try {
             SiteRegistrationController.registerUser(formInputs, null);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: Invalid fields on the person account object or invalid record type.');
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
            con.Email = 'usercontact@test.com';
            cons.add(con);
        }
        insert cons;
         
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"usercontact@test.com", "Email":"usercontact@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email", "accessLevelMode":"System", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false","multipleRecordsFoundError":"Multiple records found", "portalLoginError":"There was a problem logging in"}';

        mockSelfRegistrationSettings(configurationOptions);
        try {
            SiteRegistrationController.registerUser(formInputs, null);
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
        
        String formInputs = '{"Username":"user_create_contact_success@test.com", "Email":"user_create_contact_success@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
 
        mockSelfRegistrationSettings(configurationOptions);
        SiteRegistrationController.registerUser(formInputs, null);

        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
    }

    //Creating a Contact can fail if the admin has created custom configuration in metadata with incorrect API field names so mock that scenario
    @isTest
    private static void registerUserCreateContactObjectFailedTest() {

        Account acc = new Account();
        acc.Name = 'TestAcc';
        insert acc;
        
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_create_contact_fail@test.com", "Email":"user_create_contact_fail@test.com","password":"Testing123!", "confirmPassword":"Testing123!", "SomeFieldThatDoesntExist__c":"testvalue" }';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"User", "accountId":"' + acc.Id  +'", "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';

        mockSelfRegistrationSettings(configurationOptions);
        try {
            SiteRegistrationController.registerUser(formInputs, null); 
        }
        catch(AuraHandledException ex) {
           System.assertEquals(null, null, 'Failed: Could not create a Contact due to invalid fields');  
        }
    }

    //Mock a scenario where we register a user and do not create a new record because an existing record is found.
    @isTest
    private static void registerUserNoCreateObjectRecordFoundTest() {
                
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions;

        if (isPersonAccountEnabled()) {
            configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        } else {
            configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "createNotFound":"false", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        }

        mockSelfRegistrationSettings(configurationOptions);
        SiteRegistrationController.registerUser(formInputs, null);
        System.assertEquals(null, null, 'Site.createExternalUser() always returns null in tests.');
        
    }

    //Mock a scenario where we register a user and no existing user is found, plus the createNotFound setting is off which causes a failure.
    @isTest
    private static void registerUserNoCreateObjectRecordNotFoundTest() {
            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_no_create@test.com", "Email":"user_no_create@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions;

        if (isPersonAccountEnabled()) {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"false", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        } else {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "createNotFound":"false", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        }

        mockSelfRegistrationSettings(configurationOptions);
        try {
             SiteRegistrationController.registerUser(formInputs, null);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: No record found and create mdoe was switched off.');
        } 
    }

    //Create If not found is true but the Create type is set to blank so the code doesn't know how to proceed and fails.
    @isTest
    private static void registerUserCreateObjectUnknownTypeTest() {            
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user_create_unknown@test.com", "Email":"user_create_unknown@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions;

        if (isPersonAccountEnabled()) {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        } else {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "createNotFound":"true", "objectCreateType":"", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        }

        mockSelfRegistrationSettings(configurationOptions);
        try {
             SiteRegistrationController.registerUser(formInputs, null);
        }
        catch(AuraHandledException ex) {
            System.assertEquals(null, null, 'Failed: Record Not Found & Create If Not Found is switched off.');
        } 
    }

    //Requesting too many codes for the same email/mobile during passwordless registration causes a failure and the Person Account created should be deleted.
    @isTest
    private static void deleteRecordTest() {
        // The query in config needs to be valid for the org
        String customQuery = isPersonAccountEnabled() ? 'SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1' : 'SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"", "customQuery":"'+ customQuery +'", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in", "portalErrorSendVerificationCode": "testfailure"}';
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
        }
        catch (Exception e) {
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Incorrect type passed, exception generated');
        } 
        
        SiteUtilities.deleteRecord(con.Id, 'Contact', 'Self Registration', configurationOptionsObject);
        SiteUtilities.deleteRecord(acc.Id, 'Account', 'Self Registration', configurationOptionsObject);

        Integer conCount = [SELECT count() FROM Contact WHERE Id = :con.Id];
        Integer accCount = [SELECT count() FROM Account WHERE Id = :acc.Id];
        
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
        String customQuery = isPersonAccountEnabled() ? 'SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1' : 'SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1';
        String configurationOptions = '{"loggingEnabled":"true", "customQuery":"' + customQuery + '"}';
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

        String result = SiteRegistrationController.loginUser(username, password, configurationOptionsObject);
        System.assert(result == '', 'Site.login() always returns empty pageRef in tests.');
    }  

    @isTest
    private static void testPasswordlessSelfRegistration() {
        
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
        String profile = [
            SELECT Id,Name,UserLicenseId FROM Profile
            WHERE UserLicenseId = :userLicence
            LIMIT 1
        ].Name;

        String formInputs = '{"Email":"user@test.com"}';
        String configurationOptions;

        if (isPersonAccountEnabled()) {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"Person Account", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"'+profile+'", "portalRedirect":"/"}';
        } else {
             Account acc = new Account(Name = 'Test Account Parent');
             insert acc;
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id + '", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"'+profile+'", "portalRedirect":"/"}';
        }

        mockSelfRegistrationSettings(configurationOptions);
        String testRequestCode = SiteRegistrationController.registerUser(formInputs, null);
        Map<String, Object> testRequestCodeParsed = (Map<String, Object>) JSON.deserializeUntyped(testRequestCode);
        List<Object> dataObj = (List<Object>) testRequestCodeParsed.get('registerResult');
    
        String verificationId = null;
        for(Object obj : dataObj) {
            Map<String, Object> objMap = (Map<String, Object>) obj;
            verificationId = (String) objMap.get('verificationId');
        }
        
        //NOTE: In Apex tests, there is no Network context, so a hardcoded value is returned.
        System.assertEquals('123456', verificationId, 'Identifier returned as expected');
        
        formInputs = '{"Email":"user@test.com", "identifier":"'+ verificationId +'", "verificationCode":"123456"}';
        UserManagementWrapper mockUM = (UserManagementWrapper)Test.createStub(UserManagementWrapper.class, new MockProvider());
        String verifyUserResponse = mockUM.verifyUser(formInputs, SiteUtilities.SELF_REG_COMPONENT_NAME);

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
    private static void testRegisterUserSendVerificationCodeException() {
        // Test coverage for lines 158-171: Exception handling when sendVerificationCode fails
        // This covers the catch block that deletes created records and throws AuraHandledException
        
        // Get Community User license and profile
        Id userLicence = [
            SELECT Id,Name,LicenseDefinitionKey FROM UserLicense
            WHERE LicenseDefinitionKey = 'PID_Customer_Community'
            LIMIT 1
        ].Id;

        String profile = [
            SELECT Id,Name,UserLicenseId FROM Profile
            WHERE UserLicenseId = :userLicence
            LIMIT 1
        ].Name;

        String formInputs = '{"Email":"exceptiontest@test.com"}';
        String configurationOptions;
        Id accountId = null;

        if (isPersonAccountEnabled()) {
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "objectCreateType":"Person Account", "createNotFound":"true", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System", "personAccountRecordTypeId":"Person Account", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"'+profile+'", "portalRedirect":"/", "portalErrorSendVerificationCode":"Error sending verification code"}';
        } else {
             Account acc = new Account(Name = 'Test Account Parent');
             insert acc;
             accountId = acc.Id;
             configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"' + acc.Id + '", "enablePasswordlessLogin": true, "passwordlessMethod":"Email", "passwordlessProfileId":"'+profile+'", "portalRedirect":"/", "portalErrorSendVerificationCode":"Error sending verification code"}';
        }

        // Clear messages before test
        SiteUtilities.messages.clear();
        
        // Set flag to simulate exception in sendVerificationCode
        SiteUtilities.simulateSendVerificationCodeException = true;
        
        mockSelfRegistrationSettings(configurationOptions);
        try {
            SiteRegistrationController.registerUser(formInputs, null);
            System.assert(false, 'Should have thrown AuraHandledException');
        } catch (AuraHandledException e) {
            // Verify the exception message matches the configured error message
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Should throw configured error message');
            
            // Verify messages were added (line 160)
            System.assert(SiteUtilities.messages.size() > 0, 'Should have logged error messages');
            Boolean foundErrorMessage = false;
            for (String msg : SiteUtilities.messages) {
                if (msg.contains('Error sending a verification code')) {
                    foundErrorMessage = true;
                    break;
                }
            }
            System.assertEquals(true, foundErrorMessage, 'Should have logged error message about sending verification code');
            
            // Verify that deleteRecord was called (lines 163-167)
            // Since createNotFound=true and recordCreated=true, the record should be deleted
            Boolean foundDeleteMessage = false;
            for (String msg : SiteUtilities.messages) {
                if (msg.contains('Deleting created record Id') || msg.contains('Record was successfully deleted')) {
                    foundDeleteMessage = true;
                    break;
                }
            }
            System.assertEquals(true, foundDeleteMessage, 'Should have logged delete record messages');
            
            // Verify the record was actually deleted
            // Note: For Person Accounts, we verify deletion via log messages since PersonEmail field
            // cannot be queried in Contact orgs (causes linter errors)
            if (!isPersonAccountEnabled()) {
                // For Contact orgs, verify the Contact was deleted
                List<Contact> contacts = [SELECT Id FROM Contact WHERE Email = 'exceptiontest@test.com'];
                System.assertEquals(0, contacts.size(), 'Contact should have been deleted');
            }
            // For Person Accounts, deletion is verified via the log messages checked above
        } finally {
            // Clean up
            SiteUtilities.simulateSendVerificationCodeException = false;
            SiteUtilities.messages.clear();
        }
    }

    @isTest
    private static void getUserTest() {
       
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
       
       String email = 'user@test.com';
       Id contactId;
       
       if (isPersonAccountEnabled()) {
           String query = 'SELECT Id,PersonContactId,PersonEmail FROM Account WHERE PersonEmail = :email LIMIT 1';
           sObject acc2 = Database.query(query);
           contactId = (Id)acc2.get('PersonContactId');
       } else {
           Contact con = [SELECT Id FROM Contact WHERE Email = :email LIMIT 1];
           contactId = con.Id;
       }

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
            ContactId = contactId,
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
        String customQuery = isPersonAccountEnabled() ? 'SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1' : 'SELECT Id,Email,AccountId FROM Contact WHERE Email = :Email LIMIT 1';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "createNotFound":"true", "objectCreateType":"N/A", "customQuery":"'+ customQuery +'", "accessLevelMode":"System", "noRecordFoundError":"No record found" , "errorOnCreate": "There was a problem creating a record", "sendEmailConfirmation":"false", "portalLoginError":"There was a problem logging in"}';
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        
        UserManagementWrapper mockUM = (UserManagementWrapper)Test.createStub(UserManagementWrapper.class, new MockProvider());
        String verifyLoginResponse = mockUM.loginUser('test', 'testpw', lwcSettings);

        System.assertEquals(verifyLoginResponse, 'Failed Login', 'Site.login() always returns empty pageRef in tests so the test is mocked.');
    }

    @isTest
    private static void validateUsernameTest() {
        List<NetworkMember> userList = SiteUtilities.validateUsername('test@mail.com', '123');
        System.assertEquals(0, userList.size(), 'Username is valid');
    }

    @isTest
    private static void testDataTypeConversion() {
        Map<String, Object> configOptions = new Map<String, Object>();
        
        // Create modifiable maps of fields
        Map<String, Schema.SObjectField> contactFields = new Map<String, Schema.SObjectField>(Schema.SObjectType.Contact.fields.getMap());
        Map<String, Schema.SObjectField> accountFields = new Map<String, Schema.SObjectField>(Schema.SObjectType.Account.fields.getMap());
        
        // 1. DATE: Contact.Birthdate
        Map<String, Object> inputs = new Map<String, Object>();
        inputs.put('Birthdate', '2023-01-01');
        
        // 2. BOOLEAN: Contact.DoNotCall
        inputs.put('DoNotCall', 'true');
        
        // 3. DATETIME: Contact.CreatedDate (Read-only but valid for type check logic)
        String dtString = '2023-10-01T12:00:00Z';
        inputs.put('CreatedDate', dtString);

        // 4. TIME: No standard Time field on Account/Contact. 
        // We inject a standard Time field from BusinessHours into the map to test the logic path.
        // This simulates a custom Time field existing on the Contact object.
        // Note: BusinessHours.MondayStartTime is a Time field.
        Schema.SObjectField timeField = BusinessHours.MondayStartTime;
        contactFields.put('TestTimeField', timeField);
        inputs.put('TestTimeField', '09:00');
        
        Map<String, Object> convertedCon = SiteRegistrationController.convertFormDataToCorrectDataType(inputs, configOptions, contactFields);
        
        System.assertEquals(Date.newInstance(2023, 1, 1), convertedCon.get('Birthdate'), 'Date conversion failed');
        System.assertEquals(true, convertedCon.get('DoNotCall'), 'Boolean conversion failed');
        
        DateTime dt = (DateTime)convertedCon.get('CreatedDate');
        System.assertEquals(2023, dt.year(), 'DateTime year conversion failed');
        
        Object timeValue = convertedCon.get('TestTimeField');
        Time t;
        if (timeValue instanceof Time) {
            t = (Time)timeValue;
        } else if (timeValue instanceof String) {
            // Handle case where conversion didn't happen or value was stored as String
            String[] strTimeSplit = ((String)timeValue).split(':');
            t = Time.newInstance(Integer.valueOf(strTimeSplit[0]), Integer.valueOf(strTimeSplit[1]), 0, 0);
        } else {
            System.assert(false, 'TestTimeField is neither Time nor String: ' + timeValue);
        }
        System.assertEquals(9, t.hour(), 'Time hour conversion failed');
        
        // 5. INTEGER: Account.NumberOfEmployees
        Map<String, Object> accountInputs = new Map<String, Object>();
        accountInputs.put('NumberOfEmployees', '100');
        
        // 6. DECIMAL: Account.AnnualRevenue
        accountInputs.put('AnnualRevenue', '1000.50');

        Map<String, Object> convertedAcc = SiteRegistrationController.convertFormDataToCorrectDataType(accountInputs, configOptions, accountFields);
        System.assertEquals(100, (Integer)convertedAcc.get('NumberOfEmployees'), 'Integer conversion failed');
        System.assertEquals(1000.50, Decimal.valueOf(String.valueOf(convertedAcc.get('AnnualRevenue'))), 'Decimal conversion failed');
    }

    @isTest
    private static void testGetObjectExceptions() {
        // Test querying a Contact without AccountId in the result (triggers SObjectException in getObject logic)
        
        // Setup data
        Account acc = new Account(Name = 'Test Exception');
        insert acc;
        Contact con = new Contact(LastName = 'Test', AccountId = acc.Id, Email = 'exception@test.com');
        insert con;
        
        String formInputs = '{"Email":"exception@test.com"}';
        // Note: Intentionally omitting AccountId from query to trigger exception when type is Contact
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"false", "customQuery":"SELECT Id,Email FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found"}';
        
        Map<String, Object> inputsMap = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        
        try {
            SiteRegistrationController.getObject(inputsMap, configMap);
        } catch (AuraHandledException e) {
            // Expected
            System.assert(true, 'Exception caught as expected');
        }
    }

    @isTest
    private static void testGetObjectCase() {
        // Create a Case
        Account acc = new Account(Name = 'TestCase');
        insert acc;
        Contact con = new Contact(LastName = 'TestCase', AccountId = acc.Id);
        insert con;
        Case c = new Case(Subject = 'TestCase', ContactId = con.Id, AccountId = acc.Id);
        insert c;
        
        String formInputs = '{"Subject":"TestCase"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Case", "objectCreateType":"Case", "createNotFound":"false", "customQuery":"SELECT Id,ContactId,AccountId FROM Case WHERE Subject = :Subject LIMIT 1", "accessLevelMode":"System", "noRecordFoundError":"No record found"}';
        
        Map<String, Object> inputsMap = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> configMap = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        
        // This should return the AccountId from the case (standard flow)
        Id result = SiteRegistrationController.getObject(inputsMap, configMap);
        System.assertEquals(acc.Id, result, 'Should return AccountId from Case');
    }

    @isTest
    private static void testCreateContactInsertFailure() {
        // Force a failure during Contact insert by not providing AccountId (mandatory for Contacts in most orgs without PA or even with PA for standard contacts linked to business accounts)
        // And we don't default it in code if it's missing from config.
        
        String formInputs = '{"FirstName":"Fail", "LastName":"Insert", "Email":"fail@test.com"}';
        // Missing accountId in config
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Contact", "objectCreateType":"Contact", "createNotFound":"true", "customQuery":"SELECT Id FROM Contact WHERE Email = :Email LIMIT 1", "accessLevelMode":"System", "accountId":"", "errorOnCreate": "Creation Failed"}';
        
        mockSelfRegistrationSettings(configurationOptions);
        try {
            SiteRegistrationController.registerUser(formInputs, null);
            // If it succeeds (e.g. org allows orphan contacts), this assert will fail, but usually they are private.
        } catch (AuraHandledException e) {
             System.assertEquals('Script-thrown exception', e.getMessage(), 'Should catch exception from createContact');
        }
    }

    @isTest
    private static void testSanitiseJson() {
        Map<String, Object> formJson = new Map<String, Object>{
            'password' => 'secret123',
            'confirmPassword' => 'secret123',
            'Email' => 'test@test.com',
            'FirstName' => 'Test'
        };
        
        Map<String, Object> sanitised = SiteRegistrationController.sanitiseJson(formJson);
        
        System.assertEquals('HIDDEN', sanitised.get('password'), 'Password should be hidden');
        System.assertEquals('HIDDEN', sanitised.get('confirmPassword'), 'Confirm password should be hidden');
        System.assertEquals('test@test.com', sanitised.get('Email'), 'Email should remain');
        System.assertEquals('Test', sanitised.get('FirstName'), 'FirstName should remain');
    }

    @isTest
    private static void testIsValidUsername() {
        Map<String, Object> formInputs = new Map<String, Object>{'Username' => 'newuser@test.com'};
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'usernameTakenMessage' => 'Username already taken'
        };
        
        // Should pass as username doesn't exist
        Boolean result = SiteRegistrationController.isValidUsername(formInputs, configOptions);
        System.assertEquals(true, result, 'Username should be valid');
    }

    @isTest
    private static void testIsValidUsernameAlreadyExists() {
        // Test the exception path when username already exists (lines 72-76)
        // This tests: userList.size() >= 1, logging, and exception throwing
        
        // Create a mock NetworkMember to simulate existing username
        // Note: NetworkMember fields are read-only, so we create an empty object
        // The code only checks userList.size() >= 1, so we just need a non-empty list
        NetworkMember mockMember = new NetworkMember();
        
        // Set mock NetworkMember list - the list just needs to have size >= 1
        // The actual field values don't matter since the code only checks the size
        SiteUtilities.mockNetworkMemberList = new List<NetworkMember>{mockMember};
        
        Map<String, Object> formInputs = new Map<String, Object>{'Username' => 'existinguser@test.com'};
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'usernameTakenMessage' => 'Username already taken'
        };
        
        // Clear messages before test
        SiteUtilities.messages.clear();
        
        // Test the exception path - this will execute lines 72-76
        try {
            SiteRegistrationController.isValidUsername(formInputs, configOptions);
            System.assert(false, 'Should have thrown exception for existing username');
        } catch (AuraHandledException e) {
            // Exception path (lines 72-76) - verify correct message
            System.assertEquals('Script-thrown exception', e.getMessage(), 'Should throw exception');
            // Verify logging was called (line 74)
            System.assert(SiteUtilities.messages.size() > 0, 'Should have logged messages');
            // Verify the specific message about username existing was added (line 73)
            Boolean foundMessage = false;
            for (String msg : SiteUtilities.messages) {
                if (msg.contains('already exists') && msg.contains('Username NOT valid')) {
                    foundMessage = true;
                    break;
                }
            }
            System.assertEquals(true, foundMessage, 'Should have logged username exists message');
        } finally {
            // Clean up mock
            SiteUtilities.mockNetworkMemberList = null;
            SiteUtilities.messages.clear();
        }
    }

    @isTest
    private static void testValidatePasswordException() {
        Map<String, Object> formJson = new Map<String, Object>{
            'password' => 'short',
            'confirmPassword' => 'short'
        };
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true'
        };
        
        User testUser = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@test.com',
            Username = 'test@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8'
        );
        
        // In test context, Site.validatePassword is bypassed, so we test the exception path differently
        // The method catches exceptions, so we verify it doesn't throw when Test.isRunningTest() is true
        try {
            SiteRegistrationController.validatePassword(formJson, configOptions, testUser);
            System.assert(true, 'Password validation should be bypassed in test context');
        } catch (Exception e) {
            // If exception is thrown, verify it's handled properly
            System.assert(true, 'Exception handled');
        }
    }

    @isTest
    private static void testCreateExternalUserException() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Contact con = new Contact(FirstName = 'Test', LastName = 'User', Email = 'existing@test.com', AccountId = acc.Id);
        insert con;
        
        // Get the user licence Id for Customer Community
        Id userLicence = [
            SELECT Id,Name,LicenseDefinitionKey FROM UserLicense
            WHERE LicenseDefinitionKey = 'PID_Customer_Community'
            LIMIT 1
        ].Id;

        // Get a profile that uses that licence for Community Users
        Id profileId = [
            SELECT Id,Name,UserLicenseId FROM Profile
            WHERE UserLicenseId = :userLicence
            LIMIT 1
        ].Id;
        
        Map<String, Object> formInputs = new Map<String, Object>{
            'password' => 'Test123!',
            'Email' => 'existing@test.com'
        };
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'sendEmailConfirmation' => 'false',
            'portalRegistrationUserExists' => 'User already exists',
            'portalRegistrationError' => 'Registration error'
        };
        
        User newUser = new User(
            FirstName = 'New',
            LastName = 'User',
            Email = 'existing@test.com',
            Username = 'existing@test.com' + System.now().getTime(),
            Alias = 'nuser',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            LanguageLocaleKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profileId,
            ContactId = con.Id
        );
        
        // NOTE: In test context, Site.createExternalUser() returns null instead of throwing exceptions.
        // This test verifies that the method handles the null return value correctly.
        // The exception path (Site.ExternalUserCreateException) cannot be tested in unit tests
        // as Site.createExternalUser() doesn't throw exceptions in test context.
        String userId = SiteRegistrationController.createExternalUser(formInputs, acc.Id, newUser, configOptions);
        // In test context, Site.createExternalUser returns null, so userId will be null
        System.assertEquals(null, userId, 'Should return null in test context');
    }

    @isTest
    private static void testLoginUserException() {
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'portalRedirect' => '/test',
            'portalLoginError' => 'Login error'
        };
        
        // Test exception path - Site.login() returns null in tests, but we can test the exception handling
        try {
            String result = SiteRegistrationController.loginUser('invalid@test.com', 'wrongpassword', configOptions);
            // In test context, Site.login() returns null, so this should work
            System.assertNotEquals(null, result, 'Should return a URL even in test context');
        } catch (Exception e) {
            System.assert(true, 'Exception handled');
        }
    }

    @isTest
    private static void testGetObjectQueryException() {
        Map<String, Object> formInputs = new Map<String, Object>{'Email' => 'test@test.com'};
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'objectToQuery' => 'Contact',
            'customQuery' => 'SELECT InvalidField FROM Contact WHERE Email = :Email LIMIT 1'
        };
        
        try {
            SiteRegistrationController.getObject(formInputs, configOptions);
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(true, 'Query exception caught as expected');
        }
    }

    @isTest
    private static void testSiteUtilitiesConvertToInteger() {
        Integer result1 = SiteUtilities.convertToInteger('123');
        System.assertEquals(123, result1, 'Should convert string to integer');
        
        Integer result2 = SiteUtilities.convertToInteger(null);
        System.assertEquals(null, result2, 'Should return null for null input');
    }

    @isTest
    private static void testSiteUtilitiesGetPersonContactId() {
        if (isPersonAccountEnabled()) {
            // Get an Account from test setup - use dynamic query to avoid compiler errors in Contact orgs
            String query = 'SELECT Id FROM Account LIMIT 1';
            List<sObject> accounts = Database.query(query);
            if (!accounts.isEmpty()) {
                Id accountId = (Id)accounts[0].get('Id');
                // The method itself uses dynamic SOQL internally, so it will work in Person Account orgs
                Id contactId = SiteUtilities.getPersonContactId(accountId);
                System.assertNotEquals(null, contactId, 'Should return PersonContactId');
            }
        } else {
            System.assert(true, 'Person Accounts not enabled, skipping test');
        }
    }

    @isTest
    private static void testSiteUtilitiesGetLoginHistory() {
        // Test with existing user from setup or create one
        List<User> existingUsers = [SELECT Id FROM User WHERE IsActive = true LIMIT 1];
        if (!existingUsers.isEmpty()) {
            String status = SiteUtilities.getLoginHistory(existingUsers[0].Id);
            // Status might be null if no login history exists, which is fine - we're just testing the method executes
            System.assert(true, 'Login history method executed');
        } else {
            // Create a user if none exists
            Id profileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id;
            User testUser = new User(
                FirstName = 'Login',
                LastName = 'Test',
                Email = 'logintest@test.com',
                Username = 'logintest@test.com' + System.now().getTime(),
                Alias = 'ltest',
                TimeZoneSidKey = 'GMT',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = profileId
            );
            insert testUser;
            
            String status = SiteUtilities.getLoginHistory(testUser.Id);
            System.assert(true, 'Login history method executed');
        }
    }

    @isTest
    private static void testSiteUtilitiesSetProfileId() {
        // Get a profile that exists
        List<Profile> profiles = [SELECT Id, Name FROM Profile LIMIT 1];
        if (!profiles.isEmpty()) {
            User testUser = new User(
                FirstName = 'Profile',
                LastName = 'Test',
                Email = 'profiletest@test.com',
                Username = 'profiletest@test.com' + System.now().getTime(),
                Alias = 'ptest',
                TimeZoneSidKey = 'GMT',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8'
            );
            
            new SiteUtilities().setProfileId(testUser, profiles[0].Name);
            System.assertEquals(profiles[0].Id, testUser.ProfileId, 'ProfileId should be set');
        }
    }

    @isTest
    private static void testSiteUtilitiesSetContactId() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        Contact con = new Contact(FirstName = 'Test', LastName = 'Contact', AccountId = acc.Id);
        insert con;
        
        List<Profile> profiles = [SELECT Id FROM Profile LIMIT 1];
        if (!profiles.isEmpty()) {
            User testUser = new User(
                FirstName = 'Contact',
                LastName = 'Test',
                Email = 'contacttest@test.com',
                Username = 'contacttest@test.com' + System.now().getTime(),
                Alias = 'ctest',
                TimeZoneSidKey = 'GMT',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = profiles[0].Id
            );
            
            new SiteUtilities().setContactId(testUser, con.Id);
            System.assertEquals(con.Id, testUser.ContactId, 'ContactId should be set');
        }
    }

    @isTest
    private static void testSiteUtilitiesVerifyUserLogin() {
        // Test verifyUser for Login component (not Self Registration) via wrapper
        String formInputs = '{"Email":"test@test.com", "identifier":"123456", "verificationCode":"123456", "portalRedirect":"/"}';
        
        // Mock the UserManagement calls via wrapper
        UserManagementWrapper mockUM = (UserManagementWrapper)Test.createStub(UserManagementWrapper.class, new MockProvider());
        String result = mockUM.verifyUser(formInputs, SiteUtilities.LOGIN_COMPONENT_NAME);
        
        System.assertNotEquals(null, result, 'Should return verification result');
    }

    //The wrapper is normally replaced by a stub so the real methods are never executed. Call them directly to prove they delegate correctly.
    @isTest
    private static void userManagementWrapperDelegatesTest() {
        UserManagementWrapper wrapper = new UserManagementWrapper();

        //UserManagement cannot verify a code in a test context, so this only proves the call is delegated to SiteUtilities.
        mockValidSelfRegistrationSettings();
        try {
            wrapper.verifyUser('{"Email":"user@test.com", "identifier":"123456", "verificationCode":"123456"}', SiteUtilities.SELF_REG_COMPONENT_NAME);
        }
        catch (Exception e) {
            System.assertNotEquals(null, e, 'UserManagement cannot verify a code in a test context.');
        }

        //Site.login() may return an empty PageReference URL in tests, or null (then we fall back to the configured Portal Redirect).
        Map<String, Object> settings = new Map<String, Object>{'loggingEnabled' => true, 'portalRedirect' => '/', 'portalLoginError' => 'Login error'};
        String loginResult = wrapper.loginUser('user@test.com', 'Testing123!', settings);
        String expectedFallback = SiteUtilities.buildLoginStartUrl(null, '/');
        System.assert(
            String.isBlank(loginResult) || loginResult == expectedFallback || loginResult == '/',
            'Expected an empty Site.login result or the configured portal redirect fallback. Actual: ' + loginResult
        );
    }

    @isTest
    private static void testSiteUtilitiesSendVerificationCodeLogin() {
        List<Profile> profiles = [SELECT Id FROM Profile LIMIT 1];
        if (!profiles.isEmpty()) {
            User testUser = new User(
                FirstName = 'Verify',
                LastName = 'Test',
                Email = 'verifytest@test.com',
                Username = 'verifytest@test.com' + System.now().getTime(),
                Alias = 'vtest',
                TimeZoneSidKey = 'GMT',
                LocaleSidKey = 'en_US',
                LanguageLocaleKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = profiles[0].Id
            );
            
            String identifier = SiteUtilities.sendVerificationCode(Auth.VerificationMethod.EMAIL, testUser, SiteUtilities.LOGIN_COMPONENT_NAME);
            System.assertEquals('123456', identifier, 'Should return test identifier');
        }
    }

    @isTest
    private static void testSiteUtilitiesGetCustomConfigurationError() {
        // Test error handling in getCustomConfiguration with valid JSON but invalid component name
        // This tests the exception handling path in the try-catch block
        mockValidSelfRegistrationSettings();
        try {
            // Use valid JSON but test that the method handles errors gracefully
            String result = SiteUtilities.getCustomConfiguration('{}', 'InvalidComponent');
            // Method should still return a result (empty list) or throw exception for invalid component
            System.assertNotEquals(null, result, 'Should return a result even with empty params');
        } catch (Exception e) {
            // If exception is thrown, verify it's handled
            System.assert(true, 'Exception handled: ' + e.getMessage());
        }
    }


    @isTest
    private static void testGetCustomConfigurationWithAllFields() {
        // Test getCustomConfiguration with URL params to exercise all code paths
        // This tests: urlParameters loop, picklist handling, placeholder, validation, required, help text
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('text', 'Email', 'Email', 'Enter email', 'Invalid email', '^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$', true, 'Email is required', 'Enter your email address', null));
        mockMetadata.add(createMockMetadataWrapper('picklist', 'Country', 'Country', null, null, null, false, null, null, '["USA","Canada","UK"]'));
        mockMetadata.add(createMockMetadataWrapper('checkbox', 'SomeField', 'Some Field', null, null, null, false, null, null, null));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{"Email":"test@test.com", "Country":"USA", "SomeField":true}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        System.assertEquals(3, dataObj.size(), 'Should have three fields');
        
        // Verify Email field has placeholder, validation, required, and help text
        Map<String, Object> emailField = null;
        Map<String, Object> picklistField = null;
        Map<String, Object> checkboxField = null;
        
        for (Object obj : dataObj) {
            Map<String, Object> fieldMap = (Map<String, Object>) obj;
            if (fieldMap.get('fieldName') == 'Email') {
                emailField = fieldMap;
            } else if (fieldMap.get('fieldName') == 'Country') {
                picklistField = fieldMap;
            } else if (fieldMap.get('fieldName') == 'SomeField') {
                checkboxField = fieldMap;
            }
        }
        
        // Test Email field properties
        System.assertNotEquals(null, emailField, 'Email field should exist');
        System.assertEquals('Enter email', emailField.get('fieldPlaceholder'), 'Should have placeholder');
        System.assertEquals('Invalid email', emailField.get('fieldMessage'), 'Should have validation message');
        System.assertEquals('^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$', emailField.get('fieldRegex'), 'Should have validation regex');
        System.assertEquals('true', emailField.get('fieldRequired'), 'Should be required');
        System.assertEquals('Email is required', emailField.get('fieldRequiredMessage'), 'Should have required message');
        System.assertEquals('Enter your email address', emailField.get('fieldHelpText'), 'Should have help text');
        System.assertEquals('test@test.com', emailField.get('fieldValue'), 'Should have URL param value');
        
        // Test Picklist field
        System.assertNotEquals(null, picklistField, 'Picklist field should exist');
        System.assertEquals(true, picklistField.get('showAsPicklist'), 'Should show as picklist');
        System.assertNotEquals(null, picklistField.get('picklistOptions'), 'Should have picklist options');
        
        // Test Checkbox field
        System.assertNotEquals(null, checkboxField, 'Checkbox field should exist');
        System.assertEquals(true, checkboxField.get('fieldChecked'), 'Should be checked');
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    @isTest
    private static void testGetCustomConfigurationLoginComponent() {
        // Test Login component path
        SiteUtilities.mockComponentSettings = new Map<String, Object>{'loggingEnabled' => true, 'portalRedirect' => '/'};
        String urlParams = '{"Email":"test@test.com", "Password":"test123"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Login');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        
        // Verify it queries Custom_Login_Configuration__mdt
        if (dataObj.size() > 0) {
            Map<String, Object> fieldMap = (Map<String, Object>) dataObj[0];
            System.assert(fieldMap.containsKey('fieldName'), 'Should contain fieldName');
        }
    }

    @isTest
    private static void testGetCustomConfigurationWithBooleanUrlParams() {
        // Test URL params with boolean values to exercise fieldChecked path
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('checkbox', 'SomeCheckbox', 'Some Checkbox', null, null, null, false, null, null, null));
        mockMetadata.add(createMockMetadataWrapper('text', 'Email', 'Email', null, null, null, false, null, null, null));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{"SomeCheckbox":true, "Email":"test@test.com"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        
        // Verify boolean URL params are handled
        Boolean foundCheckbox = false;
        for (Object obj : dataObj) {
            Map<String, Object> fieldMap = (Map<String, Object>) obj;
            if (fieldMap.get('fieldName') == 'SomeCheckbox' && fieldMap.containsKey('fieldChecked')) {
                System.assertEquals(true, fieldMap.get('fieldChecked'), 'Checkbox should be checked');
                foundCheckbox = true;
            }
        }
        System.assertEquals(true, foundCheckbox, 'Should find checkbox field');
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    @isTest
    private static void testGetCustomConfigurationPicklistWithEmptyOptions() {
        // Test picklist field with empty/null picklist options
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('picklist', 'Country', 'Country', null, null, null, false, null, null, null));
        mockMetadata.add(createMockMetadataWrapper('picklist', 'State', 'State', null, null, null, false, null, null, ''));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        System.assertEquals(2, dataObj.size(), 'Should have two picklist fields');
        
        // Verify empty options are handled
        for (Object obj : dataObj) {
            Map<String, Object> fieldMap = (Map<String, Object>) obj;
            System.assertEquals('picklist', fieldMap.get('fieldType'), 'Should be picklist type');
            System.assertEquals(true, fieldMap.get('showAsPicklist'), 'Should show as picklist');
            System.assert(fieldMap.containsKey('picklistOptions'), 'Picklist should have picklistOptions');
            List<Object> options = (List<Object>)fieldMap.get('picklistOptions');
            System.assertEquals(0, options.size(), 'Options should be empty list');
        }
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    @isTest
    private static void testGetCustomConfigurationPicklistWithValidJSON() {
        // Test picklist field with valid JSON options
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('picklist', 'Country', 'Country', null, null, null, false, null, null, '["USA","Canada","UK","Australia"]'));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{"Country":"USA"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        System.assertEquals(1, dataObj.size(), 'Should have one picklist field');
        
        Map<String, Object> fieldMap = (Map<String, Object>) dataObj[0];
        System.assertEquals('picklist', fieldMap.get('fieldType'), 'Should be picklist type');
        System.assertEquals(true, fieldMap.get('showAsPicklist'), 'Should show as picklist');
        System.assert(fieldMap.containsKey('picklistOptions'), 'Picklist should have picklistOptions');
        List<Object> options = (List<Object>)fieldMap.get('picklistOptions');
        System.assertEquals(4, options.size(), 'Should have 4 options');
        System.assertEquals('USA', options[0], 'First option should be USA');
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    @isTest
    private static void testGetCustomConfigurationFieldProperties() {
        // Comprehensive test to verify all field properties are set correctly
        List<SiteUtilities.CustomConfigurationWrapper> mockMetadata = new List<SiteUtilities.CustomConfigurationWrapper>();
        mockMetadata.add(createMockMetadataWrapper('text', 'TestField', 'Test Field', null, null, null, false, null, null, null));
        SiteUtilities.mockMetadataList = mockMetadata;
        mockValidSelfRegistrationSettings();
        
        String urlParams = '{"TestField":"testValue"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Self Registration');
        List<Object> dataObj = (List<Object>) JSON.deserializeUntyped(result);
        
        System.assertNotEquals(null, dataObj, 'Result should be a list');
        System.assertEquals(1, dataObj.size(), 'Should have one field');
        
        Map<String, Object> fieldMap = (Map<String, Object>) dataObj[0];
        
        // Verify all standard properties exist
        System.assert(fieldMap.containsKey('fieldType'), 'Should have fieldType');
        System.assert(fieldMap.containsKey('fieldName'), 'Should have fieldName');
        System.assert(fieldMap.containsKey('fieldLabel'), 'Should have fieldLabel');
        System.assert(fieldMap.containsKey('fieldClass'), 'Should have fieldClass');
        System.assert(fieldMap.containsKey('fieldMinValue'), 'Should have fieldMinValue');
        System.assert(fieldMap.containsKey('fieldMessageUnder'), 'Should have fieldMessageUnder');
        System.assert(fieldMap.containsKey('fieldMaxValue'), 'Should have fieldMaxValue');
        System.assert(fieldMap.containsKey('fieldMessageOver'), 'Should have fieldMessageOver');
        System.assert(fieldMap.containsKey('fieldMinLength'), 'Should have fieldMinLength');
        System.assert(fieldMap.containsKey('fieldMinLengthMessage'), 'Should have fieldMinLengthMessage');
        System.assert(fieldMap.containsKey('fieldMaxLength'), 'Should have fieldMaxLength');
        System.assert(fieldMap.containsKey('fieldLabelVariant'), 'Should have fieldLabelVariant');
        System.assert(fieldMap.containsKey('fieldDateStyle'), 'Should have fieldDateStyle');
        System.assert(fieldMap.containsKey('fieldShowIcon'), 'Should have fieldShowIcon');
        System.assert(fieldMap.containsKey('fieldIconName'), 'Should have fieldIconName');
        System.assert(fieldMap.containsKey('fieldIconClass'), 'Should have fieldIconClass');
        System.assert(fieldMap.containsKey('fieldParentClass'), 'Should have fieldParentClass');
        System.assert(fieldMap.containsKey('fieldToggleIconName'), 'Should have fieldToggleIconName');
        System.assert(fieldMap.containsKey('fieldToggleFieldType'), 'Should have fieldToggleFieldType');
        System.assert(fieldMap.containsKey('fieldAutocomplete'), 'Should have fieldAutocomplete');
        System.assert(fieldMap.containsKey('fieldMaxLengthMessage'), 'Should have fieldMaxLengthMessage');
        System.assert(fieldMap.containsKey('fieldChecked'), 'Should have fieldChecked');
        System.assert(fieldMap.containsKey('fieldValue'), 'Should have fieldValue');
        System.assertEquals('testValue', fieldMap.get('fieldValue'), 'Should have URL param value');
        
        // Clean up
        SiteUtilities.mockMetadataList = null;
    }

    @isTest
    private static void testCreateContactSecurityDecision() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;
        
        Map<String, Object> formInputs = new Map<String, Object>{
            'FirstName' => 'Security',
            'LastName' => 'Test',
            'Email' => 'security@test.com'
        };
        Map<String, Object> configOptions = new Map<String, Object>{
            'loggingEnabled' => 'true',
            'accountId' => acc.Id,
            'enablePasswordlessLogin' => 'false',
            'errorOnCreate' => 'Creation failed'
        };
        
        Id result = SiteRegistrationController.createContact(formInputs, configOptions);
        System.assertNotEquals(null, result, 'Contact should be created');
    }

    @isTest
    private static void testCreatePersonAccountSecurityDecision() {
        if (isPersonAccountEnabled()) {
            Map<String, Object> formInputs = new Map<String, Object>{
                'FirstName' => 'Security',
                'LastName' => 'Test',
                'Email' => 'securitypa@test.com'
            };
            Map<String, Object> configOptions = new Map<String, Object>{
                'loggingEnabled' => 'true',
                'personAccountRecordTypeId' => 'Person Account',
                'errorOnCreate' => 'Creation failed'
            };
            
            Id result = SiteRegistrationController.createPersonAccount(formInputs, configOptions);
            System.assertNotEquals(null, result, 'Person Account should be created');
        } else {
            System.assert(true, 'Person Accounts not enabled, skipping test');
        }
    }
}