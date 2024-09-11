/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/02/2024
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud
 ***************************************************************************************************************/
public with sharing class SiteLoginController {
    public static List<String> messages = new List<String>();
    public static final String COMPONENT_NAME = 'Login';
    public static String siteName = Site.getName();
    public static Map<String, Auth.VerificationMethod> methods = new Map<String, Auth.VerificationMethod>{'Email' => Auth.VerificationMethod.EMAIL, 'SMS' => Auth.VerificationMethod.SMS};

    /**
     * @description Custom Exception method. This is only thrown by the test class to force an error for test coverage as the Login History is not accessible.
     */
    public class CustomLoginException extends Exception{}
    
    /**
     * @description Retrieve Custom Metadata Types which contain custom field configuration for the Self Registration form. 
     * @param urlParams a JSON string of URL params that were appended to the page.
     * @return Returns a JSON string of retrieved records
     * @see customSelfRegistration.html
     */
    @AuraEnabled(cacheable=true)
    public static String getCustomConfiguration(String urlParams) {
        String result = '';
        Map<String, Object> urlParameters = (Map<String, Object>) JSON.deserializeUntyped(urlParams);

        try {
            for (Custom_Login_Configuration__mdt mapping : [SELECT Id, Field_Name__c, Field_Type__c, Field_Label__c, Field_Message__c, Field_Help_Text__c, Field_Validation_REGEX__c, 
                    Field_Min_Length__c, Field_Max_Length__c, Field_Required__c, Field_Placeholder__c, 
                    Field_Required_Message__c, Portal_API_Name__c, Display_Order__c, Field_Class__c, Field_Message_Too_Short__c, Field_Message_Too_Long__c,
                    Minimum_Value__c, Maximum_Value__c, Field_Under_Minimum_Range_Message__c, Field_Over_Max_Range_Message__c, Field_Show_Icon__c, Field_Icon_Name__c, 
                    Field_Icon_Class__c, Field_Parent_Class__c, Field_Show_Password_Visibility__c, Field_Label_Variant__c, Field_Date_Style__c, Field_Picklist_Options__c 
                                    FROM Custom_Login_Configuration__mdt 
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
                jsonPart += '"fieldLabelVariant":"' + mapping.Field_Label_Variant__c + '",';
                jsonPart += '"fieldDateStyle":"' + mapping.Field_Date_Style__c + '",';
                
                //Settings to control icon visibility
                jsonPart += '"fieldShowIcon":' + SiteUtilities.convertToBoolean(mapping.Field_Show_Icon__c) + ','; //Needs to be a boolean as it directly controls dynamic template
                jsonPart += '"fieldIconName":"' + mapping.Field_Icon_Name__c + '",';
                jsonPart += '"fieldIconClass":"' + mapping.Field_Icon_Class__c + '",';
                jsonPart += '"fieldParentClass":"' + mapping.Field_Parent_Class__c + '",';
                
                jsonPart += '"fieldShowPasswordVisibility":' + SiteUtilities.convertToBoolean(mapping.Field_Show_Password_Visibility__c) + ',';

                //NOTE: Odd behaviour of this property... See Usage Considerations: https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation
                //https://salesforce.stackexchange.com/questions/348093/lwc-lightning-input-custom-validation-for-max-length-no-error-message-comes-on
                jsonPart += '"fieldMaxLengthMessage":"' + mapping.Field_Message_Too_Long__c + '"'; 
                
                for(String key : urlParameters.keySet()) {
                    if(mapping.Field_Name__c == key) {
                        jsonPart += ',';
                        if(SiteUtilities.convertToBoolean(urlParameters.get(key))) {
                            jsonPart += '"fieldChecked":"' + urlParameters.get(key) + '"';
                        }
                        else {
                            jsonPart += '"fieldValue":"' + urlParameters.get(key) + '"';
                        }
                    }
                }

                if(mapping.Field_Type__c == 'picklist') {
                    jsonPart += ',';
                    jsonPart += '"showAsPicklist":' + true + ',';
                    jsonPart += '"picklistOptions":' + mapping.Field_Picklist_Options__c  + ''; 
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
            throw new AuraHandledException('There was an issue displaying custom metadata. Please check the configuration and try again.');
        }
        return '['+result+']';
    }

    /**
     * @description verifyUser description
     * @param  formInputs           formInputs description
     * @param  configurationOptions configurationOptions description
     * @return                      return description
     */
    @AuraEnabled
    public static String verifyUser(String formInputs, String configurationOptions) {
        Map<String, Object> lwcSettings = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        String startURL = Site.getBaseSecureUrl() + SiteUtilities.convertToString(formJson.get('portalRegistrationRedirect'));
        Auth.VerificationMethod method = methods.get(SiteUtilities.convertToString(lwcSettings.get('passwordlessMethod')));
        String username = String.isNotBlank(SiteUtilities.convertToString(formJson.get('Username'))) ? SiteUtilities.convertToString(formJson.get('Username')) : SiteUtilities.convertToString(formJson.get('Email'));
        String password = SiteUtilities.convertToString(formJson.get('password'));
        String mobilePhone = SiteUtilities.convertToString(formJson.get('MobilePhone'));
        User user = SiteUtilities.getUser(username, mobilePhone);
        return SiteUtilities.verifyCode(method, SiteUtilities.convertToString(formJson.get('identifier')), SiteUtilities.convertToString(formJson.get('verificationCode')), startUrl, lwcSettings, formJson, COMPONENT_NAME, user);  
    }

    /**
     * @description Attempts to login the newly registered user. Redirects to the home page on success.
     * @param username - Passes in the submitted username field from the self registration form.
     * @param password - Passes in the submitted password field from the self registration form. 
     * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
     * @return String PageURL to redirect to upon successful login.
     */
    @AuraEnabled(cacheable=true)
    public static String loginUser(String formInputs, Map<String, Object> configurationOptions) {
        String pageUrl = null;

        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        String username = String.isNotBlank(SiteUtilities.convertToString(formJson.get('Username'))) ? SiteUtilities.convertToString(formJson.get('Username')) : SiteUtilities.convertToString(formJson.get('Email'));
        String password = SiteUtilities.convertToString(formJson.get('password'));
        String mobilePhone = SiteUtilities.convertToString(formJson.get('MobilePhone'));
        String identifier;
        Boolean showVerificationCode = false;
        String result = '';
        String jsonPart = '{"loginResult":[';

        try {

            if(SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin')) ) {
                Auth.VerificationMethod method = methods.get(SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod')));
                messages.add('Looking for existing user: ' + formJson);
                User user = SiteUtilities.getUser(username, mobilePhone); //TODO: Needs error handling.
                messages.add('Sending verification code via ' + SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod'))  + ' to User: ' + user);
                identifier = SiteUtilities.sendVerificationCode(method, user, COMPONENT_NAME);                
                showVerificationCode = true;
            }
            else {
                ApexPages.PageReference homePageRef = new PageReference(Site.getBaseSecureUrl() + SiteUtilities.convertToString(configurationOptions.get('portalLoginRedirect')));
                String startUrl = homePageRef.getUrl();
                ApexPages.PageReference startPageRef = Site.login(username, password, startUrl);

                //If we are running in a Test, check the test user and throw a custom exception to mimic failed logins.
                if(Test.isRunningTest()) {
                    switch on username {
                        when 'testusergenericfail@mail.com' {
                            throw new CustomLoginException('Unknown error.'); 
                        }
                        when 'testusersuccessful@mail.com' {
                            //Don't throw an exception.
                        }
                        when else {
                            throw new CustomLoginException('Your login attempt has failed. Make sure the username and password are correct.');
                        }
                    }
                }

                if(startPageRef != null) {
                    pageUrl = startPageRef.getUrl();
                } else {
                    ApexPages.PageReference pageRef = new PageReference(Site.getBaseSecureUrl());
                    pageUrl = pageRef.getUrl();
                }
            }

            jsonPart += '{';
            jsonPart += '"pageUrl":"' + pageUrl + '",';
            jsonPart += '"showVerificationCode":' + showVerificationCode + ',';
            jsonPart += '"verificationId":"' + identifier + '"}]}';
            result += jsonPart;
        } catch (Exception e) {

            //Login failed throws back a generic error. Go to the login history to get the full story to present back to the user.
            if(e.getMessage() == 'Your login attempt has failed. Make sure the username and password are correct.') {
               
               //Run in elevated permissions without sharing in a separate class to protect from the guest user as much as possible.
               String status = SiteUtilities.getUserIdWithUsername(username);

               //If we are running in a Test, check the test user and return a hardcoded status to mimic login history as Site.login() doesn't actually login.
               if(Test.isRunningTest()) {
                    switch on username {
                        when 'testuserblocked@mail.com' {
                            status = 'User is Frozen';
                        }
                        when 'testuserinvalidpassword@mail.com' {
                            status = 'Invalid Password';
                        }
                        when 'testusernotexist@mail.com' {
                            status = 'Username Not Found';
                        }   
                        when 'testuserlocked@mail.com' {
                            status = 'Password Lockout';
                        }
                        when else { //testuserother@mail.com
                            status = '';
                        }
                    }
                }

               //TODO: Handle more types of Login History Status if needed... https://stackoverflow.com/questions/11581806/is-it-possible-to-check-if-a-user-is-locked-out
               switch on status { 
                    when 'User is Frozen' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('blockUserErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME); 
                        throw new AuraHandledException(error);
                    }
                    when 'Invalid Password', 'Username Not Found' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('incorrectUserCredentialsErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);
                        throw new AuraHandledException(error); 
                    }
                    when 'Password Lockout' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('userLockedOutErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);
                        throw new AuraHandledException(error);  
                    }
                    when else {
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME); 
                        throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
                    }
               }               
            }
            messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);        
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        messages.add(username + ' successfully logged into the portal.');
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Information', COMPONENT_NAME);     
        return result;
    }
}