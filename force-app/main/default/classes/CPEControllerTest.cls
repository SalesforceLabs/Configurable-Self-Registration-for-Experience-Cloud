/*****************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/05/2023
 * PURPOSE        : Tests for SiteUtilities helpers used by configuration UIs (record types and SMS licence).
 *****************************************************************************************************/
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
}
