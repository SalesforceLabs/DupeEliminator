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
public with sharing class QueryBuilder {

        private SchemaInfo schema;
        private List<SelectOption> objects;
        private List<SelectOption> fields;

        private String queryStr;
        private List<String> fieldLabels;
        private Map<String, SObjectType> objectMap;
        private Map<String, String> objectLabels;
        private Map<String, SObjectField> fieldMap;
        private List<SObjectField> queryFields;
        private List<SObjectField> allFields;
        private Map<String, String> referenceFields;
        private Map<String, SObjectField> personAccFields;

        public String recordLimit { get { return recordLimit; } set { recordLimit = value; } }
        public String objectName { get { return objectName; } set { objectName = value; } }

        public String fieldName1 { get { return fieldName1; } set { fieldName1 = value; } }
        public String inputValue1 { get { return inputValue1; } set { inputValue1 = value; } }
        public String operatorValue1 { get { return operatorValue1; } set { operatorValue1 = value; } }
        public String fieldName2 { get { return fieldName2; } set { fieldName2 = value; } }
        public String inputValue2 { get { return inputValue2; } set { inputValue2 = value; } }
        public String operatorValue2 { get { return operatorValue2; } set { operatorValue2 = value; } }
        public String fieldName3 { get { return fieldName3; } set { fieldName3 = value; } }
        public String inputValue3 { get { return inputValue3; } set { inputValue3 = value; } }
        public String operatorValue3 { get { return operatorValue3; } set { operatorValue3 = value; } }
        public String fieldName4 { get { return fieldName4; } set { fieldName4 = value; } }
        public String inputValue4 { get { return inputValue4; } set { inputValue4 = value; } }
        public String operatorValue4 { get { return operatorValue4; } set { operatorValue4 = value; } }
        public String fieldName5 { get { return fieldName5; } set { fieldName5 = value; } }
        public String inputValue5 { get { return inputValue5; } set { inputValue5 = value; } }
        public String operatorValue5 { get { return operatorValue5; } set { operatorValue5 = value; } }

        public void setFieldName(Integer i, String field) {
            if (i == 1) fieldName1 = field;
            else if (i == 2) fieldName2 = field;
            else if (i == 3) fieldName3 = field;
            else if (i == 4) fieldName4 = field;
            else if (i == 5) fieldName5 = field;
        }

        public void setOperatorValue(Integer i, String op) {
            if (i == 1) operatorValue1 = op;
            else if (i == 2) operatorValue2 = op;
            else if (i == 3) operatorValue3 = op;
            else if (i == 4) operatorValue4 = op;
            else if (i == 5) operatorValue5 = op;
        }

        public void setInputValue(Integer i, String value) {
            if (i == 1) inputValue1 = value;
            else if (i == 2) inputValue2 = value;
            else if (i == 3) inputValue3 = value;
            else if (i == 4) inputValue4 = value;
            else if (i == 5) inputValue5 = value;
        }

        private static final List<SelectOption> operators =
                new List<SelectOption> {
                     new SelectOption('', '--None--'),
                     new SelectOption('equals', 'equals'),
                     new SelectOption('not equal to', 'not equal to'),
                     new SelectOption('not start with', 'not start with'),
                     new SelectOption('starts with', 'starts with'),
                     new SelectOption('contains', 'contains'),
                     new SelectOption('does not contain', 'does not contain'),
                     new SelectOption('less than', 'less than'),
                     new SelectOption('greater than', 'greater than'),
                     new SelectOption('less or equal', 'less or equal'),
                     new SelectOption('greater or equal', 'greater or equal'),
                     new SelectOption('includes', 'includes'),
                     new SelectOption('excludes', 'excludes')
                };

        public QueryBuilder() {
            schema = new SchemaInfo() ;
            objectMap = schema.getObjects();
            Map<String, SelectOption> sMap = new Map<String, SelectOption>();
            objectLabels = new Map<String, String>();
            for(String name : objectMap.keySet()) {
                String label = objectMap.get(name).getDescribe().getLabel();
                objectLabels.put(name, label);
                sMap.put(label+'.'+name, new SelectOption(name, label));
            }
            objects  = new List<SelectOption>();
            objects.add(new SelectOption('', '--None--'));
            List<String> objectKeys = new List<String>(sMap.keySet());
            objectKeys.sort();
            for (String k : objectKeys) {
                objects.add(sMap.get(k));
            }
            fields = new List<SelectOption>();
            queryFields = new List<SObjectField>();
            allFields = new List<SObjectField>();
            referenceFields = new Map<String, String>();
        }

        public boolean isValidObject(String name) {
            return objectMap.containsKey(name);
        }

        public boolean isValidField(String name) {
            getFields();
            return fieldMap.containsKey(name);
        }

        public boolean isValidOperator(String operator) {
            for (SelectOption op : operators) {
                if (op.getLabel().equals(operator)) return true;
            }
            return false;
        }

        public List<String> getNonReparentableChild(boolean excludePersonAccFields) {
            List<String> childRel =  schema.getNonReparentableChild(objectMap.get(objectName));
            if (excludePersonAccFields) {
                List<String> childList = new List<String>();
                for (String c : childRel) {
                    if (!(c.endsWith('__pr') || (c.startsWith('Person') && !c.endsWith('__r')))) {
                        childList.add(c);
                    }
                }
                return childList;
            }
            return childRel;
        }

        public List<SelectOption> getChildRelationshipSelection(boolean excludePersonAccFields) {
            List<SelectOption> childSelection = new List<SelectOption>();
            for (String child : getNonReparentableChild(excludePersonAccFields)) {
                childSelection.add(new SelectOption(child, child));
            }
            return childSelection;
        }

        public List<String> getChildRelationships() {
            return schema.getChildRelationships(objectMap.get(objectName));
        }

        public List<SelectOption> getObjects() {
            return objects;
        }

        public List<SelectOption> getFields() {
            if (fields.isEmpty()) {
                allFields.clear();
                referenceFields.clear();
                fieldLabels = new List<String>();
                Map<String, Schema.DescribeFieldResult> fMap = new Map<String, Schema.DescribeFieldResult>();
                fieldMap = schema.getFields(objectName);
                String idField = null;
                String nameField = null;
                for(String name : fieldMap.keySet()) {
                    Schema.DescribeFieldResult f = fieldMap.get(name).getDescribe();
                    if (f.getType() == DisplayType.ID) {
                        idField = name;
                        allFields.add(fieldMap.get(name));
                    } else {
                        String label = f.getlabel();
                        fMap.put(label+'.'+name, f);
                    }
                    if (f.isNameField()) nameField = name;
                    if (f.getType() == DisplayType.Reference &&  f.getRelationshipName() != null) {
                        String relName = f.getRelationshipName();
                        if (f.isNamePointing() && (relName == 'Who' || relName == 'What' || relName == 'Owner')) {
                            referenceFields.put(name, relName+'.Name');
                        } else if (!f.isNamePointing()) {
                            String refName = schema.getNameField(f.getReferenceTo()[0]);
                            if (refName != null) referenceFields.put(name, relName+'.'+refName);
                        }
                    }
                }
                referenceFields.put(IdField, nameField);
                fields.add(new SelectOption('', '--None--'));
                List<String> fieldKeys = new List<String>(fMap.keySet());
                fieldKeys.sort();
                for (String k : fieldKeys) {
                    Schema.DescribeFieldResult f = fMap.get(k);
                    String label = formatLabel(f, f.getLabel());
                    if (f.isFilterable()) {
                         fields.add(new SelectOption(f.getName(), label));
                    }
                    allFields.add(fieldMap.get(f.getName()));
                    fieldLabels.add(label);
                }
                fieldLabels.add(0, '<b>Master Record</b>');
            }
            return fields;
        }

        public List<SelectOption> getOperators() {
            return operators;
        }

        public List<SObjectField> getQueryFields() {
            return queryFields;
        }

        public List<SObjectField> getAllFields(boolean excludePersonAccFields) {
           if (excludePersonAccFields) {
               List<SObjectField> fields = new List<SObjectField>();
               for (SObjectField field : allFields) {
                    String name = field.getDescribe().getName();
                    if (!getPersonAccFields().containsKey(name)) {
                        fields.add(field);
                    }
               }
               return fields;
           }
           return allFields;
        }

        public List<String> getFieldLabels(boolean excludePersonAccFields) {
           if (excludePersonAccFields) {
               List<String> labels = new List<String>();
               for (SObjectField field : allFields) {
                    Schema.DescribeFieldResult f = field.getDescribe();
                    if (f.getType() != DisplayType.ID && !getPersonAccFields().containsKey(f.getName())) {
                        labels.add(formatLabel(f, f.getLabel()));
                    }
               }
               labels.add(0, '<b>Master Record</b>');
               return labels;
            }
            return fieldLabels;
        }

        public String getObjectLabel() {
            return objectLabels.get(objectName);
        }

        public Set<String> getAllFieldNames(boolean excludePersonAccFields) {
            if (excludePersonAccFields) {
                Set<String> names = fieldMap.keySet().clone();
                names.removeAll(getPersonAccFields().keySet());
                return names;
            }
            return fieldMap.keySet();
        }

        public Map<String, String> getReferenceFields() {
            return referenceFields;
        }

        public Map<String, SObjectField> getPersonAccFields() {
            if (personAccFields == null) {
                personAccFields = schema.getPersonAccFields();
            }
            return personAccFields;
        }

        public String getFieldLabel1() { return getFieldLabel(fieldName1); }
        public String getFieldLabel2() { return getFieldLabel(fieldName2); }
        public String getFieldLabel3() { return getFieldLabel(fieldName3); }
        public String getFieldLabel4() { return getFieldLabel(fieldName4); }
        public String getFieldLabel5() { return getFieldLabel(fieldName5); }

        private String getFieldLabel(String field) {
            Schema.DescribeFieldResult f = fieldMap.get(field).getDescribe();
            return formatLabel(f, f.getLabel());
        }

        private String formatLabel(Schema.DescribeFieldResult f, String label) {
            if (!f.isCustom() && f.getType() == DisplayType.Reference && f.getRelationshipName() != null) {
                String relName = f.getRelationshipName();
                if (!f.isNamePointing() || (f.isNamePointing() && (relName == 'Who' || relName == 'What' || relName == 'Owner'))) {
                    Integer endIndex = label.lastIndexOf('ID');
                    if (endIndex > 0) label = label.substring(0, endIndex);
                }
            }
            if (!f.isFilterable() && f.getType() == DisplayType.TextArea) {
                Integer count = 7;
                while (count > 0) {
                    label += '<br/>';
                    count--;
                }
                label = '<p style="margin-left: 2em;">' + label + '</p>';
            }
            return label;
        }

        public String getQueryAllFields(List<String> ids, boolean excludePersonAccFields) {
            String nameField = referenceFields.get('Id');
            String query = 'SELECT Id, ' + nameField;
            String idList = '(';
            for (Integer i = 0; i < ids.size(); i++) {
                if (i > 0) idList += ', ';
                idList += '\'' + ids[i] + '\'';
            }
            idList += ')';

            for (String f : getAllFieldNames(excludePersonAccFields)) {
                if (f != null && !f.equals('')) {
                    if (f == 'Id' || f == nameField) continue;
                    query += ', ' + f;
                    if (referenceFields.containsKey(f)) {
                        query += ', ' + referenceFields.get(f);
                    }
                }
            }

            query += ' FROM ' + objectName + ' WHERE Id IN ' + idList;
            return query;
        }

        public String getQueryString() {
            List<String> fieldNames = new List<String> { fieldName1, fieldName2, fieldName3, fieldName4, fieldName5};
            List<String> inputValues = new List<String> { inputValue1, inputValue2, inputValue3, inputValue4, inputValue5};
            List<String> operatorValues = new List<String> { operatorValue1, operatorValue2, operatorValue3, operatorValue4, operatorValue5};
            queryFields.clear();

            String nameField = referenceFields.get('Id');
            queryStr = 'SELECT Id, ' + nameField;
            if (UserInfo.isMultiCurrencyOrganization() && isValidField('CurrencyIsoCode')) {
                queryStr += ', CurrencyIsoCode';
            }
            if (objectName == 'Account' && isValidField('IsPersonAccount')) {
                queryStr += ', IsPersonAccount';
            }
            String orderBy = nameField;
            for (String f : fieldNames) {
                if (f != null && !f.equals('')) {
                     queryFields.add(fieldMap.get(f));
                     if (f == nameField) continue;
                     if (f == 'CurrencyIsoCode' || f == 'IsPersonAccount') {
                        orderBy += ', ' + f;
                        continue;
                     }
                     queryStr += ', ' + f;
                     if (referenceFields.containsKey(f)) {
                        queryStr += ', ' + referenceFields.get(f);
                        if (f == 'RecordTypeId')
                            orderBy += ', ' + f;
                        else
                            orderBy += ',' + referenceFields.get(f);
                     } else if  (fieldMap.get(f).getDescribe().isSortable()) {
                         orderBy += ', ' + f;
                     }
                }
            }
            queryStr += ' FROM ' + objectName;
            boolean firstFilter = true;
            for (Integer i = 0; i < fieldNames.size(); i++) {
                if (fieldNames[i] != null && operatorValues[i] != null) {

                    if (firstFilter) {
                        queryStr += ' WHERE ';
                        firstFilter = false;
                    } else {
                        queryStr += ' AND ';
                    }    

                   DisplayType fType = fieldMap.get(fieldNames[i]).getDescribe().getType();
                        
                    String op = '';
                    String prefix = '';
                    String suffix = '';
                    String negate = '';
                    if ('equals'.equals(operatorValues[i])) {
                        op = ' = ';
                    } else if ('not equal to'.equals(operatorValues[i])) {
                        op = ' != ';
                    } else if ('starts with'.equals(operatorValues[i])) {
                        op = ' like ';
                        suffix = '%';
                    } else if ('not start with'.equals(operatorValues[i])) {
                        op = ' like ';
                        suffix = '%';
                        negate = ' NOT ';
                    } else if ('contains'.equals(operatorValues[i])) {
                        op = ' like ';
                        prefix = '%';
                        suffix = '%';
                    } else if ('does not contain'.equals(operatorValues[i])) {
                        op = ' like ';
                        prefix = '%';
                        suffix = '%';
                        negate = ' NOT ';
                    } else if ('less than'.equals(operatorValues[i])) {
                        op = ' < ';
                    } else if ('greater than'.equals(operatorValues[i])) {
                        op = ' > ';
                    } else if ('less or equal'.equals(operatorValues[i])) {
                        op = ' <= ';
                    } else if ('greater or equal'.equals(operatorValues[i])) {
                        op = ' >= ';
                    } else if ('includes'.equals(operatorValues[i]) || 'excludes'.equals(operatorValues[i])) {
                        if (fType != DisplayType.MultiPicklist) {
                            throw new QueryException('"includes" and "excludes" operators are only supported for filter on multi-select picklists field');
                        }                        
                        op = ' ' + operatorValues[i] + ' ';
                        prefix = '(';
                        suffix = ')';
                    } else {
                        op = ' ' + operatorValues[i] + ' ';
                    }

                    String[] filterValues = new String[] {''};
                    if (inputValues[i] == null || inputValues[i].equals('')) {
                        filterValues = new String[] {'null'};
                    } else {
                        String escapeValue = String.escapeSingleQuotes(inputValues[i]);

                        if (fType == DisplayType.String || fType == DisplayType.Email || fType == DisplayType.Phone || fType == DisplayType.Picklist
                            || fType == DisplayType.Reference || fType == DisplayType.TextArea || fType == DisplayType.URL)
                        {
                            if (op.equals(' = ') || op.equals(' != ')) {
                                filterValues = new String[] {makeList(escapeValue.split(',', 0), true)};
                                if (filterValues[0].contains(',')) {
                                    prefix = '(';
                                    suffix = ')';
                                    if (op.equals(' = ')) op = ' IN ';
                                    else op = ' NOT IN ';
                                }
 
                            } else if (op.equals(' like ')) {
                                prefix = '\'' + prefix;
                                suffix = suffix + '\'';
                                filterValues = escapeValue.split(',', 0);                                
                                   
                            } else {
                                prefix = '\'' + prefix;
                                suffix = suffix + '\'';
                                filterValues = new String[] {escapeValue};
                            }
                        } else if (fType == DisplayType.MultiPicklist) {
                            filterValues = new String[] {makeList(escapeValue.split(',', 0), true)};
                        } else {
                            if (fType == DisplayType.Date) {
                                filterValues = new String[] {makeList(formatDate(escapeValue.split(',', 0)), false)};
                            } else if (fType == DisplayType.DateTime) {
                                filterValues = new String[] { makeList(formatDateTime(escapeValue.split(',', 0)), false)};
                            } else {
                                filterValues = new String[] {escapeValue};
                            }
                            
                            if (op.equals(' = ') || op.equals(' != ')) {
                                if (filterValues[0].contains(',')) {
                                    prefix = '(';
                                    suffix = ')';
                                    if (op.equals(' = ')) op = ' IN ';
                                    else op = ' NOT IN ';
                                }
                            }
                        }
                    }

                    String filterField = fieldNames[i];
                    if (referenceFields.containsKey(filterField)) {
                        filterField = referenceFields.get(filterField);
                    }
                    
                    String filterClause = '';
                    for (String filterValue : filterValues) {
                        if (!filterClause.equals('')) filterClause += ' OR ';
                        filterClause += '(' + negate + filterField + op + prefix + filterValue.trim() + suffix + ')';
                    } 
                    
                    queryStr += '(' + filterClause + ')';       
                }
            }

            if (!orderBy.equals('')) queryStr += ' ORDER BY ' + orderBy;
            if (recordLimit == null || recordLimit.equals('')) recordLimit = '10';
            queryStr += ' LIMIT ' + recordLimit;
            return queryStr;
        }

        private List<String> formatDate(String[] values) {
            List<String> dates = new List<String>();
            for (String value : values) {
                String[] d = value.trim().split('/');
                if (d.size() != 3) throw new QueryException('Invalid date format: ' + value + ', expecting format MM/dd/yyyy, e.g.: ' + Date.today().format());
                try {
                    Integer month = Integer.valueOf(d[0]);
                    Integer day = Integer.valueOf(d[1]);
                    Integer year = Integer.valueOf(d[2]);
                    dates.add(String.valueOf(Date.newInstance(year, month, day)));
                } catch (Exception e) {
                    throw new QueryException('Invalid date format: ' + value + ', expecting format MM/dd/yyyy, e.g.: ' + Date.today().format(), e);
                }
            }
            return dates;
        }

        private List<String> formatDateTime(String[] values) {
            List<String> dates = new List<String>();
            for (String value : values) {
                String[] d = value.trim().split('/|:|\\s');
                if (!(d.size() == 3 || d.size() == 6))
                    throw new QueryException('Invalid date/time format: ' + value + ', expecting format  MM/dd/yyyy hh:mm aa, e.g.: ' + DateTime.now().format());
                try {
                    Integer month = Integer.valueOf(d[0]);
                    Integer day = Integer.valueOf(d[1]);
                    Integer year = Integer.valueOf(d[2]);
                    Integer hour = d.size() == 6 ? Integer.valueOf(d[3]) : 0;
                    Integer min = d.size() == 6 ? Integer.valueOf(d[4]) : 0;
                    if (d.size() == 6 && d[5] == 'PM') hour += 12;
                    dates.add(DateTime.newInstance(year, month, day, hour, min, 0).format('yyyy-MM-dd\'T\'HH:mm:ss\'Z\''));
                } catch (Exception e) {
                    throw new QueryException('Invalid date/time format: ' + value + ', expecting format MM/dd/yyyy hh:mm aa, e.g.: ' + DateTime.now().format(), e);
                }
            }
            return dates;
        }

        private String makeList(String[] values, boolean addQuote) {
            String value = '';
            for (String s : values) {
                if (!value.equals('')) value += ', ';
                if (addQuote) value += '\'' + s.trim() + '\'';
                else value += s;
            }
            return value;
        }

        public void reset() {
            queryStr = null;
            fields.clear();
            queryFields.clear();
            allFields.clear();
            referenceFields.clear();
            personAccFields = null;
            fieldName1 = fieldName2 = fieldName3 = fieldName4 = fieldName5 = null;
            inputValue1 = inputValue2 = inputValue3 = inputValue4 = inputValue5 = null;
            operatorValue1 = operatorValue2 = operatorValue3 = operatorValue4 = operatorValue5 = null;
        }

        public class QueryException extends Exception {}

        public String[] getNotes() {
            return new String[] {
                'You can choose to display up to 5 fields on the result columns by selecting the fields on the filter without setting the operator',
                'For "(not) equal to", "(not) start with", "(does not) contain", "includes", "excludes" operator, you can enter multiple comma separated items in the value column',
                '"includes" and "excludes" operators are only supported for filter on multi-select picklists field',
                'For date fields, enter the value in the following format: ' + Date.today().format(),
                'For date/time fields, enter the value in the following format: ' + DateTime.now().format()
            };
        }
}