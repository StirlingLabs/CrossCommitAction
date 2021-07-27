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
	elif [[ -n "$GITHUB_ACTOR" ]]; then
		apiUrl="$apiUrl/$GITHUB_ACTOR"
		userNumber=$( curl -H "Authorization: token $GITHUB_TOKEN" -H "$acceptHead" "$apiUrl" | jq '.id' )
		gitUser="$GITHUB_ACTOR"
	fi
	null="null"
	if [[ -n "$userNumber" ]] || [[ "$userNumber" -eq "$null" ]]; then
		gitEmail="$userNumber+$gitUser@users.noreply.github.com"
	fi
	echo "Gonfiguring git with user.name of $gitUser and user.email of $gitEmail"
	git config --global user.name "$gitUser"
	git config --global user.email "$gitEmail"
	git config --global push.default current

	# Clone destination repo
	git clone "$repoUrl" "$TEMP"
	cd "$TEMP"

	# Check if branch exists
	LS_REMOTE="$(git ls-remote --heads origin "refs/heads/$BRANCH")"
	if [[ -n "$LS_REMOTE" ]]; then
		echo "Checking out \"$BRANCH\" from origin."
		git checkout "$BRANCH"
	else
		echo "\"$BRANCH\" does not exist on origin, creating new branch."
		git checkout -b "$BRANCH" --track
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

	# Successfully finish early if there is nothing to commit
	if [ -z "$(git diff-index --quiet HEAD)" ] && [ -n "$LS_REMOTE" ]; then
		echo "nothing to commit"
		exit 0
	fi

	commit_signoff=""
	if [ "${GIT_COMMIT_SIGN_OFF}" = "true" ]; then
		commit_signoff="-s"
	fi

	if [[ -n "$GIT_COMMIT_MSG" ]]; then
		git commit ${commit_signoff} -m "$GIT_COMMIT_MSG"
	else
		shortSHA=$(echo "$GITHUB_SHA" | head -c 6)
		msgHead="Automatic CI SYNC Commit ${shortSHA}"
		msgDetail="Syncing with ${GITHUB_REPOSITORY} commit ${GITHUB_SHA}"
		git commit ${commit_signoff} -m "${msgHead}" -m "${msgDetail}"
	fi

	echo "pushing"
	git push -u origin HEAD
	git remote show origin
}

if [[ "$CI" == "true" ]]; then
	main
fi