safeLogCheck()
{
    local pattern="$1"
    local target="$2"

    if [[ "$target" == *"*"* ]]
    then
        local dir_part=$(dirname "$target")
        local file_pattern=$(basename "$target")
        local matching_files=$(find "$dir_part" -maxdepth 1 -name "$file_pattern" -type f 2>/dev/null)

        if [ -z "$matching_files" ]
        then
            return 1
        fi

        local results=$(echo "$matching_files" | xargs grep -iE "$pattern" 2>/dev/null | \
                       grep -vE "($$|wget|bash.*Collect|curl|${SCRIPT_MARKER})" | \
                       grep -v "$(basename $0)")
    elif [ -f "$target" ]
    then
        local results=$(grep -iE "$pattern" "$target" 2>/dev/null | \
                       grep -vE "($$|wget|bash.*Collect|curl|${SCRIPT_MARKER})" | \
                       grep -v "$(basename $0)")

    elif [ -d "$target" ]
    then
        local results=$(egrep -Ri "$pattern" "$target" 2>/dev/null | \
                       grep -vE "($$|wget|bash.*Collect|curl|${SCRIPT_MARKER})" | \
                       grep -v "$(basename $0)")
    else
        return 1
    fi

    [ -n "$results" ]
}

doHtmlReport()
{
    cat << EOF >> ${efp_report_html_path}/html_head
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NISP Report: EF Portal</title>
    <style>
        :root {
            --critical-color: red;
            --info-color: green;
            --warning-color: yellow;
            --suggestion-color: cyan;
        }
        
        body {
            background-color: black;
            color: white;
            font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, Oxygen, Ubuntu, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        h1 {
            color: white;
            font-weight: 500;
            font-size: 1.75rem;
            margin-top: 1.5rem;
            margin-bottom: 0.75rem;
        }
        
        header h1 {
            font-size: 2.25rem;
            border-bottom: 1px solid rgba(255, 255, 255, 0.2);
            padding-bottom: 0.75rem;
        }
        
        .report-section {
            border-left: 4px solid rgba(255, 255, 255, 0.2);
            padding: 0.5rem 0 0.5rem 1.5rem;
            margin-bottom: 2rem;
        }
        
        .critical {
            color: var(--critical-color);
            border-left-color: var(--critical-color);
        }
        
        .warning {
            color: var(--warning-color);
            border-left-color: var(--warning-color);
        }
        
        .info {
            color: var(--info-color);
            border-left-color: var(--info-color);
        }
        
        .status-keyword {
            font-weight: bold;
        }

        .suggestion {
            color: var(--suggestion-color);
            margin-top: 0.5rem;
        }
        
        a {
            color: var(--suggestion-color);
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        .support-info {
            margin: 1rem 0 2rem;
        }

    </style>
</head>
<body>
    <header>
        <h1>NISP DCV Server Report</h1>
        <div class="support-info">
            <p>If you need support:</p>
            <p> <a href="https://www.ni-sp.com/support/" target="_blank">https://www.ni-sp.com/support/</a></p>
        </div>
    </header>
EOF

    cat << EOF >> ${efp_report_html_path}/html_tail
</body>
</html>
EOF

    cat ${efp_report_html_path}/html_head > $efp_report_html_path
    cat ${efp_report_html_path}/html_critical >> $efp_report_html_path
    cat ${efp_report_html_path}/html_warning >> $efp_report_html_path
    cat ${efp_report_html_path}/html_info >> $efp_report_html_path
    cat ${efp_report_html_path}/html_tail >> $efp_report_html_path
    rm -f ${efp_report_html_path}/html_*
}

command_exists()
{
    command -v "$1" &> /dev/null
}

byebyeMessage()
{
    echo -e "${GREEN}Thank you! ${NC}"
}

reportMessage()
{
    local message_type="$1"
    local message_text="$2"
    if [[ "$3" == "null" ]]
    then
        local log_file="${efp_report_txt_file_name}"
    else
        local log_file="${efp_report_txt_file_name} $3"
    fi
    local message_suggestion="$4"
    local recommended_links="$5"

    reportMessageWrite "${message_text}" "${log_file}" "${message_type}" "${message_suggestion}" "${recommended_links}"
    reportMessageWriteHtml "${message_text}" "null" "${message_type}" "${message_suggestion}" "${recommended_links}"
}

reportMessageWriteHtml()
{
    local message_text="$1"
    local log_file="$2"
    local message_type=$3
    local message_suggestion=$4
    local recommended_links=$5

    cat << EOF >> ${efp_report_html_path}/html_${message_type}
    <div class="report-section ${message_type}">
        <h1><span class="status-keyword ${message_type}">$(echo "${message_type}" | tr '[:lower:]' '[:upper:]'):</span> ${message_text}</h1>
EOF

    if [[ "${message_suggestion}" != "null" ]]
    then
        cat << EOF >> ${efp_report_html_path}/html_${message_type}
            <p class="suggestion"><strong>SUGGESTION:</strong> $message_suggestion</p>
EOF
    fi

    if [[ "${recommended_links}" != "null" ]]
    then
        cat << EOF >> ${efp_report_html_path}/html_${message_type}
        <p class="suggestion"><strong>Recommended links:</strong></p>
        <ul>
EOF
        for link_recommended in $recommended_links
        do
            cat << EOF >> ${efp_report_html_path}/html_${message_type}
    <li><a href="${link_recommended}" target="_blank">${link_recommended}</a></li>
EOF
        done

        cat << EOF >> ${efp_report_html_path}/html_${message_type}
        </ul>
EOF
    fi
    cat << EOF >> ${efp_report_html_path}/html_${message_type}
    </div>
EOF
}

reportMessageWrite()
{
    local message_text="$1"
    local log_file="$2"
    local message_type=$3
    local message_suggestion=$4
    local recommended_links=$5


    case $message_type in
        critical)
            echo -e "${efp_report_separator}" | tee -a $log_file  > /dev/null
            echo -e "${RED}CRITICAL: ${message_text}${NC}" | tee -a $log_file
        ;;
        warning)
            echo -e "${efp_report_separator}" | tee -a $log_file  > /dev/null
            echo -e "${YELLOW}WARNING: ${message_text}${NC}" | tee -a $log_file
        ;;
        info)
            echo -e "${efp_report_separator}" | tee -a $log_file  > /dev/null
            echo -e "${GREEN}INFO: ${message_text}${NC}" | tee -a $log_file
        ;;
    esac

    if [[ "${message_suggestion}" != "null" ]]
    then
        echo -e "${BLUE}SUGGESTION: ${message_suggestion}${NC}" | tee -a $log_file > /dev/null
    fi

    if [[ "${recommended_links}" != "null" ]]
    then
        echo -e "Recommended links:" | tee -a $log_file > /dev/null
        for link_recommended in $recommended_links
        do
            echo "- $link_recommended" | tee -a $log_file > /dev/null
        done
    fi
}
welcomeMessage()
{
    echo "This script will collect important logs to help you to find eventual issues with your configuration."
    echo -e "${GREEN}By default the script will not restart any service without your approval. So if you do not agree when asked, this script will collect all logs without touch in any running service.${NC}"

    option_selected=""
    if [[ "$collect_log_only" == "false" && "$report_only" == "false" ]]
    then
        echo -e "${GREEN}Select which option do you want to proceed:${NC}"
        echo -e "${GREEN}(1)${NC} Create a report that will look for common issues"
        echo -e "${GREEN}(2)${NC} Collect relevant logs to send to NISP Support Team"
        echo -e "${GREEN}Please type 1 or 2:${NC}"
        read option_selected

        if ! echo $option_selected | egrep -iq "^(1|2)$"
        then
            echo "Option >> $option_selected << invalid. Exiting..."
            exit 24
        fi
    elif [[ "$collect_log_only" == "true" && "$report_only" == "false" ]]
    then
        option_selected="2"
    elif [[ "$collect_log_only" == "false" && "$report_only" == "true" ]]
    then
        option_selected="1"
    else
        # collect logs will always create the report
        collect_log_only=true
        report_only=false
        option_selected="2"
    fi

    case $option_selected in
        1)
            echo -e "${GREEN}The report will be saved in the same directory of the script with the name >> $efp_report_file_name << and >> $efp_report_html_file_name <<.${NC}"
            report_only="true"
        ;;
        2)
            echo -e "${GREEN}In the end an encrypted file will be created, then it will be securely uploaded to NISP and a notification will be sent to NISP Support Team.${NC}"
            echo "If you do not have internet acess when executing this script, you will have an option to store the file in the end."

            echo "Write any text that will identify you for NISP Support Team. Can be e-mail, name, e-mail subject, company name etc."
            read identifier_string
        ;;
    esac
}

