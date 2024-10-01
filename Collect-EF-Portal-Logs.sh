#!/bin/bash
################################################################################
# Copyright (C) 2019-2024 NI SP GmbH
# All Rights Reserved
#
# info@ni-sp.com / www.ni-sp.com
#
# We provide the information on an as is basis.
# We provide no warranties, express or implied, related to the
# accuracy, completeness, timeliness, useability, and/or merchantability
# of the data and are not liable for any loss, damage, claim, liability,
# expense, or penalty, or for any direct, indirect, special, secondary,
# incidental, consequential, or exemplary damages or lost profit
# deriving from the use or misuse of this information.
################################################################################

welcomeMessage()
{
    echo "This script will collect important logs to help you to find eventual issues with your configuration."
    echo -e "${GREEN}By default the script will not restart any service without your approval. So if you do not agree when asked, this script will collect all logs without touch in any running service.${NC}"
    echo "Answering yes to those answers can help the support to troubleshoot the problem."
    echo "To start collecting the logs, press enter or ctrl+c to quit."
    read p
}

askToEncrypt()
{
    echo -e "${GREEN}The file >>> $compressed_file_name <<< was created and is ready to send to support.${NC}"
    echo "If you want to encrypt the file with password, please use this command:"
    echo "gpg -c $compressed_file_name"
    echo "And set a password to open the file. Then send the file to us and send the password in a secure way."
    echo "To decrypt and extract, the command is:"
    echo "gpg -d ${compressed_file_name}.gpg | tar xzvf -"
    echo "Encrypting is not mandatory to send to the support."
}

checkLinuxDistro()
{
    echo "Checking your Linux distribution..."
    echo "Note: If you know what you are doing, please use --force option to avoid our Linux Distro compatibility test."

    if $force_flag
    then
        echo "Force flag is set"
        # fake info
        redhat_distro_based=true
        redhat_distro_based_version=8
        ubuntu_distro=true
        ubuntu_major_version=20
        ubuntu_minor_version=04
    else
        echo "Force flag is not set"

        if [ -f /etc/redhat-release ]
        then
            release_info=$(cat /etc/redhat-release)
            if echo $release_info | egrep -iq "(centos|almalinux|rocky|red hat|redhat)"
            then
                redhat_distro_based="true"
            fi

            if [[ "${redhat_distro_based}" == "true" ]]
            then
                if echo "$release_info" | egrep -iq stream
                then
                    redhat_distro_based_version=$(cat /etc/redhat-release  |  grep -oE '[0-9]+')
                else
                    redhat_distro_based_version=$(echo "$release_info" | grep -oE '[0-9]+\.[0-9]+' | cut -d. -f1)
                fi

                if [[ ! $redhat_distro_based_version =~ ^[789]$ ]]
                then
                    echo "Your RedHat Based Linux distro version..."
                    cat /etc/redhat-release
                    echo "is not supported. Aborting..."
                    exit 18
                fi
            else
                echo "Your RedHat Based Linux distro..."
                cat /etc/redhat-release
                echo "is not supported. Aborting..."
                exit 19
            fi
        else
            if [ -f /etc/debian_version ]
            then
                if cat /etc/issue | egrep -iq "ubuntu"
                then
                    ubuntu_distro="true"
                    ubuntu_version=$(lsb_release -rs)
                    ubuntu_major_version=$(echo $ubuntu_version | cut -d '.' -f 1)
                    ubuntu_minor_version=$(echo $ubuntu_version | cut -d '.' -f 2)
                    if ( [[ $ubuntu_major_version -lt 18 ]] || [[ $ubuntu_major_version -gt 24  ]] ) && [[ $ubuntu_minor_version -ne 04 ]]
                    then
                        echo "Your Ubuntu version >>> $ubuntu_version <<< is not supported. Aborting..."
                        exit 20
                    fi
                else
                    echo "Your Debian Based Linux distro is not supported."
                    echo "Aborting..."
                    exit 21
                fi
            else
                echo "Not able to find which distro you are using."
                echo "Aborting..."
                exit 22
            fi
        fi
    fi
}

checkRequirements()
{
    if [ -d /opt/nisp ]
    then
        checkPackages
    else
        echo "Directory >>> /opt/nisp <<< does not exist. Exiting..."
        exit 25
    fi
}

