# global vars
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

temp_dir="tmp/"
hostname_parsed=$(echo ${HOSTNAME// /_})
compressed_file_name="efp_logs_collection_${hostname_parsed}.tar.gz"
encrypt_length="32"
encrypt_password=$(openssl rand -base64 48 | tr -dc '\-A-Za-z0-9@#$%^&*()_=+' | tr -d ' ' | head -c "${encrypt_length}")
encrypted_file_name="${compressed_file_name}.gpg"
upload_domain="https://dcv-logs.ni-sp.com"
upload_url="${upload_domain}/upload.php"
notify_url="${upload_domain}/notify.php"
curl_response=""
ubuntu_distro="false"
ubuntu_version=""
ubuntu_major_version=""
ubuntu_minor_version=""
redhat_distro_based="false"
redhat_distro_based_version=""
force_flag="false"
efp_dir="/opt/nisp"
efp_dir_basename=$(basename ${efp_dir})
efp_report_dir_name="efp_report"
efp_report_dir_path="${temp_dir}/${efp_report_dir_name}"
efp_report_txt_file_name="efp_report.txt"
efp_report_html_file_name="efp_report.html"
efp_report_txt_path="${efp_report_dir_path}/${efp_report_txt_file_name}"
efp_report_html_path="${efp_report_dir_path}/${efp_report_html_file_name}"
efp_report_separator="------------------------------------------------------------------"
dns_test_domain="google.com"
ip_test_external="8.8.8.8"
dns_is_working="false"
report_only="false"
collect_log_only="false"
option_selected="1"
SCRIPT_MARKER="NISPGMBHHASH$(date +%s)$$"

for arg in "$@"
do
    case $arg in
        --force)
            force_flag=true
        ;;
        --report-only)
            report_only=true
        ;;
        --collect-logs)
            collect_log_only=true
        ;;
        --efp_dir=*)
            efp_dir="${arg#*=}"
        ;;
    esac
done

main()
{
    welcomeMessage
    checkEfpDir
    checkLinuxDistro
    checkRequirements
    createTempDirs
    checkPackagesVersions
    checkEfpSetuid
    getOsData
    getNetworkData
    getEnvironmentVars
    getHwData
    getKerberosData
    getSssdData
    getNsswitchData
    getPamData
    getEtcAuthSelect
    getJavaInfo
    getEfpData
    getEfpPermissions
	doHtmlReport

    # If 'report only' was selected, finalize the report and exit.
    if [[ "$report_only" == "true" ]]; then
        finalizeReport
        removeTempDirs
        byebyeMessage
        exit 0
    fi

    # Otherwise, proceed with compressing and uploading the logs.
    compressLogCollection
    encryptLogCollection
    uploadLogCollection
    removeTempDirs
    byebyeMessage
    exit 0
}

main

# unknown error
echo "Unknown error!"
exit 255
