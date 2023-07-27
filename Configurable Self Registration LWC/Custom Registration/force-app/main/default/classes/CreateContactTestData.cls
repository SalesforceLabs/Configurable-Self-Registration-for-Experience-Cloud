/**
 * @description Simple class to create some test accounts/contacts for testing LWC. Not used in main solution. 
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
**/
public with sharing class CreateContactTestData {
    
    public static List<Contact> newContacts = new List<Contact>();
    public static List<Account> newAccs = new List<Account>();

    /**
     * @description create am Account with a specified number of Contacts related. Email is hardcoded as this is used  for test purposes only.
     * @param  noOfContacts specify the number of contacts to create against an account
     * @param  newAccountName specify the new account name to use
     */
    public static void createContactsWithAccount(Integer noOfContacts, String newAccountName) {
       
        Account newAcc = new Account();
        newAcc.Name = newAccountName;
        insert newAcc;
       
        for(Integer i = 1; i <= noOfContacts; i++) {
            Contact newContact = new Contact();
            newContact.FirstName = 'Test';
            newContact.LastName = 'Contact ' + i;
            newContact.AccountId = newAcc.Id; 
            newContact.Email = 'jamie.lowe+test' + i + '@salesforce.com';
            newContacts.add(newContact);
        }
        
        if(newContacts.size() > 0) {
            insert newContacts;
        }
    }

    /**
     * @description create the specified number of Person Accounts with the given name. Record Type Id/Email is hardcoded as this is used  for test purposes only.
     * @param  noOfAccounts number of accounts to create
     * @param  newAccountName name of the new accounts which is appended with the loop index number
     */
    public static void createPersonAccount(Integer noOfAccounts, String newAccountName) {
      
        for(Integer i = 1; i <= noOfAccounts; i++) {
            Account newAccount = new Account();
            newAccount.LastName = newAccountName + ' ' + i;
            newAccount.RecordTypeId = '012Ho000000UCdfIAG';
            newAccount.PersonEmail = 'jamie.lowe+personacctest' + i + '@salesforce.com';
            newAccs.add(newAccount);
        }
        
        if(newAccs.size() > 0) {
            insert newAccs;
        }
    }
}