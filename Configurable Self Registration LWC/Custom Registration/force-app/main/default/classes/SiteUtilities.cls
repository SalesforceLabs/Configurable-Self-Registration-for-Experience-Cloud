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

    //TODO: Setting the experience Id is required for Dynamic Branding. However, the Site.setExperienceId method doesn't appear to be working properly. 
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
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Login & Self Registration forms. 
     * @param urlParams a JSON string of URL params that were appended to the page.
     * @param componentName a string of the component that is calling this function to filter the Metadata i.e. Login or Self Registration
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled(cacheable=true)
    public static String getCustomConfiguration(String urlParams, String componentName) {
        String result = '';
        Map<String, Object> urlParameters = (Map<String, Object>) JSON.deserializeUntyped(urlParams);

        try {
            List<SObject> metadata = new List<SObject>(); 
            if(componentName == LOGIN_COMPONENT_NAME) {
                metadata = Custom_Login_Configuration__mdt.getAll().values();
            }
            else {
                metadata = Custom_Registration_Configuration__mdt.getAll().values();
            }

            List<SObject> sortedMetadata = new List<SObject>();
            for (SObject rec : metadata) {
                if(rec.get('Active__c') == true && (rec.get('Portal_API_Name__c') == siteName || rec.get('Portal_API_Name__c') == 'ALL')) {
                    sortedMetadata.add(rec); 
                }
            }

            //Custom Sort order by the Display Order field.
            sortedMetadata.sort(new CustomSort());

            for (SObject mapping : sortedMetadata) {
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
                jsonPart += '"fieldShowIcon":' + convertToBoolean(mapping.get('Field_Show_Icon__c')) + ','; //Needs to be a boolean as it directly controls dynamic template
                jsonPart += '"fieldIconName":"' + mapping.get('Field_Icon_Name__c') + '",';
                jsonPart += '"fieldIconClass":"' + mapping.get('Field_Icon_Class__c') + '",';
                jsonPart += '"fieldParentClass":"' + mapping.get('Field_Parent_Class__c') + '",';
                jsonPart += '"fieldToggleIconName":"' + mapping.get('Field_Toggle_Icon_Name__c') + '",';
                jsonPart += '"fieldToggleFieldType":"' + mapping.get('Field_Toggle_Type__c') + '",';

                String autocomplete = convertToBoolean(mapping.get('Field_Allow_Auto_Complete__c')) ? 'on' : 'off';
                jsonPart += '"fieldAutocomplete":"' + autocomplete + '",';

                //NOTE: Odd behaviour of this property... See Usage Considerations: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
                //https://salesforce.stackexchange.com/questions/348093/lwc-lightning-input-custom-validation-for-max-length-no-error-message-comes-on
                jsonPart += '"fieldMaxLengthMessage":"' + mapping.get('Field_Message_Too_Long__c') + '"'; 
                
                for(String key : urlParameters.keySet()) {
                    if(mapping.get('Field_Name__c') == key) {
                        jsonPart += ',';
                        if(convertToBoolean(urlParameters.get(key))) {
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
        List<RecordType> rt = new List<RecordType>([SELECT Id,Name,SobjectType,IsActive FROM RecordType WHERE SobjectType = :objectType AND IsActive = true]);
        Map<String, String> itemsToAdd = new Map<String,String>();
        for (RecordType r : rt) {
            itemsToAdd.put(r.Id, '{"label":"' +  r.Name + '","value":"'+  r.Name + '"}');
        }
        return jsonBuilder('recordTypes', itemsToAdd);
    }

    /**
     * @description get a list of profiles that are members of a given site
     * @param networkId pass in the sites networkId to filter the list
     * @return return JSON string of profiles Names/Ids to populate a picklist
     */
    @AuraEnabled(cacheable=true)
    public static String getProfileMembers(String networkId){
        Map<String, String> itemsToAdd = new Map<String, String>();
        List<Id> profIds = new List<Id>();
        List<NetworkMemberGroup> nmg = [SELECT Id,ParentId FROM NetworkMemberGroup WHERE AssignmentStatus = 'Added'];

        for(NetworkMemberGroup nm : nmg) {
            profIds.add(nm.ParentId);
        }

        List<Profile> profs = [SELECT Id,Name FROM Profile WHERE Id IN :profIds];
        for (Profile p : profs) {
            itemsToAdd.put(p.Id, '{"label":"' +  p.Name + '","value":"'+  p.Name + '"}');
        }
        return jsonBuilder('memberProfiles', itemsToAdd);
    }

    /**
    * @description Simple method to pass string and convert to Integer.
    * @param valueToConvert - pass in String
    * @return Integer of passed String value
    */
    public static Integer convertToInteger(String valueToConvert) {
        if(valueToConvert != null) {
            return Integer.valueOf(valueToConvert);
        }
        return null;
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
     * @description pass in attributes to build up a simple JSON String to return to the LWC to parse
     * @param  key is a key for the top level JSON structure
     * @param  itemsToAdd map of string, string to pass the key and value of each JSON element
     * @return returns a parseable JSON string.
     */
    public static String jsonBuilder(String key, Map<String, String> itemsToAdd) {        
        String jsonStart = '{"' + key + '":[';
        String jsonString = '';
        for(String jsonKey : itemsToAdd.keySet()) {
            if(String.isNotBlank(jsonString)){
                jsonString += ',';
            } 
            jsonString += itemsToAdd.get(jsonKey); 
        }
        jsonString +=  ']}';
        return jsonStart + jsonString;
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
        List<Custom_Experience_Cloud_Setting__mdt> logSetting = new List<Custom_Experience_Cloud_Setting__mdt>();
        try {
            logSetting = [SELECT Id, Enable__c, DeveloperName FROM Custom_Experience_Cloud_Setting__mdt WHERE (DeveloperName = :settingName AND Enable__c = true) WITH SECURITY_ENFORCED LIMIT 1];
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
     * NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  profileId the profileId to set on the user object as configured in the property panel with Exp. Builder.
     */
    public void setProfileId(User user, String profileName){
        user.ProfileId = [SELECT Id,Name FROM Profile WHERE Name = :profileName].Id;
    }

    /**
     * @description sets the ContactId on the non-persisted User Object
     * NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  contactId the profileId to set on the user object as configured in the property panel with Exp. Builder.
     */
    public void setContactId(User user, Id contactId){
        user.ContactId = contactId;
    }

    /**
     * @description find the PersonContactId for a given AccountId.
     *  NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  accountId pass in the Account Id to find the PersonContactId
     * @return Id of the PersonContact
     */
	public static Id getPersonContactId(Id accountId){
        return [SELECT Id,PersonContactId FROM Account WHERE Id = :accountId].PersonContactId;        
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
            SELECT Id, Member.Username, Member.Id, NetworkId
            FROM NetworkMember 
            WHERE Member.Username = :username
            AND NetworkId = :networkId
            WITH SECURITY_ENFORCED
        ];

        return userList;
    }
    
    /**
     * @description getUserIdWithUsername retrieve the user id for a given username (this would be email address if not using Usernames!) or Portal_Username__c (which is the unique username without randomly assigned SF email domain), allowing a filter on login History to understand if there were issues logging in.
     * NOTE: Does not use WITH SECURITY_ENFORCED as issues are encountered accessing some fields with the Guest User.
     * @param  username pass the username from the form as a string
     * @param mobilePhone pass the mobile phone from the form as a string
     * @return returns the user if one if found, otherwise null.
     */
    public static List<User> getUserIdWithUsername(String username, String mobilePhone) {
        List<User> u;
        
        if(String.isNotBlank(username)) {
            u = [SELECT Id,Name,Email,Username,Portal_Username__c FROM User WHERE (Username = :username OR Portal_Username__c = :username)];
        }

        if(String.isNotBlank(mobilePhone)) {
            u = [SELECT Id, MobilePhone, IsActive FROM User WHERE MobilePhone = :MobilePhone AND IsActive = true];
        }
        return u;        
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
     * @description deleteRecord deletes the recordId specified. This method is called when a verification code validation failure occurs during passwordless login/registration.
     * @param contactId the Id of a Contact to delete when using Business Accounts & Contacts or an Account when using Person Accounts.
     */
    public static void deleteRecord(Id recordId, String type, String componentName, Map<String, Object> lwcSettings) {
        try {
            if(type == 'Account') {
                delete new Account (Id = recordId);
            }
            else {  
                delete new Contact (Id = recordId);
            }            
        } catch(Exception e) {
            SiteUtilities.createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Error', componentName);
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
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
     * NOTE: Not covered in Apex tests due to limitation on User Management class in test context. This method is mocked instead.
     */
    @AuraEnabled
    public static String verifyUser(String configurationOptions, String formInputs, String componentName) {
        
        String url;
        Auth.VerificationResult res;
        
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Auth.VerificationMethod method = methods.get(convertToString(lwcSettings.get('passwordlessMethod')));
        String startUrl = convertToString(formJson.get('portalRegistrationRedirect'));
        String identifier = convertToString(formJson.get('identifier'));
        String code = convertToString(formJson.get('verificationCode'));
        String mobilePhone;
        String username = String.isNotBlank(convertToString(formJson.get('Username'))) ? convertToString(formJson.get('Username')) : convertToString(formJson.get('Email'));
        
        if(String.isNotBlank(convertToString(formJson.get('countryCode')))) {
            mobilePhone = UserManagement.formatPhoneNumber(convertToString(formJson.get('countryCode')), convertToString(formJson.get('MobilePhone'))); //Format the phone number with the user management class otherwise user isn't found!!
        }
        
        if(componentName == SELF_REG_COMPONENT_NAME) {
            res = UserManagement.verifySelfRegistration(method, identifier, code, startUrl);
        }
        else {
            List<User> user = getUserIdWithUsername(username, mobilePhone);
            res = UserManagement.verifyPasswordlessLogin(user[0].Id, method, identifier, code, startUrl);
        }
        
        messages.add('Validating verification code for user. Submitted data: ' + formJson);
        
        if(res.success == false) { 
            messages.add('Unable to validate the verification code. Error was: ' + res.message);    
            createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Error', componentName);    
            throw new AuraHandledException(convertToString(lwcSettings.get('failedCodeVerificationMessage')));
        }

        System.PageReference page = res.redirect;
        url = page.getUrl();

        Map<String, String> itemsToAdd = new Map<String, String>();
        itemsToAdd.put(identifier, '{"pageUrl":"' +  url + '","verificationSuccess":'+  res.success + '}');

        messages.add('Verification was successful. Redirecting user to: ' + url);
        createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Information', componentName); 
        return jsonBuilder('registerResult', itemsToAdd);    
    }
}