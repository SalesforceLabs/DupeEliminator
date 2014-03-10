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
public with sharing class DynamicSObject {

    private final SObject delegate;
    private final List<Schema.SObjectField> sObjectFields;
    private final Map<String, String> referenceFields;
    private final List<Field> fields;
    private final Map<String, Field> fieldMap;
    private final String name;
    private boolean selected;

    public boolean getSelected() {
        if (this.selected == null) this.selected = false;
        return this.selected;
    }

    public void setSelected(boolean b) {
        this.selected = b;
    }

    public DynamicSObject(SObject delegate, String name, List<SObjectField> sObjectFields, Map<String, String> referenceFields) {
        this.delegate = delegate;
        this.sObjectFields = sObjectFields;
        this.referenceFields = referenceFields;
        this.name = name;
        this.selected = false;
        this.fields = new List<Field>();
        this.fieldMap = new Map<String, Field>();
        loadFields();
    }

    public ID getID() {
        return this.delegate.id;
    }

    public String getDisplayID() {
        String refField = referenceFields.get('Id');
        Object refName = delegate.get(refField);
        String url = '/' + getID();
        if (name.equals('Idea')) {
            url = '/ideas/viewIdea.apexp?id=' + getID();
        }
        return '<a href="' + url + '">' + refName + '<a/>';
    }
    
    public String getIdRefUrl() {
        String url = '/' + getID();
        if (name.equals('Idea')) {
            url = '/ideas/viewIdea.apexp?id=' + getID();
        }
        return url;
    }

    public Object getIdRefName() {
        String refField = referenceFields.get('Id');
        Object refName = delegate.get(refField);
        return refName;
    }    

    public boolean getIsPersonAcc() {
        Boolean isPersonAcc = false;
        if (name == 'Account') {
            try {
                Object value = delegate.get('IsPersonAccount');
                if (value != null) isPersonAcc = Boolean.valueOf(value);
            } catch (System.SObjectException ex) {
                // Field is not available for non-B2C org
            }
        }
        return isPersonAcc;
    }

    public SObject getSObject() {
        return this.delegate;
    }

    public Field getField(String name) {
        Field f =  fieldMap.get(name);
        if (f == null) throw new DynamicSObjectException('Invalid field name: ' + name);
        return f;
    }

    public boolean hasField(String name) {
        return fieldMap.containsKey(name);
    }

    public Field getField1() { return getField(0); }
    public Field getField2() { return getField(1); }
    public Field getField3() { return getField(2); }
    public Field getField4() { return getField(3); }
    public Field getField5() { return getField(4); }

    private Field getField(Integer i) {
       if (i < 0 || i > 4 )
           throw new DynamicSObjectException('Invalid field index: ' + i + ' is greater than number of selected fields: ' + sObjectFields + ' values: ' + fields);
       return (i < fields.size()) ? fields[i] : null;
    }

    private void loadFields() {
        if (fields.isEmpty()) {
            for (Schema.SObjectField field : sObjectFields) {
                try {
                    Field f = new Field(this, field);
                    fields.add(f);
                    fieldMap.put(f.getName(), f);
                } catch (System.SObjectException ex) {
                    // Field was not selected in the select list
                    throw new DynamicSObjectException('Invalid field: ' + field, ex);
                }
            }
            if (fields.size() != sObjectFields.size())
                throw new DynamicSObjectException('Number of fields does not match, expect: ' + sObjectFields + ' actual:  ' + fields);
        }
    }

    public List<Field> getFields() {
        return this.fields;
    }

    public void selectAllFields(Boolean b) {
        for (Field f : fields) {
            if (f.isChangeable) f.selected = b;
        }
    }

    public void selectField(String field, Boolean b) {
        Field f = getField(field);
        if (f.isChangeable) f.selected = b;
    }

    public Map<String, String> getReferenceFields() {
        return referenceFields;
    }

    public class DynamicSObjectException extends Exception {}

    public class Field {

        private final DynamicSObject sobj;
        private final Schema.SObjectField f;
        private final boolean isChangeable;
        private final boolean isReference;
        private final boolean isFilterable;
        private final String name;
        private final DisplayType dType;
        private boolean selected;

        public boolean getSelected() {
            if (this.selected == null) this.selected = false;
            return this.selected;
        }

        public void setSelected(boolean b) {
            this.selected = b;
        }

        Field(DynamicSObject sobj, Schema.SObjectField f) {
            this.sobj = sobj;
            this.f = f;
            this.selected = false;
            Schema.DescribeFieldResult r = f.getDescribe();
            this.name = r.getName();
            this.dType = r.getType();
            this.isChangeable = dtype == DisplayType.ID || (r.isAccessible() && r.isUpdateable() && !r.isCalculated() && !r.isAutoNumber());
            this.isReference = dtype == DisplayType.Reference || dtype == DisplayType.ID;
            this.isFilterable = r.isFilterable();
            getValue();
        }

        public boolean getIsChangeable() {
            return this.isChangeable;
        }

        public boolean getIsReference() {
            return this.isReference;
        }

        public String getName() {
            return this.name;
        }

        public Object getValue() {
            return sobj.getSObject().get(f);
            //Object value = sobj.get(f);
            //return value != null ? String.valueOf(value) : null;
        }

        public Object getDisplayValue() {
            Object value = getValue();
            if (!isFilterable && dType == DisplayType.TextArea) {
                return formatText(value);
            } else if (value == null || String.valueOf(value) == '') {
                return ' ';
            } else if (dType == DisplayType.Currency) {
                return formatCurrency(value);
            } else if (dType == DisplayType.Date || dType == DisplayType.DateTime) {
                return formatDate(value);
            } else if (isReference) {
                return formatReference(value);
            } else {
                return value;
            }
        }
        
        public String getRefUrl() {
            Object value = getValue();
            String refField = sobj.getReferenceFields().get(name);
            String url = '/' + value;
            if (refField != null) {
                if (dtype == DisplayType.ID) {
                    if (sobj.name.equals('Idea')) {
                        url = '/ideas/viewIdea.apexp?id=' + value;
                    }
   
                } else {
                    if (sobj.name.equals('Idea') && name.equals('LastCommentId')) {
                        url = '/ideas/editComment.apexp?id=' + value;
                    } else if (name.equals('RecordTypeId')) {
                        url = '/setup/ui/recordtypefields.jsp?id=' + value;
                    }
                    String[] ref = refField.split('\\.', 2);
                    SObject s = sobj.getSObject().getSObject(ref[0]);
                    if (s == null) {
                        //This mean user does not have access to the reference record
                        //throw new DynamicSObjectException('Invalid reference: ' + refField + ' for field: ' + name);
                    } else {
                        if (s.getSObjectType().getDescribe().getName().equals('Idea')) {
                            url = '/ideas/viewIdea.apexp?id=' + value;
                        }
                    }
                }
            }
            if (sobj.name.equals('Idea') && name.equals('LastCommentId')) {
                url = '/ideas/editComment.apexp?id=' + value;
            }
            return url;
        } 
    
        public Object getRefName() {
            Object refName = getValue();
            String refField = sobj.getReferenceFields().get(name);

            if (refField != null) {
                if (dtype == DisplayType.ID) {
                    refName = sobj.getSObject().get(refField);
                } else {
                    String[] ref = refField.split('\\.', 2);
                    SObject s = sobj.getSObject().getSObject(ref[0]);
                    if (s == null) {
                        //This mean user does not have access to the reference record
                        //throw new DynamicSObjectException('Invalid reference: ' + refField + ' for field: ' + name);
                    } else {
                        refName = s.get(ref[1]);
                    }
                }
            }

            return refName;      
        }  

        private String formatDate(Object value) {
            // Date/Time field type not converted to Datetime data type using sObject.get(...)
            if (dtype == DisplayType.DateTime)
                return DateTime.valueOf(String.valueOf(value)).format();
            else if (value instanceOf Date)
                return ((Date)value).format();
            else if (value instanceOf DateTime)
                return ((DateTime)value).format();
            else
                return String.valueOf(value);
        }

        private Object formatText(Object value) {
           if (value == null)  value = '';
           String val = String.valueOf(value);
           if (val.length() > 255) {
              val = val.subString(0, 255);
              val += '... (more)';
           }
           String text = '';
           Integer start = 0;
           Integer count = 7;
           while (start < val.length()) {
              Integer offset = Math.min(45, val.length()-start);
              text += val.substring(start, start+offset) + '<br/>';
              start += offset;
              count--;
           }
           while (count > 0) {
             text += '<br/>';
             count--;
           }
           return '<p style="margin-left: 2em;">' + text + '</p>';
        }

        private Object formatCurrency(Object value) {
            if (UserInfo.isMultiCurrencyOrganization() && value != null && value != '') {
                Object isoCode = null;
                try {
                    isoCode = sobj.getSObject().get('CurrencyIsoCode');
                } catch (System.SObjectException ex) {
                    // Field was not selected in the select list
                }
                if (isoCode != null && isoCode != '')
                    return isoCode + ' ' + value;
                else
                    return value;
            }
            return value;
        }

        private String formatReference(Object value) {
            Object refName = value;
            String refField = sobj.getReferenceFields().get(name);
            String url = '/' + value;
            if (refField != null) {
                if (dtype == DisplayType.ID) {
                    if (sobj.name.equals('Idea')) {
                        url = '/ideas/viewIdea.apexp?id=' + value;
                    }
                    refName = sobj.getSObject().get(refField);
                } else {
                    if (sobj.name.equals('Idea') && name.equals('LastCommentId')) {
                        url = '/ideas/editComment.apexp?id=' + value;
                    } else if (name.equals('RecordTypeId')) {
                        url = '/setup/ui/recordtypefields.jsp?id=' + value;
                    }
                    String[] ref = refField.split('\\.', 2);
                    SObject s = sobj.getSObject().getSObject(ref[0]);
                    if (s == null) {
                        //This mean user does not have access to the reference record
                        //throw new DynamicSObjectException('Invalid reference: ' + refField + ' for field: ' + name);
                    } else {
                        if (s.getSObjectType().getDescribe().getName().equals('Idea')) {
                            url = '/ideas/viewIdea.apexp?id=' + value;
                        }
                        refName = s.get(ref[1]);
                    }
                }
            }
            if (sobj.name.equals('Idea') && name.equals('LastCommentId')) {
                url = '/ideas/editComment.apexp?id=' + value;
            }
            return '<a href="' + url + '">' + refName + '<a/>';
        }

        public void setValue(Object value) {
            if (value == null)
                sobj.getSObject().put(f, null);
            else
                sobj.getSObject().put(f, convertDataType(value));
        }

        private Object convertDataType(Object value) {
            if (value == null) {
                return value;
            // Handle data type conversions
            } else if (dType == DisplayType.Base64) {
                return Blob.valueOf(String.valueOf(value));
            } else if (dType == DisplayType.Boolean) {
                return Boolean.valueOf(value);
            } else if (dType == DisplayType.Currency) {
                return Decimal.valueOf(String.valueOf(value));
            } else if (value instanceof Date && dType == DisplayType.Date) {
                return Date.valueOf(value);
            } else if (value instanceof DateTime && dType == DisplayType.DateTime) {
                return DateTime.valueOf(value);
            } else if (value instanceof Date && dType == DisplayType.DateTime) {
                return DateTime.valueOf(String.valueOf(value));
            } else if (dType == DisplayType.Integer) {
               return Integer.valueOf(value);
            } else if (dType == DisplayType.Double || dType == DisplayType.Percent) {
                return Double.valueOf(String.valueOf(value));
            } else if (dType == DisplayType.Email || dType == DisplayType.Phone || dType == DisplayType.Picklist ||
                    dType == DisplayType.MultiPicklist || dType == DisplayType.String || dType == DisplayType.TextArea ||
                    dType == DisplayType.Url || dType == DisplayType.ID || dType == DisplayType.Reference) {
                return String.valueOf(value);
            } else {
                return value;
            }
        }
    }
}