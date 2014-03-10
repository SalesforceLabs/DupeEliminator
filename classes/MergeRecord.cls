/*
Copyright (c) 2008 salesforce.com, inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
global with sharing class MergeRecord {

    private class MergeException extends Exception {}

    public static boolean debug = false;

    global static void mergeSObject(SObject[] sObjects) {
        mergeSObject(sObjects, false);
    }

    global static void mergeSObject(SObject[] sObjects, Boolean cloneChild) {
        mergeSObject(sobjects, cloneChild, null);
    }

    global static void mergeSObject(SObject[] sObjects, Boolean cloneChild, String[] childList) {
        if (sObjects == null || sObjects.size() < 2 || sObjects.size() > 3 ||
            sObjects[0] == null || sObjects[1] == null) {
            throw new MergeException('Merge records cannot be empty, less than 2 or more than 3');
        }

        Schema.SObjectType sobjectType = sObjects[0].getSObjectType();
        for (SObject s : sObjects) {
            if (s.getSObjectType() != sobjectType)
                throw New MergeException('Cannot merge records of different sObject type');
        }

        Set<String> childRelationships = new Set<String>();
        if (cloneChild) {
            if (childList == null) {
                SchemaInfo schema = new SchemaInfo();
                childList = schema.getNonReparentableChild(sobjectType);
            }
            if (debug) System.debug('######### Clone child relationships: ' + childList);
            if (childList.size() > 10) throw New MergeException('Cannot clone more than 10 child relationships: ' + childList);
            childRelationships.addAll(childList);
        }

        SObject master = sObjects[0];
        List<SObject> slaves = sObjects.clone();
        slaves.remove(0);
        String idList = '(';
        for (Integer i = 0; i < slaves.size(); i++) {
           if (i > 0) idList += ', ';
           idList += '\'' + slaves[i].id + '\'';
        }
        idList += ')';

        String objName = master.getSObjectType().getDescribe().getName();
        Boolean isPersonAcc = false;
        if (objName == 'Account') {
            try {
                Object value = master.get('IsPersonAccount');
                if (value != null) isPersonAcc = Boolean.valueOf(value);
            } catch (System.SObjectException ex) {
                // Field is not available for non-B2C org
            }
        }

        List<Schema.ChildRelationship> childRel = sobjectType.getDescribe().getChildRelationships();
        for (Schema.ChildRelationship child : childRel) {
            Schema.DescribeSObjectResult c = child.getChildSObject().getDescribe();
            Schema.DescribeFieldResult f = child.getField().getDescribe();
            if (c.isAccessible() && c.isQueryable() && f.isAccessible() && f.isFilterable()) {
                String childName = c.getName();
                String fieldName = f.getName();
                if (debug) System.debug('########## Child: ' + childName + ', Field: ' + fieldName);

                if (objName == 'Account' && childName == 'Contact' && fieldName == 'AccountId' && isPersonAcc) {
                    continue;
                }

                if (c.isUpdateable() && f.isUpdateable()) {
                    String queryStr = 'SELECT id, ' + fieldName  + ' FROM ' + childName + ' WHERE ' + fieldName + ' IN ' + idList;
                    if (debug) System.debug('########## Query: ' + queryStr);
                    List<SObject> children = Database.query(queryStr);
                    for (SObject s : children) {
                        s.put(fieldName, master.Id);
                    }
                    Database.update(children);
                } else if (cloneChild && childRelationships.contains(child.getRelationshipName())) {
                   String fieldNames = fieldName;
                   List<Schema.SObjectField> fields = c.fields.getMap().values();
                   for (Schema.SObjectField field : fields) {
                       Schema.DescribeFieldResult r = field.getDescribe() ;
                       if (r.isAccessible() && r.isCreateable() && !r.isCalculated() && !r.isAutoNumber()
                           && r.getType() != DisplayType.ID && !r.getName().equals(fieldName)) {
                            if (c.getName().equals('OpportunityLineItem') && r.getName().equals('TotalPrice')) continue;
                                fieldNames += ', ' + r.getName();
                        }
                    }
                    String queryStr = 'SELECT id, ' + fieldNames  + ' FROM ' + childName + ' WHERE ' + fieldName + ' IN ' + idList;
                    if (debug) System.debug('########## Query: ' + queryStr);
                    List<SObject> children = Database.query(queryStr);

                    List<SObject> clones = children.deepClone(false);
                    for (SObject s : clones) {
                        s.put(fieldName, master.Id);
                    }
                    Database.insert(clones);
                    
                    //NOTE: Reparent any existing child of the orginal records to the cloned records
                    reparentChild(children, clones);
                    
                    //NOTE: This will caused child to be double deleted when we delete the parent slave
                    //Database.delete(children);
                }
            }
        }
        
        // delete the merged record first in case there are unique values that need to be updated on the master record
        Database.delete(slaves);
        Database.update(master);
    }
    
    private static void reparentChild(List<SObject> fromParents, List<SObject>  toParents) {
        if (fromParents.size() == 0) return;
        
        Schema.SObjectType sobjectType = fromParents[0].getSObjectType();
        
        Map<String, String> idMaps = new Map<String, String>();
        String idList = '(';
        for (Integer i = 0; i < fromParents.size(); i++) {
            String oldId = fromParents.get(i).Id;
            idMaps.put(oldId, toParents.get(i).Id);
            if (i > 0) idList += ', ';
            idList += '\'' + oldId + '\'';       
        }
        idList += ')';

        List<Schema.ChildRelationship> childRel = sobjectType.getDescribe().getChildRelationships();
        for (Schema.ChildRelationship child : childRel) {
            Schema.DescribeSObjectResult c = child.getChildSObject().getDescribe();
            Schema.DescribeFieldResult f = child.getField().getDescribe();
            if (c.isAccessible() && c.isQueryable() && f.isAccessible() && f.isFilterable()) {
                String childName = c.getName();
                String fieldName = f.getName();
                if (debug) System.debug('########## Child: ' + childName + ', Field: ' + fieldName);
            
                if (c.isUpdateable() && f.isUpdateable()) {   
                    String queryStr = 'SELECT id, ' + fieldName  + ' FROM ' + childName + ' WHERE ' + fieldName + ' IN ' + idList;
                    if (debug) System.debug('########## Query: ' + queryStr);
                    List<SObject> children = Database.query(queryStr);
                    for (SObject s : children) {
                        String parentId = idMaps.get((String)s.get(fieldName));
                        s.put(fieldName, parentId);
                    }
                    Database.update(children);
                } else if (c.isCreateable()) {
                    String fieldNames = fieldName;
                    List<Schema.SObjectField> fields = c.fields.getMap().values();
                    for (Schema.SObjectField field : fields) {
                       Schema.DescribeFieldResult r = field.getDescribe() ;
                       if (r.isAccessible() && r.isCreateable() && !r.isCalculated() && !r.isAutoNumber()
                           && r.getType() != DisplayType.ID && !r.getName().equals(fieldName)) {
                            if (c.getName().equals('OpportunityLineItem') && r.getName().equals('TotalPrice')) continue;
                                fieldNames += ', ' + r.getName();
                        }
                    }
                    String queryStr = 'SELECT id, ' + fieldNames  + ' FROM ' + childName + ' WHERE ' + fieldName + ' IN ' + idList;
                    if (debug) System.debug('########## Query: ' + queryStr);
                    List<SObject> children = Database.query(queryStr);

                    List<SObject> clones = children.deepClone(false);
                    for (SObject s : clones) {
                        String parentId = idMaps.get((String)s.get(fieldName));
                        s.put(fieldName, parentId);
                    }
                    Database.insert(clones);
                }                       
            }
        }        
    }
}