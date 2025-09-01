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
    cat << EOF >> ${efp_report_dir_path}/html_head
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

        .log-details {
            margin-top: 1rem;
        }
        .log-container {
            position: relative;
            background-color: #1e1e1e;
            border: 1px solid #333;
            border-radius: 4px;
            padding: 1rem;
            margin-top: 0.5rem;
        }
        .log-container pre {
            white-space: pre-wrap;
            word-wrap: break-word;
            margin: 0;
            padding-top: 2.5rem; /* Space for the copy button */
            max-height: 300px;
            overflow-y: auto;
            color: #f1f1f1;
        }
        .copy-btn {
            position: absolute;
            top: 10px;
            right: 10px;
            background-color: #333;
            color: white;
            border: 1px solid #555;
            padding: 5px 10px;
            border-radius: 3px;
            cursor: pointer;
            font-family: inherit;
        }
        .copy-btn:hover {
            background-color: #444;
        }

    </style>
    <script>
        function copyToClipboard(elementId, button) {
            const textToCopy = document.getElementById(elementId).innerText;
            navigator.clipboard.writeText(textToCopy).then(() => {
                const originalText = button.innerText;
                button.innerText = 'Copied!';
                setTimeout(() => {
                    button.innerText = originalText;
                }, 2000);
            }).catch(err => {
                console.error('Failed to copy text: ', err);
                const originalText = button.innerText;
                button.innerText = 'Failed!';
                setTimeout(() => {
                    button.innerText = originalText;
                }, 2000);
            });
        }
    </script>
</head>
<body>
    <header>
        <h1>EF Portal Server Report</h1>
        <div class="support-info">
            <p>If you need support:</p>
            <p> <a href="https://www.ni-sp.com/support/" target="_blank">https://www.ni-sp.com/support/</a></p>
        </div>
    </header>
EOF

    cat << EOF >> ${efp_report_dir_path}/html_tail
</body>
</html>
EOF

    cat ${efp_report_dir_path}/html_head > $efp_report_html_path

    for html_message_type in critical warning info
    do
        if [ -f ${efp_report_dir_path}/html_${html_message_type} ]
        then
            cat ${efp_report_dir_path}/html_${html_message_type} >> $efp_report_html_path
        fi
    done
    cat ${efp_report_dir_path}/html_tail >> $efp_report_html_path
    rm -f ${efp_report_dir_path}/html_*
}

command_exists()
{
    command -v "$1" &> /dev/null
}

byebyeMessage()
{
    echo -e "${GREEN}Thank you! ${NC}"
}

finalizeReport() {
    echo "Finalizing reports..."
    if [ -f "$efp_report_txt_path" ]; then
        cp "$efp_report_txt_path" .
        echo -e "${GREEN}Report saved to: $(pwd)/$efp_report_txt_file_name${NC}"
    else
        echo -e "${RED}Warning: Text report file not found at $efp_report_txt_path${NC}"
    fi

    if [ -f "$efp_report_html_path" ]; then
        cp "$efp_report_html_path" .
        echo -e "${GREEN}HTML Report saved to: $(pwd)/$efp_report_html_file_name${NC}"
    else
        echo -e "${RED}Warning: HTML report file not found at $efp_report_html_path${NC}"
    fi
}

reportMessage()
{
    local message_type="$1"
    local message_text="$2"
    
    # FIX: Use the full path for the text report file.
    if [[ "$3" == "null" ]]; then
        local log_file="${efp_report_txt_path}"
    else
        # The second file path ($3) is already a full path inside temp_dir
        local log_file="${efp_report_txt_path} $3"
    fi

    local message_suggestion="$4"
    local recommended_links="$5"
    local target_dir="$6"
    local string_pattern="$7"

    reportMessageWrite "${message_text}" "${log_file}" "${message_type}" "${message_suggestion}" "${recommended_links}" "${target_dir}" "${string_pattern}"
    reportMessageWriteHtml "${message_text}" "null" "${message_type}" "${message_suggestion}" "${recommended_links}" "${target_dir}" "${string_pattern}"
}

