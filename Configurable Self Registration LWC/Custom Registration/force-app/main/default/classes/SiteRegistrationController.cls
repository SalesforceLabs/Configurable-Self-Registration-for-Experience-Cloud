/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce) & Ekaterina Coburn (Salesforce)
 * CREATE DATE    : 15/05/2023
 * @description Apex controller to support custom built UI Custom Self Registration for Experience Cloud
 ***************************************************************************************************************/

public with sharing class SiteRegistrationController {

    public static List<String> messages = new List<String>();

    @TestVisible
    public static Boolean testPersonAccountStatus;
    private static Boolean orgPersonAccountStatus = Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');

    /**
     * @description isPersonAccountEnabled tests whether the org currently has Person Accounts enabled. Checks for existence of the isPersonAccount field.
     * @return returns true/false depending on setup of the org.
     */
    @AuraEnabled
    public static Boolean isPersonAccountEnabled() {
        return testPersonAccountStatus != null ? testPersonAccountStatus : orgPersonAccountStatus;
    }

    /**
     * @description pass in an object name and field name.
     * @param objName the object name to check
     * @param fieldName the field name to check
     * @return return true if the object and field both exist. If the object has been removed it will also return false. If the object exists but the field doesn’t it will return false.
     */
    public static boolean checkFieldExists(String objName, string fieldName) {
        SObject so = Schema.getGlobalDescribe().get(objName).newSObject();
        return so.getSobjectType().getDescribe().fields.getMap().containsKey(fieldName);
    }

    /**
     * @description pass in a map and remove the password elements from any logging for security
     * @param formJson - pass in a map of JSON to sanitise
     * @return return the sanitised version of the map by removing information
     */
    @AuraEnabled
    public static Map<String, Object> sanitiseJson(Map<String, Object> formJson) {
        Map<String,Object> newFormJSON = new Map<String,Object>();
        
        for(String key : formJson.keySet()){
            if(key == 'password' || key == 'confirmPassword') {
                newFormJSON.put(key, 'HIDDEN');
            }
            else {
                newFormJSON.put(key, formJson.get(key));
            }
        }

        return newFormJson;
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
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Self Registration form. 
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled(cacheable=true)
    public static String getCustomConfiguration(String urlParams) {
        String result = '';
        Map<String, Object> urlParameters = (Map<String, Object>) JSON.deserializeUntyped(urlParams);

        try {

            String siteName = Site.getName();
            
            for (Custom_Registration_Configuration__mdt mapping : [SELECT Id, Field_Name__c, Field_Type__c, Field_Label__c, Field_Message__c, Field_Help_Text__c, Field_Validation_REGEX__c, 
                    Field_Min_Length__c, Field_Max_Length__c, Field_Required__c, Field_Placeholder__c, 
                    Field_Required_Message__c, Portal_API_Name__c, Display_Order__c, Field_Class__c, Field_Message_Too_Short__c, Field_Message_Too_Long__c,
                    Minimum_Value__c, Maximum_Value__c, Field_Under_Minimum_Range_Message__c, Field_Over_Max_Range_Message__c 
                                    FROM Custom_Registration_Configuration__mdt 
                                    WHERE (Portal_API_Name__c = :siteName AND Active__c = true) 
                                    OR (Portal_API_Name__c = 'ALL' AND Active__c = true) 
                                    WITH SECURITY_ENFORCED 
                                    ORDER BY Display_Order__c]
                ) {
                if(String.isNotBlank(result)){
                    result += ',';
                } 

                String jsonPart = '{';
                jsonPart += '"fieldType":"' + mapping.Field_Type__c + '",'; 
                jsonPart += '"fieldName":"' + mapping.Field_Name__c + '",';
                jsonPart += '"fieldLabel":"' + mapping.Field_Label__c + '",';
                jsonPart += '"fieldClass":"' + mapping.Field_Class__c + '",';
                jsonPart += '"fieldMinValue":"' + mapping.Minimum_Value__c + '",';
                jsonPart += '"fieldMessageUnder":"' + mapping.Field_Under_Minimum_Range_Message__c + '",';
                jsonPart += '"fieldMaxValue":"' + mapping.Maximum_Value__c + '",';
                jsonPart += '"fieldMessageOver":"' + mapping.Field_Over_Max_Range_Message__c + '",';
                jsonPart += '"fieldMinLength":"' + mapping.Field_Min_Length__c + '",';
                jsonPart += '"fieldMinLengthMessage":"' + mapping.Field_Message_Too_Short__c + '",';
                jsonPart += '"fieldMaxLength":"' + mapping.Field_Max_Length__c + '",';

                //NOTE: Odd behaviour of this property... See Usage Considerations: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
                //https://salesforce.stackexchange.com/questions/348093/lwc-lightning-input-custom-validation-for-max-length-no-error-message-comes-on
                jsonPart += '"fieldMaxLengthMessage":"' + mapping.Field_Message_Too_Long__c + '"'; 
                
                for(String key : urlParameters.keySet()) {
                    if(mapping.Field_Name__c == key) {
                        jsonPart += ',';
                        if(convertToBoolean(urlParameters.get(key))) {
                            jsonPart += '"fieldChecked":"' + urlParameters.get(key) + '"';
                        }
                        else {
                            jsonPart += '"fieldValue":"' + urlParameters.get(key) + '"';
                        }
                    }
                }

                if(String.isNotBlank(mapping.Field_Placeholder__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldPlaceholder":"' + mapping.Field_Placeholder__c + '"';
                }

                if(String.isNotBlank(mapping.Field_Message__c) && String.isNotBlank(mapping.Field_Validation_REGEX__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldMessage":"' + mapping.Field_Message__c + '",';
                    jsonPart += '"fieldRegex":"' + mapping.Field_Validation_REGEX__c + '"';
                }

                if(mapping.Field_Required__c && String.isNotBlank(mapping.Field_Required_Message__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldRequired":"' + mapping.Field_Required__c + '",';
                    jsonPart += '"fieldRequiredMessage":"' + mapping.Field_Required_Message__c + '"';
                }

                if(String.isNotBlank(mapping.Field_Help_Text__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldHelpText":"' + mapping.Field_Help_Text__c + '"';
                }
             
                jsonPart += '}';
                result += jsonPart;
            }
        }
        catch(Exception ex) {
            result += ex.getLineNumber() + ' : ' + ex.getMessage();
        }
        System.debug('JSON Final String: ' + '['+result+']');
        return '['+result+']';
    }

    /**
     * @description Checks to see if the Logging setting is activated.
     * @return true/false depending on setting value.
     */
    @AuraEnabled(cacheable=true)
    public static Boolean isLoggingEnabled() {
        
        if(Test.isRunningTest()) { //Always return false if running Tests to prevent failure as the logging can be switched on/off by the user after installation.
            return false;  
        } 
        
        List<Custom_Registration_Settings__mdt> logSetting = new List<Custom_Registration_Settings__mdt>();
        try {
            logSetting = [SELECT Id, Activate_Setting__c, MasterLabel
                       FROM Custom_Registration_Settings__mdt 
                       WHERE (MasterLabel = 'Enable Logging' AND Activate_Setting__c = true)
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
     * @description Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on in the Experience Cloud builder.
     * @param loggingEnabled - Passes in the LWC property panel setting to turn logging on or off in a custom object called 'Self Registration Log'
     * @param message - a list of messages to store on the Platform Event
     * @param logType - the type of error to log, either 'Information' or 'Log'
     */
    @AuraEnabled
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType){
       try {
            if(loggingEnabled) {
                Self_Registration_Event__e newLog = new Self_Registration_Event__e();
                newLog.Message__c = message;
                newLog.Log_Type__c = logType;
                Eventbus.publish(newLog);
            } 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description isValidUsername Checks to see if the username supplied by the user on the registration form is available
     * @param formInputs - JSON String of the submitted form values
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel 
     * @return Boolean true if username is taken, otherwise false.
     */ 
    @AuraEnabled
    public static Boolean isValidUsername(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
        Boolean isUsernameValid = true;
        String username = convertToString(formInputs.get('Username'));

        //Get the Network Id for the current Experience Cloud Site
        String networkId = Network.getNetworkId();

        //This class runs without sharing as access cannot be granted to the Guest User and the SiteRegisterController runs as a Guest.
        List<NetworkMember> userList = RetrieveNetworkMembers.validateUsername(username, networkId);

        messages.add('Looking for registered user with username ' + username + ' on NetworkId ' + networkId);    
        
        if(userList.size() >= 1) {
            messages.add('User with username ' + username + ' already exists on NetworkId ' + networkId + '. Username NOT valid.');
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');    
            throw new AuraHandledException(convertToString(configurationOptions.get('usernameTakenMessage'))); 
        }

        messages.add('User with username ' + username + ' not found on NetworkId ' + networkId + '. Username valid.');
        return isUsernameValid;
    }

    /**
     * @description Validates that the submitted password matches the Org's password policy.
     * @param formJson - JSON String of the submitted form values
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel 
     */
    @AuraEnabled
    public static void validatePassword(Map<String, Object> formJson, Map<String, Object> configurationOptions) {

        try {
            User user = new User();
    
            for(String key : formJson.keySet()){
                if(checkFieldExists('User', key)) {
                    user.put(key, formJson.get(key));
                }
            }

            user.CommunityNickname = generateCommunityNickname(convertToString(formJson.get('Username'))); 
            if(!Test.isRunningTest()) { //NOTE: This method is buggy and always fails during Apex Tests so bypass it! See: https://help.salesforce.com/s/articleView?id=000391105&type=1
                Site.validatePassword(user, convertToString(formJson.get('password')), convertToString(formJson.get('confirmPassword'))); 
            } 
        }
        catch (SObjectException ex) {
           messages.add('An error occurred whilst trying to update the User Object:' + ex.getMessage() + '\n' + 'Form Inputs: ' + sanitiseJson(formJson));
           createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
           throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        catch (Exception ex) {
           messages.add('An error occurred whilst trying to validate the password:' + ex.getMessage() + '\n' + 'Form Inputs: ' + sanitiseJson(formJson));
           createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
           throw new AuraHandledException(ex.getMessage()); //This is deliberate as the Site.Validate function returns useful information about the password failure
        }
    }

    /**
     * @description Attempts to register a new user. Looks for existing record first based on configured query. If configured and record not found, new record is created. If record found, registered user is linked to existing Contact/Person Account.
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return String Page URL if login is successful.
     */
    @AuraEnabled
    public static String registerUser(String formInputs, String configurationOptions) { 

        String pageUrl = null;
        Id recordId = null;
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);

        System.debug('Form Inputs: ' + formJson);
        
        //Remove the Password/Confirm Password stored in the Self Registration Logs.
        Map<String, Object> sanitisedFormJson = new Map<String, Object>();
        sanitisedFormJson = sanitiseJson(formJson);

        isValidUsername(formJson, lwcSettings);
        validatePassword(formJson, lwcSettings);
  
        if(String.isNotBlank(convertToString(lwcSettings.get('customQuery')))) {
            messages.add('Searching for record with query:' + lwcSettings.get('customQuery') + ' Form Values: ' + sanitisedFormJson);
            recordId = getObject(sanitisedFormJson, lwcSettings);
            messages.add('Record Id found was: ' + recordId);
        }
    
        if(convertToBoolean(lwcSettings.get('createNotFound')) && String.isBlank(recordId)) { 
            messages.add('Creating object with type: ' + lwcSettings.get('objectCreateType') + ' Form Values: ' + sanitisedFormJson); 
            recordId = createObject(formJson, lwcSettings);
            messages.add('Created Record Id returned was: ' + recordId);   
        }

        String userId = createExternalUser(formJson, recordId, lwcSettings);
    
        if(Test.isRunningTest()) {
            userId = '123'; 
        }
    
        if(String.isNotBlank(userId)) {
            messages.add('External User Id created was: ' + userId);
            pageUrl = loginUser(convertToString(formJson.get('Username')), convertToString(formJson.get('password')), lwcSettings);
        }

        createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Information');
        return pageUrl;
    }

    /**
     * @description Looks for existing record matching the query configured in Experience Builder. Can use values from the form using Bind Variables in the query.
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return Id of record found - either Contact.AccountId if type is a Contact or Id if Person Account
     * @see https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_bind_var_soql.htm&release=242&type=5 
     */
    private static Id getObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {    
        List<sObject> recordList = new List<sObject>();

        //Process the inputs to convert strings to relevant data types to prevent SOQL errors
        //Dates: https://salesforce.stackexchange.com/questions/285603/invalid-bind-expression-type-of-string-for-column-of-type-date
        //Datetimes: https://salesforcecody.com/system-typeexception-invalid-date-time-2021-12-28t092046-0500/
        //Times: https://developer.salesforce.com/forums/?id=9062I000000IY7KQAW
        //Get Datatype: https://salesforce.stackexchange.com/questions/223323/get-the-type-data-type-of-a-field-in-apex
        //TODO: Don't call getGlobalDescribe in a loop for each field!
        for(String key : formInputs.keySet()) { 
            if(checkFieldExists(convertToString(configurationOptions.get('objectToQuery')), key)) {
                Schema.DisplayType dataType = Schema.getGlobalDescribe().get(convertToString(configurationOptions.get('objectToQuery'))).getDescribe().fields.getMap().get(key).getDescribe().getType();
                
                //Now we have the data type of the field, convert as required.
                if(convertToString(dataType) == 'DATE') {
                    Date d = Date.valueOf(convertToString(formInputs.get(key)));
                    formInputs.put(key,d);
                }
                if(convertToString(dataType) == 'TIME') {
                    String[] strTimeSplit = convertToString(formInputs.get(key)).split(':');
                    Time t = Time.newInstance(Integer.valueOf(strTimeSplit[0]),  Integer.valueOf(strTimeSplit[1]), 0, 0);
                    formInputs.put(key,t);
                }
                if(convertToString(dataType) == 'DATETIME') {
                    Datetime dt = (DateTime)JSON.deserialize('"' + convertToString(formInputs.get(key)) +'"', DateTime.class);
                    formInputs.put(key,dt);
                }
            }    
        }

        //Configurable via the component config panel. May affect what record is found based on org settings. Default is 'System'
        //TODO: Needs check on CRUD permissions for fields in the query otherwise it might cause a failure. Use stripInaccessible()?
        try {
            if(configurationOptions.get('accessLevelMode') == 'System') { 
                recordList = Database.queryWithBinds(convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.SYSTEM_MODE);
            }
            else {
                recordList = Database.queryWithBinds(convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.USER_MODE);
            }
        }
        catch(Exception e) {
            messages.add('There was a problem executing the specific query in the Custom Query property. Query used: ' + convertToString(configurationOptions.get('customQuery') + '. Error: ' + e.getMessage()));
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.'); 
        }
        
        if(!recordList.isEmpty() && recordList.size() == 1) {
            String objectType = recordList.getSObjectType().getDescribe().getName();
            switch on objectType {
                when 'Contact', 'Case' {
                    return (Id)recordList[0].get('AccountId');
                }
                when else { //TODO: Intended to work for Accounts. Further support might be required here for other objects as and when they get added.
                    return (Id)recordList[0].get('Id');
                }
            }
        }
        else if(recordList.size() > 1) { //More than one record found on specified query
            messages.add('Multiple records found for specified query. Please check your custom query configuration. External Message: ' + configurationOptions.get('errorMultipleRecordsFound') + ' Form Values: ' + formInputs);
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Information');        
            throw new AuraHandledException(convertToString(configurationOptions.get('errorMultipleRecordsFound'))); 
        }
        else if (convertToBoolean(configurationOptions.get('createNotFound'))) { //CreateIfNotFound = True, thus return Null here so we can go on to create a new record.
            return null;
        }
        else { //No record found on specified query and CreateIfNotFound = False 
            messages.add('No record found for specified query. Create If Not found setting not enabled. External Message: ' + configurationOptions.get('errorNoRecordFound') + ' Form Values: ' + formInputs);
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Information');        
            throw new AuraHandledException(convertToString(configurationOptions.get('errorNoRecordFound'))); 
        }
    }

    /**
     * @description createContact description
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return returns a new ContactId on successful creation
     */
    @AuraEnabled
    public static Id createContact(Map<String, Object> formInputs, Map<String, Object> configurationOptions){
        Database.SaveResult srList = null;
        Id recordId = null;
        try {
            List<Contact> newContacts = new List<Contact>();
            
            Contact newContact = new Contact();
            newContact.put('AccountId', convertToString(configurationOptions.get('accountId')));
             
            for(String key : formInputs.keySet()) {
                if(checkFieldExists('Contact', key)) {
                    newContact.put(key, formInputs.get(key));
                }
                newContacts.add(newContact);
            }

            SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.CREATABLE, newContacts);
            srList = Database.insert(securityDecision.getRecords()[0], false);

            if(srList.isSuccess()) { //Return the AccountId if the Contact creation was successful, this is what is used during External User creation not the Contact Id!
                return convertToString(configurationOptions.get('accountId'));
            }
            return recordId; 
        } catch (Exception e) {
            messages.add('Failed to create new Contact record for registered user with submitted values. API Error: ' + e.getMessage());
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException(convertToString(configurationOptions.get('errorOnCreate')));
        }
    }

    /**
     * @description createPersonAccount description
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return returns the Account Id (PersonAccount Id) on successful creation
     */
    @AuraEnabled
    public static Id createPersonAccount(Map<String, Object> formInputs, Map<String, Object> configurationOptions){
        Database.SaveResult srList = null;
        Id recordId = null;
        try {
            List<Account> newPersonAccounts = new List<Account>();
            Account newPersonAccount = new Account();
            newPersonAccount.put('RecordTypeId', Id.valueOf(convertToString(configurationOptions.get('personAccountRecordTypeId'))));
            for(String key : formInputs.keySet()) {
                if(checkFieldExists('Account', key)) {
                    newPersonAccount.put(key, formInputs.get(key));
                }
                if(key == 'Email') { //Form field is called Email, map this to the PersonEmail field.
                    newPersonAccount.put('PersonEmail', formInputs.get(key)); 
                }
                newPersonAccounts.add(newPersonAccount);
            }

            SObjectAccessDecision securityDecision = Security.stripInaccessible(AccessType.CREATABLE, newPersonAccounts);
            srList = Database.insert(securityDecision.getRecords()[0], false);

            if(srList.isSuccess()) { 
                return srList.getId();
            }
            return recordId;   
        } catch (Exception e) {
            messages.add('Failed to create new Person Account record for registered user with submitted values. API Error: ' + e.getMessage());
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException(convertToString(configurationOptions.get('errorOnCreate')));
        }
    }

    /**
     * @description Creates a record of type Contact or Person Account based on settings in Experience Builder. Passes in form values.
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return Id of the newly created record. Either Contact.AccountId if type is a Contact or Id if Person Account
     */
    public static Id createObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {    
        if(convertToString(configurationOptions.get('objectCreateType'))  == 'Contact') {
           return createContact(formInputs, configurationOptions);
        }
        else if(convertToString(configurationOptions.get('objectCreateType'))  == 'Person Account') {
            return createPersonAccount(formInputs, configurationOptions);
        }
        else { //Object to create was set to 'N/A' which is not valid 
            messages.add('No record found for specified query. Create If Not found setting enabled but object type was set to N/A. Please check settings and change to Person Account or Contact.');
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.'); 
        }
    }

    /**
     * @description Generate a unique nickname for the user trying to register
     * @param username - Passes in the submitted username field from the self registration form.
     * @return String of the generated Nickname to use for the user.
     */
    public static String generateCommunityNickname(String username) {
        String communityNickname = null;

        Datetime currentTime = System.now();
        Long timeInMls = currentTime.getTime()/1000;
        communityNickname = username + timeInMls;

        if(communityNickname.length() > 40) { //Nickname field is limited to 40 characters
            communityNickname = communityNickname.substring(0,40);
        }

        return communityNickname;
    }

    /**
     * @description Attempts to create an external user which is linked to a Contact/Person Account that is found/created in other methods.
     * @param formInputs - JSON String of the submitted form values 
     * @param accountId - this is the AccountId that the External User is linked to.
     * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
     * @return String of External User Id created
     */
    public static String createExternalUser(Map<String, Object> formInputs, Id accountId, Map<String, Object> configurationOptions) {
        String userId = null; 
        User user = new User();

        for(String key : formInputs.keySet()) {
            if(checkFieldExists('User', key)) {
                user.put(key, formInputs.get(key));
            }                 
        }

        user.CommunityNickname = generateCommunityNickname(convertToString(formInputs.get('Username')));

        try {
            userId = Site.createExternalUser(user, accountId, convertToString(formInputs.get('password')), convertToBoolean(configurationOptions.get('sendEmailConfirmation')));
        }
        catch (Site.ExternalUserCreateException e) { //The site class ony throws one type of exception so we have to manually handle error messages here.
            messages.add('Failed to create external user for portal.' + ' Error: ' + e.getMessage());
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            
            //Horrible error message. Show a configuration message instead from the property panel.
            //This means that the the matched contact (using the custom query) is already a portal user and therefore can't register again.
            if(e.getMessage().contains('portal user already exists for contact')) { 
                throw new AuraHandledException(convertToString(configurationOptions.get('portalRegistrationUserExists')));
            }
            else { //Anything else, show the generic message.
                throw new AuraHandledException(convertToString(configurationOptions.get('portalRegistrationError')));
            }
        }
        return userId;
    }

    /**
     * @description Attempts to login the newly registered user. Redirects to the home page on success.
     * @param username - Passes in the submitted username field from the self registration form.
     * @param password - Passes in the submitted password field from the self registration form. 
     * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
     * @return String PageURL to redirect to upon successful login.
     */
    public static String loginUser(String username, String password, Map<String, Object> configurationOptions) {
        String pageUrl = null;

        try {
            ApexPages.PageReference homePageRef = new PageReference(Site.getBaseSecureUrl() + '/');
            String startUrl = homePageRef.getUrl();
            ApexPages.PageReference startPageRef = Site.login(username, password, startUrl);

            if(startPageRef != null) {
                pageUrl = startPageRef.getUrl();
            } else {
                ApexPages.PageReference pageRef = new PageReference(Site.getBaseSecureUrl());
                pageUrl = pageRef.getUrl();
            }
        } catch (Exception e) {
            messages.add('There was a problem logging the user into the portal.' + ' Error: ' + e.getMessage());
            createLogEntry(convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');        
            throw new AuraHandledException(convertToString(configurationOptions.get('portalLoginError')));
        }
        messages.add('User successfully logged into the portal.');
        return pageUrl;
    }
}