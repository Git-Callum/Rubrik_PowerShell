function New-RubrikFilesetExport{

<#
                    .SYNOPSIS
                    Create a new FileSet Export from Rubrik

                    .DESCRIPTION
                    The New-RubrikExport cmdlet is used to create an export from a FileSet Snapshot to a network share

                    The SnapshotID for the previous day is obtained by doing the following
                    $fileset = Get-RubrikFileset -HostName $server
                    $snapshot = $fileset | Get-RubrikSnapshot | where {([datetime]$_.date) -gt ([DateTime]::Today.AddDays(-1).AddHours(19))}
                    [array]$snapshotid = 0 | foreach{$snapshot[$_].id}

                    .NOTES
                    Written by Callum Maystone for Community Usage
                    LinkedIn: https://www.linkedin.com/in/callum-maystone-57b00932/

                    .LINK
                    

                    .EXAMPLE
                    New-RubrikExport -id '11111111-2222-3333-4444-555555555555' -RubrikServer 'rubrik-clst.domain.com -Credential $Credential -Path 'C:\Users\' -Destination '\\UNCPATH\FOLDER' -ExportNode 'ExportNode.domain.internal'
                    This will create an export of the host snapshot id '11111111-2222-3333-4444-555555555555'
                    The Cluster it is exporting from is 'rubrik-clst.domain.com'
                    The Credentials are stored in  $credential
                    The folder being exported from the Fileset Snapshot is 'C:\Users\'
                    The data is being exported to '\\UNCPATH\FOLDER'
                    The data is being exported from Rubrik through 'ExportNode.domain.internal'

                #>

                [CmdletBinding(SupportsShouldProcess = $true,ConfirmImpact = 'High')]
                Param(
                  # Rubrik id of the snapshot
                  [Parameter(Mandatory = $true,ValueFromPipelineByPropertyName = $true)]
                  [String]$id,
                  # ID of Snapshot to export
                  [String]$ExportNode,
                  # Name of host(as FQDN) or HostID you're exporting through
                  [Alias('HostID')]
                  [String]$RubrikServer,
                  # URI of Rubrik Cluster
                  [String]$SrcPath,
                  # Path of folder to export
                  [String]$dstPath, 
                  # Destination of Export
                  [System.Management.Automation.PSCredential]$Credential
                  # Credentials with sufficent rights to kick off a Rubrik Export
                )

                begin {

                if((Test-NetConnection $RubrikServer -WarningAction SilentlyContinue).PingSucceeded -ne $true){
                Write-Verbose "Rubrik Cluster not available on $RubrikServer, please ensure you have entered the correct cluster"
                } else {
                Write-Verbose "Connected to $RubrikServer, creating Header"

                # Converting Credentials to a usable Header
                $User = $Credential.UserName
                $Credential.Password | ConvertFrom-SecureString | Out-Null
                $Pass = $Credential.GetNetworkCredential().password
                $authInfo = ("{0}:{1}" -f $user,$pass)
                $authInfo = [System.Text.Encoding]::UTF8.GetBytes($authInfo)
                $authInfo = [System.Convert]::ToBase64String($authInfo)
                $headers = @{Authorization=("Basic {0}" -f $authInfo)}

                Write-Verbose "Checking that $ExportNode is a valid host to export data through"

                # Obtaining HostID to export data through from Rubrik
                
                if($ExportNode -like "Host:::*"){
                $HostID = $ExportNode
                
                } Else {
                $HostID = (Get-RubrikHost -Name $ExportNode).id
                }


                if($HostID -eq $Null){
               
                Write-Verbose "Unable to locate $ExportNode, please verify that you can export through this shost through the GUI"

                } Else {
                Write-Verbose "$ExportNode exists"

                Write-Verbose "Building URI"
                $uri =  "https://$rubrikserver/api/internal/fileset/snapshot/$id/export_files"

                Write-Verbose "Building Body"
                $srcPath = $SrcPath.Replace("\","\\")
                $dstPath =  $dstPath.Replace("\","\\")
                $body = "{`"exportPathPairs`":[{`"srcPath`":`"$srcPath`",`"dstPath`":`"$dstpath`"}],`"ignoreErrors`":true,`"hostId`":`"$HostID`"}"
                
                Write-Verbose "Sending WebRequest"
                $WebRequest = Invoke-WebRequest -uri $uri -method "POST" -Headers $headers -ContentType "application/json;charset=UTF-8" -body $body


                $Verification = ($WebRequest -like "*QUEUED*")
                

                    

                if($Verification -eq $true){
                Write-Verbose "Export Sucsesfully Queued"

                $result = new-object PSObject
                Add-Member -input $result NoteProperty 'SnapshotID' $id
                Add-member -input $result NoteProperty 'ExportQueued' $Verification
                Add-member -input $result NoteProperty 'Source' $srcpath
                Add-member -input $result NoteProperty 'Destination' $dstPath
                $result

                } Else {
                Write-Verbose "Export Failed"

                $result = new-object PSObject
                Add-Member -input $result NoteProperty 'SnapshotID' $id
                Add-member -input $result NoteProperty 'ExportQueued' "Failed"
                Add-member -input $result NoteProperty 'Source' $srcpath
                Add-member -input $result NoteProperty 'Destination' $dstPath
                $result

                }
                

                }
                

                }

                
                }


}
