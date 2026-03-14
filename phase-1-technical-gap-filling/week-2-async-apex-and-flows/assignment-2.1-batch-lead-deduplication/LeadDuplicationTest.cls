
@isTest
public class LeadDuplicationTest {


    @TestSetup
    static void setupTestData(){
        Lead groupEmail1 = new Lead(FirstName='John', LastName='Doe', Email='groupEmailForTwo@gmail.com', Company='Test Company');
        Lead groupEmail2 = new Lead(FirstName='Harris', LastName='Poe', Email='groupEmailForTwo@gmail.com', Company='Test Company');
        insert new List<Lead>{groupEmail1, groupEmail2};
        Lead groupEmailForFour1 = new Lead(FirstName='John2', LastName='Doe', Email='groupEmailForFour@gmail.com', Company='Test Company');
        Lead groupEmailForFour2 = new Lead(FirstName='Harris2', LastName='Poe', Email='groupEmailForFour@gmail.com', Company='Test Company');
         Lead groupEmailForFour3= new Lead(FirstName='John2', LastName='Doe', Email='groupEmailForFour@gmail.com', Company='Test Company');
        Lead groupEmailForFour4 = new Lead(FirstName='Harris2', LastName='Poe', Email='groupEmailForFour@gmail.com', Company='Test Company');
        insert new List<Lead>{groupEmailForFour1, groupEmailForFour2, groupEmailForFour3, groupEmailForFour4};
        Lead uniqueLead1 = new Lead(FirstName='Harris', LastName='Poe', Email='uniqueEmail1@gmail.com', Company='Test Company');
        Lead uniqueLead2 = new Lead(FirstName='Harris', LastName='Poe', Email='uniqueEmail2@gmail.com', Company='Test Company');
        insert new List<Lead>{uniqueLead1,uniqueLead2};
        
    }

    @isTest
    static void testLeadDuplicationForTwo(){
        Test.startTest();
        LeadDeduplicationBatch ldb = new LeadDeduplicationBatch();
        Database.executeBatch(ldb, 50);
        Test.stopTest();

        List<Lead> leadList2 = [SELECT Id FROM Lead where Email = 'groupEmailForTwo@gmail.com'];       
        System.assertEquals(1, leadList2.size(), 'Only one lead should remain after deduplication.');
    } 
    
    @isTest
    static void testLeadDuplicationForFour(){      
        Test.startTest();
        LeadDeduplicationBatch ldb = new LeadDeduplicationBatch();
        Database.executeBatch(ldb, 50);
        Test.stopTest();

        List<Lead> leadList4 = [SELECT Id FROM Lead where Email = 'groupEmailForFour@gmail.com'];       
        System.assertEquals(1, leadList4.size(), 'Only one lead should remain after deduplication.');
    }

    @isTest 
    static void testLeadDuplicationForNone(){
        Test.startTest();
        LeadDeduplicationBatch ldb = new LeadDeduplicationBatch();
        Database.executeBatch(ldb, 50);
        Test.stopTest();

        List<Lead> leadUnique = [SELECT Id FROM Lead Where Email LIKE '%uniqueEmail%'];
        System.assertEquals(2, leadUnique.size(), 'Both leads should remain after deduplication.');
    }

    @isTest
    static void testScheduler(){
        Test.startTest();
        LeadDuplicationScheduler lds = new LeadDuplicationScheduler();
        System.schedule('Lead Deduplication', '0 0 6 ? * MON *', lds);
        Test.stopTest();
        CronTrigger ct = [SELECT Id, CronExpression, State FROM CronTrigger WHERE CronJobDetail.Name = 'Lead Deduplication'];
        System.assertEquals('0 0 6 ? * MON *', ct.CronExpression, 'Cron expression should match');
        System.assertEquals('WAITING', ct.State, 'Job should be in waiting state');
    }
}