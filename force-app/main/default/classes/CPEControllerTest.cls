/*
 * This test class covers the Apex methods used to populate picklists in the Exp Cloud builder property sheet for the various Custom Property Editors used for the Self Registration and Login components.
 */
@isTest
private class CPEControllerTest {

    private static Boolean isPersonAccountEnabled() {
        return Schema.sObjectType.Account.fields.getMap().containsKey('isPersonAccount');
    }

    @isTest
    static void getPersonAccountRecordTypeTest() {
        String jsonResult = SiteUtilities.getPersonAccountRecordTypes('Account');
        Map<String, Object> rts = (Map<String, Object>) JSON.deserializeUntyped(jsonResult); 
        List<Object> dataObj = (List<Object>) rts.get('recordTypes');
        
        if (isPersonAccountEnabled()) {
             System.assert(dataObj.size() > 0, 'Person Account Org should have at least one Account Record Type');
        }

        if (dataObj.size() > 0) {
            Map<String, Object> data = (Map<String, Object>) dataObj[0];
            System.Assert.isTrue(data.values().size() > 1, 'Record Type JSON structure should contain label and value'); 
        }
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

        String siteId;

        //Unable to mock getting the siteId in a test.
        //See: https://ideas.salesforce.com/s/idea/a0B8W00000Gdb7wUAB/allow-defining-a-network-id-in-test-classes
        //Get an Active site, and use that Id to test. Assuming an active site has Network Members.
        //Another approach if needed: https://salesforce.stackexchange.com/questions/421015/issue-with-obtaining-networkid-in-test-class-for-community-user
        try {
            List<Site> sites = [SELECT Id,Name FROM Site WHERE Status = 'Active' LIMIT 1];
            if (!sites.isEmpty()) {
                siteId = sites[0].Id;
                String jsonResult = SiteUtilities.getProfileMembers(siteId);
                Map<String, Object> rts = (Map<String, Object>) JSON.deserializeUntyped(jsonResult); 
                List<Object> dataObj = (List<Object>) rts.get('memberProfiles');
                
                if (dataObj.size() > 0) {
                     Map<String, Object> data = (Map<String, Object>) dataObj[0];
                     Integer size = data.values().size();    
                     System.assert(size > 0, 'Member profiles found.');
                }
            }
        }
        catch (Exception e) {
            System.assertEquals(siteId, null, 'Exception occurred: ' + e.getMessage());
        }
    }
}