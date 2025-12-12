/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce). Feedback/Collabration with Mike Cleaver (Github:Mike-Cleaver-LB)
 * CREATE DATE    : 05/02/2024
 * LAST MODIFIED  : 12/12/2025 - v1.9.1
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud
 ***************************************************************************************************************/
public with sharing class SiteLoginController {

    /**
     * @description Custom Exception method. Thrown to force an error when user is not found, and get the Login History. Also called in a test class.
     */
    public class CustomLoginException extends Exception{}
    
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
        String password = String.isNotBlank(SiteUtilities.convertToString(formJson.get('password'))) ? SiteUtilities.convertToString(formJson.get('password')) : '';
        
        String countryCode = SiteUtilities.extractCountryCode(formJson.get('countryCode'));
        String mobilePhone = String.isNotBlank(SiteUtilities.convertToString(formJson.get('MobilePhone'))) && String.isNotBlank(countryCode) ? UserManagement.formatPhoneNumber(countryCode, SiteUtilities.convertToString(formJson.get('MobilePhone'))) : ''; //Format the phone number with the user management class otherwise user isn't found!!;
        
        String identifier;
        Boolean showVerificationCode = false;
        String result = '';
        String jsonPart = '{"loginResult":[';
        
        // Variables to track IDs for logging
        Id accountIdForLogging = null;
        Id userIdForLogging = null;
        Id contactIdForLogging = null;

        try {

            if(SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin')) ) {
                Auth.VerificationMethod method = SiteUtilities.methods.get(SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod')));
                SiteUtilities.messages.add('Looking for existing user: ' + formJson);
                List<User> user = SiteUtilities.getUserIdWithUsername(username, mobilePhone);
                
                //Only send a code if the user is NOT found!
                if(user.isEmpty()) {
                    SiteUtilities.messages.add('Error sending verification code via ' + SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod'))  + ' to User: '+ formJson +' . User not found.');
                    throw new CustomLoginException('Your login attempt has failed. Make sure the username and password are correct.');
                }
                
                // Extract IDs for logging
                userIdForLogging = user[0].Id;
                if(user[0].ContactId != null) {
                    contactIdForLogging = user[0].ContactId;
                    accountIdForLogging = user[0].Contact != null ? user[0].Contact.AccountId : null;
                }
                
                SiteUtilities.messages.add('Sending verification code via ' + SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod'))  + ' to User: ' + formJson);
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
                
                ApexPages.PageReference homePageRef = new PageReference(Site.getBaseSecureUrl() + SiteUtilities.convertToString(configurationOptions.get('portalLoginRedirect')));
                String startUrl = homePageRef.getUrl();
                ApexPages.PageReference startPageRef = Site.login(username, password, startUrl);

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

            jsonPart += '{';
            jsonPart += '"pageUrl":"' + pageUrl + '",';
            jsonPart += '"showVerificationCode":' + showVerificationCode + ',';
            jsonPart += '"verificationId":"' + identifier + '"}]}';
            result += jsonPart;
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
               switch on status { 
                    when 'User is Frozen' {
                         error = SiteUtilities.convertToString(configurationOptions.get('blockUserErrorMessage'));
                    }
                    when 'Invalid Password', 'Username Not Found' {
                        error = SiteUtilities.convertToString(configurationOptions.get('incorrectUserCredentialsErrorMessage'));
                    }
                    when 'Password Lockout' {
                        error = SiteUtilities.convertToString(configurationOptions.get('userLockedOutErrorMessage'));
                    }
                    when else {
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging); 
                        throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
                    }
                }               
                SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging);
                throw new AuraHandledException(error); 
            }
            SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.ERROR_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging);        
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        SiteUtilities.messages.add(username + ' successfully logged into the portal.');
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), SiteUtilities.INFORMATION_LOG_TYPE, SiteUtilities.LOGIN_COMPONENT_NAME, accountIdForLogging, userIdForLogging, contactIdForLogging);     
        return result;
    }
}