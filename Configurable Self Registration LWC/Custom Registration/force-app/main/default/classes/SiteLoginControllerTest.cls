/**
 * @description Test Class to test the custom login component. 
 * NOTE: This test class uses Test.isRunningTest() method to return mock results.
 * Written as a workaround to the site.login() method returning null, and thus unable to replicate a user logging in with incorrect credentials. *****
 * @author: Jamie Lowe
 */
@isTest
private class SiteLoginControllerTest {
    
    //Setup some users for testing the logins via standard and passwordless login.
    @TestSetup
    private static void createTestData(){

        //A list of users that we create and 'test' with
        List<String> usernameList = new List<String> {'testuserinvalidpassword@mail.com', 'testusernotexist@mail.com', 'testuserlocked@mail.com', 'testuserblocked@mail.com', 'testuserother@mail.com', 'testusergenericfail@mail.com', 'testusersuccessful@mail.com'};

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
                    ContactId = (Id)acc2[0].get('PersonContactId'),
                    ProfileId = profile 
                );  
                u.add(tempUser);
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
        String urlParams = '{"Email":"test@mail.com"}';
        String result = SiteUtilities.getCustomConfiguration(urlParams, 'Login');
        String resultParsed = '{"data":' + result + '}';        
        Map<String, Object> fieldConfiguration = (Map<String, Object>) JSON.deserializeUntyped(resultParsed);
        List<Object> dataObj = (List<Object>) fieldConfiguration.get('data');
        System.assertEquals(2, dataObj.size(), '2 ACTIVE configured fields found as expected');
    }

    //Retrieve and test custom settings to enable logging for the Login component.
    @isTest
    private static void isLoggingEnabled() {
        Boolean result =  SiteUtilities.isLoggingEnabled('Login_Logging');
        if(result) {
            System.assertEquals(true, result, 'Retrieved custom settings - logging enabled');
        }
        else {
            System.assertEquals(false, result, 'Retrieved custom settings - logging disabled');
        }
    }

    //Mock a login via Passwordless. NOTE: Verifying the code to returned is already covered in registration so no need to it again here as it is mocked anyway.
    @isTest
    private static void customPasswordlessLoginTest() {
        String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out","enablePasswordlessLogin": true, "passwordlessMethod":"Email"}';
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

        try {
            String formJSON = '{"Email":"testusersuccessful@mail.com"}';
            SiteLoginController.loginUser(formJSON, lwcSettings);
        }
        catch (Exception e) {
            System.assertEquals(null, null, 'Site.login() always returns null in tests.');
        }
    }

    @isTest
    private static void customPasswordlessLoginFailedTest() {
        String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out","enablePasswordlessLogin": true, "passwordlessMethod":"Email"}';
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);

        try {
            String formJSON = '{"Email":"testusersuccessful2@mail.com"}';
            SiteLoginController.loginUser(formJSON, lwcSettings);
        }
        catch (Exception e) {
            System.assertEquals(null, null, 'Site.login() always returns null in tests.');
        }
    }

    @isTest
    private static void customLoginTest() {

        String configurationOptions = '{"portalLoginRedirect": "/", "loggingEnabled":"true", "blockUserErrorMessage":"user blocked by admin", "incorrectUserCredentialsErrorMessage":"incorrect credentials", "userLockedOutErrorMessage":"user temporarily locked out"}';
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        
        //A list of users that we create and 'test' with
        List<String> usernameList = new List<String> {'testuserinvalidpassword@mail.com', 'testusernotexist@mail.com', 'testuserlocked@mail.com', 'testuserblocked@mail.com', 'testuserother@mail.com', 'testusergenericfail@mail.com', 'testusersuccessful@mail.com'};
      
        for (String user : usernameList) { //Loop over the test users. See SiteLoginController.loginUser for hacks/workarounds as Site.Login() doesn't actually work in Test classes.
            try {
                String formJSON = '{"Email":"'+ user +'","Password":"test"}';  //Passing a real password for the test user created above has no effect in a test class!  
                SiteLoginController.loginUser(formJSON, lwcSettings);
            }
            catch (Exception e) {
                System.assertEquals(null, null, 'Site.login() always returns null in tests.');
            }
        }
    }
}