uploadLogCollection()
{
    echo -e "${GREEN}${BOLD}Securely${NC}${GREEN} uploading the file to NISP Support Team...${NC}"

    echo -e "${GREEN}Write any text that will identify you for NISP Support Team. Can be e-mail, name, e-mail subject, company name etc.${NC}"
    read identifier_string

    curl_response=$(curl -s -w "\n%{http_code}" -F "file=@${encrypted_file_name}" "${upload_url}")
    if [ $? -ne 0 ]
    then
        echo "Failed to upload the file!"
        exit 23
    else
        echo -e "\nUpload successful!"
        curl_http_body=$(echo $curl_response | cut -d' ' -f1)
        curl_http_status=$(echo $curl_response | cut -d' ' -f2)
        curl_filename=$(echo "$curl_http_body" | tr -d '\r\n')
        curl_response=$(curl -s -w "\n%{http_code}" -X POST --data-urlencode "encrypt_password=${encrypt_password}" --data-urlencode "curl_filename=${curl_filename}" --data-urlencode "identifier_string=${identifier_string}" "$notify_url")
        if [ $? -ne 0 ]
        then
            echo "Failed to notificate the NISP Support Team about the uploaded file. Please send an e-mail."
        else
            echo -e "${GREEN}NISP Support Team was notified about the file!${NC}"
        fi
    fi
}

