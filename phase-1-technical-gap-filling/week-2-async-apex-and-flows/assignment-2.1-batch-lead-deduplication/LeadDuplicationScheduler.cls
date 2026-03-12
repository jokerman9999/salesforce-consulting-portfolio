global class LeadDuplicationScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc){
        LeadDeduplicationBatch ldb = new LeadDeduplicationBatch();
        Database.executeBatch(ldb,50);
    }

}