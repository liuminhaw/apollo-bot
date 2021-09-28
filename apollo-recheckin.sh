#!/bin/bash


# Script variables
_VERSION=0.1.0
_CONFIG="config"

_WEEKDAY_MAP=(
	["1"]="Monday"
	["2"]="Tuesday"
	["3"]="Wednesday"
	["4"]="Thursday"
	["5"]="Friday"
	["6"]="Saturday"
	["7"]="Sunday"
)


# ----------------------------------------------------------------------------
# Function definition
#
# Usage: show_help
# ----------------------------------------------------------------------------
show_help() {
cat << EOF
Usage: 
${0##*/} [--help] startDate endDate
	--help						Display this help message and exit
	startDate					Start date for applying recheckin, format: YYYY-mm-dd
	endDate						End date for applying recheckin, format: YYYY-mm-dd
EOF
}

# ---------------------------------
# Check exit code function
#
# Usage: check_code EXITCODE MESSAGE
# ---------------------------------
check_code() {
	if [[ "${#}" -ne 2 ]]; then
		echo "[ERROR] Function check_code usage error"
		exit 2
	fi

    if [[ ${?} -ne 0 ]]; then
        echo ${2}
        exit ${1}
    fi
}

# --------------------------------------------------------------------------
# GET API https://auth.mayohr.com/Token and fetch code from response data
#
# Usage: get_login_code USERNAME PASSWORD
# --------------------------------------------------------------------------
get_login_code() {
	if [[ "${#}" -ne 2 ]]; then
		echo "[ERROR] Function get_login_code usage error"
		exit 2
	fi

	local _request_verification_token=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9_' | fold -w 92 | head -n 1)
	local _username=${1}
	local _password=${2}

	local _resp=$(curl -s --location --request GET "https://auth.mayohr.com/Token" \
		--header "Content-Type: application/x-www-form-urlencoded" \
		--data-urlencode "__RequestVerificationToken=${_request_verification_token}" \
		--data-urlencode "grant_type=password" \
		--data-urlencode "locale=en-us" \
		--data-urlencode "password=${_password}" \
		--data-urlencode "red=https://hrm.mayohr.com/tube" \
		--data-urlencode "userName=${_username}")

	local _code=$(echo ${_resp} | jq -r .code)

	echo ${_code}
}

# ------------------------------------------------------------------------------------
# GET API https://authcommon.mayohr.com/api/auth/checkticket and obtain session cookie
#
# Usage: get_session_cookie LOGIN_CODE
# ------------------------------------------------------------------------------------
get_session_cookie() {
	if [[ "${#}" -ne 1 ]]; then
		echo "[ERROR] Function get_session_cookie usage error"
		exit 2
	fi

	local _login_code=${1}

	local _resp_header=$(curl -s -I --request GET "https://authcommon.mayohr.com/api/auth/checkticket?code=${_login_code}")
	# local _session_cookie=$(echo "${_resp_header}" | grep "__ModuleSessionCookie=" | cut -d ":" -f 2- | xargs)
	local _session_cookie=$(echo "${_resp_header}" | grep "__ModuleSessionCookie=" | cut -d ":" -f 2-)

	echo ${_session_cookie}
}

# -------------------------------------------------------------------------------
# POST API https://pt-backend.mayohr.com/api/reCheckInApproval to apply recheckin
#
# Usage: apply_recheckin TIMEZONE ATTEND_DATE ATTEND_TIME ATTEND_TYPE SESSION_COOKIE
# ATTEND_TYPE should be value "arrive" of "leave"
# -------------------------------------------------------------------------------
apply_recheckin() {
	if [[ "${#}" -ne 5 ]]; then
		echo "[ERROR] Function apply_recheckin usage error"
		exit 2
	fi

	local _timezone=${1}
	local _attend_date=${2}
	local _attend_time=${3}
	local _attend_type=${4}
	local _cookie=${5}

	if [[ "${_attend_type,,}" != "arrive" && ${_attend_type,,} != "leave" ]]; then
		echo "[ERROR] Function get_session_cookie parameter ATTEND_TYPE should have value of 'arrive' or 'leave'"
		exit 2
	elif [[ "${_attend_type,,}" == "arrive" ]]; then
		_attend_type="1"
	elif [[ "${_attend_type,,}" == "leave" ]]; then
		_attend_type="2"
	fi

	curl --location --request POST "https://pt-backend.mayohr.com/api/reCheckInApproval" \
		--header "Cookie: ${_cookie}" \
		--header "Content-Type: application/json" \
		--data-raw "$(jq -n \
			--arg _attendance_on "${_attend_date}T${_attend_time}${_timezone}" \
			--arg _attendance_type "${_attend_type}" \
			'.AttendanceOn = $_attendance_on |
			.AttendanceType = $_attendance_type |
			.PunchesLocationId = "00000000-0000-0000-0000-000000000000" |
			.LocationDetails = "remote" |
			.ReasonsForMissedClocking = "" |
			.IsBehalf = "false"'
		)"
}


