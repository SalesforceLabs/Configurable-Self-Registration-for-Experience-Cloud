/**
 * @description retrieves PersonAccount Record Type Ids to populate a picklist on the Self Registration LWC
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
 */ 
global with sharing class RetrievePersonAccountRecordTypes extends VisualEditor.DynamicPickList {

    global VisualEditor.DynamicPickListRows myValues = new VisualEditor.DynamicPickListRows();

    /**
     * @description implemented as per: https://developer.salesforce.com/docs/atlas.en-us.lightning.meta/lightning/components_config_for_app_builder_dynamic_picklists.htm to remove potential performance degradation issues
     * @param  attr NOT USED
     * @return Boolean
     */
    public boolean isValid(Boolean attr) {
        return true;
    }

    /**
     * @description - sets the default value of the picklist
     * @return always returns null as no default is required
    */
    global override VisualEditor.DataRow getDefaultValue(){
        VisualEditor.DataRow defaultValue = null;
        return defaultValue;
    }

    /**
     * @description - retrieve Record Types for Accounts to build dynamic picklist LWC component configuration panel 
     * @return returns picklist values to populate LWC custom component picklist
     */
    global override VisualEditor.DynamicPickListRows getValues() {
    
        List<RecordType> rt = new List<RecordType>([SELECT Id,Name,SobjectType,IsActive FROM RecordType WHERE SobjectType = 'Account' AND IsActive = true WITH SECURITY_ENFORCED]);

        for (RecordType r : rt) {
            VisualEditor.DataRow value = new VisualEditor.DataRow(r.Name, String.valueOf(r.Id));
            myValues.addRow(value);
        }
        return myValues;
    }
}