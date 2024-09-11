/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 13/04/2024
 * @description Apex controller to provide common functions between SiteRegistration, SiteLogin and others in the future
 ***************************************************************************************************************/
public without sharing class SiteUtilities {

    //TODO: Setting the experience Id is required for Dynamic Branding. However, this doesn't appear to be working properly. 
    //The browser cookie does not get updated when the expid parameter changes, causing inconsistent behaviour.
    /*@AuraEnabled
    public static void setExperienceId(String expId){ 
        if (String.isNotBlank(expId)) { 
            Site.setExperienceId(expId);
        }
        else {
           Site.setExperienceId(''); 
        }
    }*/ 

    /**
    * @description Simple method to check for the existance of the Identity Verification Credits licence needed to send SMS code for passwordless login.
    * @return count of the Identity Verification Credits licence. 1 will enable the ability to use SMS codes for PasswordLess login.
    */
    @AuraEnabled(cacheable=true)
    public static Integer checkSMSLicence(){
        return [SELECT count() FROM TenantUsageEntitlement WHERE Setting = 'setting/force.com/orgValue.IdentityVerificationCredits'];
    }

    /**
     * @description get a list of record types for a given object type.
     * @param  objectType pass in the object to filter Record Types on.
     * @return returns a JSON string of record type Ids & names for display in a picklist.
     */
    @AuraEnabled(cacheable=true)
    public static String getPersonAccountRecordTypes(String objectType){
        String result = '{"recordTypes":[';
        String jsonPart = '';
                
        List<RecordType> rt = new List<RecordType>([SELECT Id,Name,SobjectType,IsActive FROM RecordType WHERE SobjectType = :objectType AND IsActive = true]);

        for (RecordType r : rt) {
            if(String.isNotBlank(jsonPart)){
                jsonPart += ',';
            } 

            jsonPart += '{';
            jsonPart += '"label":"' + r.Name + '",';
            jsonPart += '"value":"' + r.Id + '"}';
        }
    
        return result + jsonPart + ']}';
    }

    /**
     * @description get a list of profiles that are members of a given site
     * @param networkId pass in the sites networkId to filter the list
     * @return return JSON string of profiles Names/Ids to populate a picklist
     */
    @AuraEnabled(cacheable=true)
    public static String getProfileMembers(String networkId){
        String result = '{"memberProfiles":[';
        String jsonPart = '';
        List<Id> profIds = new List<Id>();
        List<NetworkMemberGroup> nmg = [SELECT Id,ParentId FROM NetworkMemberGroup WHERE AssignmentStatus = 'Added'];

        for(NetworkMemberGroup nm : nmg) {
            profIds.add(nm.ParentId);
        }

        List<Profile> profs = [SELECT Id,Name FROM Profile WHERE Id IN :profIds];
        
        for (Profile p : profs) {
            if(String.isNotBlank(jsonPart)){
                jsonPart += ',';
            } 

            jsonPart += '{';
            jsonPart += '"label":"' + p.Name + '",';
            jsonPart += '"value":"' + p.Id + '"}'; 
        }
        return result + jsonPart + ']}';
    }
    
    /**
    * @description Simple method to wrap Object's Key > String conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a String value
    * @return String of passed object value
    */
    @AuraEnabled
    public static String convertToString(Object valueToConvert) {
        if(valueToConvert != null) {
            return String.valueOf(valueToConvert);
        }
        return '';
    }

    /**
    * @description Simple method to wrap Object > Boolean conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a Boolean value
    * @return Boolean of passed object value
    */
    @AuraEnabled
    public static Boolean convertToBoolean(Object valueToConvert) {
        if(valueToConvert != null) {
            return Boolean.valueOf(valueToConvert);
        }
        return false;
    }    

    /** 
     * @description Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on in the Custom Metadata Types.
     * @param loggingEnabled - Passes in the LWC property panel setting to turn logging on or off in a custom object called 'Self Registration Log'
     * @param message - a list of messages to store on the Platform Event
     * @param logType - the type of error to log, either 'Information' or 'Log'
     * @param componentName - the name of the component that is calling this function
     */
    @AuraEnabled
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName){
       try {
            if(loggingEnabled) {
                Experience_Cloud_Event__e newLog = new Experience_Cloud_Event__e();
                newLog.Message__c = message;
                newLog.Log_Type__c = logType;
                newLog.Component_Name__c = componentName;
                Eventbus.publish(newLog);
            } 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Checks to see if the Logging setting is activated.
    * @param settingName - pass in the settingName which is related to the component
    * @return true/false depending on setting value.
    */
    @AuraEnabled(cacheable=true)
    public static Boolean isLoggingEnabled(String settingName) {
        
        if(Test.isRunningTest()) { //Always return false if running Tests to prevent failure as the logging can be switched on/off by the user after installation.
            return false;  
        } 
        
        List<Custom_Experience_Cloud_Setting__mdt> logSetting = new List<Custom_Experience_Cloud_Setting__mdt>();
        try {
            logSetting = [SELECT Id, Enable__c, DeveloperName
                        FROM Custom_Experience_Cloud_Setting__mdt 
                        WHERE (DeveloperName = :settingName AND Enable__c = true)
                        WITH SECURITY_ENFORCED
                        LIMIT 1];
        }
        catch(Exception ex) {
            return false;
        }
        
        if(!logSetting.isEmpty() && logSetting.size() == 1) {
            return true;
        }
        return false;
    }

    /**
     * @description sets the ProfileId on the non-persisted User Object
     * *  NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  profileId the profileId to set on the user object as configured in the property panel with Exp. Builder.
     */
    public void setProfileId(User user, Id profileId){
        user.ProfileId = profileId;
    }

    /**
     * @description sets the ContactId with either the ContactId or the PersonContactId based on how the component is configured.
     *  NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  type pass in the type of 'Account' or 'Contact' to correctly set the ContactId
     * @param  recordId pass in the recordId which is either used to set the ContactId directly, or find the PersonContactId
     */
	public void setContactId(User user, String type, Id recordId){
        if(type == 'Account') {
            Id contactId = [SELECT Id,PersonContactId FROM Account WHERE Id = :recordId].PersonContactId;
            user.ContactId = contactId;
        }
        else {
            user.ContactId = recordId;
        }
    }

    /**
     * @description find a user based on the specified string.
     * @param username specify the username string to locate an existing user to login.
     * @return returns a User object if found.
     */
    @AuraEnabled(cacheable=true)
    public static User getUser(String username, String mobilePhone){
        try {
            if(String.isNotBlank(username)) {
                return [SELECT Id, Username, IsActive FROM User WHERE Username = :username AND IsActive = true];
            }
            else {
                return [SELECT Id, MobilePhone, IsActive FROM User WHERE MobilePhone = :MobilePhone AND IsActive = true];
            }
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage()); //TODO Parameter?
        }
    }

    /**
    * @description Query records using the specified custom query
    * @param formInputs Map of the submitted form values 
    * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
    * @return Specified records as a generic sObject list
    */
    public static List<sObject> getRecords(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
        List<sObject> recordList = new List<sObject>();
        
        if(configurationOptions.get('accessLevelMode') == 'System') { 
            recordList = Database.queryWithBinds(SiteUtilities.convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.SYSTEM_MODE);
        }
        else {  
            recordList = Database.queryWithBinds(SiteUtilities.convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.USER_MODE);
        }

        return recordList;
    }
    /**
     * @description Query the Network Member table which holds entries for the registrations. This allows for username re-use if there are multiple portals in an org, but not for the same portal!
     * @param username username to use in the query
     * @param networkId the Id of the portal to check against for membership
     * @return List of NetworkMember records
     */
    public static List<NetworkMember> validateUsername(String username, String networkId) {
        
        //SF assigns a username by taking the submitted value then appending everything after the "@" automatically and randomly to keep unique.
        //Formula field is used to calculate value we are interested i.e. the submitted value with no domain that we can query with '='. 
        //This way, if the username changes in anyway, filter continues to work as a 2nd field doesn't need to be updated!
        List<NetworkMember> userList = [
            SELECT Id, Member.Portal_Username__c, Member.Id, NetworkId
            FROM NetworkMember 
            WHERE Member.Portal_Username__c = :username
            AND NetworkId = :networkId
            WITH SECURITY_ENFORCED
        ];

        return userList;
    }
    
    /**
     * @description getUserIdWithUsername retrieve the user id for a given username (this would be email address if not using Usernames!) or Portal_Username__c (which is the unique username without randomly assigned SF email domain), allowing a filter on login History to understand if there were issues logging in.
     * NOTE: Does not use WITH SECURITY_ENFORCED as issues are encountered accessing some fields with the Guest User.
     * @param  username pass the username from the from as a string
     * @return either the Login History Status or "Username not found" as a String if user doesn't exist
     */
    public static String getUserIdWithUsername(String username) {
        List<User> userId = [SELECT Id,Name,Email,Portal_Username__c FROM User WHERE (Username = :username OR Portal_Username__c = :username)];
        
        if(!userId.isEmpty()) {
            return getLoginHistory(userId[0].Id);
        }        
        return 'Username Not Found'; //Custom to handle the username not found.
    }

     /**
     * @description getLoginHistory retrieves exactly 1 entry from the LoginHistory for the specified UserId sorted by DESC i.e. the most recent. NOTE: Cannot filter by Username directly.
     * NOTE: Does not use WITH SECURITY_ENFORCED as issues are encountered accessing some fields with the Guest User.
     * @param userId pass in the User Id from getUserIdWithUsername() result. 
     * @return returns the Login History status field.
     */
    public static String getLoginHistory(String userId) {
        
        List<LoginHistory> history = [SELECT Id, UserId, LoginTime, Status FROM LoginHistory WHERE UserId = :userId ORDER BY LoginTime DESC  LIMIT 1];
        
        if(history.size() == 1) {
            return history[0].Status;
        }
        return null;
    }
    
    /**
     * @description send a verification code via the specified method e.g. EMAIL, SMS, SALESFORCE_AUTHENTICATOR, TOTP for Self Registration & Login
     * NOTE: The component only supports Email and SMS (if the org is licenced) right now.
     * NOTE: In Apex tests, there is no Network context, so a hardcoded value is returned.
     * @return returns the verification code identifier value to be passed to the verify function later.
     */
    public static String sendVerificationCode(Auth.VerificationMethod method, User user, String mode) { 
        if(mode == SiteRegistrationController.COMPONENT_NAME) {
            return Test.isRunningTest() ? '123456' : UserManagement.initSelfRegistration(method, user);
        }   
        return Test.isRunningTest() ? '123456' : UserManagement.initPasswordlessLogin(user.Id, method);
    }

    /**
     * @description verify the code submitted by the user, and return a JSON string with the redirect URL if verification is successful.
     * @param method the method by which a code will be sent. Configured in the property panel in Exp. Builder.
     * @param identifier the identifier is generated when requesting a new verification code and submitted back in via the form.
     * @param code this is the generated code submitted by the user and received by the specified method
     * @param startUrl this is the URL that a user is redirected to upon successful verification. Configured via the property panel in Exp. builder.
     * @param lwcSettings the property panel settings configured in Exp builder.
     * @param formJson the submitted form values
     */
    public static String verifyCode(Auth.VerificationMethod method, String identifier, String code, String startUrl, Map<String, Object> lwcSettings, Map<String, Object> formJson, String mode, User user) {
        
        String url;
        Auth.VerificationResult res;

        if(mode == SiteRegistrationController.COMPONENT_NAME) {
            res = UserManagement.verifySelfRegistration(method, identifier, code, startUrl);
        }
        else {
            res = UserManagement.verifyPasswordlessLogin(user.Id, method, identifier, code, startUrl);
        }
        
        System.PageReference page = res.redirect;
        url = page.getUrl();
        
        SiteRegistrationController.messages.add('Validating verification code for user. Submitted data: ' + formJson);
        
        if(res.success == false) { 
            SiteRegistrationController.messages.add('Unable to validate the verification code. Error was: ' + res.message);
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(SiteRegistrationController.messages,'\n'), 'Error', SiteRegistrationController.COMPONENT_NAME);    
            throw new AuraHandledException(SiteUtilities.convertToString(lwcSettings.get('failedCodeVerificationMessage')));
        }

        String jsonPart = '{"registerResult":[';
        
        jsonPart += '{';
        jsonPart += '"pageUrl":"' + url + '",';
        jsonPart += '"verificationSuccess":"' + res.success + '"}]}';
        
        SiteRegistrationController.messages.add('Verification was successful. Redirecting user to: ' + url);
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(SiteRegistrationController.messages,'\n'), 'Information', SiteRegistrationController.COMPONENT_NAME); 
        return jsonPart;   
    }
}