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
public with sharing class SchemaInfo {

    private Map<String, Schema.SObjectType> globalObjectMap;
    private static final Set<String> excludeObjs = new Set<String>();
    private static final Set<String> excludeFields = new Set<String>();

    static {
        excludeObjs.add('Document');
        excludeObjs.add('IdeaComment');
        excludeObjs.add('CaseComment');
        excludeFields.add('ForecastCategory');
    }

    public SchemaInfo(){
        globalObjectMap = Schema.getGlobalDescribe();
    }

    public Map<String, SObjectType> getObjects() {
        Map<String, SObjectType> result = new Map<String, SObjectType>();
        List<Schema.SObjectType> oTokens = globalObjectMap.values() ;
        for (Schema.SObjectType t : oTokens) {
            Schema.DescribeSObjectResult s = t.getDescribe();
            if (s.isAccessible() && s.isSearchable() && s.isQueryable() && s.isUpdateable() && s.isDeletable() && s.isUndeletable()) {
                if (excludeObjs.contains(s.getName())) continue;
                result.put(s.getName(), t) ;
            }
        }
        return result ;
    }

    public Map<String, SObjectField> getFields(String objName) {
        Map<String, SObjectField> result = new Map<String, SObjectField>();
        Schema.SObjectType s = globalObjectMap.get(objName) ;
        Map<String, Schema.SObjectField> fMap = s.getDescribe().fields.getMap() ;
        List<Schema.SObjectField> fTokens = fMap.values() ;
        for (Schema.SObjectField t : fTokens) {
            Schema.DescribeFieldResult f = t.getDescribe() ;
            if (f.isAccessible() && !f.getName().equals('IsDeleted')) {
                if (excludeFields.contains(f.getName())) continue;
                result.put(f.getName(), t);
            }
        }
        return result;
    }

    public Map<String, SObjectField> getPersonAccFields() {
        Map<String, SObjectField> result = new Map<String, SObjectField>();
        Schema.SObjectType s = globalObjectMap.get('Account') ;
        Map<String, Schema.SObjectField> fMap = s.getDescribe().fields.getMap() ;
        List<Schema.SObjectField> fTokens = fMap.values() ;
        for (Schema.SObjectField t : fTokens) {
            Schema.DescribeFieldResult f = t.getDescribe() ;
            if (f.isAccessible() && !f.getName().equals('IsDeleted')) {
                if (excludeFields.contains(f.getName())) continue;
                if ((f.isCustom() && f.getName().endsWith('__pc')) || (!f.isCustom() && f.getName().startsWith('Person'))) {
                    result.put(f.getName(), t);
                }
            }
        }
        return result;
    }

    public String getNameField(Schema.SObjectType sobjectType) {
        Schema.DescribeSObjectResult s = sObjectType.getDescribe();
        if (s.isCustom()) return 'Name';
        String name = s.getName();
        if (name == 'Account' || name == 'Asset' || name == 'Campaign' || name == 'Contact' || name == 'Contract' ||
            name == 'Lead' || name == 'Product' || name == 'Opportunity' || name == 'User' || name == 'BusinessHours')
            return 'Name';
        else if (name == 'Case')
            return 'CaseNumber';
        else if (name == 'Solution')
            return 'SolutionNumber';
        else if (name == 'Idea')
            return 'Title';
        else if (name == 'Task' || name == 'Event')
            return 'Subject';

        Map<String, Schema.SObjectField> fMap = s.fields.getMap() ;
        Schema.SObjectField field = fMap.get('Name');
        if (field != null) {
            Schema.DescribeFieldResult f = field.getDescribe();
            if (f.isNameField()) return f.getName();
        }
        for (Schema.SObjectField sfield : fMap.values()) {
            Schema.DescribeFieldResult f = sfield.getDescribe();
            if (f.isNameField()) return f.getName();
        }
        return null;
    }

    public List<String> getNonReparentableChild(SObjectType sobjectType) {
        List<String> relationships = new List<String>();
        if (sobjectType == null) return relationships;
        List<Schema.ChildRelationship> childRel = sobjectType.getDescribe().getChildRelationships();
        for (Schema.ChildRelationship child : childRel) {
            Schema.DescribeSObjectResult c = child.getChildSObject().getDescribe();
            Schema.DescribeFieldResult f = child.getField().getDescribe();
            if (c.isAccessible() && c.isQueryable() /*&& c.isUpdateable()*/ && f.isAccessible() && f.isFilterable() &&
                !f.isUpdateable() && c.isCreateable() && child.getRelationshipName() != null &&
                'Shares' != child.getRelationshipName()) {
                relationships.add(child.getRelationshipName());
            }
        }
        relationships.sort();
        return relationships;
    }

    public List<String> getChildRelationships(SObjectType sobjectType) {
        List<String> relationships = new List<String>();
        if (sobjectType == null) return relationships;
        List<Schema.ChildRelationship> childRel = sobjectType.getDescribe().getChildRelationships();
        for (Schema.ChildRelationship child : childRel) {
            relationships.add(child.getRelationshipName());
        }
        relationships.sort();
        return relationships;
    }
}