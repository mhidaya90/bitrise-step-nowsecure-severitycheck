#!/bin/bash
set -ex

# Required parameters
if [ -z "${nowsecure_api_token}" ] ; then
  echo " [!] Missing required input: nowsecure_api_token"
  exit 1
fi

if [ -z "${platform}" ] ; then
  echo " [!] Missing required input: platform"
  exit 1
fi

if [ -z "${package}" ] ; then
  echo " [!] Missing required input: package"
  exit 1
fi

if [ -z "${bitrise_token}" ] ; then
  echo " [!] Missing required input: package"
  exit 1
fi

rm -f AssessmentlistResponse.json

AssessmentListCall=$(curl -H "Authorization: Bearer $nowsecure_api_token" -X GET \
    https://lab-api.nowsecure.com/app/$platform/$package/assessment/ -o AssessmentlistResponse.json)

status=$(jq '.[-1].task_status' AssessmentlistResponse.json | tr -d \")

if [ "$status" == "pending" ] ; then
    taskID=$(jq '.[-1].task' AssessmentlistResponse.json)
fi

while [ "$status" == "pending" ]
        do
            echo "Assessment Check Status:"$status
            echo "Wait for Assessment to complete.!!Please be Patient....."
            sleep 60
            rm -f AssessmentlistResponse.json
	    AssessmentListCall=$(curl -H "Authorization: Bearer $nowsecure_api_token" -X GET \
    https://lab-api.nowsecure.com/app/$platform/$package/assessment/ -o AssessmentlistResponse.json)

            status=$(jq '.[-1].task_status' AssessmentlistResponse.json | tr -d \")            
        done

if [ ! -z "$taskID" ] ;	then
	rm -f findingsResponse.json
	AssessmentfindingsCall=$(curl -H "Authorization: Bearer $nowsecure_api_token" -X GET \
https://lab-api.nowsecure.com/assessment/$taskID/findings -o AssessmentfindingsResponse.json)
	if [ -s AssessmentfindingsResponse.json ] ; then
		severityCount=$(jq '.[].severity' AssessmentfindingsResponse.json | grep "medium\|high\|critical" | wc -l)
		echo "severityCount===>"$severityCount
		if [ $severityCount -ge 1 ] ; then 
			echo "Abort Going to Call----->>>"
              		curl -X POST -H "Authorization: $bitrise_token" https://api.bitrise.io/v0.1/apps/$BITRISE_APP_SLUG/builds/$BITRISE_BUILD_SLUG/abort -d '{"abort_reason": "Now Secure Identified Medium/High Priority Risk in App Bundle"}'
          	else
			echo "Application has no Severities, Good to go for Production..!!!"
			exit 0
		fi
 	else
		curl -X POST -H "Authorization: $bitrise_token" https://api.bitrise.io/v0.1/apps/$BITRISE_APP_SLUG/builds/$BITRISE_BUILD_SLUG/abort -d '{"abort_reason": "NowSecure Assessment Findings Internal API Error"}'
 	fi
else
curl -X POST -H "Authorization: $bitrise_token" https://api.bitrise.io/v0.1/apps/$BITRISE_APP_SLUG/builds/$BITRISE_BUILD_SLUG/abort -d '{"abort_reason": "NowSecure Assessment List Internal API Error"}'
fi
