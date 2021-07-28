#!/bin/bash

main(){
	set -euo pipefail

	if [ -z "$EXCLUDES" ]; then
		echo "Exclude nothing."
	else
		readarray -t excludeArray <<<"$EXCLUDES"  # split $EXCLUDES to array 
		declare -a EXCLUDES=("--exclude" "${excludeArray[@]}") # Add git command
	fi

	# Create Temporary Directory
	TEMP=$(mktemp -d)

	# strip protocol from repo (if specified)
	REPO="${REPO#http://}"
	REPO="${REPO#https://}"
	repoUrl="https://$REPO"
	# set up user variables for git
	acceptHead="Accept: application/vnd.github.v3+json"
	apiUrl="https://api.github.com/users"
	userNumber=""
	gitUser="Cross Commit Action"
	gitEmail="cross.commit@github.action"

	# Set up git
	if [[ -n "$USER" ]]; then
		if [[ -z "$USER_SECRET" ]]; then
			echo "Error: When using a private repo, must set a USER & PAT (if public, set neither)."
			exit 1
		fi
		repoUrl="https://$USER:$USER_SECRET@$REPO"
		apiUrl="$apiUrl/$USER"
		userNumber=$( curl -H "Authorization: token $GITHUB_TOKEN" -H "$acceptHead" "$apiUrl" | jq '.id' )
		gitUser="$USER"
	fi
	if [[ -n "$GITHUB_ACTOR" ]]; then
		apiUrl="$apiUrl/$GITHUB_ACTOR"
		userNumber=$( curl -H "Authorization: token $GITHUB_TOKEN" -H "$acceptHead" "$apiUrl" | jq '.id' )
		gitUser="$GITHUB_ACTOR"
	fi
	null="null"
	if [[ -n "$userNumber" ]] || [[ "$userNumber" -eq "$null" ]]; then
		gitEmail="$userNumber+$gitUser@users.noreply.github.com"
	fi
	echo "Configuring git with user.name of $gitUser and user.email of $gitEmail"
	git config --global user.name "$gitUser"
	git config --global user.email "$gitEmail"
	gitRemote="$(git remote)"

	# Clone destination repo
	cd "$TEMP"

	# Check if branch exists
	LS_REMOTE="$(git ls-remote "$repoUrl" --heads "refs/heads/$BRANCH")"
	if [[ -n "$LS_REMOTE" ]]; then # branch exists
		echo "\"$BRANCH\" already exists, cloning."
		git clone --recursive --branch "$BRANCH" --single-branch "$repoUrl" "$TEMP"
	else
		echo "\"$BRANCH\" does not exist, will create."
		git clone --recursive "$repoUrl" "$TEMP"
		git branch "$BRANCH"
		git switch "$BRANCH"
	fi

	# Sync $TARGET folder to $REPO state repository, excluding excludes
	f="/"
	if [[ -f "${GITHUB_WORKSPACE}/${SOURCE}" ]]; then
		f=""
	fi
	# echo "running 'rsync -avh --delete ${EXCLUDES[*]} $GITHUB_WORKSPACE/${SOURCE}${f} $TEMP/$TARGET'"
	rsync -avh --delete "${EXCLUDES[@]}" "$GITHUB_WORKSPACE/${SOURCE}${f}" "$TEMP/$TARGET"

	# Success finish early if there are no changes
	# i.e. up to date and branch exists
	if [ -z "$(git status --porcelain)" ] && [ -n "$LS_REMOTE" ]; then
		echo "no changes to sync"
		exit 0
	fi

	# Add changes
	git add --all --verbose "$TARGET"	

	commit_signoff=""
	if [ "${GIT_COMMIT_SIGN_OFF}" = "true" ]; then
		commit_signoff="-s"
	fi

	if [[ -n "$GIT_COMMIT_MSG" ]]; then
		git commit ${commit_signoff} -m "$GIT_COMMIT_MSG" --allow-empty
	else
		shortSHA=$(echo "$GITHUB_SHA" | head -c 6)
		msgHead="Automatic CI SYNC Commit ${shortSHA}"
		msgDetail="Syncing with ${GITHUB_REPOSITORY} commit ${GITHUB_SHA}"
		git commit ${commit_signoff} -m "${msgHead}" -m "${msgDetail}" --allow-empty
	fi

	echo "pushing to $gitRemote"
	git push --set-upstream "$gitRemote" "$BRANCH" --verbose --porcelain
	git remote show origin
}

if [[ "$CI" == "true" ]]; then
	main
fi