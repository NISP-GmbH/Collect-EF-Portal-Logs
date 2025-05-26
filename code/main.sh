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
ef_dir="/opt/nisp"
ef_dir_basename=$(basename ${ef_dir})

for arg in "$@"
do
    if [ "$arg" = "--force" ]
    then
        force_flag=true
        break
    fi
done

main()
{
    welcomeMessage
	checkEfDir
    checkLinuxDistro
    checkRequirements
    createTempDirs
    checkPackagesVersions
    getOsData
    getEnvironmentVars
    getHwData
    getKerberosData
    getSssdData
    getNsswitchData
    getPamData
    getEtcAuthSelect
    getJavaInfo
    getEfpData
    compressLogCollection
    encryptLogCollection
    uploadLogCollection
    removeTempDirs
    exit 0
}

main
