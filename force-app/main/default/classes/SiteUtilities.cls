/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce). Feedback/Collabration with Mike Cleaver (Github:Mike-Cleaver-LB)
 * CREATE DATE    : 13/04/2024
 * LAST MODIFIED  : 28/08/2026 - Added Outcome to Experience Cloud logging for reportable login and registration results.
 * @description Apex controller to provide common functions between SiteRegistration, SiteLogin and others in the future
 ***************************************************************************************************************/
public without sharing class SiteUtilities {

    public static final String SELF_REG_COMPONENT_NAME = 'Self Registration';
    public static final String LOGIN_COMPONENT_NAME = 'Login';
    public static final String SMS_LICENCE_NAME = 'setting/force.com/orgValue.IdentityVerificationCredits';
    public static final String INFORMATION_LOG_TYPE = 'Information';
    public static final String ERROR_LOG_TYPE = 'Error';
    public static final String OUTCOME_LOGIN_SUCCESS = 'Login Success';
    public static final String OUTCOME_LOGIN_FAILED = 'Login Failed';
    public static final String OUTCOME_REGISTRATION_SUCCESS = 'Registration Success';
    public static final String OUTCOME_USERNAME_EXISTS = 'Username Exists';
    public static final String OUTCOME_USERNAME_NOT_FOUND = 'Username Not Found';
    public static final String OUTCOME_INVALID_PASSWORD = 'Invalid Password';
    public static final String OUTCOME_USER_FROZEN = 'User Frozen';
    public static final String OUTCOME_PASSWORD_LOCKOUT = 'Password Lockout';
    public static final String OUTCOME_PASSWORD_VALIDATION_FAILED = 'Password Validation Failed';
    public static final String OUTCOME_RECORD_CREATE_FAILED = 'Record Create Failed';
    public static final String OUTCOME_USER_CREATE_FAILED = 'User Create Failed';
    public static final String OUTCOME_RECORD_DELETE_FAILED = 'Record Delete Failed';
    public static final String OUTCOME_QUERY_ERROR = 'Query Error';
    public static final String OUTCOME_CONFIGURATION_ERROR = 'Configuration Error';
    public static final String OUTCOME_NO_RECORD_FOUND = 'No Record Found';
    public static final String OUTCOME_MULTIPLE_RECORDS_FOUND = 'Multiple Records Found';
    public static final String OUTCOME_VERIFICATION_SENT = 'Verification Sent';
    public static final String OUTCOME_VERIFICATION_SEND_FAILED = 'Verification Send Failed';
    public static final String OUTCOME_VERIFICATION_FAILED = 'Verification Failed';
    public static final String OUTCOME_VERIFICATION_SUCCESS = 'Verification Success';

    public static Map<String, Auth.VerificationMethod> methods = new Map<String, Auth.VerificationMethod>{'Email' => Auth.VerificationMethod.EMAIL, 'SMS' => Auth.VerificationMethod.SMS};
    public static List<String> messages = new List<String>();
    public static String siteName = Site.getName();

    // Test-visible wrapper for Custom Metadata to allow mocking in tests
    @TestVisible
    private static List<CustomConfigurationWrapper> mockMetadataList;
    
    // Test-visible mock for NetworkMember results to allow mocking in tests
    @TestVisible
    public static List<NetworkMember> mockNetworkMemberList;
    
    // Test-visible mock for Custom_Experience_Cloud_Setting__mdt to allow mocking in tests. Keyed by Type__c i.e. 'Login' or 'Self Registration'.
    @TestVisible
    public static Map<String, Boolean> mockLoggingSettings;

    // Test-visible mock for the component settings map returned by getComponentSettings. Uses the unified camelCase keys.
    @TestVisible
    public static Map<String, Object> mockComponentSettings;
    
    // Test-visible flag to simulate exception in sendVerificationCode
    @TestVisible
    public static Boolean simulateSendVerificationCodeException = false;

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
     * @description Thrown when the Custom Experience Cloud Setting record for a component cannot be found or is misconfigured.
     */
    public class ComponentSettingsException extends Exception {}

    /**
     * @description Loads the behavioural settings for a component from Custom_Experience_Cloud_Setting__mdt.
     * NOTE: Deliberately NOT @AuraEnabled. These settings contain the custom query, Account Id and access level mode which must never be
     * discoverable by the guest user. Apex loads them server side and ignores anything sent up from the client.
     * @param componentType the Type__c picklist value identifying the record. Use LOGIN_COMPONENT_NAME or SELF_REG_COMPONENT_NAME.
     * @return a map of the settings using the unified camelCase keys shared by both components.
     */
    public static Map<String, Object> getComponentSettings(String componentType) {
        if (mockComponentSettings != null) {
            return mockComponentSettings;
        }

        List<Custom_Experience_Cloud_Setting__mdt> settings = [
            SELECT Type__c, Enable__c, Button_Label__c, Button_Waiting_Message__c, Button_Awaiting_Code_Message__c,
                   Portal_Redirect__c, Enable_Passwordless_Login__c, Passwordless_Method__c, Passwordless_Profile_Id__c,
                   Failed_Code_Verification_Message__c, Portal_Error_Send_Verification_Code__c, Block_User_Error_Message__c,
                   Incorrect_User_Credentials_Error__c, User_Locked_Out_Error_Message__c, Custom_Query__c, Access_Level_Mode__c,
                   Send_Email_Confirmation__c, Password_Match_Error__c, Username_Taken_Message__c, No_Record_Found_Error__c,
                   Multiple_Records_Found_Error__c, Error_On_Create__c, Portal_Login_Error__c, Portal_Registration_Error__c,
                   Portal_Registration_User_Exists__c, Create_Not_Found__c, Object_Create_Type__c, Person_Account_Record_Type__c,
                   Account_Id__c
            FROM Custom_Experience_Cloud_Setting__mdt
            WHERE Type__c = :componentType
            WITH SECURITY_ENFORCED
            LIMIT 1
        ];

        if (settings.isEmpty()) {
            throw new ComponentSettingsException('No Custom Experience Cloud Setting record was found with a Type of "' + componentType + '".');
        }

        Custom_Experience_Cloud_Setting__mdt setting = settings[0];
        Map<String, Object> componentSettings = new Map<String, Object>();

        componentSettings.put('loggingEnabled', setting.Enable__c);
        componentSettings.put('buttonLabel', setting.Button_Label__c);
        componentSettings.put('buttonWaitingMessage', setting.Button_Waiting_Message__c);
        componentSettings.put('buttonAwaitingCodeMessage', setting.Button_Awaiting_Code_Message__c);
        componentSettings.put('portalRedirect', setting.Portal_Redirect__c);
        componentSettings.put('enablePasswordlessLogin', setting.Enable_Passwordless_Login__c);
        componentSettings.put('passwordlessMethod', setting.Passwordless_Method__c);
        componentSettings.put('passwordlessProfileId', setting.Passwordless_Profile_Id__c);
        componentSettings.put('failedCodeVerificationMessage', setting.Failed_Code_Verification_Message__c);
        componentSettings.put('portalErrorSendVerificationCode', setting.Portal_Error_Send_Verification_Code__c);
        componentSettings.put('blockUserErrorMessage', setting.Block_User_Error_Message__c);
        componentSettings.put('incorrectUserCredentialsErrorMessage', setting.Incorrect_User_Credentials_Error__c);
        componentSettings.put('userLockedOutErrorMessage', setting.User_Locked_Out_Error_Message__c);
        componentSettings.put('customQuery', setting.Custom_Query__c);
        componentSettings.put('accessLevelMode', setting.Access_Level_Mode__c);
        componentSettings.put('sendEmailConfirmation', setting.Send_Email_Confirmation__c);
        componentSettings.put('passwordMatchError', setting.Password_Match_Error__c);
        componentSettings.put('usernameTakenMessage', setting.Username_Taken_Message__c);
        componentSettings.put('noRecordFoundError', setting.No_Record_Found_Error__c);
        componentSettings.put('multipleRecordsFoundError', setting.Multiple_Records_Found_Error__c);
        componentSettings.put('errorOnCreate', setting.Error_On_Create__c);
        componentSettings.put('portalLoginError', setting.Portal_Login_Error__c);
        componentSettings.put('portalRegistrationError', setting.Portal_Registration_Error__c);
        componentSettings.put('portalRegistrationUserExists', setting.Portal_Registration_User_Exists__c);
        componentSettings.put('createNotFound', setting.Create_Not_Found__c);
        componentSettings.put('objectCreateType', setting.Object_Create_Type__c);
        componentSettings.put('personAccountRecordTypeId', setting.Person_Account_Record_Type__c);
        componentSettings.put('accountId', setting.Account_Id__c);
        componentSettings.put('objectToQuery', getObjectToQuery(setting.Custom_Query__c));

        return componentSettings;
    }

    /**
     * @description Returns the subset of the component settings that the browser needs to render the form, so the components read every
     * value from Custom Metadata rather than from the deprecated Experience Builder properties.
     * NOTE: This deliberately excludes the custom query, Account Id, profile and record type. Those must never be discoverable by the
     * guest user, which is why getComponentSettings itself is not exposed to the client.
     * @param componentName the Type__c of the settings record to load i.e. 'Login' or 'Self Registration'.
     * @return a JSON string of the display values only.
     */
    @AuraEnabled(cacheable=true)
    public static String getDisplaySettings(String componentName) {
        String componentType = (componentName == LOGIN_COMPONENT_NAME) ? LOGIN_COMPONENT_NAME : SELF_REG_COMPONENT_NAME;

        try {
            Map<String, Object> settings = getComponentSettings(componentType);
            return JSON.serialize(new Map<String, Object>{
                'buttonLabel' => settings.get('buttonLabel'),
                'buttonWaitingMessage' => settings.get('buttonWaitingMessage'),
                'buttonAwaitingCodeMessage' => settings.get('buttonAwaitingCodeMessage'),
                'passwordMatchError' => settings.get('passwordMatchError')
            });
        }
        catch(ComponentSettingsException ex) {
            throw new AuraHandledException(ex.getMessage());
        }
    }

    /**
     * @description Derives the object being queried from the configured SOQL so it does not need to be stored or calculated in the browser.
     * @param customQuery the SOQL configured on the Self Registration settings record.
     * @return the sObject name that follows the FROM keyword, or a blank string if it cannot be determined.
     */
    public static String getObjectToQuery(String customQuery) {
        if(String.isBlank(customQuery)) {
            return '';
        }
        Matcher queryMatcher = Pattern.compile('(?i)\\bFROM\\s+([A-Za-z0-9_]+)').matcher(customQuery);
        return queryMatcher.find() ? queryMatcher.group(1) : '';
    }

    /**
     * @description Validates the Self Registration settings that the component cannot safely check in the browser now the query lives server side.
     * @param settings the settings map returned by getComponentSettings.
     * @return a message describing the first configuration problem found, or null when the configuration is valid.
     */
    public static String validateSelfRegistrationSettings(Map<String, Object> settings) {
        String customQuery = convertToString(settings.get('customQuery'));
        if(String.isBlank(customQuery)) {
            return 'A Custom Query is required to use this component.';
        }

        String objectToQuery = convertToString(settings.get('objectToQuery'));
        if(objectToQuery != 'Contact' && objectToQuery != 'Account' && objectToQuery != 'Case') {
            return 'Only Contact, Account or Case objects are supported with a Custom Query on this component.';
        }

        if(objectToQuery == 'Account' && !SiteRegistrationController.isPersonAccountEnabled()) {
            return 'Person Accounts are not enabled on this org so you cannot use Accounts in a Custom Query.';
        }

        //The profile is used to build the unsaved User during passwordless self registration, whether or not a record is created.
        if(convertToBoolean(settings.get('enablePasswordlessLogin'))) {
            try {
                getProfileId(convertToString(settings.get('passwordlessProfileId')));
            }
            catch(ComponentSettingsException ex) {
                return ex.getMessage();
            }
        }

        if(!convertToBoolean(settings.get('createNotFound'))) {
            return null;
        }

        String objectCreateType = convertToString(settings.get('objectCreateType'));
        if(String.isBlank(objectCreateType)) {
            return 'Object Create Type must be set when Create Record If Not Found is enabled.';
        }

        if(objectCreateType == 'Contact') {
            String accountId = convertToString(settings.get('accountId'));
            if(String.isBlank(accountId)) {
                return 'Please specify an Account Id on the Self Registration settings record when creating a Contact.';
            }
            if(accountId.length() != 15 && accountId.length() != 18) {
                return 'Account Id must be a Salesforce 15 or 18 character reference.';
            }
            if(!accountId.startsWith('001')) {
                return 'Account Id must start with 001 (Account Object Type).';
            }
        }

        if(objectCreateType == 'Person Account') {
            if(!SiteRegistrationController.isPersonAccountEnabled()) {
                return 'Person Accounts are not enabled on this org.';
            }

            //Resolve the record type here so a name that no longer exists is reported to the admin when the page loads,
            //rather than surfacing as a generic record creation failure to the first person who tries to register.
            try {
                getPersonAccountRecordTypeId(convertToString(settings.get('personAccountRecordTypeId')));
            }
            catch(ComponentSettingsException ex) {
                return ex.getMessage();
            }
        }

        return null;
    }

    /**
     * @description Resolves the Person Account record type configured on the settings record to its Id.
     * NOTE: Matches on DeveloperName first because record type labels can be renamed and are translated per user language.
     * Falls back to the label so existing configurations that stored one keep working.
     * @param recordTypeName the DeveloperName or label of an Account record type.
     * @return the record type Id.
     * @throws ComponentSettingsException when the setting is blank or names a record type that does not exist.
     */
    public static Id getPersonAccountRecordTypeId(String recordTypeName) {
        if(String.isBlank(recordTypeName)) {
            throw new ComponentSettingsException('Please set a Person Account Record Type to create a Person Account during registration.');
        }

        Schema.DescribeSObjectResult accountDescribe = Schema.SObjectType.Account;
        Schema.RecordTypeInfo recordType = accountDescribe.getRecordTypeInfosByDeveloperName().get(recordTypeName);

        if(recordType == null) {
            recordType = accountDescribe.getRecordTypeInfosByName().get(recordTypeName);
        }

        if(recordType == null) {
            throw new ComponentSettingsException('No Account record type called "' + recordTypeName + '" exists. Check the Person Account Record Type on the Self Registration Settings record.');
        }

        return recordType.getRecordTypeId();
    }

    /**
     * @description Resolves the profile configured on the settings record to its Id.
     * @param profileName the Name of a Profile. The profile must also be a member of the site or user creation fails later on.
     * @return the profile Id.
     * @throws ComponentSettingsException when the setting is blank or names a profile that does not exist.
     */
    public static Id getProfileId(String profileName) {
        if(String.isBlank(profileName)) {
            throw new ComponentSettingsException('Please set a Passwordless Profile on the Self Registration Settings record. The profile must be a member of the site.');
        }

        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];

        if(profiles.isEmpty()) {
            throw new ComponentSettingsException('No profile called "' + profileName + '" exists. Check the Passwordless Profile on the Self Registration Settings record.');
        }

        return profiles[0].Id;
    }

    /**
     * @description Get metadata wrappers - uses mock data in tests if available, otherwise queries real metadata
     * Based on pattern from: https://crsinfosolutions.com/custom-metadata-unit-test/
     */
    @TestVisible
    private static List<CustomConfigurationWrapper> getMetadataWrappers(String componentName) {
        // If mock data is set in tests, use it
        if (mockMetadataList != null) {
            return mockMetadataList;
        }
        
        // Otherwise, query real metadata
        List<SObject> metadata = new List<SObject>(); 
        String objectName = (componentName == LOGIN_COMPONENT_NAME) ? 'Custom_Login_Configuration__mdt' : 'Custom_Registration_Configuration__mdt';
        
        // Query fields explicitly to avoid getAll() truncation issues with Long Text Areas and sort by Display Order
        String query = 'SELECT Active__c, Portal_API_Name__c, Display_Order__c, Field_Type__c, Field_Name__c, ' +
                       'Field_Label__c, Field_Class__c, Minimum_Value__c, Field_Under_Minimum_Range_Message__c, ' +
                       'Maximum_Value__c, Field_Over_Max_Range_Message__c, Field_Min_Length__c, ' +
                       'Field_Message_Too_Short__c, Field_Max_Length__c, Field_Label_Variant__c, ' +
                       'Field_Date_Style__c, Field_Show_Icon__c, Field_Icon_Name__c, Field_Icon_Class__c, ' +
                       'Field_Parent_Class__c, Field_Toggle_Icon_Name__c, Field_Toggle_Type__c, ' +
                       'Field_Allow_Auto_Complete__c, Field_Message_Too_Long__c, Field_Picklist_Options__c, ' +
                       'Field_Placeholder__c, Field_Message__c, Field_Validation_REGEX__c, ' +
                       'Field_Required__c, Field_Required_Message__c, Field_Help_Text__c ' +
                       'FROM ' + objectName + 
                       ' WHERE Active__c = true AND (Portal_API_Name__c = :siteName OR Portal_API_Name__c = \'ALL\')' +
                       ' ORDER BY Display_Order__c ASC';
        
        metadata = Database.query(query);
        
        List<CustomConfigurationWrapper> wrappers = new List<CustomConfigurationWrapper>();
        for (SObject m : metadata) {
            wrappers.add(new CustomConfigurationWrapper(m));
        }
        return wrappers;
    }

    /**
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Login & Self Registration forms. 
     * Also confirms that the Custom Experience Cloud Setting record for the component exists and is valid before the form is rendered.
     * NOTE: The settings themselves are never returned to the client, only a message describing any configuration problem.
     * @param urlParams a JSON string of URL params that were appended to the page.
     * @param componentName a string of the component that is calling this function to filter the Metadata i.e. Login or Self Registration
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled
    public static String getCustomConfiguration(String urlParams, String componentName) {
        Map<String, Object> urlParameters = (Map<String, Object>) JSON.deserializeUntyped(urlParams);
        List<Map<String, Object>> resultList = new List<Map<String, Object>>();
        String componentType = (componentName == LOGIN_COMPONENT_NAME) ? LOGIN_COMPONENT_NAME : SELF_REG_COMPONENT_NAME;

        try {
            Map<String, Object> settings = getComponentSettings(componentType);

            if(componentType == SELF_REG_COMPONENT_NAME) {
                String configurationError = validateSelfRegistrationSettings(settings);
                if(String.isNotBlank(configurationError)) {
                    throw new ComponentSettingsException(configurationError);
                }
            }
        }
        catch(ComponentSettingsException ex) {
            throw new AuraHandledException(ex.getMessage());
        }

        try {
            List<CustomConfigurationWrapper> metadataWrappers = getMetadataWrappers(componentName);

            for (CustomConfigurationWrapper mapping : metadataWrappers) {
                Map<String, Object> fieldMap = new Map<String, Object>();
                
                fieldMap.put('fieldType', mapping.fieldType);
                fieldMap.put('fieldName', mapping.fieldName);
                fieldMap.put('fieldLabel', mapping.fieldLabel);
                fieldMap.put('fieldClass', mapping.fieldClass);
                fieldMap.put('fieldMinValue', mapping.minimumValue);
                fieldMap.put('fieldMessageUnder', mapping.fieldUnderMinimumRangeMessage);
                fieldMap.put('fieldMaxValue', mapping.maximumValue);
                fieldMap.put('fieldMessageOver', mapping.fieldOverMaximumRangeMessage);
                fieldMap.put('fieldMinLength', mapping.fieldMinLength);
                fieldMap.put('fieldMinLengthMessage', mapping.fieldMessageTooShort);
                fieldMap.put('fieldMaxLength', mapping.fieldMaxLength);
                fieldMap.put('fieldLabelVariant', mapping.fieldLabelVariant);
                fieldMap.put('fieldDateStyle', mapping.fieldDateStyle);
                
                //Settings to control icon visibility
                fieldMap.put('fieldShowIcon', convertToBoolean(mapping.fieldShowIcon));
                fieldMap.put('fieldIconName', mapping.fieldIconName);
                fieldMap.put('fieldIconClass', mapping.fieldIconClass);
                fieldMap.put('fieldParentClass', mapping.fieldParentClass);
                fieldMap.put('fieldToggleIconName', mapping.fieldToggleIconName);
                fieldMap.put('fieldToggleFieldType', mapping.fieldToggleType);

                String autocomplete = convertToBoolean(mapping.fieldAllowAutoComplete) ? 'on' : 'off';
                fieldMap.put('fieldAutocomplete', autocomplete);

                //NOTE: Odd behaviour of this property... See Usage Considerations: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
                //https://salesforce.stackexchange.com/questions/348093/lwc-lightning-input-custom-validation-for-max-length-no-error-message-comes-on
                fieldMap.put('fieldMaxLengthMessage', mapping.fieldMessageTooLong);
                
                //TODO: We could add fields to control the default values from custom metadata if needed.
                fieldMap.put('fieldChecked', false);
                fieldMap.put('fieldValue', '');

                for(String key : urlParameters.keySet()) {
                    if(mapping.fieldName == key) {
                        if(convertToBoolean(urlParameters.get(key))) {
                            fieldMap.put('fieldChecked', urlParameters.get(key));
                        }
                        else {
                            fieldMap.put('fieldValue', urlParameters.get(key));
                        }
                    }
                }

                if(mapping.fieldType == 'picklist') {
                    fieldMap.put('showAsPicklist', true);
                    String picklistOptions = mapping.fieldPicklistOptions;
                    if (String.isNotBlank(picklistOptions)) {
                        try {
                            fieldMap.put('picklistOptions', JSON.deserializeUntyped(picklistOptions));
                        } catch (Exception e) {
                            System.debug('Error parsing picklist options: ' + e.getMessage());
                            // Fallback to empty list or handle error
                            fieldMap.put('picklistOptions', new List<Object>());
                            throw new AuraHandledException('There was an issue loading the picklist options. Please check the configuration is valid JSON and try again. ' + e.getMessage());
                        }
                    } else {
                        fieldMap.put('picklistOptions', new List<Object>());
                    }
                }

                if(String.isNotBlank(convertToString(mapping.fieldPlaceholder))) {
                    fieldMap.put('fieldPlaceholder', mapping.fieldPlaceholder);
                }

                if(String.isNotBlank(convertToString(mapping.fieldMessage)) && String.isNotBlank(convertToString(mapping.fieldValidationRegex))) {
                    fieldMap.put('fieldMessage', mapping.fieldMessage);
                    fieldMap.put('fieldRegex', mapping.fieldValidationRegex);
                }

                if(convertToBoolean(mapping.fieldRequired) && String.isNotBlank(convertToString(mapping.fieldRequiredMessage))) {
                    fieldMap.put('fieldRequired', convertToString(mapping.fieldRequired));
                    fieldMap.put('fieldRequiredMessage', mapping.fieldRequiredMessage);
                }

                if(String.isNotBlank(convertToString(mapping.fieldHelpText))) {
                    fieldMap.put('fieldHelpText', mapping.fieldHelpText);
                }
                
                resultList.add(fieldMap);
            }
        }
        catch(Exception ex) {
            throw new AuraHandledException('There was an issue displaying custom metadata. Please check the configuration and try again. ' + ex.getMessage());
        }
        
        return JSON.serialize(resultList);
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
     * @description Extracts the dial code portion from a value stored as "code_Country".
     * @param rawCountryCode the raw country code value from the form/configuration.
     * @return the code segment before the underscore, or blank if not present.
     */
    public static String extractCountryCode(Object rawCountryCode) {
        String countryCodeRaw = convertToString(rawCountryCode);
        if(String.isNotBlank(countryCodeRaw)) {
            List<String> countryParts = countryCodeRaw.split('_');
            return !countryParts.isEmpty() ? countryParts[0] : '';
        }
        return '';
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
     * @description Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on with the Enable Logging field on the Custom Experience Cloud Setting record.
     * @param loggingEnabled - the 'loggingEnabled' value from the component settings, sourced from Enable__c on Custom_Experience_Cloud_Setting__mdt
     * @param message - a list of messages to store on the Platform Event
     * @param logType - the type of error to log, either SiteUtilities.INFORMATION_LOG_TYPE or SiteUtilities.ERROR_LOG_TYPE
     * @param componentName - the name of the component that is calling this function
     * @param accountId - the Account Id of the record identified or created (optional)
     * @param userId - the User Id of the user identified or created (optional)
     * @param contactId - the Contact Id (PersonAccountId in Person Account enabled orgs, ContactId in BusinessAccount and Contact only orgs) (optional)
     * @param outcome - short reportable result of the attempt (optional). Use SiteUtilities.OUTCOME_* constants.
     */
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName, Id accountId, Id userId, Id contactId, String outcome){
        if(loggingEnabled) {
            Experience_Cloud_Event__e newLog = new Experience_Cloud_Event__e();
            newLog.Message__c = message;
            newLog.Log_Type__c = logType;
            newLog.Component_Name__c = componentName;
            newLog.AccountId__c = accountId;
            newLog.UserId__c = userId;
            newLog.ContactId__c = contactId;
            newLog.Outcome__c = outcome;
            Eventbus.publish(newLog);
        } 
    }

    /** 
     * @description Overloaded method that includes related record Ids but no outcome.
     */
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName, Id accountId, Id userId, Id contactId){
        createLogEntry(loggingEnabled, message, logType, componentName, accountId, userId, contactId, null);
    }

    /** 
     * @description Overloaded method that includes an outcome but no related record Ids.
     */
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName, String outcome){
        createLogEntry(loggingEnabled, message, logType, componentName, null, null, null, outcome);
    }
    
    /** 
     * @description Overloaded method for backward compatibility. Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on with the Enable Logging field on the Custom Experience Cloud Setting record.
     * @param loggingEnabled - the 'loggingEnabled' value from the component settings, sourced from Enable__c on Custom_Experience_Cloud_Setting__mdt
     * @param message - a list of messages to store on the Platform Event
     * @param logType - the type of error to log, either SiteUtilities.INFORMATION_LOG_TYPE or SiteUtilities.ERROR_LOG_TYPE
     * @param componentName - the name of the component that is calling this function
     */
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName){
        createLogEntry(loggingEnabled, message, logType, componentName, null, null, null, null);
    }

    /**
    * @description Checks to see if the Logging setting is activated for a component.
    * NOTE: Apex should prefer the 'loggingEnabled' key on the settings map it has already loaded via getComponentSettings.
    * @param componentType - the Type__c value of the settings record i.e. 'Login' or 'Self Registration'
    * @return true/false depending on setting value.
    */
    @AuraEnabled(cacheable=true)
    public static Boolean isLoggingEnabled(String componentType) {
        // If mock data is set in tests, use it
        if (mockLoggingSettings != null && mockLoggingSettings.containsKey(componentType)) {
            return mockLoggingSettings.get(componentType);
        }
        
        List<Custom_Experience_Cloud_Setting__mdt> logSetting = [SELECT Id, Enable__c, Type__c FROM Custom_Experience_Cloud_Setting__mdt WHERE (Type__c = :componentType AND Enable__c = true) WITH SECURITY_ENFORCED LIMIT 1];
        
        return !logSetting.isEmpty();
    }

    /**
     * @description sets the ProfileId on the non-persisted User Object
     * NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  profileName the name of the Profile configured on the Custom Experience Cloud Setting record.
     */
    public void setProfileId(User user, String profileName){
        user.ProfileId = getProfileId(profileName);
    }

    /**
     * @description sets the ContactId on the non-persisted User Object
     * NOTE: This method lives here because it needs to run in a 'without sharing' context as it is accessed by the guest user during Passwordless Self Registration.
     * @param  user pass in the user object which is currently not persisted until the user is verified
     * @param  contactId the contactId to set on the user object.
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
	public static Id getPersonContactId(Id accountId) {
        String account = accountId;
        sObject personAccount = Database.query('SELECT Id,PersonContactId FROM Account WHERE Id = :account');
        return (Id)personAccount.get('PersonContactId');
        //return [SELECT Id,PersonContactId FROM Account WHERE Id = :accountId].PersonContactId;        
    }

    /**
    * @description Query records using the specified custom query
    * @param formInputs Map of the submitted form values 
    * @param configurationOptions - the server side settings map loaded from Custom_Experience_Cloud_Setting__mdt
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
        // If mock data is set in tests, use it
        if (mockNetworkMemberList != null) {
            return mockNetworkMemberList;
        }
        
        //SF assigns a username by taking the submitted value then appending everything after the "@" automatically and randomly to keep unique.
        //Formula field is used to calculate value we are interested i.e. the submitted value with no domain that we can query with '='. 
        //This way, if the username changes in anyway, filter continues to work as a 2nd field doesn't need to be updated!
        List<NetworkMember> userList = [
            SELECT Id, Member.Username, Member.Portal_Username__c, Member.Id, NetworkId
            FROM NetworkMember 
            WHERE (Member.Username = :username OR Member.Portal_Username__c = :username)
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
            u = [SELECT Id,Name,Email,Username,ContactId,Contact.AccountId FROM User WHERE Username = :username];
        }
        if(String.isNotBlank(mobilePhone)) {
            u = [SELECT Id, MobilePhone, IsActive, ContactId, Contact.AccountId FROM User WHERE MobilePhone = :mobilePhone AND IsActive = true ORDER BY CreatedDate DESC LIMIT 1];
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
            SiteUtilities.createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, componentName, null, null, null, SiteUtilities.OUTCOME_RECORD_DELETE_FAILED);
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
        // Simulate exception in tests if flag is set
        if (simulateSendVerificationCodeException) {
            throw new CalloutException('Simulated exception for testing sendVerificationCode');
        }
        
        if(componentName == SELF_REG_COMPONENT_NAME) {
            return Test.isRunningTest() ? '123456' : UserManagement.initSelfRegistration(method, user);
        }   
        return Test.isRunningTest() ? '123456' : UserManagement.initPasswordlessLogin(user.Id, method);
    }

    /**
     * @description Chooses a safe post-login redirect. Prefers a relative startURL from the login page query string when present;
     * otherwise uses the configured Portal Redirect. Rejects protocol-relative and external absolute URLs to prevent open redirects.
     * @param requestedStartUrl the startURL/startUrl query parameter from the browser (untrusted).
     * @param configuredPortalRedirect the Portal_Redirect__c value from Custom Metadata (trusted fallback).
     * @return a relative path or same-site absolute URL suitable for Site.login / UserManagement verification.
     */
    public static String resolveStartUrl(String requestedStartUrl, String configuredPortalRedirect) {
        String fallback = String.isNotBlank(configuredPortalRedirect) ? configuredPortalRedirect : '/';

        if(String.isBlank(requestedStartUrl)) {
            return fallback;
        }

        String candidate = requestedStartUrl.trim();

        // Experience Cloud typically supplies a site-relative path e.g. /s/article/My-Article
        if(candidate.startsWith('/') && !candidate.startsWith('//')) {
            return candidate;
        }

        // Absolute URL only when it remains on this Experience Cloud site
        String baseUrl = Site.getBaseSecureUrl();
        if(String.isNotBlank(baseUrl) && candidate.startsWith(baseUrl)) {
            return candidate;
        }

        messages.add('Requested startURL was rejected as unsafe. Using configured portal redirect instead. Requested: ' + requestedStartUrl);
        return fallback;
    }

    /**
     * @description Builds the startUrl value passed to Site.login from a resolved relative or absolute path.
     * Experience Cloud startURL values already include the site path prefix (e.g. /lwctest/s/test-page).
     * Prepending Site.getBaseSecureUrl() in that case doubles the prefix and produces an invalid URL.
     * @param requestedStartUrl the startURL/startUrl query parameter from the browser (untrusted).
     * @param configuredPortalRedirect the Portal_Redirect__c value from Custom Metadata (trusted fallback).
     * @return the URL string to pass as the startUrl argument to Site.login.
     */
    public static String buildLoginStartUrl(String requestedStartUrl, String configuredPortalRedirect) {
        String resolved = resolveStartUrl(requestedStartUrl, configuredPortalRedirect);
        if(resolved.startsWith('http://') || resolved.startsWith('https://')) {
            return new PageReference(resolved).getUrl();
        }

        String resolvedPath = resolved.startsWith('/') ? resolved : '/' + resolved;
        String baseUrl = Site.getBaseSecureUrl();
        if(String.isBlank(baseUrl)) {
            return new PageReference(resolvedPath).getUrl();
        }

        // If the path already starts with the community/site path from getBaseSecureUrl(), pass it through.
        // Example: base https://host/lwctest/s + startURL /lwctest/s/test-page must NOT become .../lwctest/s/lwctest/s/test-page
        String basePath = normalizeUrlPath(new System.Url(baseUrl).getPath());
        String normalizedResolved = normalizeUrlPath(resolvedPath);
        if(String.isNotBlank(basePath) && basePath != '/'
            && (normalizedResolved == basePath || normalizedResolved.startsWith(basePath + '/'))) {
            return resolvedPath;
        }

        // Short configured redirects such as "/" still need the site base URL.
        return new PageReference(baseUrl + resolvedPath).getUrl();
    }

    /**
     * @description Strips a trailing slash from a URL path for prefix comparisons, leaving "/" unchanged.
     */
    @TestVisible
    private static String normalizeUrlPath(String path) {
        if(String.isBlank(path) || path == '/') {
            return path;
        }
        return path.endsWith('/') ? path.substring(0, path.length() - 1) : path;
    }

    /**
     * @description verify the code submitted by the user, and return a JSON string with the redirect URL if verification is successful.
     * The verification method and redirect URL are read from the Custom Experience Cloud Setting record matching the component type.
     * When startUrl is supplied (from the login page query string), it takes precedence over the configured Portal Redirect if it is a safe relative or same-site URL.
     * @param formInputs the submitted form values as a JSON string, including the identifier and the code entered by the user.
     * @param componentName the Type__c of the settings record to load i.e. 'Login' or 'Self Registration'.
     * @param startUrl optional relative or same-site URL from the Experience Cloud startURL query parameter.
     * @return a JSON string containing the URL to redirect the verified user to.
     * NOTE: Not covered in Apex tests due to limitation on User Management class in test context. This method is mocked instead.
     */
    @AuraEnabled
    public static String verifyUser(String formInputs, String componentName, String startUrl) {
        
        String url;
        Auth.VerificationResult res;
        
        Map<String, Object> lwcSettings = getComponentSettings(componentName);
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        Auth.VerificationMethod method = methods.get(convertToString(lwcSettings.get('passwordlessMethod')));
        String resolvedStartUrl = resolveStartUrl(startUrl, convertToString(lwcSettings.get('portalRedirect')));
        String identifier = convertToString(formJson.get('identifier'));
        String code = convertToString(formJson.get('verificationCode'));
        String mobilePhone;
        String username = String.isNotBlank(convertToString(formJson.get('Username'))) ? convertToString(formJson.get('Username')) : convertToString(formJson.get('Email'));
        
        //Do this to ensure the country code is formatted correctly. The value is stored as a string in the format "countryCode_Country" because codes are shared in some countries e.g. Canada/United States which should show as separate options, but give weird behaviour in picklists if the value is the same.
        String countryCode = extractCountryCode(formJson.get('countryCode'));
        if(String.isNotBlank(countryCode)) {
            mobilePhone = UserManagement.formatPhoneNumber(countryCode, convertToString(formJson.get('MobilePhone'))); //Format the phone number with the user management class otherwise user isn't found!!
        }
        
        // Variables to track IDs for logging
        Id accountIdForLogging = null;
        Id userIdForLogging = null;
        Id contactIdForLogging = null;
        
        if(componentName == SELF_REG_COMPONENT_NAME) {
            res = UserManagement.verifySelfRegistration(method, identifier, code, resolvedStartUrl);
            
            // Populate logging IDs for successful self-registration verification
            List<User> registeredUsers = getUserIdWithUsername(username, mobilePhone);
            if(!registeredUsers.isEmpty()) {
                userIdForLogging = registeredUsers[0].Id;
                if(registeredUsers[0].ContactId != null) {
                    contactIdForLogging = registeredUsers[0].ContactId;
                    accountIdForLogging = registeredUsers[0].Contact != null ? registeredUsers[0].Contact.AccountId : null;
                }
            }
        } else {
            List<User> user = getUserIdWithUsername(username, mobilePhone);
            if(!user.isEmpty()) {
                userIdForLogging = user[0].Id;
                if(user[0].ContactId != null) {
                    contactIdForLogging = user[0].ContactId;
                    accountIdForLogging = user[0].Contact != null ? user[0].Contact.AccountId : null;
                }
            }
            res = UserManagement.verifyPasswordlessLogin(user[0].Id, method, identifier, code, resolvedStartUrl);
        }
        
        messages.add('Validating verification code for user. Submitted data: ' + formJson);
        
        if(res.success == false) { 
            messages.add('Unable to validate the verification code. Error was: ' + res.message);    
            createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, componentName, accountIdForLogging, userIdForLogging, contactIdForLogging, SiteUtilities.OUTCOME_VERIFICATION_FAILED);    
            throw new AuraHandledException(convertToString(lwcSettings.get('failedCodeVerificationMessage')));
        }

        System.PageReference page = res.redirect;
        url = page.getUrl();

        Map<String, String> itemsToAdd = new Map<String, String>();
        itemsToAdd.put('registerResult', '{"pageUrl":"' +  url + '","verificationSuccess":'+  res.success + '}');

        messages.add('Verification was successful. Redirecting user to: ' + url);
        createLogEntry(convertToBoolean(lwcSettings.get('loggingEnabled')), String.join(messages,'\n'), SiteUtilities.INFORMATION_LOG_TYPE, componentName, accountIdForLogging, userIdForLogging, contactIdForLogging, SiteUtilities.OUTCOME_VERIFICATION_SUCCESS); 
        return jsonBuilder('registerResult', itemsToAdd);    
    }

    /**
     * @description Wrapper class for Custom Metadata configuration to allow mocking in tests
     * Based on pattern from: https://crsinfosolutions.com/custom-metadata-unit-test/
     */
    @TestVisible
    private class CustomConfigurationWrapper {
        public String fieldType;
        public String fieldName;
        public String fieldLabel;
        public String fieldClass;
        public Decimal minimumValue;
        public String fieldUnderMinimumRangeMessage;
        public Decimal maximumValue;
        public String fieldOverMaximumRangeMessage;
        public Decimal fieldMinLength;
        public String fieldMessageTooShort;
        public Decimal fieldMaxLength;
        public String fieldLabelVariant;
        public String fieldDateStyle;
        public Boolean fieldShowIcon;
        public String fieldIconName;
        public String fieldIconClass;
        public String fieldParentClass;
        public String fieldToggleIconName;
        public String fieldToggleType;
        public Boolean fieldAllowAutoComplete;
        public String fieldMessageTooLong;
        public String fieldPicklistOptions;
        public String fieldPlaceholder;
        public String fieldMessage;
        public String fieldValidationRegex;
        public Boolean fieldRequired;
        public String fieldRequiredMessage;
        public String fieldHelpText;
        public Boolean active;
        public String portalApiName;
        public Decimal displayOrder;

        public CustomConfigurationWrapper(SObject metadata) {
            this.fieldType = (String)metadata.get('Field_Type__c');
            this.fieldName = (String)metadata.get('Field_Name__c');
            this.fieldLabel = (String)metadata.get('Field_Label__c');
            this.fieldClass = (String)metadata.get('Field_Class__c');
            this.minimumValue = (Decimal)metadata.get('Minimum_Value__c');
            this.fieldUnderMinimumRangeMessage = (String)metadata.get('Field_Under_Minimum_Range_Message__c');
            this.maximumValue = (Decimal)metadata.get('Maximum_Value__c');
            this.fieldOverMaximumRangeMessage = (String)metadata.get('Field_Over_Max_Range_Message__c');
            this.fieldMinLength = (Decimal)metadata.get('Field_Min_Length__c');
            this.fieldMessageTooShort = (String)metadata.get('Field_Message_Too_Short__c');
            this.fieldMaxLength = (Decimal)metadata.get('Field_Max_Length__c');
            this.fieldLabelVariant = (String)metadata.get('Field_Label_Variant__c');
            this.fieldDateStyle = (String)metadata.get('Field_Date_Style__c');
            this.fieldShowIcon = (Boolean)metadata.get('Field_Show_Icon__c');
            this.fieldIconName = (String)metadata.get('Field_Icon_Name__c');
            this.fieldIconClass = (String)metadata.get('Field_Icon_Class__c');
            this.fieldParentClass = (String)metadata.get('Field_Parent_Class__c');
            this.fieldToggleIconName = (String)metadata.get('Field_Toggle_Icon_Name__c');
            this.fieldToggleType = (String)metadata.get('Field_Toggle_Type__c');
            this.fieldAllowAutoComplete = (Boolean)metadata.get('Field_Allow_Auto_Complete__c');
            this.fieldMessageTooLong = (String)metadata.get('Field_Message_Too_Long__c');
            this.fieldPicklistOptions = (String)metadata.get('Field_Picklist_Options__c');
            this.fieldPlaceholder = (String)metadata.get('Field_Placeholder__c');
            this.fieldMessage = (String)metadata.get('Field_Message__c');
            this.fieldValidationRegex = (String)metadata.get('Field_Validation_REGEX__c');
            this.fieldRequired = (Boolean)metadata.get('Field_Required__c');
            this.fieldRequiredMessage = (String)metadata.get('Field_Required_Message__c');
            this.fieldHelpText = (String)metadata.get('Field_Help_Text__c');
            this.active = (Boolean)metadata.get('Active__c');
            this.portalApiName = (String)metadata.get('Portal_API_Name__c');
            this.displayOrder = (Decimal)metadata.get('Display_Order__c');
        }

        // Test-visible constructor for creating mock wrappers in tests
        @TestVisible
        public CustomConfigurationWrapper(
            String fieldType, String fieldName, String fieldLabel, String fieldPlaceholder,
            String fieldMessage, String fieldValidationRegex, Boolean fieldRequired,
            String fieldRequiredMessage, String fieldHelpText, String fieldPicklistOptions) {
            this.fieldType = fieldType;
            this.fieldName = fieldName;
            this.fieldLabel = fieldLabel;
            this.fieldClass = 'test-class';
            this.minimumValue = null;
            this.fieldUnderMinimumRangeMessage = null;
            this.maximumValue = null;
            this.fieldOverMaximumRangeMessage = null;
            this.fieldMinLength = null;
            this.fieldMessageTooShort = null;
            this.fieldMaxLength = null;
            this.fieldLabelVariant = null;
            this.fieldDateStyle = null;
            this.fieldShowIcon = false;
            this.fieldIconName = null;
            this.fieldIconClass = null;
            this.fieldParentClass = null;
            this.fieldToggleIconName = null;
            this.fieldToggleType = null;
            this.fieldAllowAutoComplete = false;
            this.fieldMessageTooLong = null;
            this.fieldPicklistOptions = fieldPicklistOptions;
            this.fieldPlaceholder = fieldPlaceholder;
            this.fieldMessage = fieldMessage;
            this.fieldValidationRegex = fieldValidationRegex;
            this.fieldRequired = fieldRequired;
            this.fieldRequiredMessage = fieldRequiredMessage;
            this.fieldHelpText = fieldHelpText;
            this.active = true;
            this.portalApiName = 'ALL';
            this.displayOrder = 1;
        }
    }
}