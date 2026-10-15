# Collect EF Portal Logs

This script was created to help you collect all relevant logs to troubleshoot any EF Portal issue.

How to execute:

```bash
wget --no-check-certificate -qO- /tmp/Collect-EF-Portal-Logs.sh https://raw.githubusercontent.com/NISP-GmbH/Collect-EF-Portal-Logs/main/Collect-EF-Portal-Logs.sh && sudo bash /tmp/Collect-EF-Portal-Logs.sh

```

__Important:__ The script will not stop/start or touch any service without your permission. When needed, the script will ask and you can say no if you do not agree.

# Parameters

- *--force:* If your OS is not supported, you can force the log collect with --force parameter.
- *--report-only:* Only generate the report without collecting logs.
- *--collect-logs:* Collect logs and create the report without the interactive menu.
- *--without-encryption:* Create the compressed file without GPG encryption. The `.tar.gz` will not be encrypted with a passphrase.
- *--without-upload:* Skip the automatic upload to NI SP. The file is preserved locally so you can upload it manually.
- *--efp_dir=:* If you setup EF Portal in a non usual path (/opt/nisp) you can use --efp_dir=/my/own/path/
- *--name "text":* Your name or company, sent with the upload.
- *--email "addr":* Your e-mail, so NI SP Support can reach you.
- *--problem "text":* Short description of the problem you are seeing.
- *--without-analysis:* Upload without asking for or requesting the automatic analysis. NI SP Support is notified of the upload.

`--name`, `--email` and `--problem` are mandatory unless `--without-upload` is used. They are asked
interactively when missing; without a terminal (cron, Ansible, SSM...) the script stops with an error
instead. They are stored with the upload on NI SP's upload service, so NI SP Support can see who sent the
bundle, and go to Deep NI SP with the analysis request.

Before uploading, the script asks whether to send the logs to Deep NI SP for an automatic analysis.
If you agree it prints a private report link; if not, the bundle is only uploaded and NI SP Support
is notified. Without a terminal the analysis is requested unless `--without-analysis` is given.

## Produce an unencrypted bundle (for the automatic log analysis)

```bash
sudo bash Collect-EF-Portal-Logs.sh --collect-logs --without-encryption --without-upload
```

This creates an unencrypted `efp_logs_collection_<HOSTNAME>.tar.gz` in the current
directory that you can upload to Deep NI SP for an automatic log analysis. The bundle now includes a
`collection_meta.json` manifest for automatic product identification.
