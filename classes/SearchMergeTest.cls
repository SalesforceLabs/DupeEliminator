/**
 * This class contains unit tests for validating the behavior of Apex classes
 * and triggers.
 *
 * Unit tests are class methods that verify whether a particular piece
 * of code is working properly. Unit test methods take no arguments,
 * commit no data to the database, and are flagged with the testMethod
 * keyword in the method definition.
 *
 * All test methods in an organization are executed whenever Apex code is deployed
 * to a production organization to confirm correctness, ensure code
 * coverage, and prevent regressions. All Apex classes are
 * required to have at least 75% code coverage in order to be deployed
 * to a production organization. In addition, all triggers must have some code coverage.
 *
 * The @isTest class annotation indicates this class only contains test
 * methods. Classes defined with the @isTest annotation do not count against
 * the organization size limit for all Apex scripts.
 *
 * See the Apex Language Reference for more information about Testing and Code Coverage.
 */
@isTest
private class SearchMergeTest {

    public static testMethod void testSearchMerge() {

        // Create records for testing
        long now = System.currentTimeMillis();
        List<Account> accs = new List<Account>();
        accs.add(new Account(Name='master_'+now, Phone='123', Type='Prospect', AnnualRevenue=100000, NumberOfEmployees=1000));
        accs.add(new Account(Name='slave1_'+now, Phone='456', Type='Prospect', AnnualRevenue=200000, NumberOfEmployees=2000));
        accs.add(new Account(Name='slave2_'+now, Phone='789', Type='Prospect', AnnualRevenue=300000, NumberOfEmployees=3000));
        insert(accs);

        List<Contact> cons = new List<Contact>();
        List<Note> notes = new List<Note>();
        for (Account acc : accs) {
            cons.add(new Contact(LastName=acc.name, FirstName='contact', accountId=acc.Id));
            notes.add(new Note(title=acc.name+' note', parentId=acc.Id ));
        }
        insert(cons);

        // Use the PageReference Apex class to instantiate a page
        PageReference pageRef = Page.SearchMerge;

        // The Visualforce page named 'SearchMerge' is the starting point of this test method.
        Test.setCurrentPage(pageRef);

        // Add parameters to page URL
        Map<String, String> params = ApexPages.currentPage().getParameters();
        params.put('debug', 'true');
        params.put('showQuery', 'true');
        params.put('hideFilter', 'false');
        params.put('hideHeader', 'false');
        params.put('hideSidebar', 'false');
        params.put('find', 'true');
        params.put('object', 'Account');
        params.put('field1', 'Name');
        params.put('field2', 'Phone');
        params.put('field3', 'Type');
        params.put('field4', 'AnnualRevenue');
        params.put('field5', 'CreatedDate');
        params.put('op1', 'contains');
        params.put('op2', 'not equal to');
        params.put('op3', 'equals');
        params.put('op4', 'greater than');
        params.put('op5', 'greater or equals');
        params.put('value1', String.valueOf(now));
        params.put('value2', '');
        params.put('value3', 'Prospect');
        params.put('value4', '1000');
        params.put('value5', DateTime.newInstance(now).format());
        params.put('limit', '10');

        // Instantiate a new controller with all parameters in the page
        SearchMergeController controller = new SearchMergeController();

        // Set searh criteria thru QueryBuilder
        QueryBuilder q = controller.getQueryBuilder();
        /*
        q.objectName = 'Account';
        q.fieldName1 = 'Name';
        q.fieldName2 = 'Phone';
        q.fieldName3 = 'Type';
        q.fieldName4 = 'AnnualRevenue';
        q.fieldName5 = 'NumberOfEmployees';
        q.operatorValue1 = 'contains';
        q.operatorValue2 = 'not equal to';
        q.operatorValue3 = 'equals';
        q.operatorValue4 = 'greater than';
        q.operatorValue5 = 'less than';

        q.inputValue2 = '';
        q.inputValue3 = 'Prospect';
        q.inputValue4 = '1000';
        q.inputValue5 = '10000';
        q.recordLimit = '10';
        */
        q.getObjects();
        q.getFields();
        q.getOperators();
        q.getChildRelationships();
        controller.getFieldLabels();

        System.assertEquals(q.getObjectLabel(), 'Account');
        System.assertEquals(q.getFieldLabel1(), 'Account Name');
        System.assertEquals(q.getFieldLabel2(), 'Account Phone');
        System.assertEquals(q.getFieldLabel3(), 'Account Type');
        System.assertEquals(q.getFieldLabel4(), 'Annual Revenue');
        System.assertEquals(q.getFieldLabel5(), 'Created Date');

        System.assert(controller.getShowQuery());
        System.assert(controller.debug);
        System.assert(!controller.hideFilter);
        System.assert(!controller.hideHeader);
        System.assert(!controller.hideSidebar);

        // Find records to merge
        //controller.find();

        // Select records to merge
        List<DynamicSObject> records = controller.getResults();
        System.assertEquals(3, records.size());
        for (DynamicSObject s : records) {
            s.setSelected(true);
            System.assert(s.getField1().getValue() != null);
            System.assert(s.getField2().getValue() != null);
            System.assert(s.getField3().getValue() != null);
            System.assert(s.getField4().getValue() != null);
            System.assert(s.getField5().getValue() != null);
        }

        // Go to MergeRecord page
        PageReference nextPage = controller.selectMerge();
        // Verify that next() method returns the proper URL.
        System.assertEquals(Page.MergeRecord.getUrl(), nextPage.getUrl());

        controller.previous();
        controller.selectMerge();

        System.assertEquals(accs[0].id, controller.getMergeRecord1().getID());
        System.assertEquals(accs[1].id, controller.getMergeRecord2().getID());
        System.assertEquals(accs[2].id, controller.getMergeRecord3().getID());

        // Check clone non-reparantable child records option
        controller.cloneNonReparentableChild = true;
        controller.showMasterAfterMerge = true;

        List<String> childRelationships = controller.getChildRelationships();
        for (SelectOption s : controller.getChildRelationshipSelection()) {
            childRelationships.add(s.getValue());
        }
        controller.setChildRelationships(childRelationships);

        // Select all fields from 2nd record
        controller.selectedRecord = controller.getMergeRecord2().getID();
        controller.doSelectRecord();

        // Select master record
        controller.selectedRecord = controller.getMergeRecord1().getID();
        controller.selectedField = 'Id';
        controller.doSelectField();

        System.assert(controller.getMergeRecord1().getDisplayID() != null);

        for (DynamicSObject.Field f : controller.getMergeRecord1().getFields()) {
            f.getDisplayValue();
        }

        Test.startTest();

        // Merge records
        PageReference endPage = controller.doMerge();

        Test.stopTest();

        // Verify that doMerge() method returns the proper URL.
        System.assertEquals('/'+accs[0].Id, endPage.getUrl());

        System.assertEquals(null, controller.getError());

        controller.clearChildSelection();
        controller.cancel2();

        // Verify slave accounts are deleted
        List<Account> delAccs = Database.query('Select id, isDeleted from Account where id in (\''+ accs[1].id + '\', \'' + accs[2].id + '\') all rows');
        for (Account a : delAccs) {
            System.assert(a.isDeleted);
        }
    }
}