checkPackages()
{
    if $ubuntu_distro
    then
        for package_to_check in tar gzip
        do
            if ! dpkg -s $package_to_check &> /dev/null
            then
                echo "The package >>> $package_to_check <<< is not present. Exiting..."
                exit 23
            fi
        done
    fi

    if $redhat_distro_based
    then
        for package_to_check in tar gzip
        do
            if ! rpm -q $package_to_check &> /dev/null
            then
                echo "The package >>> $package_to_check <<< is not present. Exiting..."
                exit 24
            fi
        done
    fi
}

compressLogCollection()
{
    tar czf $compressed_file_name $temp_dir
}

removeTempDirs()
{
    rm -rf $temp_dir
}

createTempDirs()
{
    echo "Creating temp dirs structure to store the data..."
    for new_dir in java_info kerberos_conf pam_conf sssd_conf nsswitch_conf warnings os_info os_log journal_log hardware_info efp_log efp_conf
    do
        sudo mkdir -p ${temp_dir}/$new_dir
    done
}

containsVersion() {
    local string="$1"
    local version="$2"
    [[ "$string" =~ (\.|-)[0-9]+\.el$version([._]|$) || 
       "$string" =~ \.el$version([._]|$) || 
       "$string" =~ -$version\. || 
       "$string" == *".$version" ||
       "$string" =~ \.module\+el$version ]]
}

checkPackagesVersions()
{
    echo "Checking packages versions... depending of your server it can take up to 2 minutes..."
    target_dir="${temp_dir}/warnings/"

    if [[ "$ubuntu_distro" == "false" ]]
    then
        if [[ "$redhat_distro_based" == "false" ]]
        then
            echo "OS not supported" > ${target_dir}/os_not_supported
        fi
    fi

    if [[ "$redhat_distro_based" == true ]]
    then
        rpm -qa --qf "%{NAME} %{VERSION}-%{RELEASE}\n" | while read -r package version_release
        do
            if ! containsVersion "$version_release" "$redhat_distro_based_version"
            then
                echo "Package $package version $version_release might not be compatible with EL$redhat_distro_based_version" >> ${target_dir}/packages_might_not_os_compatible
            fi
        done

    fi

    if [[ "$ubuntu_distro" == "true" ]]
    then

        for package in $(apt list --installed 2> /dev/null| cut -d/ -f1)
        do
            version=$(dpkg-query -W -f='${Version}' "$package")                
            year=$(echo "$version" | cut -d'.' -f1)
            
            if [[ "$ubuntu_version" == "20.04" ]]
            then
                min_year=2020
            elif [[ "$ubuntu_version" == "22.04" ]]
            then
                min_year=2022
            else
                min_year=$(($(date +%Y) - 1))  # Default to last year for unknown Ubuntu versions
            fi

            if [[ $year =~ ^[0-9]+$ ]]
            then
                if [[ "$year" -lt "$min_year" ]]
                then
                    echo "Warning: $package version $version might be too old for Ubuntu $ubuntu_version. Expected minimum year: $min_year" >> "${target_dir}/packages_version_mismatch"
                else
                    echo "Note: $package version $version appears to be compatible with Ubuntu $ubuntu_version" >> "${target_dir}/packages_version_info"
                fi
            fi
        done
    fi
}

getEnvironmentVars()
{
    echo "Collecting environment variables..."
    target_dir="${temp_dir}/os_info/"
    env > ${target_dir}/env_command
    env | sort > ${target_dir}/env_sorted_command
    printenv > ${target_dir}/printenv_command

    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | while read -r user
    do
        USER_DIR="${target_dir}/users_environment_vars/$user"
        mkdir -p "$USER_DIR"
    
        pid=$(pgrep -u "$user" -n)
        env_file="$USER_DIR/env.txt"

        if [ -z "$pid" ]
        then
            echo "No running processes found for user $user" > ${USER_DIR}/env_file
            continue
        fi

        cat "/proc/$pid/environ" | tr '\0' '\n' >> "$env_file"
    done
}

getPamData()
{
    echo "Collecting all PAM relevant info..."
    target_dir="${temp_dir}/pam_conf/"

    if [ -d /etc/pam.d ]
    then
        sudo cp -r /etc/pam.d ${target_dir} > /dev/null 2>&1
    fi
}

getKerberosData()
{
    echo "Collecting all Kerberos relevant info..."
    target_dir="${temp_dir}/kerberos_conf/"

    if [ -f /etc/krb5.conf ]
    then
        sudo cp /etc/krb5.conf $target_dir > /dev/null 2>&1
    fi
}

