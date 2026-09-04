/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce). Feedback/Collabration with Mike Cleaver (Github:Mike-Cleaver-LB)
 * CREATE DATE    : 05/02/2024
 * LAST MODIFIED  : 28/08/2026 - Added Outcome to Experience Cloud logging for reportable login results.
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud
 ***************************************************************************************************************/
public with sharing class SiteLoginController {

    /**
     * @description Custom Exception method. Thrown to force an error when user is not found, and get the Login History. Also called in a test class.
     */
    public class CustomLoginException extends Exception{}
    
    /**
     * @description Attempts to login the user. Redirects to the startURL query parameter when present and safe, otherwise the configured Portal Redirect.
     * Behaviour comes from the Custom Experience Cloud Setting record with a Type of 'Login' so the guest user cannot influence it.
     * @param formInputs - JSON String of the submitted login form values.
     * @param startUrl - optional relative or same-site URL from the Experience Cloud startURL query parameter.
     * @return String JSON of the login result to redirect to upon successful login.
     */
    @AuraEnabled(cacheable=true)
    public static String loginUser(String formInputs, String startUrl) {
        String pageUrl = null;

        Map<String, Object> settings = SiteUtilities.getComponentSettings(SiteUtilities.LOGIN_COMPONENT_NAME);
        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        String username = String.isNotBlank(SiteUtilities.convertToString(formJson.get('Username'))) ? SiteUtilities.convertToString(formJson.get('Username')) : SiteUtilities.convertToString(formJson.get('Email'));
        String password = String.isNotBlank(SiteUtilities.convertToString(formJson.get('password'))) ? SiteUtilities.convertToString(formJson.get('password')) : '';
        
        String countryCode = SiteUtilities.extractCountryCode(formJson.get('countryCode'));
        String mobilePhone = String.isNotBlank(SiteUtilities.convertToString(formJson.get('MobilePhone'))) && String.isNotBlank(countryCode) ? UserManagement.formatPhoneNumber(countryCode, SiteUtilities.convertToString(formJson.get('MobilePhone'))) : ''; //Format the phone number with the user management class otherwise user isn't found!!;
        
        String identifier = '';
        Boolean showVerificationCode = false;
        
        // Variables to track IDs for logging
        Id accountIdForLogging = null;
        Id userIdForLogging = null;
        Id contactIdForLogging = null;

        try {

            if(SiteUtilities.convertToBoolean(settings.get('enablePasswordlessLogin')) ) {
                Auth.VerificationMethod method = SiteUtilities.methods.get(SiteUtilities.convertToString(settings.get('passwordlessMethod')));
                SiteUtilities.messages.add('Looking for existing user: ' + formJson);
                List<User> user = SiteUtilities.getUserIdWithUsername(username, mobilePhone);
                
                //Only send a code if the user is NOT found!
                if(user.isEmpty()) {
                    SiteUtilities.messages.add('Error sending verification code via ' + SiteUtilities.convertToString(settings.get('passwordlessMethod'))  + ' to User: '+ formJson +' . User not found.');
                    throw new CustomLoginException('Your login attempt has failed. Make sure the username and password are correct.');
                }
                
                // Extract IDs for logging
                userIdForLogging = user[0].Id;
                if(user[0].ContactId != null) {
                    contactIdForLogging = user[0].ContactId;
                    accountIdForLogging = user[0].Contact != null ? user[0].Contact.AccountId : null;
                }
                
                SiteUtilities.messages.add('Sending verification code via ' + SiteUtilities.convertToString(settings.get('passwordlessMethod'))  + ' to User: ' + formJson);
                identifier = SiteUtilities.sendVerificationCode(method, user[0], SiteUtilities.LOGIN_COMPONENT_NAME);                
                showVerificationCode = true;
            }
            else {
                // Get user info for logging before login attempt
                List<User> userList = SiteUtilities.getUserIdWithUsername(username, mobilePhone);
                if(!userList.isEmpty()) {
                    userIdForLogging = userList[0].Id;
                    if(userList[0].ContactId != null) {
                        contactIdForLogging = userList[0].ContactId;
                        accountIdForLogging = userList[0].Contact != null ? userList[0].Contact.AccountId : null;
                    }
                }
                
                String resolvedStartUrl = SiteUtilities.buildLoginStartUrl(startUrl, SiteUtilities.convertToString(settings.get('portalRedirect')));
                ApexPages.PageReference startPageRef = Site.login(username, password, resolvedStartUrl);

                //If we are running in a Test, check the test user and throw a custom exception to mimic failed logins.
                //NOTE: Cannot reference the constants from the test class in a 'switch' statement.
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
        } catch (Exception e) {

            String status = 'Username Not Found';

            //Login failed throws back a generic error. Go to the login history to get the full story to present back to the user.
            if(e.getMessage() == 'Your login attempt has failed. Make sure the username and password are correct.') {
               
               //Run in elevated permissions without sharing in a separate class to protect from the guest user as much as possible.
               List<User> u = SiteUtilities.getUserIdWithUsername(username, mobilePhone);

               if(u.size() == 1) {
                    status = SiteUtilities.getLoginHistory(u[0].Id);
               }

               //If we are running in a Test, check the test user and return a hardcoded status to mimic login history as Site.login() doesn't actually login.
               //NOTE: Cannot reference the constants from the test class in a 'switch' statement.
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
               String error = '';
               String outcome = SiteUtilities.OUTCOME_LOGIN_FAILED;
               switch on status { 
                    when 'User is Frozen' {
                         error = SiteUtilities.convertToString(settings.get('blockUserErrorMessage'));
                         outcome = SiteUtilities.OUTCOME_USER_FROZEN;
                    }
                    when 'Invalid Password' {
                        error = SiteUtilities.convertToString(settings.get('incorrectUserCredentialsErrorMessage'));
                        outcome = SiteUtilities.OUTCOME_INVALID_PASSWORD;
                    }
                    when 'Username Not Found' {
                        error = SiteUtilities.convertToString(settings.get('incorrectUserCredentialsErrorMessage'));
                        outcome = SiteUtilities.OUTCOME_USERNAME_NOT_FOUND;
                    }
                    when 'Password Lockout' {
                        error = SiteUtilities.convertToString(settings.get('userLockedOutErrorMessage'));
                        outcome = SiteUtilities.OUTCOME_PASSWORD_LOCKOUT;
                    }
                    when else {
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(settings.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging, SiteUtilities.OUTCOME_LOGIN_FAILED); 
                        throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
                    }
                }               
                SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(settings.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging, outcome);
                throw new AuraHandledException(error); 
            }
            SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(settings.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging, SiteUtilities.OUTCOME_LOGIN_FAILED);        
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        String successOutcome = showVerificationCode ? SiteUtilities.OUTCOME_VERIFICATION_SENT : SiteUtilities.OUTCOME_LOGIN_SUCCESS;
        SiteUtilities.messages.add(username + ' successfully logged into the portal.');
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(settings.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.INFORMATION_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging, successOutcome);     

        Map<String, String> itemsToAdd = new Map<String, String>();
        itemsToAdd.put('loginResult', '{"pageUrl":"' + pageUrl + '","showVerificationCode":' + SiteUtilities.convertToString(showVerificationCode) + ',"verificationId":"' + identifier + '"}');
        return SiteUtilities.jsonBuilder('loginResult', itemsToAdd);
    }
}