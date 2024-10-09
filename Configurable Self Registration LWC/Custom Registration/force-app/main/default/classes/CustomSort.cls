public class CustomSort implements Comparator<SObject> {

    public Integer compare(SObject rec1, SObject rec2) {
        
        String rec1DisplayOrder = String.valueOf((rec1.get('Display_Order__c')));
        String rec2DisplayOrder = String.valueOf(rec2.get('Display_Order__c')); 

        if(Integer.valueOf(rec1DisplayOrder) == Integer.valueOf(rec2DisplayOrder)) {
            return 0;
        }
        else if(Integer.valueOf(rec1DisplayOrder) > Integer.valueOf(rec2DisplayOrder)) {
            return 1;
        }
        else if(Integer.valueOf(rec1DisplayOrder) < Integer.valueOf(rec2DisplayOrder)) {
            return -1;
        }
        return 0;
    }
}