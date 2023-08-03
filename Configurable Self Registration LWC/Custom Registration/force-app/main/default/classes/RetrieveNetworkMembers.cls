/**
 * @description A simple class to retrieve network members using without sharing. This class is called from the SiteRegistrationController where with sharing has been enforced.
 * It runs as the guest user which cannot have access to query this table which causes errors with the component.
 * @author: Jamie Lowe
 */
public without sharing class RetrieveNetworkMembers {
    
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
}