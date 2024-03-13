/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/02/2024
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud.
 * Runs in 'without sharing' to retrieve users/login history not accessible to the guest user
 ***************************************************************************************************************/

public without sharing class RetrieveLoginHistory {
    
    /**
     * @description getUserIdWithUsername retrieve the user id for a given username, allowing a filter on login History to understand if there were issues logging in.
     * @param  username pass the username from the from as a string
     * @return either the Login History Status or "Username not found" as a String if user doesn't exist
     */
    public static String getUserIdWithUsername(String username) {
        List<User> userId = [SELECT Id,Name, Email FROM User WHERE Username = :username];

        if(!userId.isEmpty()) {
            return getLoginHistory(userId[0].Id);
        }        
        return 'Username Not Found'; //Custom to handle the username not found.
    }

    /**
     * @description getLoginHistory retrieves exactly 1 entry from the LoginHistory for the specified UserId sorted by DESC i.e. the most recent. NOTE: Cannot filter by Username directly.
     * @param userId pass in the User Id from getUserIdWithUsername() result. 
     * @return returns the Login History status field.
     */
    public static String getLoginHistory(String userId) {
        
        List<LoginHistory> history = [SELECT Id, UserId, LoginTime, Status FROM LoginHistory WHERE UserId = :userId ORDER BY LoginTime DESC LIMIT 1];
        
        if(history.size() == 1) {
            return history[0].Status;
        }
        return null;
    }
}