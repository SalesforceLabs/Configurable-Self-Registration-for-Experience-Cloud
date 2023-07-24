/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 15/05/2023
 * @description Apex controller to support custom built UI Custom Self Registration for Experience Cloud
 ***************************************************************************************************************/

//TODO: Change 'without sharing' to 'sharing'?
public without sharing class SiteRegistrationController {

    //These maps are used to define fields that should be skipped from the registration form for creating External User, Contact and Person Account.
    public static Map<String, String> skipFieldDuringRegistration = new Map <String, String>{'password' => '','confirmPassword' => ''};
    public static Map<String, String> skipFieldDuringNewContactCreate = new Map <String, String>{'password' => '','confirmPassword' => '', 'Username' => ''};
    public static Map<String, String> skipFieldDuringNewPersonAccountCreate = new Map <String, String>{'password' => '','confirmPassword' => '', 'Username' => '', 'Email' => ''};
    
    public static List<String> messages = new List<String>();

    /**
    * @description Simple method to wrap Object's Key > String conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a String value
    * @return String of passed object value
    */
    @AuraEnabled
    public static String convertToString(Object valueToConvert) {
        return String.valueOf(valueToConvert);
    }

    /**
    * @description Simple method to wrap Object > Boolean conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a Boolean value
    * @return Boolean of passed object value
    */
    @AuraEnabled
    public static Boolean convertToBoolean(Object valueToConvert) {
        return Boolean.valueOf(valueToConvert);
    }

    /**
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Self Registration form.
     * @param sObjectName - currently hardcoded to 'User' only within the LWC. Returns only configuration linked to the User record, everything else is ignored. 
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled(cacheable=true)
    public static String getCustomConfiguration(String sObjectName) {
        String result = '';
        try {

            String siteName = Site.getName();
            for (Custom_Registration_Configuration__mdt mapping : [SELECT Id, Field_Name__c, Field_Type__c, Field_Label__c, Field_Message__c, Field_Help_Text__c, Field_Validation_REGEX__c, Field_Max_Length__c, Field_Required__c, Portal_API_Name__c, Object_Name__c
                                                                   FROM Custom_Registration_Configuration__mdt 
                                                                   WHERE Portal_API_Name__c = :siteName
                                                                   AND Object_Name__c = :sObjectName
                                                                   AND Active__c = true 
                                                                   WITH SECURITY_ENFORCED]) {
           
                if(String.isNotBlank(result)){
                    result += ',';
                } 

                String jsonPart = '{';
                jsonPart += '"fieldType":"' + mapping.Field_Type__c + '",'; 
                jsonPart += '"fieldName":"' + mapping.Field_Name__c + '",';
                jsonPart += '"fieldLabel":"' + mapping.Field_Label__c + '",';
                jsonPart += '"fieldHelpText":"' + mapping.Field_Help_Text__c + '",';
                jsonPart += '"fieldMaxLength":"' + mapping.Field_Max_Length__c + '"';

                if(String.isNotBlank(mapping.Field_Message__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldMessage":"' + mapping.Field_Message__c + '"';
                }

                if(String.isNotBlank(mapping.Field_Validation_REGEX__c)) {
                    jsonPart += ',';
                    jsonPart += '"fieldRegex":"' + mapping.Field_Validation_REGEX__c + '"';
                }

                if(mapping.Field_Required__c) {
                    jsonPart += ',';
                    jsonPart += '"fieldRequired":"' + mapping.Field_Required__c + '"';
                }
             
                jsonPart += '}';
                result += jsonPart;
            }
        }
        catch(Exception ex) {
            result += ex.getLineNumber() + ' : ' + ex.getMessage();
        }
        return '['+result+']';
    }

    /**
     * @description Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on in the Experience Cloud builder.
     * @param loggingEnabled - Passes in the LWC property panel setting to turn logging on or off in a custom object called 'Self Registration Log'
     * @param message - a list of messages to store on the Platform Event
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
     * @param username - Passes in the submitted username field from the self registration form.
     * @param loggingEnabled - Passes in the LWC property panel setting to turn logging on or off in a custom object called 'Self Registration Log'
     * @return Boolean true if username is taken, otherwise false.
     */ 
    @AuraEnabled
    public static Boolean isValidUsername(String username, Boolean loggingEnabled) {
        Boolean isUsernameValid = true;
        List<NetworkMember> userList = null;

        //Get the Network Id for the current Experience Cloud Site
        String networkId = Network.getNetworkId();

        messages.add('Looking for registered user with username ' +username + ' on NetworkId ' + networkId);    

        //Query the Network Member table which holds entries for the registrations. This allows for username re-use if there are multiple portals in an org, but not for the same portal!
        //SF assigns a username by taking the submitted value then appending everything after the "@" automatically and randomly to keep unique.
        //Formula field is used to calculate value we are interested i.e. the submitted value with no domain that we can query with '='. 
        //This way, if the username changes in anyway, filter continues to work as a 2nd field doesn't need to be updated!
        userList = [
            SELECT Id, Member.Portal_Username__c, Member.Id, NetworkId
            FROM NetworkMember 
            WHERE Member.Portal_Username__c = :username
            AND NetworkId = :networkId
            WITH SECURITY_ENFORCED
        ];

        if(userList.size() >= 1) {
            messages.add('User with username ' +username + ' already exists on NetworkId ' + networkId + '. Username NOT valid.');
            createLogEntry(loggingEnabled, String.join(messages,'\n'), 'Error');    
            return !isUsernameValid; 
        }

        messages.add('User with username ' +username + ' not found on NetworkId ' + networkId + '. Username valid.');
        createLogEntry(loggingEnabled, String.join(messages,'\n'), 'Information');
        return isUsernameValid;
    }

    /**
     * @description Validates that the submitted password matches the Org's password policy.
     * @param formInputs - JSON String of the submitted form values
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel 
     */
    @AuraEnabled
    public static void validatePassword(String formInputs, String configurationOptions) {
       
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        
        try {
            User user = new User();
    
            for(String key : formJson.keySet()){
                if(!skipFieldDuringRegistration.containsKey(key)) {
                    user.put(key, formJson.get(key));
                }
            }

            user.CommunityNickname = generateCommunityNickname(convertToString(formJson.get('Username'))); 
            Site.validatePassword(user, convertToString(formJson.get('password')), convertToString(formJson.get('confirmPassword'))); 
        }
        catch (Exception ex) {
           messages.add('An Unknown Error Occurred whilst trying to validate the password:' + ex.getMessage() + '\n' + 'Form Inputs: ' + formInputs);
           createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
           throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
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

        try {

            Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
           
            if(String.isNotBlank(convertToString(lwcSettings.get('customQuery')))) {
                messages.add('Searching for record with query:' + lwcSettings.get('customQuery') + ' Form Values: ' + formJson);
                recordId = getObject(formJson, lwcSettings);
                messages.add('Record Id found was: ' + recordId);
            }
            
            if(convertToBoolean(lwcSettings.get('createNotFound'))  && String.isBlank(recordId)) { 
                messages.add('Creating object with type: ' + lwcSettings.get('objectCreateType') + 'Form Values: ' + formJson); 
                recordId = createObject(formJson, lwcSettings);
                messages.add('Created Record Id returned was: ' + recordId);   
            }

            String userId = createExternalUser(formJson, recordId, lwcSettings);
            if(String.isNotBlank(userId)) {
                messages.add('External User Id created was: ' + userId);
                pageUrl = loginUser(convertToString(formJson.get('Username')), convertToString(formJson.get('password')), lwcSettings);
            }

            createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Information');

        } catch (AuraHandledException ex) {
            throw ex;
        } catch (Exception ex) {
            messages.add('An Unknown Error Occurred: ' + ex.getMessage());
            createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }

        return pageUrl;
    }

    //TODO: Needs check on CRUD permissions for fields otherwise it might cause a failure.
    /**
     * @description Looks for existing record matching the query configured in Experience Builder. Can use values from the form using Bind Variables in the query.
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return Id of record found - either Contact.AccountId if type is a Contact or Id if Person Account
     * @see https://help.salesforce.com/s/articleView?id=release-notes.rn_apex_bind_var_soql.htm&release=242&type=5 
     */
    private static Id getObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {    
        List<sObject> recordList = new List<sObject>();

        //Configurable via the component config panel. May affect what record is found based on org settings. Default is 'System'
        if(configurationOptions.get('accessLevelMode') == 'System') { 
           recordList = Database.queryWithBinds(ConvertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.SYSTEM_MODE);
        }
        else {
           recordList = Database.queryWithBinds(ConvertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.USER_MODE);
        }

        if(!recordList.isEmpty() && recordList.size() == 1) {
            String objectType = recordList.getSObjectType().getDescribe().getName();
            return objectType == 'Contact' ? (Id)recordList[0].get('AccountId') : (Id)recordList[0].get('Id');
        }
        else if (ConvertToBoolean(configurationOptions.get('createNotFound'))) { //CreateIfNotFound = True, thus return Null here so we can go on to create a new record.
            return null;
        }
        else { //No record found on specified query and CreateIfNotFound = False
            messages.add('No record found for specified query. Create If Not found setting not enabled. External Message: ' + configurationOptions.get('errorNoRecordFound') + ' Form Values: ' + formInputs);
            createLogEntry(ConvertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Information');        
            throw new AuraHandledException(ConvertToString(configurationOptions.get('errorNoRecordFound'))); 
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
            Contact newContact = new Contact();
            newContact.put('AccountId', ConvertToString(configurationOptions.get('accountId')) );
             
            for(String key : formInputs.keySet()) {
                if(!skipFieldDuringNewContactCreate.containsKey(key)) {
                    newContact.put(key, formInputs.get(key));
                }
            }
           srList = Database.insert(newContact, false);
           if(srList.isSuccess()) {
              return Id.valueOf(srList.getId());
           }
           return recordId; 
        } catch (Exception e) {
            messages.add('Failed to create new Contact record for registered user with submitted values. API Error: ' + e.getMessage());
            createLogEntry(ConvertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException(ConvertToString(configurationOptions.get('errorOnCreate')));
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
            Account newPersonAccount = new Account();
            newPersonAccount.put('RecordTypeId', Id.valueOf(convertToString(configurationOptions.get('personAccountRecordTypeId'))));
            for(String key : formInputs.keySet()) {
                if(!skipFieldDuringNewPersonAccountCreate.containsKey(key)) {
                    newPersonAccount.put(key, formInputs.get(key));
                }
                if(key == 'Email') { //Form field is called Email, map this to the PersonEmail field.
                    newPersonAccount.put('PersonEmail', formInputs.get(key)); 
                }
            }
            //System.debug('Person Account to create' + newPersonAccount);
            srList = Database.insert(newPersonAccount, false);
            if(srList.isSuccess()) { 
                return srList.getId();
            }
            return recordId;   
        } catch (Exception e) {
            messages.add('Failed to create new Person Account record for registered user with submitted values. API Error: ' + e.getMessage());
            createLogEntry(ConvertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException(ConvertToString(configurationOptions.get('errorOnCreate')));
        }
    }

    /**
     * @description Creates a record of type Contact or Person Account based on settings in Experience Builder. Passes in form values.
     * @param formInputs - JSON String of the submitted form values 
     * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
     * @return Id of the newly created record. Either Contact.AccountId if type is a Contact or Id if Person Account
     */
    public static Id createObject(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {    
        if(ConvertToString(configurationOptions.get('objectCreateType'))  == 'Contact') {
           return createContact(formInputs, configurationOptions);
        }
        else if(ConvertToString(configurationOptions.get('objectCreateType'))  == 'Person Account') {
            return createPersonAccount(formInputs, configurationOptions);
        }
        else { //Object to create was set to 'N/A' which is not valid 
            messages.add('No record found for specified query. Create If Not found setting enabled but object type was set to N/A. Please check settings and change to Person Account or Contact.');
            createLogEntry(ConvertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.'); 
        }
    }

    /**
     * @description Generate a unique nickname for the user trying to register
     * @param username - Passes in the submitted username field from the self registration form.
     * @return String of the generated Nickname to use for the user.
     */
    private static String generateCommunityNickname(String username) {
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
            if(!skipFieldDuringRegistration.containsKey(key)) {
                user.put(key, formInputs.get(key));
            }
        }

        user.CommunityNickname = generateCommunityNickname(convertToString(formInputs.get('Username')));
        userId = Site.createExternalUser(user, accountId, convertToString(formInputs.get('password')), convertToBoolean(configurationOptions.get('sendEmailConfirmation')));
        
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
            createLogEntry(ConvertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error');        
            throw new AuraHandledException(ConvertToString(configurationOptions.get('portalLoginError')));
        }

        return pageUrl;
    }
}