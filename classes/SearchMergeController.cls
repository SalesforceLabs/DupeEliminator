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
public with sharing class SearchMergeController {

    private QueryBuilder queryBuilder;
    private List<DynamicSObject> results;
    private List<DynamicSObject> mergeRecords;
    private List<SObject> sObjects;
    private boolean excludePersonAccFields;
    private String error;
    public boolean debug;
    public boolean showQuery;

    private String[] childRelationships = new String[]{};

    public SearchMergeController(){
        queryBuilder = new QueryBuilder();
        results = new List<DynamicSObject>();
        mergeRecords = new List<DynamicSObject>();
        renderResult = false;
        cloneNonReparentableChild = false;
        showMasterAfterMerge = false;
        excludePersonAccFields = false;
        init();
    }

    private void init() {
        String debugParam = ApexPages.currentPage().getParameters().get('debug');
        debug = (debugParam != null && (debugParam.equals('1') || debugParam.equals('true'))) ? true : false;
        String showQueryParam = ApexPages.currentPage().getParameters().get('showQuery');
        showQuery = (showQueryParam != null && (showQueryParam.equals('1') || showQueryParam.equals('true'))) ? true : false;
        String hideFilterParam = ApexPages.currentPage().getParameters().get('hideFilter');
        hideFilter = (hideFilterParam != null && (hideFilterParam.equals('1') || hideFilterParam.equals('true'))) ? true : false;
        String hideHeaderParam = ApexPages.currentPage().getParameters().get('hideHeader');
        hideHeader = (hideHeaderParam != null && (hideHeaderParam.equals('1') || hideHeaderParam.equals('true'))) ? true : false;
        String hideSidebarParam = ApexPages.currentPage().getParameters().get('hideSidebar');
        hideSidebar = (hideSidebarParam != null && (hideSidebarParam.equals('1') || hideSidebarParam.equals('true'))) ? true : false;

        // Get default query parameters
        String findParam = ApexPages.currentPage().getParameters().get('find');
        boolean find = (findParam != null && (findParam.equals('1') || findParam.equals('true'))) ? true : false;
        String objectName = ApexPages.currentPage().getParameters().get('object');
        if (find && queryBuilder.isValidObject(objectName)) {
            queryBuilder.objectName = objectName;
            for (Integer i = 1; i <= 5; i++) {
                String field = ApexPages.currentPage().getParameters().get('field' + i);
                String op = ApexPages.currentPage().getParameters().get('op' + i);
                String value = ApexPages.currentPage().getParameters().get('value' + i);
                if (queryBuilder.isValidField(field))
                    queryBuilder.setFieldName(i, field);
                if (queryBuilder.isValidOperator(op))
                    queryBuilder.setOperatorValue(i, op);
                queryBuilder.setInputValue(i, value);

            }
            queryBuilder.recordLimit = ApexPages.currentPage().getParameters().get('limit');
            find();
        }
    }

    public boolean hideHeader  {
        get {
            if (hideHeader == null) hideHeader = false;
            return hideHeader;
         }
        set;
    }
    public boolean hideSidebar  {
        get {
            if (hideSidebar == null) hideSidebar = false;
            return hideSidebar;
         }
        set;
    }
    public boolean hideFilter  {
        get {
            if (hideFilter == null) hideFilter = false;
            return hideFilter;
         }
        set;
    }
    public boolean renderResult  { get; set; }
    public boolean cloneNonReparentableChild  { get; set; }
    public boolean showMasterAfterMerge  { get; set; }


    public boolean getShowQuery() {
        return showQuery;
    }

    public QueryBuilder getQueryBuilder() {
        return queryBuilder;
    }

    public List<DynamicSObject> getResults() {
        if (debug) for (DynamicSObject s : results) System.debug('############## result: ' + s);
        return results;
    }

    public String getError() { return error; }

    public PageReference find() {
        error = null;
        String queryStr = null;
        results.clear();
        try {
            queryStr = queryBuilder.getQueryString();
            if (debug) System.debug('######################### Query: ' + queryStr);
            List<SObject> sobjectResults = Database.query(queryStr);
            for (SObject s : sobjectResults) {
                if (debug) System.debug('######################### SObject: ' + s);
                results.add(new DynamicSObject(s, queryBuilder.objectName, queryBuilder.getQueryFields(), queryBuilder.getReferenceFields()));
            }
            renderResult = true;
        } catch (Exception e) {
            if (debug) throw e;
            ApexPages.addMessages(e);
            if (queryStr != null)
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, 'Query: ' + queryStr));
        }

        return null;
    }

    public PageReference cancel() {
        queryBuilder.objectName = null;
        return resetQuery();
    }

    public PageReference cancel2() {
        cancel();
        return Page.SearchMerge;
    }

    public PageReference resetQuery() {
        queryBuilder.reset();
        results.clear();
        mergeRecords.clear();
        renderResult = false;
        excludePersonAccFields = false;
        cloneNonReparentableChild = false;
        childRelationships.clear();
        error = null;
        return null;
    }

    public PageReference previous() {
        error = null;
        excludePersonAccFields = false;
        cloneNonReparentableChild = false;
        childRelationships.clear();
        mergeRecords.clear();
        return Page.SearchMerge;
    }

    public DynamicSObject getMergeRecord1() { return mergeRecords.size() >= 1 ? mergeRecords[0] : null; }
    public DynamicSObject getMergeRecord2() { return mergeRecords.size() >= 2 ? mergeRecords[1] : null; }
    public DynamicSObject getMergeRecord3() { return mergeRecords.size() >= 3 ? mergeRecords[2] : null; }

    public PageReference selectMerge() {
        error = null;
        mergeRecords.clear();
        String query = null;
        try {

            List<DynamicSObject> selectedSObjects = new List<DynamicSObject>();
            for (DynamicSObject o : getResults()) {
                if (o.getSelected()) {
                    if (selectedSObjects.size() < 3) {
                        selectedSObjects.add(o);
                    } else {
                        error = 'You may only select up to three records to merge.';
                        return null;
                    }
                }
            }

            if (selectedSObjects.size() < 2) {
                error = 'You must select two or three records to merge.';
                return null;
            }

            Boolean isPersonAcc1 = true;
            Boolean isPersonAcc2 = false;
            List<ID> mergeIds = new List<ID>();
            for (DynamicSObject o : selectedSObjects) {
                mergeIds.add(o.getID());
                if (queryBuilder.objectName == 'Account' && queryBuilder.isValidField('IsPersonAccount')) {
                    isPersonAcc1 &= o.getIsPersonAcc();
                    isPersonAcc2 |= o.getIsPersonAcc();
                }
            }

            if (queryBuilder.objectName == 'Account' && queryBuilder.isValidField('IsPersonAccount') && isPersonAcc1 != isPersonAcc2) {
                error = 'The accounts cannot be merged. Selected records do not have compatible record types and cannot be merged together.';
                return null;
            }

            excludePersonAccFields =  queryBuilder.objectName == 'Account' && queryBuilder.isValidField('IsPersonAccount') && !isPersonAcc1;
            List<SObjectField> fields = queryBuilder.getAllFields(excludePersonAccFields);
            query = queryBuilder.getQueryAllFields(mergeIds, excludePersonAccFields);
            if (debug) System.debug('######################### Query: ' + query);
            sObjects = Database.query(query);
            Map<ID, DynamicSObject> recordMap = new Map<ID, DynamicSObject>();
            for (SObject s : sObjects) {
                recordMap.put(s.id, new DynamicSObject(s, queryBuilder.objectName, fields, queryBuilder.getReferenceFields()));
            }
            for (ID id : mergeIds) {
                mergeRecords.add(recordMap.get(id));
            }

            selectedRecord = mergeIds[0];
            doSelectRecord();
        } catch (Exception e) {
             if (debug) throw e;
             ApexPages.addMessages(e);
             if (query != null)
                 ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.INFO, ' Query: ' + query));
             return null;
        }
        return Page.MergeRecord;
    }

    public List<String> getFieldLabels() {
        return queryBuilder.getFieldLabels(excludePersonAccFields);
    }

    public String selectedRecord { get; set; }
    public String selectedField { get; set; }

    public PageReference doSelectRecord() {
        if (debug) System.debug('############# Selected record: ' + selectedRecord);
        for (DynamicSObject s : mergeRecords) {
            if (s.getID() == selectedRecord) {
                s.selectAllFields(true);

            } else {
                s.selectAllFields(false);
            }
        }
        return null;
    }

    public PageReference doSelectField() {
        if (debug) System.debug('############# Selected record: ' + selectedRecord);
        if (debug) System.debug('############# Selected field: ' + selectedField);
        String nameField = null;
        if (selectedField == 'Id') {
            nameField = queryBuilder.getReferenceFields().get('Id');
        }
        for (DynamicSObject s : mergeRecords) {
            if (s.getID() == selectedRecord) {
                s.selectField(selectedField, true);
                if (nameField != null) s.selectField(nameField, true);
            } else {
                s.selectField(selectedField, false);
                if (nameField != null) s.selectField(nameField, false);
            }
        }
        return null;
    }

    public String[] getChildRelationships() {
        return childRelationships;
    }

    public void setChildRelationships(String[] childRelationships) {
        this.childRelationships = childRelationships;
    }

    public List<SelectOption> getChildRelationshipSelection() {
        return queryBuilder.getChildRelationshipSelection(excludePersonAccFields);
    }

    public void clearChildSelection() {
        if (!cloneNonReparentableChild && childRelationships != null)
            childRelationships.clear();
    }

    public PageReference doMerge() {
        sObjects.clear();
        DynamicSObject master;
        try {
            for (DynamicSObject s : mergeRecords) {
                DynamicSObject.Field f = s.getField('Id');
                if (debug) System.assertNotEquals(null, f, 'Cannot find field: Id ');
                if (f.getSelected()) {
                    if (sObjects.isEmpty()) sObjects.add(s.getSObject());
                    else sObjects.add(0, s.getSObject());
                    master = s;
                } else {
                    sObjects.add(s.getSObject());
                }
            }
            if (master == null) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You must select a master record to merge.'));
                return null;
            }
            for (DynamicSObject s : mergeRecords) {
                if (s.getID() != master.getID()) {
                    for (String f : queryBuilder.getAllFieldNames(excludePersonAccFields)) {
                        if (debug) System.debug('########## Field: ' + f);
                        DynamicSObject.Field m_field = master.getField(f);
                        DynamicSObject.Field s_field = s.getField(f);
                        if (debug) System.assertNotEquals(null, m_field, 'Cannot find field: ' + f);
                        if (debug) System.assertNotEquals(null, s_field, 'Cannot find field: ' + f);
                        if (!m_field.getSelected() && s_field.getSelected() && m_field.getValue() != s_field.getValue()) {
                            m_field.setValue(s_field.getValue());
                        }
                    }
                }
            }

            MergeRecord.debug = debug;
            MergeRecord.mergeSObject(sObjects, cloneNonReparentableChild, childRelationships);
        } catch (Exception e) {
            if (debug) throw e;
            ApexPages.addMessages(e);
            return null;
        }

        if (showMasterAfterMerge) {
            String viewUrl = '/' + master.getID();
            if (queryBuilder.objectName.equals('Idea')) {
                viewUrl = '/ideas/viewIdea.apexp?id=' + master.getID();
            }
            PageReference recordPage = new PageReference(viewUrl);
            recordPage.setRedirect(true);
            return recordPage;
        } else {
            find();
            return previous();
        }
    }
}