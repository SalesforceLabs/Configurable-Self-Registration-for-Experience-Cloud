public class CustomSort implements Comparator<SObject> {

    public Integer compare(SObject rec1, SObject rec2) {
        
        String rec1DisplayOrder = SiteUtilities.convertToString(rec1.get('Display_Order__c'));
        String rec2DisplayOrder = SiteUtilities.convertToString(rec2.get('Display_Order__c')); 

        if(SiteUtilities.convertToInteger(rec1DisplayOrder) == SiteUtilities.convertToInteger(rec2DisplayOrder)) {
            return 0;
        }
        else if(SiteUtilities.convertToInteger(rec1DisplayOrder) > SiteUtilities.convertToInteger(rec2DisplayOrder)) {
            return 1;
        }
        else if(SiteUtilities.convertToInteger(rec1DisplayOrder) < SiteUtilities.convertToInteger(rec2DisplayOrder)) {
            return -1;
        }
        return 0;
    }
}