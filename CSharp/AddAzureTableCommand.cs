using System;
using System.Collections.Generic;
using System.Text;
using System.Management.Automation;
using System.Net;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using System.Security;

namespace AzureStorageCmdlets
{
    [Cmdlet(VerbsCommon.Add, "AzureTable")]
    public class AddAzureTableCommand : AzureTableCmdletBase
    {
        [Parameter(Mandatory = true, Position=0, ValueFromPipelineByPropertyName = true)]
        [Alias("Name")]
        public string TableName
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

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string Author
        {
            get;
            set;
        }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string Email
        {
            get;
            set;
        }

        private List<AzureTable> CreateTable(string tableName)
        {
            return Retry<List<AzureTable>>(delegate()
            {
                HttpWebResponse response;
                List<AzureTable> tables = new List<AzureTable>();

                try
                {
                    string now = DateTime.UtcNow.ToString("o");

                    string requestBody = String.Format("<?xml version=\"1.0\" encoding=\"utf-8\" standalone=\"yes\"?>" +
                                          "<entry xmlns:d=\"http://schemas.microsoft.com/ado/2007/08/dataservices\"" +
                                          "       xmlns:m=\"http://schemas.microsoft.com/ado/2007/08/dataservices/metadata\"" +
                                          "       xmlns=\"http://www.w3.org/2005/Atom\"> " +
                                          "  <title /> " +
                                          "  <updated>" + now + "</updated> " +
                                          "  <author>" +
                                          "    <name/> " +
                                          "  </author> " +
                                          "  <id/> " +
                                          "  <content type=\"application/xml\">" +
                                          "    <m:properties>" +
                                          "      <d:TableName>{0}</d:TableName>" +
                                          "    </m:properties>" +
                                          "  </content> " +
                                          "</entry>",
                                          tableName);

                    if (! String.IsNullOrEmpty(Author)) {
                        if (!String.IsNullOrEmpty(Email)) {
                            requestBody.Replace("<name/>", ("<name>" + SecurityElement.Escape(Author) + "</name><email>" + SecurityElement.Escape(Email) +  "</email>"));
                        } else {
                            requestBody.Replace("<name/>", ("<name>" + SecurityElement.Escape(Author) + "</name>"));
                        }
                        
                    }
                    response = CreateRESTRequest("POST", "Tables", requestBody, null, null, null).GetResponse() as HttpWebResponse;
                    if (response.StatusCode == HttpStatusCode.Created)
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
                        (int)(ex.Response as HttpWebResponse).StatusCode == 409)
                        return null;

                    throw;
                }
            });
        }

        protected override void ProcessRecord()
        {
            // Calling the base processrecord 
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; } 

            if (PassThru)
            {
                this.WriteObject(CreateTable(TableName), true);
            }
            else
            {
                CreateTable(TableName);
            }
            
        }
    }
}
