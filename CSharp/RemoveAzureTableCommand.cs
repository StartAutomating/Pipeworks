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

    [Cmdlet(VerbsCommon.Remove, "AzureTable", ConfirmImpact=ConfirmImpact.High, SupportsShouldProcess=true)]
    public class RemoveAzureTableCommand : AzureTableCmdletBase
    {
        #region Parameters

        [Parameter(Mandatory = true, Position=0,ValueFromPipelineByPropertyName = true)]
        [Alias("Name")]
        public string TableName
        {
            get;
            set;
        }
        
        [Parameter(Position=1,ValueFromPipelineByPropertyName = true)]        
        public string PartitionKey
        {
            get;
            set;
        }
        
        [Parameter(Position=2,ValueFromPipelineByPropertyName = true)]        
        public string RowKey
        {
            get;
            set;
        }
                
        #endregion

        private bool DeleteTable(string tableName)
        {
            return Retry<bool>(delegate()
            {
                HttpWebResponse response;
                List<AzureTable> tables = new List<AzureTable>();
                try
                {
                    response = CreateRESTRequest("DELETE", "Tables('" + tableName + "')", String.Empty, null, String.Empty, String.Empty).GetResponse() as HttpWebResponse;                    
                    response.Close();

                    return true;
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.ProtocolError &&
                        ex.Response != null &&
                        (int)(ex.Response as HttpWebResponse).StatusCode == 409)
                        return false;

                    throw;
                }
            });
        }
        
        public bool DeleteEntity(string tableName, string partitionKey, string rowKey)
        {
            return Retry<bool>(delegate()
            {
                HttpWebRequest request;
                HttpWebResponse response;

                try
                {
                    string resource = String.Format(tableName + "(PartitionKey='{0}',RowKey='{1}')", partitionKey, rowKey);

                    SortedList<string, string> headers = new SortedList<string, string>();
                    headers.Add("If-Match", "*");

                    request = CreateRESTRequest("DELETE", resource, null, headers, String.Empty, String.Empty);

                    response = request.GetResponse() as HttpWebResponse;
                    response.Close();

                    return true;
                }
                catch (WebException ex)
                {
                    if (ex.Status == WebExceptionStatus.ProtocolError &&
                        ex.Response != null &&
                        (int)(ex.Response as HttpWebResponse).StatusCode == 409)
                        return false;

                    throw;
                }
            });
        }

        protected override void ProcessRecord()
        {
            
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; } 
            
            if (this.MyInvocation.BoundParameters.ContainsKey("TableName") && 
                this.MyInvocation.BoundParameters.ContainsKey("PartitionKey") &&                this.MyInvocation.BoundParameters.ContainsKey("RowKey")) {
                if (this.ShouldProcess(TableName + "/" + PartitionKey + "/" + RowKey))
                {
                    DeleteEntity(TableName, PartitionKey, RowKey);
                }
            } else if (this.MyInvocation.BoundParameters.ContainsKey("TableName") && 
                this.MyInvocation.BoundParameters.ContainsKey("PartitionKey")) {
                // Name and Partition                if (this.ShouldProcess(TableName + "/" + PartitionKey)) {                }
            } else {                // Just Name
                if (this.ShouldProcess(TableName))
                {
                    DeleteTable(TableName);
                }
            }                                             
        }
    }
}