encryptLogCollection()
{
    gpg --symmetric --cipher-algo AES256 --batch --yes --passphrase "${encrypt_password}" --output "${encrypted_file_name}"  "${compressed_file_name}"
}

checkEfDir()
{
	if [ -d /opt/nisp ]
	then
		efp_dir="/opt/nisp"
	else
		efp_dir="/opt/nice"
	fi
	
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
    if [ -d $efp_dir ]
    then
        checkPackages
    else
        echo "Directory >>> $efp_dir <<< does not exist. Exiting..."
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
    for new_dir in java_info kerberos_conf pam_conf authselect_conf sssd_conf nsswitch_conf warnings os_info os_log journal_log hardware_info efp_log efp_conf efp_files
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

getEtcAuthSelect()
{
    if [ -d /etc/authselect ]
    then
        echo "Collecting /etc/authselect info..."
        target_dir="${temp_dir}/authselect_conf/"
    
        sudo cp -a /etc/authselect $target_dir
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

    sssd_config_file=$(find ${temp_dir}/sssd_conf/ -iname sssd.conf)
	if [[ "${sssd_config_file}x" != "x" ]]
	then
        if [ -f ${sssd_config_file} ]
        then
        	sudo sed -i 's/^[[:space:]]*ldap_default_authtok = .*/ldap_default_authtok = /' $sssd_config_file
        fi
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

    if command -v uptime > /dev/null 2>&1
    then
        sudo uptime > $target_dir/uptime 2>&1
    fi

    if command -v free > /dev/null 2>&1
    then
        sudo free -h > $target_dir/free_-h 2>&1
    fi

    if command -v df > /dev/null 2>&1
    then
        sudo df -h > $target_dir/df_-h 2>&1
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
    sudo journalctl -n 50000 > ${target_dir}/journal_last_50000_lines.log 2>&1
    sudo journalctl --no-page | grep -i selinux > ${target_dir}/selinux_log_from_journal 2>&1
    sudo journalctl --no-page | grep -i apparmor > ${target_dir}/apparmor_log_from_journal 2>&1
    sudo journalctl --no-page | grep -i "failed to allocate" > ${target_dir}/failed_to_allocate_messages
    sudo journalctl --no-page | grep -i "fail" > ${target_dir}/fail_messages
    sudo journalctl --no-page | grep -i "erro" > ${target_dir}/error_messages
}

getEfpData()
{
    echo "Collecting all EF Portal relevant data..."
    target_dir="${temp_dir}/efp_conf/"

    if [ -d ${efp_dir}/enginframe/conf/ ]
    then
        mkdir -p ${target_dir}/opt/${efp_dir_basename}/enginframe/
        sudo cp -r ${efp_dir}/enginframe/conf ${target_dir}/opt/${efp_dir_basename}/enginframe/
    fi

    if [ -d ${efp_dir}/enginframe/ ]
    then
        for efp_version in $(ls ${efp_dir}/enginframe/ | egrep -i "202[0-9]{1}" )
        do
			if [ -d "${efp_dir}/enginframe/${efp_version}" ]
			then
            	mkdir -p ${target_dir}/${efp_dir}/enginframe/${efp_version}/enginframe/
            	sudo cp -r ${efp_dir}/enginframe/${efp_version}/enginframe/conf ${target_dir}/${efp_dir}/enginframe/${efp_version}/enginframe/
			fi
        done
    fi


    target_dir="${temp_dir}/efp_log/"

    if [ -d ${efp_dir}/enginframe/logs ]
    then
        sudo cp -r ${efp_dir}/enginframe/logs ${target_dir}/logs_main
    fi

    if [ -d ${efp_dir}/enginframe/install ]
    then
        sudo cp -r ${efp_dir}/enginframe/install ${target_dir}/install_log
    fi

    efportal_install_config=$(ls -t ${target_dir}/install_log/install/*/efinstall-efportal*\.config 2>/dev/null | head -1)
	if [[ "${efportal_install_config}x" != "x" ]]
	then
	    if [ -f $efportal_install_config ]
	    then
	        cat $efportal_install_config | egrep -i "pam.user" >> $target_dir/pam_user
	    fi
	fi

    efportal_install_log=$(ls -t ${target_dir}/install_log/install/*/efinstall-efportal*.log 2>/dev/null | head -1)
	if [[ "${efportal_install_log}x" != "x" ]]
	then
	    if [ -f $efportal_install_log ]
	    then
	        cat $efportal_install_log | egrep -i "no such file" >> $target_dir/efp_installer_log_no_such_file
	        cat $efportal_install_log | egrep -i "erro" >> $target_dir/efp_installer_log_erro_messages
	        cat $efportal_install_log | egrep -i "fail" >> $target_dir/efp_installer_log_fail_messages
	        cat $efportal_install_log | egrep -i "exit" >> $target_dir/efp_installer_log_exit_messages
	    fi
	fi

    find ${efp_dir} -type d -name "tmp[0-9][0-9][0-9][0-9][0-9]*.session.ef" | while read -r dir
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

    string_pattern="Timeout while waiting for Xdcv process"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/Xdcv_errors
    
        reportMessage \
        "critical" \
        "Identified some issue with Xdcv during DCV Session creation." \
        "${temp_dir}/warnings/Xdcv_timeout" \
        "Xdcv is not starting in a expected time. You need to check your DCV Server." \
        "null"
    else
        reportMessage \
        "info" \
        "Did not find Xdcv timeout issues events." \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="Unable to get host chart for cluster.*SMClient"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/SMClient_errors
    
        reportMessage \ 
        "critical" \
        "Identified a SMClient issue to connect into a cluster." \
        "${temp_dir}/warnings/SMClient_errors" \
        "Please review your cluster configuration and credentials." \
        "null"
    else
        reportMessage \
        "info" \
        "Did not find SMClient issues events." \
        "null" \
        "null" \
        "null"
    fi
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

        readlink -f $(which java) &> $target_dir/java_bin_path
    else
        echo "java command not found!" > ${temp_dir}/warnings/java_not_found
    fi

    echo "List of .jar found and respective md5sum" > ${target_dir}/jar_files_md5sum
    find ${efp_dir} -type f -iname "*.jar" -print0 | while IFS= read -r -d '' jar_file
    do
        md5sum "$jar_file" &>> "${target_dir}/jar_files_md5sum"
    done
}
