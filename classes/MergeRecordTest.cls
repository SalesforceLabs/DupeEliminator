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
private class MergeRecordTest {

    static {
        MergeRecord.debug = true;
    }

    public static testMethod void testErrorHandling() {
        List<Account> accs = new List<Account>();
        accs.add(new Account(Name='master'));
        accs.add(new Account(Name='slave1'));
        accs.add(new Account(Name='slave2'));
        accs.add(new Account(Name='slave3'));
        insert(accs);
        List<SObject> cons = new List<Contact>();
        cons.add(new Contact(LastName=accs[0].name, FirstName='contact', accountId=accs[0].Id));
        insert(cons);

        try {
            MergeRecord.mergeSObject(new Account[] {accs[0]});
        } catch (Exception e) {
            System.debug(e);
        }

        try {
            MergeRecord.mergeSObject(accs, true);
        } catch (Exception e) {
            System.debug(e);
        }
    }

    public static testMethod void testMergeAccount() {
        List<Account> accs = new List<Account>();
        accs.add(new Account(Name='master'));
        accs.add(new Account(Name='slave1'));
        accs.add(new Account(Name='slave2'));
        insert(accs);
        List<Contact> cons = new List<Contact>();
        List<Note> notes = new List<Note>();
        for (Account a : accs) {
           cons.add(new Contact(LastName=a.name, FirstName='contact', accountId=a.Id));
           notes.add(new Note(Title=a.name, parentId=a.Id));
        }
        insert(cons);
        insert(notes);
        /*
        List<Case> cases = new List<Case>();
        for (Contact c : cons) {
            cases.add(new Case(contactId=c.Id));
        }
        insert(cases);
        */

        SchemaInfo schema = new SchemaInfo();
        schema.getObjects();
        schema.getFields('Account');
        schema.getNameField(Account.sObjectType);
        schema.getChildRelationships(Account.sObjectType);
        schema.getNonReparentableChild(Account.sObjectType);
        schema.getPersonAccFields();

        Test.startTest();
        MergeRecord.mergeSObject(accs, true, new String[] {'Notes'});
        Test.stopTest();
    }

    /*
    public static testMethod void testMergeContact() {
        Account acc1 = new Account(Name='acc1');
        Account acc2 = new Account(Name='acc2');
        insert(new Account[] {acc1, acc2});
        List<Contact> cons = new List<Contact>();
        cons.add(new Contact(LastName=acc1.name, FirstName='contact', accountId=acc1.Id));
        cons.add(new Contact(LastName=acc2.name, FirstName='contact1', accountId=acc2.Id));
        cons.add(new Contact(LastName=acc2.name, FirstName='contact2', accountId=acc2.Id));
        insert(cons);
        List<Case> cases = new List<Case>();
        for (Contact c : cons) {
            cases.add(new Case(contactId=c.Id));
        }
        insert(cases);
        MergeRecord.mergeSObject(cons, true);
    }

    public static testMethod void testMergeOpportunity() {
        Account acc1 = new Account(Name='acc1');
        Account acc2 = new Account(Name='acc2');
        insert(new Account[] {acc1, acc2});
        List<Opportunity> opps = new List<Opportunity>();
        opps.add(new Opportunity(Name=acc1.name + ' opp1', StageName='Open', CloseDate=System.today(), accountId=acc1.Id));
        opps.add(new Opportunity(Name=acc2.name + ' opp1', StageName='Open', CloseDate=System.today(), accountId=acc2.Id));
        opps.add(new Opportunity(Name=acc2.name + ' opp2', StageName='Open', CloseDate=System.today(), accountId=acc2.Id));
        insert(opps);

        Pricebook2 pb = [select Id from Pricebook2 where isStandard=true];
        Product2 prod = new Product2(Name='TestProd', IsActive=true, CanUseQuantitySchedule=true, CanUseRevenueSchedule=true);
        insert(prod);
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id=pb.Id, Product2Id=prod.Id, IsActive=true, UnitPrice=10);
        insert(pbe);

        List<OpportunityLineItem> lineItems = new List<OpportunityLineItem>();
        for (Opportunity o : opps) {
            lineItems.add(new OpportunityLineItem(OpportunityId=o.Id, PriceBookEntryId=pbe.Id, Quantity=1, UnitPrice=10));
        }
        insert(lineItems);
        List<OpportunityLineItemSchedule> schedules = new List<OpportunityLineItemSchedule>();
        for (OpportunityLineItem oli : lineItems) {
            schedules.add(new OpportunityLineItemSchedule(OpportunityLineItemId=oli.Id, Type='Both', Quantity=1.0, Revenue=100.0, ScheduleDate=System.today()));
            schedules.add(new OpportunityLineItemSchedule(OpportunityLineItemId=oli.Id, Type='Both', Quantity=1.0, Revenue=100.0, ScheduleDate=System.today()+1));
        }
        insert(schedules);

        MergeRecord.mergeSObject(opps, true);
    }

    public static testMethod void testMergeCustomObject() {
        Account acc1 = new Account(Name='acc1');
        Account acc2 = new Account(Name='acc2');
        insert(new Account[] {acc1, acc2});
        List<Contact> cons = new List<Contact>();
        cons.add(new Contact(LastName=acc1.name, FirstName='contact1', accountId=acc1.Id));
        cons.add(new Contact(LastName=acc2.name, FirstName='contact2', accountId=acc2.Id));
        insert(cons);

        List<My_Obj__c> objs = new List<My_Obj__c>();
        Integer i = 1;
        for (Contact c : cons) {
            objs.add(new My_Obj__c(name='obj_'+ i++, account__c=c.accountId, contact__c=c.Id));
        }
        insert(objs);
        MergeRecord.mergeSObject(objs);

        MergeRecord.mergeSObject(new Account[] {acc1, acc2});
    }
    */
}