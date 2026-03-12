global class LeadDeduplicationBatch implements Database.Batchable<sObject>, Database.Stateful {

    global Integer totalRecordsProcessed = 0;
    global Integer totalMerges = 0;
    global Integer totalFailures = 0;


    global Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('Select Id, Email, CreatedDate from Lead where Email!=null Order by CreatedDate DESC');
    }

    global void execute(Database.BatchableContext bc, List<Lead> scope){
        if(scope.size() == 0) { return; }
        Map<String,List<Lead>> duplicateListMap = new Map<String,List<Lead>>();        
        List<Lead> duplicateLeads = new List<Lead>();        
        for(Integer i = 0;i<scope.size();i++){
            if(duplicateListMap.containsKey(scope.get(i).Email)){
                duplicateLeads = duplicateListMap.get(scope.get(i).Email);
                duplicateLeads.add(scope.get(i));
                duplicateListMap.put(scope.get(i).Email,duplicateLeads);
            }else{
                duplicateListMap.put(scope.get(i).Email,new List<Lead>{scope.get(i)});
            }
            totalRecordsProcessed++; 
        }
        for(String str: duplicateListMap.keySet()){
            List<Lead> duplicates = duplicateListMap.get(str);
                if(duplicates.size() > 1) {
                Lead masterLead = duplicates.get(0);
                for(Integer i=1;i<duplicates.size();i++){
                    Database.MergeResult result = Database.merge(masterLead, duplicates.get(i), false);
                    if(result.isSuccess()){
                        totalMerges++;
                    }else{
                        totalFailures++;
                    }
                }
            }
        }
    }

    global void finish(Database.BatchableContext bc){
        Messaging.SingleEmailMessage emailMessage = new Messaging.SingleEmailMessage();
        User user = [Select Id,Email from User where Profile.Name = 'System Administrator' and isActive = true limit 1];
        emailMessage.setToAddresses(new String[] {user.Email});
        emailMessage.setSubject('Lead Data Cleansing Batch Complete');
        emailMessage.setPlainTextBody(
            'The Lead Merge Batch has completed.\n\n'+ 'Total Records Scanned: '+totalRecordsProcessed +'\n' + 'Total Merges Successful:'+totalMerges+'\n' +           
            'Total Failures:' + totalFailures 
        );
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { emailMessage });
    }

}