/*
 * This test class covers the Apex methods used to populate picklists in the Exp Cloud builder property sheet for the various Custom Property Editors used for the Self Registration and Login components.
 */
@isTest
private class CPEControllerTest {

    @isTest
    static void getPersonAccountRecordTypeTest() {
        String jsonResult = SiteUtilities.getPersonAccountRecordTypes('Account');
        Map<String, Object> rts = (Map<String, Object>) JSON.deserializeUntyped(jsonResult); 
        List<Object> dataObj = (List<Object>) rts.get('recordTypes');
        Map<String, Object> data = new Map<String,Object>();
        for (Object item : dataObj) {
            data = (Map<String, Object>) item;
        }
        System.assertEquals(2, data.values().size(), '2 ACTIVE configured record types found as expected'); 
    }

    @isTest
    static void checkSMSLicenceTest() {
        Integer count = SiteUtilities.checkSMSLicence();
        
        if(count == 0) { 
            System.assertEquals(0, count, 'SMS licence is not available in the org.'); 
        }
        else {
            System.assertEquals(1, count, 'SMS licence is available in the org.'); 
        }
    }

    @isTest
    static void getProfileMembersTest() {

        //Unable to mock getting the siteId in a test.
        //See: https://ideas.salesforce.com/s/idea/a0B8W00000Gdb7wUAB/allow-defining-a-network-id-in-test-classes
        //Get an Active site, and use that Id to test. Assuming an active site has Network Members.
        //Another approach if needed: https://salesforce.stackexchange.com/questions/421015/issue-with-obtaining-networkid-in-test-class-for-community-user
        String siteId = [SELECT Id,Name FROM Site WHERE Status = 'Active' LIMIT 1].Id;

        String jsonResult = SiteUtilities.getProfileMembers(siteId);
        Map<String, Object> rts = (Map<String, Object>) JSON.deserializeUntyped(jsonResult); 
        List<Object> dataObj = (List<Object>) rts.get('memberProfiles');
        Map<String, Object> data = new Map<String,Object>();
        
        for (Object item : dataObj) {
            data = (Map<String, Object>) item;
        }

        Integer size = data.values().size();    
        System.assert(size > 0, 'Member profiles found.');  
    }
}