reportMessageWriteHtml()
{
    local message_text="$1"
    local log_file="$2"
    local message_type=$3
    local message_suggestion=$4
    local recommended_links=$5
    local target_dir="$6"
    local string_pattern="$7"

    cat << EOF >> ${efp_report_dir_path}/html_${message_type}
    <div class="report-section ${message_type}">
        <h1><span class="status-keyword ${message_type}">$(echo "${message_type}" | tr '[:lower:]' '[:upper:]'):</span> ${message_text}</h1>
EOF

    if [[ "${message_suggestion}" != "null" ]]
    then
        cat << EOF >> ${efp_report_dir_path}/html_${message_type}
            <p class="suggestion"><strong>SUGGESTION:</strong> $message_suggestion</p>
EOF
    fi

    if [[ "${recommended_links}" != "null" ]]
    then
        cat << EOF >> ${efp_report_dir_path}/html_${message_type}
        <p class="suggestion"><strong>Recommended links:</strong></p>
        <ul>
EOF
        for link_recommended in $recommended_links
        do
            cat << EOF >> ${efp_report_dir_path}/html_${message_type}
    <li><a href="${link_recommended}" target="_blank">${link_recommended}</a></li>
EOF
        done

        cat << EOF >> ${efp_report_dir_path}/html_${message_type}
        </ul>
EOF
    fi

    if [[ "${target_dir}" != "null" && "${string_pattern}" != "null" && -n "${target_dir}" && -n "${string_pattern}" ]]
    then
        local unique_id="log_block_$(date +%s%N)"
        local log_content=$(egrep -Ri "${string_pattern}" "${target_dir}" 2>/dev/null | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g; s/'"'"'/\&#39;/g')
        if [ -n "$log_content" ]
        then
            cat << EOF >> ${efp_report_dir_path}/html_${message_type}
            <div class="log-details">
                <p><strong>Found Patterns Log:</strong></p>
                <div class="log-container">
                    <button class="copy-btn" onclick="copyToClipboard('${unique_id}', this)">Copy</button>
                    <pre id="${unique_id}"><code>${log_content}</code></pre>
                </div>
            </div>
EOF
        fi
    fi

    cat << EOF >> ${efp_report_dir_path}/html_${message_type}
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
    local target_dir="$6"
    local string_pattern="$7"


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

    if [[ "${target_dir}" != "null" && "${string_pattern}" != "null" && -n "${target_dir}" && -n "${string_pattern}" ]]
    then
        local log_content=$(egrep -Ri "${string_pattern}" "${target_dir}" 2>/dev/null)
        if [ -n "$log_content" ]
        then
            echo -e "\n--- Found Patterns Log ---" | tee -a $log_file > /dev/null
            echo "$log_content" | tee -a $log_file > /dev/null
            echo -e "--- End of Patterns Log ---\n" | tee -a $log_file > /dev/null
        fi
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
            # FIX: Used the correct variable for the text report file name
            echo -e "${GREEN}The report will be saved in the same directory of the script with the name >> $efp_report_txt_file_name << and >> $efp_report_html_file_name <<.${NC}"
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
    for new_dir in java_info kerberos_conf pam_conf authselect_conf sssd_conf sssd_log kerberos_conf nsswitch_conf warnings os_info os_log journal_log hardware_info efp_log efp_conf efp_permissions ${efp_report_dir_name} network_data
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

checkEfpSetuid()
{
    echo "Checking for required setuid permissions..."

    # Find all potential checkpassword-pam files within the EnginFrame installation
    local pam_files=$(find "${efp_dir}" -type f -name "checkpassword-pam.*" 2>/dev/null)

    if [ -z "$pam_files" ]; then
        reportMessage \
        "warning" \
        "Could not find any 'checkpassword-pam' binaries." \
        "null" \
        "The PAM plugin might not be installed correctly or the script is looking in the wrong directory. This can cause authentication issues." \
        "null" \
        "null" \
        "null"
        return
    fi

    for file in $pam_files; do
        # Check if the file has the setuid bit set using find's -perm check
        if ! find "$file" -perm -4000 | grep -q "."; then
            reportMessage \
            "critical" \
            "Missing setuid permission on critical file." \
            "null" \
            "The file '${file}' is missing the setuid bit. This will cause PAM authentication to fail. Please run 'sudo chmod u+s \"${file}\"' to fix it." \
            "null" \
            "null" \
            "null"
        else
            reportMessage \
            "info" \
            "File '${file}' has correct setuid permissions." \
            "null" \
            "null" \
            "null" \
            "null" \
            "null"
        fi
    done
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
        # Use -L to dereference symbolic links and copy the actual files
        sudo cp -Lr /etc/pam.d ${target_dir} > /dev/null 2>&1
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

    string_pattern="sssd.*error"
    warning_file_name="sssd_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}
    
        reportMessage \ 
        "critical" \
        "Identified SSSD errors." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please check your SSSD logs to identify why error messages are happening. It can affect your authentication." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find SSSD issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
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

getNetworkData()
{
    echo "Collecting all Network relevant data..."
    target_dir="${temp_dir}/network_data/"

    if command_exists netstat
    then
        echo "Using netstat..."
        netstat -tulpn >> ${target_dir}/netstat_-tulpn
    elif command_exists ss
    then
        echo "Using ss..."
        ss -tulpn >> ${target_dir}/ss_-tulpn
    elif command_exists lsof
    then
        echo "Using lsof..."
        lsof -i -P -n | grep LISTEN >> ${target_dir}/lsof_-i_-P_-n
    else
        echo "None of the required commands (netstat, ss, lsof) are available."
        echo "Falling back to /proc filesystem:"
        echo "TCP ports:"
        cat /proc/net/tcp 2>/dev/null >> ${target_dir}/proc_net_tcp
        echo "UDP ports:"
        cat /proc/net/udp 2>/dev/null ${target_dir}/proc_net_udp
    fi

    if command_exists dmesg
    then
        DMESG_ERRORS=$(sudo dmesg | grep -iE '(eth|eno|ens|enp|wl)[0-9]: (link|driver|hardware|error|timeout)')

        if [ -n "$DMESG_ERRORS" ]
        then
            reportMessage \
            "warning" \
            "Network errors were found in dmesg." \
            "${temp_dir}/warnings/found_network_issues" \
            "You need to troubleshoot what is wrong with your ethernet card or the network driver.." \
            "null" \
            "null" \
            "null"

            sudo dmesg | grep -iE '(eth|eno|ens|enp|wl)[0-9]: (link|driver|hardware|error|timeout)' | grep -i "error\|fail\|down\|collision\|duplex\|timeout" > ${target_dir}/network_issues_log
        else
            reportMessage \
            "info" \
            "Did not find network errors in the ethernet devices." \
            "null" \
            "null" \
            "null" \
            "null" \
            "null"
        fi
    fi

    dns_is_working="false"
    if command_exists host
    then
        if ! host $dns_test_domain &>/dev/null
        then
            dns_is_working="false"
        else
                dns_is_working="true"
        fi
    elif command_exists dig
    then
        if ! dig +short $dns_test_domain  &>/dev/null
        then
            dns_is_working="false"
        else
            dns_is_working="true"
        fi
    elif command_exists nslookup
    then
        if ! nslookup $dns_test_domain  &>/dev/null
        then
            dns_is_working="false"
        else
            dns_is_working="true"
        fi
    elif command_exists getent
    then
        if ! getent hosts  &>/dev/null
        then
            dns_is_working="false"
        else
            dns_is_working="true"
        fi
    fi

    if $dns_is_working
    then
        reportMessage \
        "info" \
        "DNS resolution >> IS WORKING <<." \
        "${target_dir}/dns_is_working" \
        "DNS is important to validate your EFP license and to reach your RLM server, if you are using one." \
        "null" \
        "null" \
        "null"
    else
        reportMessage \
        "critical" \
        "DNS resolution >> IS NOT WORKING <<." \
        "${target_dir}/dns_is_NOT_working ${temp_dir}/warnings/dns_is_NOT_working" \
        "You need to check your DHCP server and your /etc/resolv.conf to understand why your server can not solve DNS." \
        "null" \
        "null" \
        "null"
    fi

    if command_exists ping
    then
        if ! ping -c 1 -W 3 $ip_test_external &>/dev/null
        then
            reportMessage \
            "warning" \
            "No external connectivity to ${ip_test_external}." \
            "${target_dir}/ping_to_${ip_test_external}_is_NOT_working ${temp_dir}/warnings/ping_to_${ip_test_external}_is_NOT_working" \
            "It seems that you have issues to get external connectivity. Can be your firewall blocking or some network issue. You need to check the EFP server logs for possible network issues." \
            "null" \
            "null" \
            "null"
        else
            reportMessage \
            "info" \
            "External connectivity to ${ip_test_external} was tested and is working." \
            "${target_dir}/ping_to_${ip_test_external}_is_working" \
            "null" \
            "null" \
            "null" \
            "null"
        fi
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
    
    if [ -f /etc/shadow ]
    then
        sudo cp /etc/shadow $target_dir > /dev/null 2>&1
    fi

    if [ -f /etc/group ]
    then
        sudo cp /etc/group $target_dir > /dev/null 2>&1
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
    sudo journalctl -n 100000 > ${target_dir}/journal_last_100000_lines.log 2>&1
    sudo journalctl --no-page | grep -i selinux > ${target_dir}/selinux_log_from_journal 2>&1
    sudo journalctl --no-page | grep -i apparmor > ${target_dir}/apparmor_log_from_journal 2>&1
    sudo journalctl --no-page | grep -i "failed to allocate" > ${target_dir}/failed_to_allocate_messages
    sudo journalctl --no-page | grep -i -C 10 "fail" > ${target_dir}/fail_messages
    sudo journalctl --no-page | grep -i -C 10 "erro" > ${target_dir}/error_messages
    sudo journalctl --no-page | grep -i -C 10 "(timeout|timedout|timed out)" > ${target_dir}/timeout_messages
    sudo journalctl --no-page | grep -i -C 10 "dcv" > ${target_dir}/dcv_messages
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

    find ${efp_dir} -type d -name "tmp[0-9][0-9][0-9][0-9][0-9]*.session.ef" | while read -r found_dir
    do
        session_tmp_dir=$(basename "$found_dir")
        mkdir -p "${target_dir}/sessions/${session_tmp_dir}"
    
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
    
        for file_name in "${files_to_copy[@]}"
        do
            if [ -f "$found_dir/$file_name" ]
            then
                sudo cp "$found_dir/$file_name" "${target_dir}/sessions/${session_tmp_dir}/"
            fi
        done
    
        if [ -d "$found_dir/server-log" ]
        then
            sudo cp -r "$found_dir/server-log" "${target_dir}/sessions/$session_tmp_dir/"
        fi
    done

    string_pattern="Connection refused"
    warning_file_name="connection_refused"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        count_string_pattern=$(egrep -Ric "${string_pattern}" ${target_dir}/logs_main/*)
        reportMessage \
        "critical" \
        "Identified >>> $count_string_pattern <<< messages about connection refused." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please review your cluster configuration and credentials." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find Connection Refused messages." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="request token does not match session token"
    warning_file_name="csrf_token_does_not_match"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        count_string_pattern=$(egrep -Ric "${string_pattern}" ${target_dir}/logs_main/*)
        reportMessage \
        "warning" \
        "Identified >>> $count_string_pattern <<< messages about CSRF Token not matching with the session token." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please review your cluster configuration and credentials." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find CSRF Token not match session token issue." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="Unable to get host chart for cluster.*SMClient"
    warning_file_name="SMClient_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}
    
        reportMessage \
        "critical" \
        "Identified a SMClient issue to connect into a cluster." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please review your cluster configuration and credentials." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find SMClient issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="dcvsm.*Error during retrieval of host list for cluster"
    warning_file_name="efp_dcvsm_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified an issue to connect into a DCV SM cluster." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please review your cluster configuration and credentials." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find DCV SM issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="SQL.*No current connection"
    warning_file_name="efp_db_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified connection issues with the database." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please check your database service status if the service is working. Also test if the EF Portal can reach the database IP and port." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find database connection issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="error.*Failed to retrieve a valid token for user.*dcvsm"
    warning_file_name="efp_dcvsm_cluster"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified failure to retrieve a valid token for DCV SM cluster." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please check your DCV SM Cluster configuration and logs to identify why is not possible to retrieve a valid token." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find DCVM SM token issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="slurm.*jobs.*error"
    warning_file_name="slurm_jobs_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified SLURM jobs errors." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please check your SLURM service to identify the root cause." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find SLURM jobs issues events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="syntax error near unexpected token"
    warning_file_name="efp_syntax_errors"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified EF Portal scripts with syntax errors." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Please check your published applicatons and customized files to identify from where the syntax error is coming." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find EF Portal scripts syntax issue events." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="grid.*Unable to get host list for cluster"
    warning_file_name="efp_unable_to_get_host_list_for_cluster"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "Identified issues to get a host list from a cluster." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "You need to check your cluster configuration and the connectivity with the cluster to identify and fix the issue." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find issues events to get host list from a cluster." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi

    string_pattern="An I/O error was encountered submitting your job"
    warning_file_name="efp_io_error_while_submitting_job"
    if safeLogCheck "${string_pattern}" "${target_dir}"
    then
        egrep -Ri "${string_pattern}" ${target_dir}/* >> ${temp_dir}/warnings/${warning_file_name}

        reportMessage \
        "critical" \
        "An I/O error was encountered submitting your job." \
        "${temp_dir}/warnings/${warning_file_name}" \
        "Is not possible to use I/O resources due some issue that is happening with your OS or the remote filesystem used. Please check your ef.log logs to get more details." \
        "null" \
        "${target_dir}" \
        "${string_pattern}"
    else
        reportMessage \
        "info" \
        "Did not find I/O error issues events when submitting jobs." \
        "null" \
        "null" \
        "null" \
        "null" \
        "null"
    fi
}

getEfpPermissions()
{
    echo "Collecting all EF Portal permissions..."
    target_dir="${temp_dir}/efp_permissions/"

    # Using find with -ls to get a detailed, structured list of all files and their permissions.
    # This is a standard and easily comparable format.
    sudo find "${efp_dir}" -ls > "${target_dir}/efp_file_permissions.ls" 2>/dev/null

    # An alternative, more structured format using printf for easier parsing
    sudo find "${efp_dir}" -printf "%M\t%u\t%g\t%p\n" > "${target_dir}/efp_file_permissions.txt" 2>/dev/null
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

checkEfpDir()
{
    # If --efp_dir is passed, we honor it. Otherwise, we try to auto-detect.
    if [[ "$efp_dir" != "/opt/nisp" ]]; then
        echo "User specified --efp_dir=${efp_dir}. Using it."
    elif [ -d "/opt/nisp" ]; then
        efp_dir="/opt/nisp"
        echo "Found EnginFrame in /opt/nisp."
    elif [ -d "/opt/nice" ]; then
        efp_dir="/opt/nice"
        echo "Found EnginFrame in /opt/nice."
    else
        # Find the script's absolute path, resolving symlinks
        local script_path
        script_path=$(readlink -f "$0")
        # Check if 'enginframe' is in the path
        if [[ "$script_path" == *"/enginframe/"* ]]; then
            # Get the path part before the first '/enginframe/'
            efp_dir=${script_path%%/enginframe/*}
            echo "Determined EnginFrame base directory from script path: ${efp_dir}"
        else
            efp_dir="" # Reset to empty if not found
        fi
    fi

    if [ -z "$efp_dir" ] || [ ! -d "$efp_dir" ]; then
        echo -e "${RED}Error: Could not determine the EnginFrame installation directory.${NC}"
        echo "Checked /opt/nisp, /opt/nice, and script path. Please specify the directory using the --efp_dir=<path> argument."
        exit 40
    fi

    # Update efp_dir_basename based on the found directory
    efp_dir_basename=$(basename "${efp_dir}")
    echo "Using ${efp_dir} as the EnginFrame installation directory."
}