# Command line options
_config=${_CONFIG}
while :; do
    case ${1} in
        --help)
            show_help
            exit
            ;;
        --version)
            echo "Version: ${_VERSION}"
            exit
            ;;
        --config)
            if [[ "${2}" ]]; then
                _config=${2}
                shift
            else
                echo -e "[ERROR] '--config' requires a non-empty option argument." 1>&2
                exit 1
            fi
            ;;
        --config=?*)
            _config=${1#*=} # Delete everything up to "=" and assign the remainder
            ;;
        --config=)
            echo -e "[ERROR] '--config' requires a non-empty option argument." 1>&2
            exit 1
            ;;
        -?*)
            echo -e "[WARN] Unknown option (ignored): ${1}" 1>&2
            exit 1
            ;;
        *)  # Default case: no more options
            break
    esac

    shift
done


# Parameters validation
if [[ "${#}" -ne 2 ]]; then
	show_help
	exit 1
fi

if [[ ! -f "${_config}" ]]; then
	echo "[ERROR] configuration file ${_config} does not exist"
	exit 3 
else
	source ${_config}
fi

# Loop through date
_start_date=${1}
_end_date=${2}

_start_date_fmt=$(date -d ${_start_date} +%Y%m%d)
check_code 1 "Format invalid for start date '${_start_date}'"
_end_date_fmt=$(date -d ${_end_date} +%Y%m%d)
check_code 1 "Format invalid for end date '${_end_date}'"

if [[ ${_start_date_fmt} -gt ${_end_date_fmt} ]]; then
	echo "[ERROR] Start date ${_start_date} should not be after End date ${_end_date}"
	exit 1
fi

_check_ticket_code=$(get_login_code ${_USERNAME} ${_PASSWORD})
echo "[DEBUG] Login code: ${_check_ticket_code}"
_session_cookie=$(get_session_cookie ${_check_ticket_code})
_session_cookie=$(echo ${_session_cookie} | sed -e "s/\r//g")
echo "[DEBUG] Session cookie: ${_session_cookie}"

echo "Start date: ${_start_date}, End date: ${_end_date}"

for (( i=${_start_date_fmt}; i<=${_end_date_fmt}; i++ )); do
	_apply_date=$(date -d ${i} +%Y-%m-%d)
	_weekday=$(date -d ${i} +%u)
	echo "[INFO] Date ${i} - ${_WEEKDAY_MAP[${_weekday}]}"

	if [[ "${_weekday}" -eq 6 || "${_weekday}" -eq 7 ]]; then
		echo "[INFO] No checkin need to be applied on weekend"
		sleep 1
	else
		apply_recheckin "${_TIMEZONE}" "${_apply_date}" "${_ARRIVE_ON}" "arrive" "${_session_cookie}"
		sleep 3
		apply_recheckin "${_TIMEZONE}" "${_apply_date}" "${_LEAVE_AT}" "leave" "${_session_cookie}"
		sleep 3
		echo ""
	fi
done
