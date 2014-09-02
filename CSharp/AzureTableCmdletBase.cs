namespace AzureStorageCmdlets
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using System.Management.Automation;
    using System.Net;
    using System.IO;
    using System.Linq;
    using System.Xml.Linq;
    using System.Security;
    using System.Collections;
    using System.Collections.ObjectModel;

    public class AzureTableCmdletBase: AzureStorageCmdletBase
    {
        public override string Endpoint
        {
            get {
                return "http://" + StorageAccount + ".table.core.windows.net/";
            }
        }                                                

        // Query entities. Returned entity list XML matching query filter.
        // Return true on success, false if not found, throw exception on error.
        protected string QueryEntities(string tableName, string partition,  string row, string filter, string sort, string select, uint first)
        {
            return Retry<string>(delegate()
            {
                HttpWebRequest request;
                HttpWebResponse response;

                string entityXml = null;

                try
                {
                    string resource = tableName;
                    if (
                        !String.IsNullOrEmpty(row)
                        &&
                        !String.IsNullOrEmpty(partition)
                    )
                    {
                        resource += @"(PartitionKey=""" + partition + @""",RowKey=""" + row + @""")?";
                    }
                    else
                    {
                        resource += "()?";
                    }
                    if (!String.IsNullOrEmpty(sort))
                    {
                        resource += "$OrderBy=" + sort + "&";
                    }
                    
                    if (!String.IsNullOrEmpty(filter))
                    {
                        resource += "$filter=" + Uri.EscapeDataString(filter) + "&";
                    }
                    if (!String.IsNullOrEmpty(select))
                    {
                        resource += "$select=" + select + "&";
                    }

                    if (first > 0)
                    {
                        resource += "$top=" + first + "&";
                    }
                    
                    resource = resource.TrimEnd('&');                   
                    this.WriteVerbose("Creating Request for " + (Endpoint + resource));
                    SortedList<string, string> headers = new SortedList<string, string>();
                    if (! String.IsNullOrEmpty(nextTable)) {
                        
                        resource += ("&NextTableName=" + nextTable);
                        WriteVerbose("NextTable" + nextTable);
                    }
                    if (! String.IsNullOrEmpty(nextPart)) {
                        
                        resource += ("&NextPartitionKey=" + nextPart);
                        WriteVerbose("NextPart" + nextPart);
                    }
                    if (! String.IsNullOrEmpty(nextRow)) {
                        
                        resource += ("&NextRowKey=" + nextRow);
                        WriteVerbose("NextRow" + nextRow);
                    }
                    if (headers.Count == 0) {
                        headers = null;
                    }                    
                    request = CreateRESTRequest("GET", resource, null, headers, null, null);
                    nextRow = String.Empty;
                    nextPart = String.Empty;
                    request.Accept = "application/atom+xml,application/xml";

                    response = request.GetResponse() as HttpWebResponse;

                    if ((int)response.StatusCode == 200)
                    {
                        using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                        {
                            string result = reader.ReadToEnd();

                            XNamespace ns = "http://www.w3.org/2005/Atom";
                            XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";

                            XElement entry = XElement.Parse(result);

                            entityXml = entry.ToString();
                        }
                    }

                    response.Close();
                    string nextRowHeader = response.Headers["x-ms-continuation-NextRowKey"];
                    if (! (String.IsNullOrEmpty(nextRowHeader))) {
                        nextRow = nextRowHeader;
                    }
                    string nextPartHeader = response.Headers["x-ms-continuation-NextPartitionKey"];
                    if (! (String.IsNullOrEmpty(nextPartHeader))) {
                        nextPart = nextPartHeader;
                    }
                    string nextTableName = response.Headers["x-ms-continuation-NextTableName"];
                    if (! (String.IsNullOrEmpty(nextTableName))) {
                        nextTable = nextPartHeader;
                    }
                    return entityXml;
                }
                catch (WebException ex)
                {
                    WriteWebError(ex, "Table: " + tableName + " Filter: " + filter);
                    return string.Empty;
                }
            });
        }

        protected string nextRow;
        protected string nextPart;
        protected string nextTable;

        protected PSObject InsertEntity(string tableName, string partitionKey, string rowKey, PSObject obj, string author, string email, bool update, bool merge, bool excludeTableInfo)
        {
            return Retry<PSObject>(delegate()
            {
                HttpWebResponse response;

                try
                {
                    // Create properties list. Use reflection to retrieve properties from the object.

                    StringBuilder properties = new StringBuilder();
                    properties.Append(string.Format("<d:{0}>{1}</d:{0}>\n", "PartitionKey", partitionKey));
                    properties.Append(string.Format("<d:{0}>{1}</d:{0}>\n", "RowKey", rowKey));

                    string lastTypeName = obj.TypeNames.Last();
                    if (lastTypeName != "System.Object" && lastTypeName != "System.Management.Automation.PSObject")
                    {
                    
                        properties.Append(string.Format("<d:psTypeName>{0}</d:psTypeName>\n", SecurityElement.Escape(lastTypeName)));
                    }
                    foreach (PSPropertyInfo p in obj.Properties)
                    {
                        try
                        {
                            
                            string valueToInsert = (string)LanguagePrimitives.ConvertTo(p.Value, typeof(string));
                            
                            properties.Append(string.Format("<d:{0}>{1}</d:{0}>\n", p.Name, SecurityElement.Escape(valueToInsert)));
                        }
                        catch
                        {

                        }
                    }

                    string now = DateTime.UtcNow.ToString("o", System.Globalization.CultureInfo.InvariantCulture);
                    string id = String.Empty;
                    if (update || merge)
                    {
                        id = String.Format("http://{0}.table.core.windows.net/{1}(PartitionKey='{2}',RowKey='{3}')", StorageAccount, tableName, partitionKey, rowKey);
                    }
                    string requestBody = String.Format("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?>" +
                                          "<entry xmlns:d=\"http://schemas.microsoft.com/ado/2007/08/dataservices\"" +
                                          "       xmlns:m=\"http://schemas.microsoft.com/ado/2007/08/dataservices/metadata\"" +
                                          "       xmlns=\"http://www.w3.org/2005/Atom\"> " +
                                          "  <title /> " +
                                          "  <updated>{0}</updated> " +
                                          "  <author>" +
                                          "    <name/> " +
                                          "  </author> " +
                                          "  <id>{1}</id> " +
                                          "  <content type=\"application/xml\">" +
                                          "  <m:properties>" +
                                          "{2}" +
                                          "  </m:properties>" +
                                          "  </content> " +
                                          "</entry>",
                                          now,
                                          id,
                                          properties);

                    if (!String.IsNullOrEmpty(author))
                    {
                        if (!String.IsNullOrEmpty(email))
                        {
                            requestBody.Replace("<name/>", ("<name>" + SecurityElement.Escape(author) + "</name><email>" + SecurityElement.Escape(email) + "</email>"));
                        }
                        else
                        {
                            requestBody.Replace("<name/>", ("<name>" + SecurityElement.Escape(author) + "</name>"));
                        }

                    }

                    if (merge)
                    {
                        string resource = String.Format(tableName + "(PartitionKey='{0}',RowKey='{1}')", partitionKey, rowKey);
                        SortedList<string, string> headers = new SortedList<string, string>();
                        headers.Add("If-Match", "*");
                        response = CreateRESTRequest("MERGE", resource, requestBody, headers, String.Empty, String.Empty).GetResponse() as HttpWebResponse;
                    }
                    else if (update)
                    {
                        string resource = String.Format(tableName + "(PartitionKey='{0}',RowKey='{1}')", partitionKey, rowKey);
                        SortedList<string, string> headers = new SortedList<string, string>();
                        headers.Add("If-Match", "*");

                        response = CreateRESTRequest("PUT", resource, requestBody, headers, String.Empty, String.Empty).GetResponse() as HttpWebResponse;
                    }
                    else
                    {
                        response = CreateRESTRequest("POST", tableName, requestBody, null, String.Empty, String.Empty).GetResponse() as HttpWebResponse;
                    }

                    if (response.StatusCode == HttpStatusCode.Created)
                    {
                        using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                        {
                            string result = reader.ReadToEnd();

                            XNamespace ns = "http://www.w3.org/2005/Atom";
                            XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";
                            XNamespace m = "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata";
                            return RecreateObject(result, ! excludeTableInfo, tableName).First();                            
                        }
                    }
                    response.Close();

                    return null;
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.ProtocolError &&
                        ex.Response != null)

                        WriteError(
                            new ErrorRecord(
                                new InvalidOperationException(
                                    ((ex.Response as HttpWebResponse).StatusCode.ToString()) + "-- Table: " + tableName + "Partition: " + partitionKey + "Row: " + rowKey),
                                    "SetAzureTableCommand.WebError." + ((int)(ex.Response as HttpWebResponse).StatusCode).ToString(),
                                    ErrorCategory.InvalidOperation,
                                    this)
                                    );
                    return null;
                }
            });
        }
        
        protected IEnumerable ExpandObject(string atomXml, bool includeTableInfo, string fromTable) 
        {
            if (String.IsNullOrEmpty(atomXml)) {
                yield break;
            }
            XNamespace m = "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata";
            this.WriteDebug(atomXml);
            
            XElement entry = XElement.Parse(atomXml);
            


            foreach (XElement propertyGroup in entry.Descendants(m + "properties"))
            {
                PSObject returnObject = new PSObject();
                foreach (XElement element in propertyGroup.Descendants())
                {
                    if (element.Name.LocalName == "psTypeName")
                    {
                        returnObject.TypeNames.Clear();
                        foreach (string typename in element.Value.Split(',')) {
                            returnObject.TypeNames.Add(typename);    
                        }
                        
                    } else if (element.Name.LocalName == "PartitionKey") {                        
                        if (!includeTableInfo) { continue;} 
                        PSNoteProperty noteProperty = new PSNoteProperty("PartitionKey", element.Value);
                        try {                                                        
                            returnObject.Properties.Add(noteProperty);
                        } catch {
                            try {
                                // Remove the old and replace with the new
                                returnObject.Properties.Remove(noteProperty.Name);
                                returnObject.Properties.Add(noteProperty);
                            } catch {
                            
                            }
                        }
                    } else if (element.Name.LocalName == "RowKey") {
                       if (!includeTableInfo) { continue;} 
                       PSNoteProperty noteProperty = new PSNoteProperty("RowKey", element.Value);
                       try {                                                                                        
                            returnObject.Properties.Add(noteProperty);
                       } catch {
                            try {
                                // Remove the old and replace with the new
                                returnObject.Properties.Remove(noteProperty.Name);
                                returnObject.Properties.Add(noteProperty);
                            } catch {
                            
                            }
                        }                            
                    } else if (element.Name.LocalName == "Timestamp") {                            
                        if (!includeTableInfo) { continue;}  
                        try {
                            DateTime lastUpdated = DateTime.Parse(element.Value);
                            PSNoteProperty noteProperty = new PSNoteProperty("Timestamp", lastUpdated);
                            returnObject.Properties.Add(noteProperty);
                        } catch {
                            try {
                                // Remove the old and replace with the new
                                returnObject.Properties.Remove("Timestamp");
                                PSNoteProperty noteProperty = new PSNoteProperty("Timestamp", element.Value);
                                returnObject.Properties.Add(noteProperty);
                            } catch {
                            
                            }
                        }                        
                    
                    } else {
                        PSNoteProperty noteProperty = new PSNoteProperty(element.Name.LocalName, element.Value);
                        returnObject.Properties.Add(noteProperty);
                    }
                }
                if (includeTableInfo)
                {                    
                    try {
                        PSNoteProperty noteProperty = new PSNoteProperty("TableName", fromTable);
                        returnObject.Properties.Add(noteProperty);                    
                    } catch {
                    
                    }
                }
                yield return returnObject;
            }
                                                    
        }

        protected Collection<PSObject> RecreateObject(string atomXml, bool includeTableInfo, string fromTable)
        {
            if (String.IsNullOrEmpty(atomXml)) {
                return null;
            }
            Collection<PSObject> psObjects = new Collection<PSObject>();
            XNamespace ns = "http://www.w3.org/2005/Atom";
            XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";
            XNamespace m = "http://schemas.microsoft.com/ado/2007/08/dataservices/metadata";
            this.WriteVerbose("Recreating Object From ATOM:" + Environment.NewLine + atomXml);
            XElement entry = XElement.Parse(atomXml);
            
            

            foreach (XElement propertyGroup in entry.Descendants(m + "properties"))
            {
                PSObject returnObject = new PSObject();
                foreach (XElement element in propertyGroup.Descendants())
                {
                    if (element.Name.LocalName == "psTypeName")
                    {
                        returnObject.TypeNames.Clear();
                        foreach (string typename in element.Value.Split(',')) {
                            returnObject.TypeNames.Add(typename);    
                        }
                        
                    }
                    else if (element.Name.LocalName == "PartitionKey")
                    {
                        if (includeTableInfo)
                        {
                            returnObject.Properties.Remove("PartitionKey");                            
                            PSNoteProperty noteProperty = new PSNoteProperty("PartitionKey", element.Value);
                            returnObject.Properties.Add(noteProperty);
                        }
                    }
                    else if (element.Name.LocalName == "RowKey")
                    {
                        if (includeTableInfo)
                        {
                            returnObject.Properties.Remove("RowKey");
                            PSNoteProperty noteProperty = new PSNoteProperty("RowKey", element.Value);
                            returnObject.Properties.Add(noteProperty);
                        }
                    }
                    else if (element.Name.LocalName == "Timestamp")
                    {
                        if (includeTableInfo)
                        {
                            returnObject.Properties.Remove("Timestamp");
                            DateTime lastUpdated = (DateTime)LanguagePrimitives.ConvertTo(element.Value, typeof(DateTime));
                            PSNoteProperty noteProperty = new PSNoteProperty("Timestamp", element.Value);
                            returnObject.Properties.Add(noteProperty);
                        }
                    }
                    else
                    {
                        PSNoteProperty noteProperty = new PSNoteProperty(element.Name.LocalName, element.Value);
                        returnObject.Properties.Add(noteProperty);
                    }
                }
                if (includeTableInfo && !String.IsNullOrEmpty(fromTable))
                {                    
                    returnObject.Properties.Remove("TableName");
                    PSNoteProperty noteProperty = new PSNoteProperty("TableName", fromTable);
                    returnObject.Properties.Add(noteProperty);                    
                }
                psObjects.Add(returnObject);
            }
                                        
            return psObjects;
        }

        protected override bool IsTableStorage
        {
            get
            {
                return true;
            }
        }
    }
}
