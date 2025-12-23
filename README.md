# Collect EF Portal Logs

This script was created to help you collect all relevant logs to troubleshoot any EF Portal issue.

How to execute:

```bash
wget --no-check-certificate -qO- /tmp/Collect-EF-Portal-Logs.sh https://raw.githubusercontent.com/NISP-GmbH/Collect-EF-Portal-Logs/main/Collect-EF-Portal-Logs.sh)" && sudo bash /tmp/Collect-EF-Portal-Logs.sh

```

__Important:__ The script will not stop/start or touch any service without your permission. When needed, the script will ask and you can say no if you do not agree.

# Parameters

- *--force:* If your OS is not supported, you can force the log collect with --force parameter.
- *--efp_path=:* If you setup EF Portal in non usual path (/opt/nisp) you can use --efp_path=/my/own/path/