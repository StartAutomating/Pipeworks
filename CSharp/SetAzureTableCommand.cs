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
    using System.Reflection;

    [Cmdlet(VerbsCommon.Set, "AzureTable", SupportsShouldProcess=true)]
    public class SetAzureTableCommand : AzureTableCmdletBase
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName=true)]
        [Alias("Name")]        
        public string TableName
        {
            get;
            set;
        }

        [Parameter(ValueFromPipelineByPropertyName=true)]
        [Alias(new string[] { "TablePart", "TablePartition", "Partition" })]       
        public string PartitionKey
        {
            get;
            set;
        }
        
        [Parameter(ValueFromPipelineByPropertyName=true)]
        [Alias(new string[] { "TableRow", "Row"})]
        public string RowKey
        {
            get;
            set;
        }

        [Parameter(Mandatory=true,Position=0,ValueFromPipeline=true)]
        public PSObject InputObject
        {
            get;
            set;
        }


        [Parameter()]
        public SwitchParameter PassThru
        {
            get;
            set;
        }

        [Parameter(ValueFromPipelineByPropertyName=true)]
        public string Author
        {
            get;
            set;
        }

        [Parameter(ValueFromPipelineByPropertyName=true)]
        public string Email
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
                
        
        [Parameter()]
        public int StartAtRow
        {
            get { return rowNumber; }
            set { rowNumber = value; }
        }

        int rowNumber = 0;
        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; }
            if (! (this.MyInvocation.BoundParameters.ContainsKey("RowKey")))
            {
                RowKey = this.rowNumber.ToString();
                rowNumber++;
            }
            if (!(this.MyInvocation.BoundParameters.ContainsKey("PartitionKey")))
            {
                PartitionKey = "Default"; 
            }
            if (this.ShouldProcess(this.TableName + "/" + this.PartitionKey + "/" + this.RowKey)) {
                if (PassThru)
                {
                    WriteObject(
                        InsertEntity(this.TableName, this.PartitionKey, this.RowKey, this.InputObject, this.Author, this.Email, false, false, ExcludeTableInfo), 
                        true);
                }
                else
                {
                    InsertEntity(this.TableName, this.PartitionKey, this.RowKey, this.InputObject, this.Author, this.Email, false, false, true);
                }
            }                        
        }
    }
}
