# Collect EF Portal Logs

This script was created to help you collect all relevant logs to troubleshoot any EF Portal issue.

How to execute:

```bash
sudo bash Collect-EF-Portal-Logs.sh
```

or

```bash
sudo bash -c "$(wget --no-check-certificate -qO- https://raw.githubusercontent.com/NISP-GmbH/Collect-EF-Portal-Logs/main/Collect-EF-Portal-Logs.sh)"
```

Important: The script will not stop/start or touch any service without your permission. When needed, the script will ask and you can say no if you do not agree.


If your OS is not supported, you can force the log collect with --force parameter:

```bash
sudo bash Collect-EF-Portal-Logs.sh --force
```
or

```bash
sudo bash -c "$(wget --no-check-certificate -qO- https://raw.githubusercontent.com/NISP-GmbH/Collect-EF-Portal-Logs/main/Collect-EF-Portal-Logs.sh)" -- --force
```
