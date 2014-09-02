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

    [Cmdlet(VerbsData.Update, "AzureTable")]
    public class UpdateAzureTableCommand: AzureTableCmdletBase
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true)]
        [Alias("Name")]
        public string TableName
        {
            get;
            set;
        }

        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true)]
        [Alias(new string[] { "TablePart", "TablePartition"})]
        public string PartitionKey
        {
            get;
            set;
        }

        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true)]
        [Alias(new string[] { "TableRow"})]
        public string RowKey
        {
            get;
            set;
        }

        [Parameter(Mandatory = true, Position = 0, ValueFromPipeline=true, ValueFromPipelineByPropertyName = true)]
        public PSObject Value
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

        [Parameter()]
        public string Author
        {
            get;
            set;
        }

        [Parameter()]
        public string Email
        {
            get;
            set;
        }

        [Parameter()]
        public SwitchParameter Merge
        {
            get;
            set;
        }

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; }
            InsertEntity(this.TableName, this.PartitionKey, this.RowKey, this.Value, this.Author, this.Email, true, Merge, true);
        }
    }
}
