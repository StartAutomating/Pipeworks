namespace AzureStorageCmdlets
{
    using System;
    using System.Collections.Generic;
    using System.Text;
    using System.Net;
    using System.IO;
    using System.Management.Automation;
    using System.Linq;
    using System.Xml.Linq;

    public class AzureTable
    {
        public Uri TableId
        {
            get;
            set;
        }

        public DateTime Updated
        {
            get;
            set;
        }

        public string TableName
        {
            get;
            set;
        }
    }


    [Cmdlet(VerbsCommon.Get, "AzureTable", DefaultParameterSetName="GetATable")]
    public class GetAzureTableCommand : AzureTableCmdletBase
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true,  Position=0,ParameterSetName = "GetSpecificItem")]
        [Parameter(ValueFromPipelineByPropertyName = true,  Position=0,ParameterSetName = "GetATable")]        
        [Alias(new string[] { "Name", "Table" })]
        public string TableName
        {
            get;
            set;
        }

        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, Position=1,ParameterSetName = "GetSpecificItem")]
        [Alias(new string[] { "TablePart", "TablePartition", "PartitionKey" })]
        public string Partition
        {
            get;
            set;
        }

        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, Position=2,ParameterSetName = "GetSpecificItem")]
        [Alias(new string[] { "TableRow", "RowKey" })]
        public string Row
        {
            get;
            set;
        }
        
        [Parameter()]
        public SwitchParameter ExcludeTableInfo
        {
            get;
            set;
        }

        private List<AzureTable> ListTables()
        {
            return Retry<List<AzureTable>>(delegate()
            {
                HttpWebResponse response;
                List<AzureTable> tables = new List<AzureTable>();

                tables = new List<AzureTable>();

                try
                {
                    response = CreateRESTRequest("GET", "Tables", String.Empty, null, String.Empty, String.Empty).GetResponse() as HttpWebResponse;

                    if ((int)response.StatusCode == 200)
                    {
                        using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                        {
                            string result = reader.ReadToEnd();

                            XNamespace ns = "http://www.w3.org/2005/Atom";
                            XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";

                            XElement x = XElement.Parse(result, LoadOptions.SetBaseUri);

                            foreach (XElement table in x.Descendants(ns + "entry"))
                            {
                                AzureTable tableOutput = new AzureTable();
                                tableOutput.TableId = new Uri(table.Descendants(ns + "id").First().Value);
                                tableOutput.TableName = table.Descendants(d + "TableName").First().Value;
                                tableOutput.Updated = (DateTime)LanguagePrimitives.ConvertTo((table.Descendants(ns + "updated").First().Value), DateTime.Now.GetType());
                                tables.Add(tableOutput);
                            }
                        }
                    }

                    response.Close();

                    return tables;
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.ProtocolError &&
                        ex.Response != null &&
                        (int)(ex.Response as HttpWebResponse).StatusCode == 404)
                        return null;

                    throw;
                }
            });
        }

        // Retrieve an entity. Returns entity XML.
        // Return true on success, false if not found, throw exception on error.

        private string GetEntity(string tableName, string partitionKey, string rowKey)
        {
            return Retry<string>(delegate()
            {
                HttpWebRequest request;
                HttpWebResponse response;

                string entityXml = null;

                try
                {
                    string resource = String.Format(tableName + "(PartitionKey='{0}',RowKey='{1}')", partitionKey, rowKey);

                    SortedList<string, string> headers = new SortedList<string, string>();
                    headers.Add("If-Match", "*");

                    request = CreateRESTRequest("GET", resource, null, headers, String.Empty, String.Empty);

                    request.Accept = "application/atom+xml";

                    response = request.GetResponse() as HttpWebResponse;

                    if ((int)response.StatusCode == 200)
                    {
                        using (StreamReader reader = new StreamReader(response.GetResponseStream()))
                        {
                            string result = reader.ReadToEnd();                            
                            if (! String.IsNullOrEmpty(result)) {
                                XNamespace ns = "http://www.w3.org/2005/Atom";
                                XNamespace d = "http://schemas.microsoft.com/ado/2007/08/dataservices";
                                
                                XElement entry = XElement.Parse(result);

                                entityXml = entry.ToString();
                            }

                        }
                    }

                    response.Close();

                    return entityXml;
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.ProtocolError &&
                        ex.Response != null)
                    {
                        WriteWebError(ex, tableName + ":" + partitionKey + ":" + rowKey);
                        return String.Empty;
                    }
                    return String.Empty;
                }
            });
        }



        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; }
            if (this.ParameterSetName == "GetATable")
            {
                if (String.IsNullOrEmpty(this.TableName)) {
                    WriteObject(ListTables(), true);
                } else {
                    foreach (AzureTable at in ListTables()) {
                        if (this.TableName.Contains('?') || this.TableName.Contains('*')) {
                            WildcardPattern wp = new WildcardPattern(this.TableName);
                            if (wp.IsMatch(at.TableName)) {
                                WriteObject(at);
                            }
                        } else {
                            if (String.Compare(at.TableName, this.TableName, StringComparison.InvariantCultureIgnoreCase) == 0) {
                                WriteObject(at);
                            }
                        }
                        
                    }    
                }                
            } else if (this.ParameterSetName == "GetSpecificItem") {
                string itemXml = GetEntity(this.TableName, this.Partition, this.Row);
                WriteObject(ExpandObject(itemXml, (!ExcludeTableInfo), this.TableName), true);                
            }            
        }
    }
}
