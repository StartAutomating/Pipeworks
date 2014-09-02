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
    using System.Collections.ObjectModel;
    using System.Collections.Specialized;

    [Cmdlet(VerbsCommon.Search, "AzureTable", DefaultParameterSetName="WholeTable")]
    public class SearchAzureTableCommand : AzureTableCmdletBase
    {
        [Parameter(Mandatory = true,
            Position=0,
            ValueFromPipelineByPropertyName=true )]       
        [Alias(new string[] { "Name", "Table" })]
        public string TableName
        {
            get;
            set;
        }

        [Parameter(Mandatory = true,ParameterSetName="FilterString")]
        public string Filter
        {
            get;
            set;
        }
        
        [Parameter(Mandatory = true,ValueFromPipelineByPropertyName=true,ParameterSetName="ContinueSearch")]
        public string NextRowKey
        {
            get;
            set;
        }
        
        [Parameter(Mandatory = true,ValueFromPipelineByPropertyName=true,ParameterSetName="ContinueSearch")]
        public string NextPartition
        {
            get;
            set;
        }
        
        [Parameter(ParameterSetName="ContinueSearch")]
        public uint Next
        {
            get;
            set;
        }
        
        

        [Parameter(Mandatory = true, 
            Position=1, 
            ParameterSetName = "WhereBlock")]
        public ScriptBlock[] Where
        {
            get;
            set;
        }

        [Parameter(ParameterSetName = "WhereBlock")]
        public SwitchParameter Or
        {
            get;
            set;
        }

        

        [Parameter()]			        
        public string[] Select
        {
            get;
            set;
        }

                
        public string[] Sort
        {
            get;
            set;
        }
        
        [Parameter(ValueFromPipelineByPropertyName=true)]
        public uint BatchSize
        {
            get;
            set;
        }
        
        [Parameter(ValueFromPipelineByPropertyName=true)]
        public uint First
        {
            get;
            set;
        }
                
        
        public uint Skip
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

        protected override void ProcessRecord()
        {
            base.ProcessRecord();
            if (String.IsNullOrEmpty(StorageAccount) || String.IsNullOrEmpty(StorageKey)) { return; }
            #region WhereBlockTranslation
            this.WriteVerbose(this.ParameterSetName);
            if (this.ParameterSetName == "WhereBlock")
            {
                
                StringCollection filterList = new StringCollection();

                foreach (ScriptBlock whereBlock in Where)
                {
                    this.WriteVerbose(String.Format("Processing Where Clause {0}", whereBlock.ToString()));
                    string whereString = whereBlock.ToString();
                    if (whereString.Length > 512)
                    {
                        WriteError(
                                new ErrorRecord(new Exception("Will not tokenize filters longer than 512 characters"),
                                    "SearchAzureTable.WhereBlockTooLong", ErrorCategory.InvalidArgument, whereBlock));
                        continue;
                    }

                    Collection<PSParseError> error = new Collection<PSParseError>(); ;
                    Collection<PSToken> tokens = PSParser.Tokenize(whereString, out error);
                    this.WriteVerbose(String.Format("Tokens Count {0}", tokens.Count.ToString()));
                    bool ok = true;
                    string adoFilter = String.Empty;
                    IEnumerator<PSToken> enumerator = tokens.GetEnumerator();                    
                    enumerator.MoveNext();
                    while (enumerator.Current != null)
                    {
                        this.WriteVerbose(String.Format("Processing {0}", enumerator.Current.ToString()));
                        if (enumerator.Current.Type != PSTokenType.Variable || enumerator.Current.Content != "_")
                        {
                            WriteError(
                                new ErrorRecord(new Exception("The first item in the filter script must $_"),
                                    "SearchAzureTable.FilterScriptMustStartWithDollarUnderbar", 
                                    ErrorCategory.InvalidArgument,
                                    enumerator.Current));
                            ok = false;
                            break;
                        }

                        if (!enumerator.MoveNext())
                        {
                            ok = false;
                            break;
                        }
                        if (enumerator.Current.Type != PSTokenType.Operator && enumerator.Current.Content != ".") {
                            WriteError(
                                new ErrorRecord(new Exception("$_ must be followed by the . operator"),
                                    "SearchAzureTable.FilterScriptDollarUnderBarMustBeFollowedByDot",
                                    ErrorCategory.InvalidArgument,
                                    enumerator.Current));
                            ok = false;
                            break;
                        }

                        if (!enumerator.MoveNext())
                        {
                            ok = false;
                            break;
                        }

                        if (enumerator.Current.Type != PSTokenType.Member)
                        {
                            WriteError(
                                new ErrorRecord(new Exception("The . operator must be followed by a property name"),
                                    "SearchAzureTable.FilterScriptDotMustBeFollowedByPropertyName",
                                    ErrorCategory.InvalidArgument,
                                    enumerator.Current));
                            ok = false;
                            break;
                        }

                        adoFilter += enumerator.Current.Content;


                        if (!enumerator.MoveNext())
                        {
                            ok = false;
                            break;
                        }


                        if (enumerator.Current.Type != PSTokenType.Operator)
                        {
                            WriteError(
                                new ErrorRecord(new Exception("The filter item must be followed by an operator"),
                                    "SearchAzureTable.FilterScriptItemMustBeFollowedByOperator",
                                    ErrorCategory.InvalidArgument,
                                    enumerator.Current));
                            ok = false;
                            break;
                        }

                        string[] validOperators = new string[] { "-gt", "-lt", "-ge", "-le", "-ne", "-eq" };
                        bool isValidOperator = false;
                        foreach (string validOp in validOperators) {
                            if (enumerator.Current.Content == validOp)
                            {
                                isValidOperator = true;
                                break;
                            }
                        }

                        if (!isValidOperator)
                        {
                            WriteError(
                               new ErrorRecord(new Exception(enumerator.Current.Content + @" is not a valid operator.  Please use ""-gt"", ""-lt"", ""-ge"", ""-le"", ""-ne"", ""-eq"""),
                                   "SearchAzureTable.FilterScriptUsesInvalidOperator",
                                   ErrorCategory.InvalidArgument,
                                   enumerator.Current));
                            ok = false;
                            break;
                        }

                        adoFilter += enumerator.Current.Content.Replace("-", " ");

                        if (!enumerator.MoveNext())
                        {
                            ok = false;
                            break;
                        }

                        this.WriteVerbose(String.Format("Comparing Tokens {0}", enumerator.Current.Type.ToString()));
                        if (! (enumerator.Current.Type == PSTokenType.Number || enumerator.Current.Type == PSTokenType.String))
                        {
                            WriteError(
                              new ErrorRecord(new Exception("The operator must be followed by a string or a number"),
                                  "SearchAzureTable.FilterScriptOperatorMustBeFollowedByStringOrNumber",
                                  ErrorCategory.InvalidArgument,
                                  enumerator.Current));
                            ok = false;
                            break;
                        }

                        if (enumerator.Current.Type == PSTokenType.String && enumerator.Current.Content.Contains("$("))
                        {
                            WriteError(
                              new ErrorRecord(new Exception("Variables expansion not allowed in filter script"),
                                  "SearchAzureTable.FilterScriptCannotContainVariables",
                                  ErrorCategory.InvalidArgument,
                                  enumerator.Current));
                            ok = false;
                            break;
                        }

                        adoFilter += " '" + this.SessionState.InvokeCommand.ExpandString(enumerator.Current.Content) + "'";
                        enumerator.MoveNext();
                    }
                    if (ok) { filterList.Add(adoFilter); } else {
                        return;
                    }
                }

                if (filterList.Count >= 1)
                {
                    if (filterList.Count > 1)
                    {
                        StringBuilder filterBuilder = new StringBuilder();
                        foreach (string f in filterList)
                        {
                            filterBuilder.Append("(");
                            filterBuilder.Append(f);
                            filterBuilder.Append(")");
                            if (Or)
                            {
                                filterBuilder.Append("or");
                            }
                            else
                            {
                                filterBuilder.Append("and");
                            }
                        }
                    }
                    else
                    {
                        Filter = filterList[0];
                    }
                }
            }
            #endregion


            string selectString = String.Empty;
            if (this.MyInvocation.BoundParameters.ContainsKey("Select"))
            {
                
                for (int i =0 ;i < Select.Length; i++) {
                    selectString+=Select[i];
                    if (i != (Select.Length - 1)) {
                        selectString += ",";
                    }
                }
            }

            string sortString = String.Empty;
            if (this.MyInvocation.BoundParameters.ContainsKey("Sort"))
            {
                
                for (int i = 0; i < Sort.Length; i++)
                {
                    sortString += Sort[i];
                    if (i != (Sort.Length - 1))
                    {
                        sortString  += ",";
                    }
                }
            }
            
            if (! this.MyInvocation.BoundParameters.ContainsKey("BatchSize")) {
                BatchSize  =640; 
            }
            
            
            

            bool thereIsMore =false;
            nextRow = String.Empty;
            if (this.MyInvocation.BoundParameters.ContainsKey("NextRowKey")) {
                nextRow = NextRowKey;
            }
            nextPart = String.Empty;
            if (this.MyInvocation.BoundParameters.ContainsKey("NextPartition")) {
                nextPart = NextPartition;
            }
            int collectedSoFar = 0;
            if (this.MyInvocation.BoundParameters.ContainsKey("Next")) {
                First = Next;
            }

            if (this.MyInvocation.BoundParameters.ContainsKey("First") && First < BatchSize) {
                BatchSize = First;
            }
            
            
            
            do { 
                if (this.MyInvocation.BoundParameters.ContainsKey("First") ||
                    this.MyInvocation.BoundParameters.ContainsKey("Next")) {
                    if (collectedSoFar >= First) {
                        break;
                    }
                }
                string result = QueryEntities(
                    this.TableName,
                    null,
                    null,
                    this.Filter,
                    sortString,
                    selectString,
                    BatchSize);

                if (!String.IsNullOrEmpty(result))
                {
                    if (this.MyInvocation.BoundParameters.ContainsKey("First") || 
                        this.MyInvocation.BoundParameters.ContainsKey("Next")) {
                        foreach (PSObject resultObj in ExpandObject(result, !ExcludeTableInfo, this.TableName)) { 
                            
                            
                            collectedSoFar++;
                            
                            if (collectedSoFar >= First) {
                                if (! (String.IsNullOrEmpty(nextRow) && String.IsNullOrEmpty(nextPart))) {
                                    PSNoteProperty nextRowKey = new PSNoteProperty("NextRowKey", nextRow);
                                    resultObj.Properties.Add(nextRowKey);
                                    PSNoteProperty nextPartition= new PSNoteProperty("NextPartition", nextPart);
                                    resultObj.Properties.Add(nextPartition);

                                }
                                WriteObject(resultObj);
                                break;
                            } else {
                                WriteObject(resultObj);
                            }
                        }
                    } else {
                        WriteObject(
                            ExpandObject(result, !ExcludeTableInfo, this.TableName), true);
                    }
                }
                
                if (! (String.IsNullOrEmpty(nextRow) && String.IsNullOrEmpty(nextPart))) {
                    thereIsMore = true;
                } else {
                    thereIsMore = false;
                }
            } while (thereIsMore);
        }
    }
}