getSssdData()
{
    echo "Collecting all SSSD relevant info..."
    target_dir="${temp_dir}/sssd_conf/"

    if [ -d /etc/sssd/ ]
    then
        sudo cp -r /etc/sssd ${target_dir} > /dev/null 2>&1
    fi

    detect_sssd=$(sudo ps aux | egrep -i '[s]ssd')
    if [[ "${detect_sssd}x" != "x" ]]
    then
        echo "$detect_sssd" > $temp_dir/warnings/sssd_is_running
    fi

    target_dir="${temp_dir}/sssd_log"
    if [ -f /var/log/sssd ]
    then
        sudo cp -r /var/log/sssd ${target_dir}> /dev/null 2>&1
    fi
}

getNsswitchData()
{
    echo "Collecting all NSSwitch relevant info..."
    target_dir="${temp_dir}/nsswitch_conf/"

    if [ -d /etc/nsswitch.conf ]
    then
        sudo cp /etc/nsswitch.conf ${target_dir}/ > /dev/null 2>&1
    fi
}

getHwData()
{
    echo "Collecting all Hardware relevant info..."
    target_dir="${temp_dir}/hardware_info/"

    if command -v lshw > /dev/null 2>&1
    then
        sudo lshw > ${target_dir}/lshw_hardware_info.txt
    else
        echo "lshw not found" > ${target_dir}/not_found_lshw
    fi

    if command -v lscpu > /dev/null 2>&1
    then
        sudo lscpu  > ${target_dir}/lscpu_hardware_info.txt
    else
        echo "lscpu not found" > ${target_dir}/not_found_lscpu
    fi

    if command -v dmidecode > /dev/null 2>&1
    then
        sudo dmidecode > ${target_dir}/dmidecode 2>&1
    else
        echo "dmidecode not found" > ${target_dir}/not_found_dmidecode 

    fi
}

getOsData()
{
    echo "Collecting all Operating System relevant data..."
    target_dir="${temp_dir}/os_info/"
    sudo uname -a > $target_dir/uname_-a

    if command -v lsb_release > /dev/null 2>&1
    then
        sudo lsb_release -a > $target_dir/lsb_release_-a 2>&1
    else
        echo "lsb_release not found" > $target_dir/not_found_lsb_release
    fi

    if command -v getenforce > /dev/null 2>&1
    then
        sudo getenforce > $target_dir/getenforce_result 2>&1
    fi

    if [ -f /etc/issue ]
    then
        sudo cp /etc/issue $target_dir > /dev/null 2>&1
    fi

    if [ -f /etc/debian_version ]
    then
        sudo cp /etc/debian_version $target_dir > /dev/null 2>&1
    fi

    if [ -f /etc/redhat-release ]
    then
        sudo cp /etc/redhat-release $target_dir > /dev/null 2>&1
    fi

    if [ -f /etc/centos-release ]
    then
        sudo cp /etc/centos-release $target_dir > /dev/null 2>&1
    fi

    if [ -f /usr/lib/apt ]
    then
        sudo dpkg -a > ${target_dir}/deb_packages_list 2>&1
    fi

    if [ -f /usr/bin/rpm ]
    then
        sudo rpm -qa > ${target_dir}/rpm_packages_list 2>&1
    fi

    ps aux --forest > ${target_dir}/ps_aux_--forest 2>&1
    pstree -p > ${target_dir}/pstree 2>&1

    target_dir="${temp_dir}/os_log/"
    sudo cp /var/log/dmesg* $target_dir > /dev/null 2>&1
    sudo cp /var/log/messages* $target_dir > /dev/null 2>&1
    sudo cp /var/log/kern* $target_dir > /dev/null 2>&1
    sudo cp /var/log/auth* $target_dir > /dev/null 2>&1
    sudo cp /var/log/syslog* $target_dir > /dev/null 2>&1
    sudo cp -r /var/log/audit* $target_dir > /dev/null 2>&1
    sudo cp -r /var/log/secure* $target_dir > /dev/null 2>&1
    sudo cp -r /var/log/boot* $target_dir > /dev/null 2>&1
    sudo cp -r /var/log/kdump* $target_dir > /dev/null 2>&1

    if [ -f $target_dir/dmesg ]
    then
        if egrep -iq "oom" $target_dir/dmesg > /dev/null 2>&1
        then
            cat $target_dir/dmesg | egrep -i "(oom|killed)" > ${temp_dir}/warnings/oom_killer_log_found_dmesg
        fi
    fi

    if [ -f $target_dir/messages ]
    then
        if egrep -iq "oom" $target_dir/messages > /dev/null 2>&1
        then
            cat $target_dir/messages | egrep -i "(oom|killed)" > ${temp_dir}/warnings/oom_killer_log_found_messages
        fi
    fi

    target_dir="${temp_dir}/journal_log"
    sudo journalctl -n 5000 > ${target_dir}/journal_last_5000_lines.log 2>&1
    sudo journalctl --no-page | grep -i selinux > ${target_dir}/selinux_log_from_journal 2>&1
    sudo journalctl --no-page | grep -i apparmor > ${target_dir}/apparmor_log_from_journal 2>&1
}

