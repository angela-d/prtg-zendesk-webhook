# PRTG Zendesk Tickets Webhook

Automatically open Zendesk tickets for triggered sensors using Powershell.  Forked from [Integrating Zendesk and PRTG](https://tietze.io/b/2015/09/08/integrating-zendesk-and-prtg/)

![Zendesk Tickets](./img/tickets.png)


Before:
> Error by lookup value

After:
> Critical (2) in channel Imaging Unit (Magenta)
>
> .. if additional triggers from the same sensor, a newline to easily list the problems

Main Features:
- Automatically open Zendesk tickets when a sensor is triggered; useful for IT Staff to automate delegation to tech assistants
- Update/reopen existing tickets for the same sensor

This version has additional features:
- Tokenized authentication, to keep your password secure
- Secure API connections over TLS 1.2
- Fixes the single quote bug when using Powershell
- Option to update existing open/new tickets
- Local logging option for debugging when testing sensor messages
- A bit more newb friendly
- Formatting cleanup

![PRTG Parameters](./img/execute-program.png)

## How to use it
- First, clone/copy *ZendeskWebhook.ps1* to: `C:\Program Files (x86)\PRTG Network Monitor\Notifications\EXE` (your path may vary if using a different architecture with your PRTG server)
- Open *ZendeskWebhook.ps1* and add your config (Zendesk credentials, log options, etc; use your *API token* as the password)
- Login to your PRTG dashboard
- Setup > Account Settings > Notification Templates
- Add/click on the template you want to use with this script
- Populate the settings as you wish, then scroll toward the bottom for the **Execute Program** toggle; click it
- In the **Program File** field, select `Zendeskwebhook.ps1`
- In the **Parameters** field, add the following:
```powershell
-Device '%device' -Status '%status' -Down '%down' -Group '%group' -commentssensor '%commentssensor' -CommentsProbe '%commentsprobe' -Message '%message'
```
- In the search field (upper right corner), search for the *sensor Group* you'd like to use this script with
- Under the group list, click it > Notification Triggers > Add/edit the trigger you wish to use with this script and select the notification template you assigned the script to earlier
- Save and trigger a sensor that's using the template to test!

## Customizing
If you'd like to add additional verbiage to your tickets, you can call [additional parameters](https://www.paessler.com/manuals/prtg/list_of_placeholders_for_notifications) in similar fashion to the existing parameters.

(Don't forget to add them to *params()* to initialize inside `ZendeskWebhook.ps1`)

***
**(optional) Update Existing Tickets**

- 1) Set the `$updateExisting` variable to `1`
- 2) You can customize "update" messages by modifying the following:
  ```powershell
    # Update existing ticket or create new
    if ($existingNewTickets -gt 0 -and $updateExisting -eq 1) {

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
      ...
  ```
    - `public = $false;` = Whether or not you want the reply to be a public reply, or just for agents
    - `body = $CommentBody;` = If you want a custom reply, set your own message (or variable) here, otherwise, it'll re-post the initial message
    - `author_id = $AuthorId;` = If you want to change the follow-up reply author, modify that here, otherwise, the initial poster will be the reply author

### Password Auth over Token Authorization
If you prefer to use password authentication with Zendesk instead of token auth (the default), simply remove '/token' from the username.

### Troubleshooting
- Auto-closure of tickets after a device returns to Up/OK is not a feature, at this time.  If this is something you need, you'll have to extend the codebase.
- Duplicate tickets: If you're seeing numerous tickets per device, set a dependency in each sensor (under Settings for the Device), so the child sensors get paused if the parent (Ping, for example) is down.
- If you aren't getting tickets opened for messages that have single quotes: `Error by lookup value 'Critical (1)' in channel 'Toner (Yellow)'` - modify your contact template to have double-quotes over the **-Message** parameter, like so:
    ```text
    -Message "%lastmessage"
    ```
    *instead of*
    ```text
    -Message '%lastmessage'
    ```

### License
Tietze's release is unlicensed/public domain; my changes are licensed under GPL2
