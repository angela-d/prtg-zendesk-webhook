# original script by https://tietze.io/b/2015/09/08/integrating-zendesk-and-prtg/
#
# solves bug: https://kb.paessler.com/en/topic/75261-single-quote-in-sensor-message-breaks-notification-script
#
# angela 12/7/18: added:
# - detailed messages & tags that don't break with single quotes
# - local log generator for easy troubleshooting
# - made the script a bit more newb friendly
# - formatting cleanup
#
# This will create a new ticket in PRTG if no open PRTG ticket is found for this device; otherwise it will update the first found open PRTG ticket for this device.

# initialize parameters that will be used later on in the script, more available at: https://kb.paessler.com/en/topic/373-what-placeholders-can-i-use-with-prtg
Param(
  [string]$Device,
  [string]$Status,
  [string]$Down,
  [string]$Group,
  [string]$CommentsSensor,
  [string]$Message,
  [string]$CommentsProbe
)

## CONFIG
# zendesk credentials
$User      = "youremail@example.com/token" # user must be verified to use the zendesk api
$Pass      = "abcdefghijklmnopqrstuvwxyz0123456789"
# Author ID (numeric) for updates to existing tickets, ie: https://[example].zendesk.com/agent/#/users/370381808374
$AuthorId  = "1234567989"
$prtgName  = "PRTG"
$prtgEmail = "prtg@example.com"
$BaseUri   = "https://[yourzendeskurl].zendesk.com"
$debug     = 1 # set to 1 if you want to save a log file to the location referenced in $logPath
$logPath   = "C:\Users\Administrator\Desktop\log.txt"
## END CONFIG


# additional processing is required to handle messages that have single quotes in them, kinda hacky, but this isn't really going to be a high-traffic script that runs frequently (right?)
foreach ($arg in $args){

  $paramResult += "" + $arg + " "

}

# without the numeric string length, the string duplicates. bugfix for another time
$fullMessage = [string]$args.Length + ":" + $paramResult
$stripBefore = $fullMessage.IndexOf("-Message")

# now that the message has been extracted, it can be passed as a normal variable
$Message     = $fullMessage.Substring($stripBefore+1)

# remove the numeric string prefix, referenced on line 46
$Message     = $Message.Trim() -replace "^[0-9]*:",""

# remove 'error by lookup value' in the body of the ticket
$Message     = $Message -replace "Error by lookup value ",""

# inject a newline when there's a dash in the comments, to keep it clean
$Message     = $Message -replace " — ","`n"
$Message     = $Message -replace "'","" # strip out the trailing '


# if you want to log something other than the $Message var, simply replace the references in the conditional code block
if ($debug -eq 1 -AND (Test-Path $logPath)) {

  Write-Output $Message | Out-File $logPath -Append

} elseif ($debug -eq 1 -AND !(Test-Path $logPath)) {

  New-Item $logPath -ItemType file
  # redundant, but add-content was goobering up with unnecessary spaces between letters
  Write-Output $Message | Out-File $logPath -Append
}

$AuthHeader = @{

  "Content-Type"  = "application/json";
  "Authorization" = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($User):$($Pass)"))
}

# call the zendesk api
function Call-ZenDesk($Api, $Method, $Body) {

  # by default, powershell seems to want to use insecure/deprecated tls, the following fixes that
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-RestMethod -Method $Method -Uri "$($BaseUri)$($Api)" -Headers $AuthHeader -Body $Body
}

$CommentBody   = "$($Device) $($Group) $($Status) $($Down)`n`n$($CommentSsensor) $($Message) $($CommentsProbe)"
$TicketSubject = "$($Device) $($Group) Issue"
# formatting used to search tags & add new; for updating existing tickets
$deviceTag     = $Device.Trim() -replace ' ','-'

# find existing tickets, if any
$Transaction = @{

  query = "subject:$($deviceTag) status<solved tags:monitoring-alert";
}

$SearchResults = Call-ZenDesk '/api/v2/search.json' Get $Transaction
Write-Host "Search results count: $($SearchResults.count)"

# Update existing ticket or create new
if ($SearchResults.count -gt 0) {

  # there is at least one open ticket for this device tagged with PRTG
  $Ticket = $SearchResults.results.Item(0)
  Write-Host "Found a ticket! Updating ticket #$($Ticket.id)"

  $Transaction = @{
    ticket = @{
      comment = @{
        public    = $false;
        body      = $CommentBody;
        author_id = $AuthorId;
      }
    }
  }

  $Body = ConvertTo-Json($Transaction)
  Call-ZenDesk "/api/v2/tickets/$($Ticket.id).json" Put $Body

} else {

  # no ticket found, create one; to add additional tags, separate by a comma
  $Tags        = "monitoring-alert,$($deviceTag)"
  $CommentBody = "$($CommentBody)"
  $Transaction = @{

    ticket = @{
    requester = @{
      name  = "$prtgName";
      email = "$prtgEmail"
    };
    subject  = $TicketSubject;
    type     = "Incident";
    priority = "Normal";

    comment = @{
      public = $false;
      body   = $CommentBody;
    };
    tags = $Tags.Split(',')
    }
  }

  $Body = ConvertTo-Json $Transaction

  Call-ZenDesk "/api/v2/tickets.json" Post $Body
}
