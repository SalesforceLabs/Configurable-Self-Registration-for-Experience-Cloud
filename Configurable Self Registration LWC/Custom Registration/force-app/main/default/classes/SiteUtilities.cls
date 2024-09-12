/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 13/04/2024
 * @description Apex controller to provide common functions between SiteRegistration, SiteLogin and others in the future
 ***************************************************************************************************************/
public without sharing class SiteUtilities {

    public static final String SELF_REG_COMPONENT_NAME = 'Self Registration';
    public static final String LOGIN_COMPONENT_NAME = 'Login';
    public static final String SMS_LICENCE_NAME = 'setting/force.com/orgValue.IdentityVerificationCredits';

    public static Map<String, Auth.VerificationMethod> methods = new Map<String, Auth.VerificationMethod>{'Email' => Auth.VerificationMethod.EMAIL, 'SMS' => Auth.VerificationMethod.SMS};
    public static List<String> messages = new List<String>();
    public static String siteName = Site.getName();

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
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Self Registration form. 
     * @param urlParams a JSON string of URL params that were appended to the page.
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled(cacheable=true)
    public static String getCustomConfiguration(String urlParams, String componentName) {
        String result = '';
        Map<String, Object> urlParameters = (Map<String, Object>) JSON.deserializeUntyped(urlParams);

        try {
            List<SObject> metadata = new List<SObject>(); 
            if(componentName == SiteUtilities.LOGIN_COMPONENT_NAME) {
                metadata = Custom_Login_Configuration__mdt.getAll().values();
            }
            else {
                metadata = Custom_Registration_Configuration__mdt.getAll().values();
            }

            for (SObject mapping : metadata) {
                if(mapping.get('Active__c') == true && (mapping.get('Portal_API_Name__c') == siteName || mapping.get('Portal_API_Name__c') == 'ALL')) {

                    if(String.isNotBlank(result)){
                        result += ',';
                    }

                    String jsonPart = '{';
                    jsonPart += '"fieldType":"' + mapping.get('Field_Type__c') + '",'; 
                    jsonPart += '"fieldName":"' + mapping.get('Field_Name__c') + '",';
                    jsonPart += '"fieldLabel":"' + mapping.get('Field_Label__c') + '",';
                    jsonPart += '"fieldClass":"' + mapping.get('Field_Class__c') + '",';
                    jsonPart += '"fieldMinValue":"' + mapping.get('Minimum_Value__c') + '",';
                    jsonPart += '"fieldMessageUnder":"' + mapping.get('Field_Under_Minimum_Range_Message__c') + '",';
                    jsonPart += '"fieldMaxValue":"' + mapping.get('Maximum_Value__c') + '",';
                    jsonPart += '"fieldMessageOver":"' + mapping.get('Field_Over_Max_Range_Message__c') + '",';
                    jsonPart += '"fieldMinLength":"' + mapping.get('Field_Min_Length__c') + '",';
                    jsonPart += '"fieldMinLengthMessage":"' + mapping.get('Field_Message_Too_Short__c') + '",';
                    jsonPart += '"fieldMaxLength":"' + mapping.get('Field_Max_Length__c') + '",';
                    jsonPart += '"fieldLabelVariant":"' + mapping.get('Field_Label_Variant__c') + '",';
                    jsonPart += '"fieldDateStyle":"' + mapping.get('Field_Date_Style__c') + '",';
                    
                    //Settings to control icon visibility
                    jsonPart += '"fieldShowIcon":' + SiteUtilities.convertToBoolean(mapping.get('Field_Show_Icon__c')) + ','; //Needs to be a boolean as it directly controls dynamic template
                    jsonPart += '"fieldIconName":"' + mapping.get('Field_Icon_Name__c') + '",';
                    jsonPart += '"fieldIconClass":"' + mapping.get('Field_Icon_Class__c') + '",';
                    jsonPart += '"fieldParentClass":"' + mapping.get('Field_Parent_Class__c') + '",';
                    
                    jsonPart += '"fieldShowPasswordVisibility":' + SiteUtilities.convertToBoolean(mapping.get('Field_Show_Password_Visibility__c')) + ',';

                    //NOTE: Odd behaviour of this property... See Usage Considerations: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
                    //https://salesforce.stackexchange.com/questions/348093/lwc-lightning-input-custom-validation-for-max-length-no-error-message-comes-on
                    jsonPart += '"fieldMaxLengthMessage":"' + mapping.get('Field_Message_Too_Long__c') + '"'; 
                    
                    for(String key : urlParameters.keySet()) {
                        if(mapping.get('Field_Name__c') == key) {
                            jsonPart += ',';
                            if(SiteUtilities.convertToBoolean(urlParameters.get(key))) {
                                jsonPart += '"fieldChecked":"' + urlParameters.get(key) + '"';
                            }
                            else {
                                jsonPart += '"fieldValue":"' + urlParameters.get(key) + '"';
                            }
                        }
                    }

                    if(mapping.get('Field_Type__c') == 'picklist') {
                        jsonPart += ',';
                        jsonPart += '"showAsPicklist":' + true + ',';
                        jsonPart += '"picklistOptions":' + mapping.get('Field_Picklist_Options__c')  + ''; 
                    }

                    if(String.isNotBlank(convertToString(mapping.get('Field_Placeholder__c')))) {
                        jsonPart += ',';
                        jsonPart += '"fieldPlaceholder":"' + mapping.get('Field_Placeholder__c') + '"';
                    }

                    if(String.isNotBlank(convertToString(mapping.get('Field_Message__c'))) && String.isNotBlank(convertToString(mapping.get('Field_Validation_REGEX__c')))) {
                        jsonPart += ',';
                        jsonPart += '"fieldMessage":"' + mapping.get('Field_Message__c') + '",';
                        jsonPart += '"fieldRegex":"' + mapping.get('Field_Validation_REGEX__c') + '"';
                    }

                    if(convertToBoolean(mapping.get('Field_Required__c')) && String.isNotBlank(convertToString(mapping.get('Field_Required_Message__c')))) {
                        jsonPart += ',';
                        jsonPart += '"fieldRequired":"' + mapping.get('Field_Required__c') + '",';
                        jsonPart += '"fieldRequiredMessage":"' + mapping.get('Field_Required_Message__c') + '"';
                    }

                    if(String.isNotBlank(convertToString(mapping.get('Field_Help_Text__c')))) {
                        jsonPart += ',';
                        jsonPart += '"fieldHelpText":"' + mapping.get('Field_Help_Text__c') + '"';
                    }
                
                    jsonPart += '}';
                    result += jsonPart;
                }
            }
        }
        catch(Exception ex) {
            result += ex.getLineNumber() + ' : ' + ex.getMessage();
            throw new AuraHandledException('There was an issue displaying custom metadata. Please check the configuration and try again.');
        }
        return '['+result+']';
    }

    /**
    * @description Simple method to check for the existance of the Identity Verification Credits licence needed to send SMS code for passwordless login.
    * @return count of the Identity Verification Credits licence. 1 will enable the ability to use SMS codes for PasswordLess login.
    */
    @AuraEnabled(cacheable=true)
    public static Integer checkSMSLicence(){
        return [SELECT count() FROM TenantUsageEntitlement WHERE Setting = :SMS_LICENCE_NAME];
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
            recordList = Database.queryWithBinds(convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.SYSTEM_MODE);
        }
        else { 
            recordList = Database.queryWithBinds(convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.USER_MODE);
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
    public static String sendVerificationCode(Auth.VerificationMethod method, User user, String componentName) { 
        if(componentName == SELF_REG_COMPONENT_NAME) {
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
    public static String verifyCode(Auth.VerificationMethod method, String identifier, String code, String startUrl, Map<String, Object> lwcSettings, Map<String, Object> formJson, String componentName, User user) {
        
        String url;
        Auth.VerificationResult res;

        if(componentName == SELF_REG_COMPONENT_NAME) {
            res = UserManagement.verifySelfRegistration(method, identifier, code, startUrl);
        }
        else {
            res = UserManagement.verifyPasswordlessLogin(user.Id, method, identifier, code, startUrl);
        }
        
        System.PageReference page = res.redirect;
        url = page.getUrl();
        
        messages.add('Validating verification code for user. Submitted data: ' + formJson);
        
        if(res.success == false) { 
            messages.add('Unable to validate the verification code. Error was: ' + res.message);
            createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Error', componentName);    
            throw new AuraHandledException(convertToString(lwcSettings.get('failedCodeVerificationMessage')));
        }

        String jsonPart = '{"registerResult":[';
        
        jsonPart += '{';
        jsonPart += '"pageUrl":"' + url + '",';
        jsonPart += '"verificationSuccess":"' + res.success + '"}]}';
        
        messages.add('Verification was successful. Redirecting user to: ' + url);
        createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Information', componentName); 
        return jsonPart;   
    }
}