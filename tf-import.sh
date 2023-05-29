#!/bin/bash


function import_members() {
  members_file="members.json"

  # Read members from JSON file
  members=$(jq -r '.[] | @base64' $members_file)

  # Loop through members and import state
  for member in $members; do
    decoded_member=$(echo $member | base64 -d)
    username=$(echo $decoded_member | jq -r '.username')

    terraform import "github_membership.member[\"${username}\"]" "${ORG}:${username}"
  done
}

function import_teams() {
  teams_file="teams.json"

  # Parse the JSON file into an array of objects
  teams=$(jq -r '.[] | @base64' $teams_file)

  # Loop through the teams and import the Terraform state for each one
  for team in $teams; do
    decoded_team=$(echo $team | base64 -d)
    team_id=$(echo $decoded_team | jq -r '.id')
    team_slug_name=$(echo $decoded_team | jq -r '.slug')
    team_name=$(echo $decoded_team | jq -r '.name')

    terraform import "github_team.teams[\"${team_name}\"]" "${team_id}"
  done
}


function import_team_membership() {
  team_memberships_file="team_memberships.json"

  for team_id in $(jq -r '.[].id' team_memberships.json); do
    for username in $(jq -r ".[] | select(.id == $team_id) | .members[].username" team_memberships.json); do
      terraform import "github_team_membership.team_memberships[\"$team_id-$username\"]" "$team_id:$username"
    done
  done
}


# function import_repo_collaborator() {
#   # Path to the JSON file containing collaborator data
#   json_file="repo-collaborators.json"

#   # Retrieve the list of collaborators from the JSON file
#   collaborators=$(jq -r '.[] | "\(.repo) \(.user)"' "$json_file")

#   # Loop through each collaborator and perform the Terraform import
#   while read -r repo user; do
#     terraform import "github_repository_collaborator.collaborator[\"$repo-$user\"]" "$repo:$user"
#   done <<< "$collaborators"
# }


import_repo_collaborator() {
    local json_file="individual_collaborators.json"

    local collaborators=$(cat "$json_file")
    local repos=$(echo "$collaborators" | jq -r 'keys[]')

    for repo in $repos
    do
      local users=$(echo "$collaborators" | jq -r --arg REPO "$repo" '.[$REPO][] | .username')

      for user in $users
      do
        echo "Importing collaborator $user for repository $repo..."
        terraform import github_repository_collaborators.collaborator[\"$repo\"] "$repo"
      done
    done
}


function main {

  case "$1" in
    members)
      import_members
      ;;
    teams)
      import_teams
      ;;
    team-membership)
      import_team_membership
      ;;
    repo-collab)
      import_repo_collaborator
      ;;
    all)
      import_members
      import_teams
      import_team_membership
      import_repo_collaborator
      ;;
    *)
      printf "\n%s" \
        "This script imports Terraform state from a Github Organization" \
        "Designate Github Organization by environment variable GITHUB_ORG" \
        "Eg. export GITHUB_ORG=\"<organization>\"" \
        "" \
        "Usage: $0 [members|teams|team-membership|repo-collab|all]" \
        "" \
        ""
      exit 1
      ;;
  esac

  exit 0
}


GITHUB_TOKEN=${GITHUB_TOKEN:-''}
ORG=${GITHUB_OWNER:-''}

main "$@"

exit 0
