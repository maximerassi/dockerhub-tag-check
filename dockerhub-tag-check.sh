#!/bin/bash

################################################################################
# DTC - DockerHub Tag Check                                                    #
# v0.1.0000                                                                    #
#                                                                              #
# Check if the specified tag already was already used for your image.          #
#                                                                              #
# Usage                                                                        #
# > ./dockerhb-tag-check.sh -u username -p password -i myimage -t ec98d823132  #
# > FOUND                                                                      #
#                                                                              #
# Please note: This script is meant to be used within a CI pipeline. In such   #
# pipelines, sensitive information such as as password can be automatically    #
# hidden from all logs when it is stored as a secret environment variable.     #
# Please ensure your password does not end up in clear text in any logs by     #
# referring to your pipeline's documentation.                                  #
#                                                                              #
################################################################################
################################################################################
################################################################################
#                                                                              #
#  https://github.com/maximerassi                                              #
#                                                                              #
################################################################################
################################################################################
################################################################################

DOCKE_USERNAME=""
DOCKER_PASSWORD=""
IMAGE_NAME=""
IMAGE_TAG=""
OPTIND=1

#
# Show all available and required parameters.
show_help() {

   echo ""
   echo "Usage: $0 -u DOCKER_USERNAME -p DOCKER_PASSWORD -i IMAGE_NAME"
   echo -e "\t-u Docker Username."
   echo -e "\t-p Docker Password."
   echo -e "\t-i Docker image name."
   echo -e "\t-t Docker image tag to search for."
   exit
}

while getopts "u:p:i:t:" opt
do
   case "$opt" in
      u ) DOCKER_USERNAME="$OPTARG" ;;
      p ) DOCKER_PASSWORD="$OPTARG" ;;
      i ) IMAGE_NAME="$OPTARG" ;;
      t ) IMAGE_TAG="$OPTARG" ;;
      ? ) show_help ;;
   esac
done

#
# Check whether all required dependencies are installed.
check_dependencies () {
  check_dependency "jq"
  check_dependency "curl"
}

#
# Check whether a specific dependency is installed.
check_dependency () {
  COMMAND=$1
  type -P $COMMAND &>/dev/null || { echo "Aborting. ${COMMAND} is not installed"; exit 1; }
}

#
# Check whether all required inputs have been set.
check_required_input () {
  if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ] || [ -z "$IMAGE_NAME" ]
  then
     echo "Some or all of the parameters are empty";
     show_help
  fi
}

#
# Generic HTTP response handler to exit on error.
http_process_response () {
  local URL="$1"
  shift
  # curl specific parameter
  local ARRAY=("$@")

  HTTP_RESPONSE="$(curl -sSL --write-out "HTTPSTATUS:%{http_code}" \
    -H "Content-Type: application/json;charset=UTF-8" \
    "${ARRAY[@]}" \
    "$URL")"

  HTTP_BODY=$(echo $HTTP_RESPONSE | sed -e 's/HTTPSTATUS\:.*//g')
  HTTP_STATUS=$(echo $HTTP_RESPONSE | tr -d '\n' | sed -e 's/.*HTTPSTATUS://')

  if [ ! $HTTP_STATUS -eq 200  ]; then
    echo "HTTP Error $HTTP_STATUS. Aborting"
    echo ${HTTP_BODY}
    exit 1
  fi

  echo $HTTP_BODY
}

#
# Attempt to fetch the dockerhub session from the current local session.
# Doing it this way would not require providing username/password.
# This is currently not in use.
# @return Return your docker hub api token.
fetch_token_from_session() {
  REGISTRY_SERVICE=${REGISTRY_SERVICE:-"registry.docker.io"}
  CURL_URL="https://auth.docker.io/token?service=${REGISTRY_SERVICE##*(//)}"
  CURL_PARAMS=(
    --header "Content-Type: application/json" \
    --request GET
  )

  response=$(http_process_response "${CURL_URL}" "${CURL_PARAMS[@]}")
  echo $response | jq -r .token
}

#
# Fetch the API token from docker hub using docker username and password.
# This token will be required for requests.
# @return Return your docker hub api token.
fetch_token_from_credentials() {
  CURL_URL="https://hub.docker.com/v2/users/login/"
  CURL_PARAMS=(
    --request POST \
    --data '{"username": "'${DOCKER_USERNAME}'", "password": "'${DOCKER_PASSWORD}'"}'
  )

  response=$(http_process_response "${CURL_URL}" "${CURL_PARAMS[@]}")
  echo $response | jq -r .token
}

#
# Generic method to run GET requests that require authentication.
# @return Return the http response.
docker_http_get () {
  CURL_URL=$1
  TOKEN=$(fetch_token_from_credentials)
  CURL_PARAMS=(
    --header "Authorization: JWT ${TOKEN}" \
    --request GET
  )

  response=$(http_process_response "${CURL_URL}" "${CURL_PARAMS[@]}")
  echo $response
}

#
# Retrieve all tags for the given image
# @param Name of the image in your private namespace. i.e. myimage
# @return Return objects for each tag.
get_image_tags () {
  INPUT_IMAGE_NAME=$1
  DOMAIN="https://hub.docker.com/v2"
  response=$(docker_http_get "${DOMAIN}/repositories/${DOCKER_USERNAME}/${INPUT_IMAGE_NAME}/tags/")
  echo $response
}

#
# Retrieve the last tag for the given image.
# @return Return an object for the specified tag. Or empty.
find_image_tag () {
  # Name of the image in your private namespace. i.e. myimage
  INPUT_IMAGE_NAME=$1
  # Tag to search for
  INPUT_IMAGE_TAG_NAME=$2
  IMAGE_TAGS=$(get_image_tags $INPUT_IMAGE_NAME)
  # echo $IMAGE_TAGS | jq '[."results"[]["name"]]'
  echo $IMAGE_TAGS | jq --arg i "$INPUT_IMAGE_TAG_NAME" '."results"[] | select(.name == $i) | .'
}

check_dependencies
check_required_input

tag_search_result=$(find_image_tag $IMAGE_NAME $IMAGE_TAG)

if [ -z "$tag_search_result" ]
then
  echo "NOT_FOUND"
else
  echo "FOUND"
fi
