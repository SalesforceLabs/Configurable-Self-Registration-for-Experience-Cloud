/**
 * @description       : Used to create test data for contacts & accounts 
 * @author            : Jamie Lowe - jamielowe1990/jlowesfdc
 * @group             : 
 * @last modified on  : 21-07-2023
 * @last modified by  : Jamie Lowe - jamielowe1990/jlowesfdc
**/
public with sharing class createContact {
    
    public static List<Contact> newContacts = new List<Contact>();

    public static void createContacts(Integer noOfAccounts,Integer noOfContacts, String newAccountName) {
       
        Account newAcc = new Account();
        newAcc.Name = newAccountName;
        insert newAcc;

        System.debug('New Account Id: ' + newAcc.Id);
       
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
}