getEfpData()
{
    echo "Collecting all EF Portal relevant data..."
    target_dir="${temp_dir}/efp_conf/"

    if [ -d /opt/nisp/enginframe/conf/ ]
    then
        mkdir -p ${target_dir}/opt/nisp/enginframe/
        sudo cp -r /opt/nisp/enginframe/conf ${target_dir}/opt/nisp/enginframe/
    fi

    if [ -d /opt/nisp/enginframe/ ]
    then
        for efp_version in $(ls /opt/nisp/enginframe/ | egrep -i "202[0-9]{1}")
        do
            mkdir -p ${target_dir}/opt/nisp/enginframe/${efp_version}/enginframe/
            sudo cp -r /opt/nisp/enginframe/${efp_version}/enginframe/conf ${target_dir}/opt/nisp/enginframe/${efp_version}/enginframe/
        done
    fi

    target_dir="${temp_dir}/efp_log/"

    if [ -d /opt/nisp/enginframe/logs ]
    then
        sudo cp -r /opt/nisp/enginframe/logs ${target_dir}/logs_main
    fi

    if [ -d /opt/nisp/enginframe/install ]
    then
        sudo cp -r /opt/nisp/enginframe/install ${target_dir}/install_log
    fi

    find /opt/nisp/ -type d -name "tmp[0-9][0-9][0-9][0-9][0-9]*.session.ef" | while read -r dir
    do
        tmp_dir=$(basename "$dir")
        mkdir -p "${target_dir}/sessions/${tmp_dir}"
    
        files_to_copy=(
            "env.log"
            "dcv2.save.auth"
            "gpu.balancer.conf"
            "generated.lsf.dcv2.bash"
            "job.log"
            "session.info"
            "session.log"
            "shared-fs"
        )
    
        for file in "${files_to_copy[@]}"
        do
            if [ -f "$dir/$file" ]
            then
                sudo cp "$dir/$file" "${target_dir}/sessions/${tmp_dir}/"
            fi
        done
    
        if [ -d "$dir/server-log" ]
        then
            sudo cp -r "$dir/server-log" "${target_dir}/sessions/$tmp_dir/"
        fi
done
}

getJavaInfo()
{
    target_dir="${temp_dir}/java_info/"

    if command -v java > /dev/null 2>&1
    then
        java -version &> $target_dir/java_-version

        echo $JAVA_HOME &> $target_dir/JAVA_HOME_variable
        
        if [[ "${JAVA_HOME}x" == "x" ]]
        then
            echo "JAVA_HOME seems to be empty; was executed by user >>> $USER <<<." > ${temp_dir}/warnings/java_home_not_recognized_by_user_${USER}
        fi

        readlink -f $(which java) | sed "s:/bin/java::" &> $target_dir/java_bin_path
    else
        echo "java command not found!" > ${temp_dir}/warnings/java_not_found
    fi

    echo "List of .jar found and respective md5sum" > ${target_dir}/jar_files_md5sum
    find /opt/nisp -type f -iname "*.jar" -print0 | while IFS= read -r -d '' jar_file
    do
        md5sum "$jar_file" &>> "${target_dir}/jar_files_md5sum"
    done
}

# global vars
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

temp_dir="tmp/"
compressed_file_name="efp_logs_collection.tar.gz"
ubuntu_distro="false"
ubuntu_version=""
ubuntu_major_version=""
ubuntu_minor_version=""
redhat_distro_based="false"
redhat_distro_based_version=""
force_flag="false"

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
    getJavaInfo
    getEfpData
    compressLogCollection
    askToEncrypt
    removeTempDirs
    exit 0
}

main

# unknown error
exit 255
