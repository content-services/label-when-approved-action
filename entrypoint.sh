#!/bin/bash
set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "Set the GITHUB_TOKEN env variable."
  exit 1
fi

if [[ -z "$GITHUB_REPOSITORY" ]]; then
  echo "Set the GITHUB_REPOSITORY env variable."
  exit 1
fi

if [[ -z "$GITHUB_EVENT_PATH" ]]; then
  echo "Set the GITHUB_EVENT_PATH env variable."
  exit 1
fi

addLabel=$ADD_LABEL
if [[ -n "$LABEL_NAME" ]]; then
  echo "Warning: Plase define the ADD_LABEL variable instead of the deprecated LABEL_NAME."
  addLabel=$LABEL_NAME
fi

if [[ -z "$addLabel" ]]; then
  echo "Set the ADD_LABEL or the LABEL_NAME env variable."
  exit 1
fi

URI="https://api.github.com"
API_HEADER="Accept: application/vnd.github.v3+json"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"

action=$(jq --raw-output .action "$GITHUB_EVENT_PATH")
state=$(jq --raw-output .review.state "$GITHUB_EVENT_PATH")
number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")

label_when_approved() {
  curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "https://api.github.com/organizations/102682140/team/7316832/members"
  teamMembers=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "https://api.github.com/organizations/102682140/team/7316832/members" | jq --raw-output ".[].login") #TODO make the team name configurable

  # https://developer.github.com/v3/pulls/reviews/#list-reviews-on-a-pull-request
  body=$(curl -sSL -H "${AUTH_HEADER}" -H "${API_HEADER}" "${URI}/repos/${GITHUB_REPOSITORY}/pulls/${number}/reviews?per_page=100")
  reviews=$(echo "$body" | jq --raw-output '.[] | {state: .state, login: .user.login} | @base64')
  
  for r in $reviews; do
    review="$(echo "$r" | base64 -d)"
    rState=$(echo "$review" | jq --raw-output '.state')
    reviewer=$(echo "$review" | jq --raw-output '.login')
    if [[ "$rState" == "APPROVED" ]]; then
      for tm in $teamMembers; do
        if [[ "$tm" == "$reviewer" ]]; then
          echo "Labeling pull request"

          curl -sSL \
            -H "${AUTH_HEADER}" \
            -H "${API_HEADER}" \
            -X POST \
            -H "Content-Type: application/json" \
            -d "{\"labels\":[\"${addLabel}\"]}" \
            "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels"

          if [[ -n "$REMOVE_LABEL" ]]; then
              curl -sSL \
                -H "${AUTH_HEADER}" \
                -H "${API_HEADER}" \
                -X DELETE \
                "${URI}/repos/${GITHUB_REPOSITORY}/issues/${number}/labels/${REMOVE_LABEL}"
          fi
          break
        fi
      done
    fi
  done
}

label_when_approved
