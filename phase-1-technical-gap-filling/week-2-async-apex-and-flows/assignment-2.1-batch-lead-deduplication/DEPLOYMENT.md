# Deployment Guide — Lead Deduplication Batch
**Assignment 2.1 | Phase 1 — Week 2**  
**Author:** Tushar Kandwal  
**Last Updated:** March 2026

---

## Overview

This solution identifies and merges duplicate Lead records in Salesforce based on matching email addresses. It is designed to handle 10,000+ records safely within governor limits.

### Classes Included

| Class | Type | Purpose |
|---|---|---|
| `LeadDeduplicationBatch` | Batch Apex | Finds and merges duplicate leads by email |
| `LeadDuplicationScheduler` | Schedulable Apex | Schedules the batch to run weekly |
| `LeadDuplicationTest` | Test Class | Covers all deduplication and scheduling scenarios |

### Business Logic
- Leads are ordered by `CreatedDate DESC` — the **newest lead is kept** as the master
- All older leads with the same email are merged into the master
- A summary email is sent to the System Administrator on completion

---

## Prerequisites

Before deploying, ensure the following are in place:

- Salesforce CLI installed (`sf --version` to verify)
- VS Code with Salesforce Extension Pack installed
- Target org authenticated via CLI
- Email Deliverability set to **All Email** in target org
  - Setup → Email → Deliverability → Access Level → All Email
- At least one active **System Administrator** user in the target org
- **Lead Duplicate Rules** deactivated or configured to allow merges
  - Setup → Duplicate Rules → Leads → Deactivate if needed

---

## Deployment Steps

### Step 1 — Authenticate to Target Org

```bash
sf org login web --alias target-org
sf config set target-org target-org
```

### Step 2 — Deploy All Classes

```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org target-org
```

Expected output:
```
Deployed Source
──────────────────────────────────────────
State    Full Name                    Type
──────────────────────────────────────────
Add      LeadDeduplicationBatch       ApexClass
Add      LeadDuplicationScheduler     ApexClass
Add      LeadDuplicationTest          ApexClass
```

### Step 3 — Run Test Classes

```bash
sf apex run test --class-names LeadDuplicationTest --target-org target-org --result-format human
```

Expected coverage:
- `LeadDeduplicationBatch` → 97%+
- `LeadDuplicationScheduler` → 100%

---

## Post-Deployment Setup

### Schedule the Weekly Job

Open Developer Console → Debug → Open Execute Anonymous Window and run:

```apex
System.schedule(
    'Weekly Lead Deduplication',
    '0 0 6 ? * MON *',
    new LeadDuplicationScheduler()
);
```

**Cron Expression Breakdown:**

| Field | Value | Meaning |
|---|---|---|
| Seconds | 0 | At 0 seconds |
| Minutes | 0 | At 0 minutes |
| Hours | 6 | At 6:00 AM |
| Day of Month | ? | No specific day |
| Month | * | Every month |
| Day of Week | MON | Every Monday |
| Year | * | Every year |

### Verify the Job is Scheduled

Go to **Setup → Scheduled Jobs** and confirm:
- Job Name: `Weekly Lead Deduplication`
- Status: `Waiting`
- Next Run: Coming Monday at 6:00 AM

---

## Running the Batch Manually

To trigger the batch outside of the schedule (e.g. for initial data cleanup):

```apex
Database.executeBatch(new LeadDeduplicationBatch(), 50);
```

> **Important:** Batch size is set to 50 intentionally. Do not increase beyond 100 to avoid hitting DML row governor limits during merge operations.

Monitor progress at **Setup → Apex Jobs**.

---

## Verification Steps

After the batch completes, verify results:

**1. Check Apex Jobs**
- Setup → Apex Jobs → Confirm status is `Completed` with 0 failures

**2. Check Summary Email**
- Admin inbox should contain email with subject: `Lead Data Cleansing Batch Complete`
- Email shows Total Records Scanned, Total Merges, Total Failures

**3. Verify No Remaining Duplicates**

Run in Anonymous Apex:
```apex
List<AggregateResult> dupes = [
    SELECT Email, COUNT(Id) total 
    FROM Lead 
    WHERE Email != null 
    GROUP BY Email 
    HAVING COUNT(Id) > 1
];
System.debug('Remaining duplicate groups: ' + dupes.size());
```

Expected output: `Remaining duplicate groups: 0`

---

## Rollback Procedure

If issues arise after deployment, follow these steps:

**Step 1 — Abort the Scheduled Job**

```apex
List<CronTrigger> jobs = [
    SELECT Id FROM CronTrigger 
    WHERE CronJobDetail.Name = 'Weekly Lead Deduplication'
];
for(CronTrigger ct : jobs) {
    System.abortJob(ct.Id);
}
```

**Step 2 — Delete Deployed Classes**

```bash
sf project deploy start --source-dir force-app/main/default/classes --target-org target-org --ignore-errors
```

Or manually delete via Setup → Apex Classes.

> **Note:** Merged leads cannot be automatically restored. Ensure a data backup exists before running the batch in production for the first time.

---

## Troubleshooting

| Issue | Likely Cause | Fix |
|---|---|---|
| Summary email not received | Deliverability set to System Only | Setup → Email → Deliverability → All Email |
| Merge failures in logs | Duplicate Rules active | Deactivate Lead Duplicate Rules |
| Batch shows 0 records processed | No leads with email in org | Verify lead data exists |
| Cannot save class | Scheduled job active | Abort job first, then redeploy |
| `System Administrator` query fails | No active admin user | Verify admin user exists and is active |
